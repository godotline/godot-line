@tool
extends CharacterBody3D
class_name Player

static var instance: Player
static var sceneReloadInProgress: bool = false

## ========== 事件信号 ==========
signal OnTurn		## 玩家转向（对齐 Unity Player.OnTurn）

@onready var y: float = $".".position.y
var Speed: float

## ========== Data ==========
@export_group("Data")
@export var levelData: LevelData

## ========== Settings ==========
@export_group("Settings")
@export var sceneCamera: Camera3D
@export var sceneLight: DirectionalLight3D
@export var characterMaterial: Material
@export var alphaMaterial: Material
@export var startPosition: Vector3 = Vector3.ZERO
@export var firstDirection: Vector3 = Vector3(0, 90, 0)
@export var secondDirection: Vector3 = Vector3.ZERO
@export_range(1, 1000, 1, "or_greater") var poolSize: int = 100
@export var playedAnimators: Array[AnimationPlayer] = []
@export var playedTimelines: Array[AnimationPlayer] = []
@export var allowTurn: bool = true
@export var noDeath: bool = false
@export var drawDirection: bool = false:
	set(value):
		drawDirection = value
		if Engine.is_editor_hint():
			update_gizmos()
@export var musicDelay: float = 0.0
@export_range(0.0, 1.0, 0.01) var musicVolume: float = 1.0

@export_group("Editor Tools")
@export_tool_button("Get Start Position", "Position")
var getStartPositionButton: Callable = func() -> void:
	if Engine.is_editor_hint():
		var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
		if undoRedo:
			undoRedo.create_action("Get Start Position")
			undoRedo.add_do_property(self, "startPosition", position)
			undoRedo.add_undo_property(self, "startPosition", startPosition)
			undoRedo.add_do_method(self, "notify_property_list_changed")
			undoRedo.add_undo_method(self, "notify_property_list_changed")
			undoRedo.commit_action()
			return
	startPosition = position
	notify_property_list_changed()

@export_group("Other")
@export var animation: NodePath
@export var deathParticle: PackedScene

var _currentDirection: int = 0

var currentDirection: Vector3:
	get:
		return secondDirection if _currentDirection == 1 else firstDirection

var fly: bool = false
var noclip: bool = false
var isTurn: bool = false
var isEnd: bool = false
var tailHolder: Node3D

@onready var mesh: Mesh = $MeshInstance3D.mesh
@onready var tailPosition: Vector3 = position
@onready var material: StandardMaterial3D = $MeshInstance3D.get_surface_override_material(0)
@onready var tree: SceneTree = get_tree()
@onready var animationNode: AnimationPlayer = get_node(animation) if animation else null

var dustParticle: PackedScene = preload("res://#Template/[Resources]/Dust.tscn")

var managedAnimationStates: Array[Dictionary] = []
var gravityOverride: Vector3 = Vector3.ZERO
var hasGravityOverride: bool = false

var henShin: bool = false
var henshinObject: Node3D
var objectOffset: Vector3 = Vector3.ZERO
var showLineTail: bool = true
var showLineBody: bool = true
var rotationTime: float = 0.0

var timeout: float = 0.1
var isLive: bool = true
var line: MeshInstance3D
var previousFrameIsGrounded: bool = false
var pastIsOnFloorEffect: bool = false

var gameStarts: bool = false
var tailScale: int = 1

var startTransform: Transform3D = transform
var loading: bool = false
var reloadQueued: bool = false
var debug: bool = false
var disallowInput: bool = false

## 标记首次启动延迟是否已应用（复活时不重置，对齐 Unity gameStarts）
var delayApplied: bool = false
var allowCreateTail: bool = true
var didCreateTail: bool = false

## ========== Tail 对象池 ==========
const TAIL_COLLISION_LAYER: int = 1 << 3
const TAIL_COLLISION_MASK: int = (1 << 1) | (1 << 2)
const TAIL_JOIN_OVERLAP: float = 0.025
const TAIL_COLLISION_MARGIN: float = 0.001
const TAIL_INITIAL_LENGTH: float = 1.0
const TAIL_MASS: float = 1000.0
const TAIL_LINEAR_DAMP: float = 1.0
const TAIL_ANGULAR_DAMP: float = 2.0
var tailPool: ObjectPool = ObjectPool.new(100)
var tailBodyPool: ObjectPool = ObjectPool.new(100)

## GameEvents 事件枢纽缓存（惰性获取，对应 Unity Player.Events 属性）
var gameEventsHub: GameEvents = null

## 惰性获取子节点上的 GameEvents 枢纽；不存在时返回 null
func getEvents() -> GameEvents:
	if not is_instance_valid(gameEventsHub):
		gameEventsHub = get_node_or_null("GameEvents") as GameEvents
	return gameEventsHub

## 触发 GameEvents 枢纽事件（对齐 Unity Player.Events?.Invoke(index)）
func emitGameEvent(index: int) -> void:
	var events: GameEvents = getEvents()
	if events:
		events.invoke(index)

func _ready() -> void:
	add_to_group("Player")
	instance = self
	tailPool.size = poolSize
	tailBodyPool.size = poolSize
	if characterMaterial:
		material = characterMaterial
		if $MeshInstance3D:
			$MeshInstance3D.set_surface_override_material(0, characterMaterial)
	elif not material and $MeshInstance3D:
		material = $MeshInstance3D.get_surface_override_material(0)
	if not Engine.is_editor_hint():
		if not LevelManager.cameraCheckpoint.has_checkpoint:
			LevelManager.reset_to_defaults()

		if LevelManager.isEnd == true:
			LevelManager.isEnd = false
			reload()
		if not LevelManager.cameraCheckpoint.has_checkpoint:
			LevelManager.InitPlayerPosition(self, startPosition, false)
		LevelManager.load_checkpoint_to_main_line(self)
		if not levelData:
			push_error("Player.gd: levelData 未设置，无法应用速度")
		else:
			Speed = levelData.speed
		rotation_degrees = currentDirection
		_cache_scene_references()
		_pause_managed_animators()
		emitGameEvent(0)
	if is_inside_tree():
		if levelData:
			levelData.apply_to(self, get_world_3d().space)

	# 实例化 DebugOverlay（调试面板）。对齐 Unity #if UNITY_EDITOR：仅运行时/调试构建生效，编辑器内不挂载
	var debugOverlayScene: PackedScene = load("res://#Template/[Resources]/DebugOverlay.tscn") as PackedScene
	if debugOverlayScene and not Engine.is_editor_hint():
		var overlay: DebugOverlay = debugOverlayScene.instantiate()
		add_child(overlay)

	# 实例化 StartPage（启动界面）
	var startPageScene: PackedScene = load("res://#Template/[Resources]/Prefabs/StartPage.tscn") as PackedScene
	if startPageScene and not Engine.is_editor_hint():
		# 加载持久化设置（对齐 Unity PlayerPrefs）
		var saved: Dictionary = SetLatency.load_settings()
		musicDelay = saved.delay
		musicVolume = saved.volume
		GraphicsQuality.load_settings()

		var page: StartPage = startPageScene.instantiate()
		add_child(page)
		page.set_setting("latency", musicDelay)
		page.set_setting("volume", musicVolume)
		page.set_setting("quality", GraphicsQuality.get_quality_label())
		page.set_setting("antialiasing", GraphicsQuality.get_antialiasing_label())
		page.shadowCheckbox.button_pressed = GraphicsQuality.shadowsEnabled
		page.postCheckbox.button_pressed = GraphicsQuality.postProcessEnabled
		page.start_requested.connect(_on_start_from_startpage)
		page.setting_changed.connect(_on_setting_changed)
		page.shadow_toggled.connect(_on_shadow_toggled)
		page.post_toggled.connect(_on_post_toggled)
		GraphicsQuality.apply_to_scene(get_viewport(), get_tree(), get_scene_environment())
	if not Engine.is_editor_hint():
		call_deferred("_clear_scene_reload_guard")

func _clear_scene_reload_guard() -> void:
	sceneReloadInProgress = false

func _on_start_from_startpage() -> void:
	Turn()

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and (isLive or LevelManager.GameState == LevelManager.GameStatus.Moving):
		# Unity 版在 Update() 中推进水平位移；物理帧只处理垂直运动和碰撞状态。
		var horizontalVelocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity += get_current_gravity() * delta
		move_and_slide()
		velocity.x = horizontalVelocity.x
		velocity.z = horizontalVelocity.z
		if isLive and is_on_wall() and not noDeath and LevelManager.GameState == LevelManager.GameStatus.Playing:
			# 对齐 Unity Player.cs：!showLineBody 时传 null cubesPrefab
			PlayerDeath(showLineBody)
		if fly:
			$".".position.y = y

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or (not isLive and LevelManager.GameState != LevelManager.GameStatus.Moving) or LevelManager.GameState == LevelManager.GameStatus.Waiting:
		return

	if LevelManager.GameState == LevelManager.GameStatus.Playing or LevelManager.GameState == LevelManager.GameStatus.Moving:
		_move_head(delta)

	var isOnFloorNow: bool = is_on_floor() or fly
	if LevelManager.GameState == LevelManager.GameStatus.Playing or LevelManager.GameState == LevelManager.GameStatus.Moving:
		if isOnFloorNow and not pastIsOnFloorEffect:
			_play_land_effect()
			emitGameEvent(4)
	pastIsOnFloorEffect = isOnFloorNow

	if isOnFloorNow:
		if previousFrameIsGrounded != isOnFloorNow:
			new_line()
		if line:
			var tailPosition: Vector3 = position
			tailPosition.y = self.tailPosition.y
			var offset: Vector3 = tailPosition - self.tailPosition
			var distance: float = offset.length()
			var center: Vector3 = self.tailPosition + offset / 2

			_update_tail_body(line, center, distance)
	else:
		if previousFrameIsGrounded != isOnFloorNow:
			line = null
			emitGameEvent(3)
	previousFrameIsGrounded = isOnFloorNow

	if henShin:
		didCreateTail = false
		if is_instance_valid(henshinObject):
			henshinObject.global_position = global_position + objectOffset
		if not showLineTail:
			line = null
			allowCreateTail = false
		if $MeshInstance3D:
			$MeshInstance3D.visible = showLineBody
	else:
		if not didCreateTail:
			allowCreateTail = true
			if isOnFloorNow:
				new_line()
			if $MeshInstance3D:
				$MeshInstance3D.visible = true
			didCreateTail = true

func _move_head(delta: float) -> void:
	var forward: Vector3 = basis * Vector3.BACK
	position += forward * Speed * delta

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		# StartPage 显示时，鼠标点击由 StartPage 的信号处理
		if not gameStarts and event is InputEventMouseButton:
			var page: CanvasLayer = get_node_or_null("StartPage") as CanvasLayer
			if page and page.visible:
				return
		var canStart: bool = LevelManager.GameState == LevelManager.GameStatus.Waiting and not gameStarts
		var canPlay: bool = LevelManager.GameState == LevelManager.GameStatus.Playing and not disallowInput
		# Autoplay blocks gameplay turns, but Unity still accepts the click that starts a revived run.
		if event.is_action_pressed("turn") and isLive and allowTurn and (canStart or canPlay):
			Turn()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				if not Engine.is_editor_hint() and not loading:
					loading = true
					reload()
			KEY_K:
				if not Engine.is_editor_hint() and LevelManager.GameState == LevelManager.GameStatus.Playing:
					PlayerDeath(true, LevelManager.GameStatus.Died, false)
			KEY_D:
				if OS.is_debug_build():
					debug = not debug
			KEY_C:
				if Engine.is_editor_hint() and $MusicPlayer.playing:
					print("Music time: %.3f" % $MusicPlayer.get_playback_position())

func reload() -> void:
	if reloadQueued or sceneReloadInProgress:
		return
	reloadQueued = true
	sceneReloadInProgress = true
	LevelManager.mainLineTransform = Transform3D(Basis.from_euler(firstDirection * (PI / 180.0)), startPosition)
	LevelManager.revivePosition = startPosition
	LevelManager.reset_camera_checkpoint()
	LevelManager.playerDirectionIndex = _currentDirection
	LevelManager.playerFirstDirection = firstDirection
	LevelManager.playerSecondDirection = secondDirection
	LevelManager.animTime = 0.0
	_clear_tail()
	call_deferred("_reload_current_scene")

func _reload_current_scene() -> void:
	if not is_inside_tree():
		reloadQueued = false
		return
	var currentScene: Node = tree.current_scene
	if not is_instance_valid(currentScene):
		reloadQueued = false
		sceneReloadInProgress = false
		loading = false
		push_error("Player.gd: 当前场景为空，无法重新加载关卡")
		return
	var reloadError: Error = tree.reload_current_scene()
	if reloadError != OK:
		reloadQueued = false
		sceneReloadInProgress = false
		loading = false
		push_error("Player.gd: 重新加载关卡失败，错误码: %s" % reloadError)

func ClearPool() -> void:
	line = null
	tailPosition = position
	var holder: Node3D = _get_or_create_player_tail_holder()
	if holder:
		for child in holder.get_children():
			if is_instance_valid(child):
				child.queue_free()
	tailPool.DestoryAll()
	tailBodyPool.DestoryAll()

func _clear_tail() -> void:
	ClearPool()

func _return_to_pool(tail: MeshInstance3D) -> void:
	var body: RigidBody3D = tail.get_parent() as RigidBody3D
	if body:
		body.remove_child(tail)
		if body.get_parent():
			body.get_parent().remove_child(body)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
		if not tailBodyPool.is_full():
			tailBodyPool.Add(body)
		else:
			body.queue_free()
	elif tail.get_parent():
		tail.get_parent().remove_child(tail)
	tail.position = Vector3.ZERO
	tail.rotation = Vector3.ZERO
	tail.scale = Vector3.ONE
	tail.visible = false
	if not tailPool.is_full():
		tailPool.Add(tail)
	else:
		tail.queue_free()

func _get_from_pool() -> MeshInstance3D:
	if not tailPool.full:
		var tail: MeshInstance3D = MeshInstance3D.new()
		tailPool.Add(tail)
		return tail
	else:
		var tail: MeshInstance3D = tailPool.First() as MeshInstance3D
		if not is_instance_valid(tail):
			tail = MeshInstance3D.new()
		elif tail.get_parent():
			tail.get_parent().remove_child(tail)
		tailPool.Add(tail)
		return tail

func _get_or_create_player_tail_holder() -> Node3D:
	var root: Node = tree.current_scene
	if not is_instance_valid(root):
		return null

	var holder: Node3D = root.get_node_or_null("PlayerTailHolder") as Node3D
	if not holder:
		holder = Node3D.new()
		holder.name = "PlayerTailHolder"
		root.add_child.call_deferred(holder)

	tailHolder = holder
	return holder

func new_line() -> void:
	if not allowCreateTail:
		return
	var tailHolder: Node3D = _get_or_create_player_tail_holder()
	if not tailHolder:
		return
	_finish_tail_join(line)
	_spawn_corner_tail(position, rotation)
	line = _get_from_pool()
	line.name = "TailMesh"
	line.mesh = mesh
	line.position = Vector3.ZERO
	line.rotation = Vector3.ZERO
	var initialScale: Vector3 = Vector3.ONE
	line.scale = initialScale
	line.set_surface_override_material(0, material)
	line.visible = showLineTail or not henShin

	var body: RigidBody3D = _create_tail_body()
	tailPosition = position
	body.position = position
	body.rotation = rotation
	tailHolder.add_child(body)
	body.add_child(line)
	_update_tail_collision(line, initialScale)

func _finish_tail_join(tail: MeshInstance3D) -> void:
	var halfWidth: float = float(tailScale) * 0.5
	if not is_instance_valid(tail):
		return

	var body: RigidBody3D = tail.get_parent() as RigidBody3D
	if not body:
		return

	var previousForward: Vector3 = body.basis * Vector3.BACK
	previousForward.y = 0.0
	previousForward = previousForward.normalized()
	var currentForward: Vector3 = basis * Vector3.BACK
	currentForward.y = 0.0
	currentForward = currentForward.normalized()

	var directionDot: float = clampf(previousForward.dot(currentForward), -1.0, 1.0)
	var angle: float = rad_to_deg(acos(directionDot))
	var joinOffset: float
	if angle <= 90.0:
		joinOffset = halfWidth * tan(deg_to_rad(angle * 0.5))
	else:
		joinOffset = -halfWidth * tan(deg_to_rad((180.0 - angle) * 0.5))

	var horizontalOffset: Vector3 = position - tailPosition
	horizontalOffset.y = 0.0
	if horizontalOffset.length() < TAIL_INITIAL_LENGTH:
		_update_tail_body(tail, tailPosition, TAIL_INITIAL_LENGTH)
		return
	var end: Vector3 = tailPosition + previousForward * (horizontalOffset.length() + joinOffset + TAIL_JOIN_OVERLAP)
	end.y = tailPosition.y
	var joinLength: float = maxf(tailPosition.distance_to(end), TAIL_INITIAL_LENGTH)
	_update_tail_body(tail, (tailPosition + end) / 2, joinLength)

func _create_tail_body() -> RigidBody3D:
	if not tailBodyPool.full:
		var body: RigidBody3D = RigidBody3D.new()
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var box: BoxShape3D = BoxShape3D.new()
		box.margin = TAIL_COLLISION_MARGIN
		collision.shape = box
		body.add_child(collision)
		tailBodyPool.Add(body)
		body.name = "TailRigidBody"
		_configure_tail_physics(body)
		return body
	else:
		var body: RigidBody3D = tailBodyPool.First() as RigidBody3D
		if not is_instance_valid(body):
			body = RigidBody3D.new()
			var collision: CollisionShape3D = CollisionShape3D.new()
			collision.name = "CollisionShape3D"
			var box: BoxShape3D = BoxShape3D.new()
			box.margin = TAIL_COLLISION_MARGIN
			collision.shape = box
			body.add_child(collision)
		elif body.get_parent():
			body.get_parent().remove_child(body)
		tailBodyPool.Add(body)
		body.name = "TailRigidBody"
		_configure_tail_physics(body)
		return body

func _configure_tail_physics(body: RigidBody3D) -> void:
	body.collision_layer = TAIL_COLLISION_LAYER
	body.collision_mask = TAIL_COLLISION_MASK
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.mass = TAIL_MASS
	body.linear_damp = TAIL_LINEAR_DAMP
	body.angular_damp = TAIL_ANGULAR_DAMP
	body.axis_lock_linear_x = true
	body.axis_lock_linear_z = true
	body.axis_lock_angular_x = false
	body.axis_lock_angular_y = false
	body.axis_lock_angular_z = true
	body.gravity_scale = 0.0
	body.constant_force = Vector3(0.0, get_current_gravity().y * body.mass, 0.0)
	body.freeze = false
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false

	var physicsMaterial: PhysicsMaterial = PhysicsMaterial.new()
	physicsMaterial.friction = 1.0
	physicsMaterial.rough = true
	physicsMaterial.bounce = 0.0
	physicsMaterial.absorbent = true
	body.physics_material_override = physicsMaterial

func _update_tail_body(tail: MeshInstance3D, _center: Vector3, length: float) -> void:
	var body: RigidBody3D = tail.get_parent() as RigidBody3D
	if not body:
		return
	var tailScale: Vector3 = Vector3(1.0, 1.0, length)
	tail.scale = tailScale
	tail.position = Vector3(0, 0, length * 0.5)
	_update_tail_collision(tail, tailScale)

func _update_tail_collision(tail: MeshInstance3D, tailScale: Vector3) -> void:
	var body: RigidBody3D = tail.get_parent() as RigidBody3D
	if not body or not tail.mesh:
		return
	var collision: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision or not collision.shape is BoxShape3D:
		return
	var meshAabb: AABB = tail.mesh.get_aabb()
	var box: BoxShape3D = collision.shape as BoxShape3D
	box.size = meshAabb.size * tailScale.abs()
	collision.position = tail.position + meshAabb.get_center() * tailScale

func _spawn_corner_tail(atPosition: Vector3, atRotation: Vector3) -> void:
	# 拐角只保留一个可模拟刚体，避免无碰撞网格盖住真正的物理尾。
	var body: RigidBody3D = _create_tail_body()
	body.name = "CornerTail"
	body.position = atPosition
	body.rotation = atRotation

	var tailMesh: MeshInstance3D = _get_from_pool()
	tailMesh.name = "TailMesh"
	tailMesh.mesh = mesh
	tailMesh.position = Vector3.ZERO
	tailMesh.rotation = Vector3.ZERO
	tailMesh.scale = Vector3.ONE
	tailMesh.set_surface_override_material(0, material)
	tailMesh.visible = showLineTail or not henShin

	var tailHolder: Node3D = _get_or_create_player_tail_holder()
	tailHolder.add_child(body)
	body.add_child(tailMesh)
	_update_tail_collision(tailMesh, Vector3.ONE)

func get_current_gravity() -> Vector3:
	if hasGravityOverride:
		return gravityOverride
	return levelData.gravity if levelData else Vector3(0.0, -9.8, 0.0)

func set_gravity_override(value: Vector3) -> void:
	gravityOverride = value
	hasGravityOverride = true

func clear_gravity_override() -> void:
	gravityOverride = Vector3.ZERO
	hasGravityOverride = false

func get_scene_camera() -> Camera3D:
	if not is_instance_valid(sceneCamera):
		sceneCamera = get_viewport().get_camera_3d()
	return sceneCamera

func get_scene_light() -> DirectionalLight3D:
	if not is_instance_valid(sceneLight):
		sceneLight = get_tree().get_first_node_in_group("scene_light") as DirectionalLight3D
	if not is_instance_valid(sceneLight) and get_tree().current_scene:
		var lights: Array[Node] = get_tree().current_scene.find_children("*", "DirectionalLight3D", true, false)
		if not lights.is_empty():
			sceneLight = lights[0] as DirectionalLight3D
	return sceneLight

func get_scene_environment() -> Environment:
	var camera: Camera3D = get_scene_camera()
	if camera and camera.get_environment():
		return camera.get_environment()
	return get_world_3d().environment

func _cache_scene_references() -> void:
	get_scene_camera()
	get_scene_light()

func ResetHenshinState() -> void:
	if henshinObject:
		henshinObject.visible = false
	henShin = false
	henshinObject = null
	objectOffset = Vector3.ZERO
	showLineTail = true
	showLineBody = true
	rotationTime = 0.0
	$MeshInstance3D.visible = true

func _sync_henshin_rotation() -> void:
	if not henShin or not is_instance_valid(henshinObject):
		return
	if rotationTime <= 0.0:
		henshinObject.rotation_degrees = rotation_degrees
		return
	henshinObject.create_tween().tween_property(henshinObject, "rotation_degrees", rotation_degrees, rotationTime)

## 捕获受管动画状态。manualGameTime >= 0 时（检查点 AutoRecord 关闭），
## 时间轴进度按检查点授权的音乐时间记录而非实际位置（对齐 Unity GetTimelineProgresses）
func capture_managed_animation_state(manualGameTime: float = -1.0) -> void:
	managedAnimationStates.clear()
	for animator: AnimationPlayer in playedAnimators:
		if animator and not animator.current_animation.is_empty():
			managedAnimationStates.append({
				"animator": animator,
				"animation": animator.current_animation,
				"position": animator.current_animation_position,
				"playing": animator.is_playing()
			})
	var timelinePosition: float = manualGameTime
	for timeline: AnimationPlayer in playedTimelines:
		if timeline and not timeline.current_animation.is_empty():
			if manualGameTime < 0.0:
				timelinePosition = timeline.current_animation_position
			managedAnimationStates.append({
				"animator": timeline,
				"animation": timeline.current_animation,
				"position": timelinePosition,
				"playing": timeline.is_playing()
			})

func restore_managed_animation_state() -> void:
	for state: Dictionary in managedAnimationStates:
		var animator: AnimationPlayer = state.get("animator") as AnimationPlayer
		if not animator:
			continue
		var animationName: StringName = state.get("animation", StringName()) as StringName
		if animationName.is_empty() or not animator.has_animation(animationName):
			continue
		animator.play(animationName)
		animator.seek(state.get("position", 0.0) as float, true)
		if not (state.get("playing", false) as bool):
			animator.pause()

func _pause_managed_animators() -> void:
	for animator: AnimationPlayer in playedAnimators:
		if animator:
			animator.pause()
	for timeline: AnimationPlayer in playedTimelines:
		if timeline:
			timeline.pause()

func _resume_managed_animators() -> void:
	for animator: AnimationPlayer in playedAnimators:
		if animator and not animator.current_animation.is_empty():
			animator.play()
	for timeline: AnimationPlayer in playedTimelines:
		if timeline and not timeline.current_animation.is_empty():
			timeline.play()

func _resume_fake_players() -> void:
	for fakeNode: Node in get_tree().get_nodes_in_group("fake_players"):
		var fake: FakePlayer = fakeNode as FakePlayer
		if fake and fake.playing:
			fake.state = FakePlayer.State.Moving

func _play_land_effect() -> void:
	var dust: CPUParticles3D = dustParticle.instantiate() as CPUParticles3D
	get_tree().current_scene.add_child(dust)
	dust.global_position = global_position + Vector3(0, -0.5, 0)
	dust.restart()
	dust.emitting = true
	dust.get_tree().create_timer(2.0).timeout.connect(dust.queue_free)

func Turn() -> void:
	if not (is_on_floor() or fly):
		return

	# 动画设置 — 所有路径都立即执行
	if animationNode and not animationNode.is_playing():
		if LevelManager.lineCrossingCrown == 0 and not $MusicPlayer.stream_paused:
			LevelManager.animTime = 0
		animationNode.play("level")
		animationNode.seek(LevelManager.animTime)

	if gameStarts:
		# 常规转向
		emit_signal("OnTurn")
		emitGameEvent(2)
		_currentDirection = 1 - _currentDirection
		rotation_degrees = currentDirection
		_sync_henshin_rotation()
		velocity = to_global(Vector3(0, 0, 1) * Speed) - position
		new_line()
		_play_music_from_level_data()
	else:
		# —— 首次转向（游戏启动）——
		gameStarts = true
		var page: CanvasLayer = get_node_or_null("StartPage") as CanvasLayer
		if page and page is CanvasLayer:
			page.hide_animated()
		emitGameEvent(1)
		# 对齐 Unity Player.cs：开局隐藏鼠标（死亡 / 结算时由 LevelUI 恢复显示）
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		rotation_degrees = currentDirection
		_sync_henshin_rotation()
		_resume_managed_animators()

		if delayApplied:
			_play_music_from_level_data()
			LevelManager.GameState = LevelManager.GameStatus.Playing
			_resume_fake_players()
			velocity = to_global(Vector3(0, 0, 1) * Speed) - position
			new_line()
		elif musicDelay > 0:
			delayApplied = true
			# 正值：线立即移动，音乐延后播放（对齐 Unity delay > 0 分支）
			LevelManager.GameState = LevelManager.GameStatus.Playing
			_resume_fake_players()
			velocity = to_global(Vector3(0, 0, 1) * Speed) - position
			new_line()
			get_tree().create_timer(musicDelay).timeout.connect(_play_music_from_level_data)
		elif musicDelay < 0:
			delayApplied = true
			# 负值：音乐立即播放，线原地不动等待后移动（对齐 Unity delay < 0 分支）
			_play_music_from_level_data()
			get_tree().create_timer(-musicDelay).timeout.connect(_start_game_after_delay)
		else:
			delayApplied = true
			# 零值：音画同步启动（原行为）
			LevelManager.GameState = LevelManager.GameStatus.Playing
			_resume_fake_players()
			velocity = to_global(Vector3(0, 0, 1) * Speed) - position
			new_line()
			_play_music_from_level_data()

## 从 levelData 启动音乐播放（处理 stream_paused / not playing 两种情况）
func _play_music_from_level_data() -> void:
	if not levelData or not levelData.levelAudioClip:
		return
	if $MusicPlayer.stream_paused:
		$MusicPlayer.stream_paused = false
		$MusicPlayer.volume_db = linear_to_db(max(musicVolume, 0.001))
	elif not $MusicPlayer.playing:
		$MusicPlayer.stream = levelData.levelAudioClip
		var startTime: float = levelData.get_audio_start_time()
		_play_music(startTime)

## 播放音乐，补偿系统音频延迟（AudioServer）并应用用户音量设置
## latency: AudioServer.get_output_latency() — 系统硬件延迟自动补偿
## musicVolume: 用户手动调节的音量
func _play_music(startTime: float) -> void:
	$MusicPlayer.volume_db = linear_to_db(max(musicVolume, 0.001))
	var latency: float = AudioServer.get_output_latency()
	if latency > 0.0:
		var adjustedTime: float = max(startTime - latency, 0.0)
		$MusicPlayer.play(adjustedTime)
	else:
		$MusicPlayer.play(startTime)


## musicDelay < 0 时：timer 回调，启动游戏移动（对齐 Unity delay < 0 分支的 yield 之后逻辑）
func _start_game_after_delay() -> void:
	LevelManager.GameState = LevelManager.GameStatus.Playing
	_resume_fake_players()
	velocity = to_global(Vector3(0, 0, 1) * Speed) - position

	new_line()

func _on_Area_body_entered(_body: Node) -> void:
	if not isLive or noDeath:
		return

	# 对齐 Unity Player.cs：!showLineBody 时传 null cubesPrefab，不爆方块不播音效
	PlayerDeath(showLineBody)
func PlayerDeath(spawn_particles: bool = true, death_state: LevelManager.GameStatus = LevelManager.GameStatus.Died, hasCollision: bool = true) -> void:
	if !noclip:
		isLive = false
		LevelManager.GameState = death_state
		emitGameEvent(5)
		if death_state == LevelManager.GameStatus.Died:
			velocity = Vector3.ZERO
		if animationNode: animationNode.pause()
		if is_instance_valid(LevelManager.currentCheckpoint):
			LevelManager.GameOverRevive()
		else:
			LevelManager.GameOverNormal(false)
		AudioManager.FadeOut()
		if spawn_particles:
			$AudioStreamPlayer.play()

		if not spawn_particles or not deathParticle or not hasCollision:
			return

		var deathParticleInstance: Node3D = deathParticle.instantiate() as Node3D
		deathParticleInstance.add_to_group("death_particles")
		var parent: Node = get_parent()
		if not parent:
			push_error("Player.gd: 不在场景树中，无法生成死亡粒子")
			return
		parent.add_child(deathParticleInstance)
		deathParticleInstance.global_position = global_position
		deathParticleInstance.rotation = rotation
		var playerCubes: PlayerCubes = deathParticleInstance as PlayerCubes
		if playerCubes:
			playerCubes.play()

## StartPage 设置变化回调：更新 Player 字段 + 立即持久化 + 实时应用音量
## 对齐 Unity SetLatency.cs 的 AddLatency/SubtractLatency/AddVolume/SubtractVolume + SetText + PlayerPrefs.SetFloat
func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"latency":
			musicDelay = float(value)
			SetLatency.save_settings(musicDelay, musicVolume)
		"volume":
			musicVolume = float(value)
			if $MusicPlayer.playing:
				$MusicPlayer.volume_db = linear_to_db(max(musicVolume, 0.001))
			SetLatency.save_settings(musicDelay, musicVolume)
		"quality":
			var qualityLevel: int = GraphicsQuality.quality_level_from_value(value)
			GraphicsQuality.set_level(qualityLevel)
			# 对齐 Unity SetQuality：任意图形项变更都立即全套重应用（含阴影图集分辨率 / 后处理），而非仅刷新可见性分组
			GraphicsQuality.apply_to_scene(get_viewport(), get_tree(), get_scene_environment())
			GraphicsQuality.save_settings()
		"antialiasing":
			GraphicsQuality.antiAliasLevel = GraphicsQuality.antialiasing_level_from_value(value)
			GraphicsQuality.apply_to_scene(get_viewport(), get_tree(), get_scene_environment())
			GraphicsQuality.save_settings()

func _on_shadow_toggled(isOn: bool) -> void:
	GraphicsQuality.shadowsEnabled = isOn
	GraphicsQuality.apply_to_scene(get_viewport(), get_tree(), get_scene_environment())
	GraphicsQuality.save_settings()

func _on_post_toggled(isOn: bool) -> void:
	GraphicsQuality.postProcessEnabled = isOn
	GraphicsQuality.apply_to_scene(get_viewport(), get_tree(), get_scene_environment())
	GraphicsQuality.save_settings()
