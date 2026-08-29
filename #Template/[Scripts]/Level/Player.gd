@tool
extends RigidBody3D
class_name Player

static var instance: Player
static var sceneReloadInProgress: bool = false

const HIT_CLIP: AudioStream = preload("res://#Template/[Resources]/Hit.wav")
const DROWNED_CLIP: AudioStream = preload("res://#Template/[Resources]/WaterDie.wav")
const GROUNDED_RAY_START_OFFSET: float = 0.1
const GROUNDED_RAY_DISTANCE: float = 0.05

## ========== 事件信号 ==========
signal OnTurn		## 玩家转向（对齐 Unity Player.OnTurn）

@onready var y: float = $".".position.y
var Speed: float
var SoundTrack: AudioStreamPlayer = null

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
var getStartPositionButton: Callable = GetStartPosition

func GetStartPosition() -> void:
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
@onready var collisionShape: CollisionShape3D = $CollisionShape3D
var groundRays: Array[RayCast3D] = []
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
const TAIL_COLLISION_MARGIN: float = 0.001
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
	var frontLeft: RayCast3D = $GroundRayFrontLeft
	var frontRight: RayCast3D = $GroundRayFrontRight
	var backLeft: RayCast3D = $GroundRayBackLeft
	var backRight: RayCast3D = $GroundRayBackRight
	groundRays = [
		frontLeft,
		frontRight,
		backLeft,
		backRight
	]
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
		Timeline.Reset()
		emitGameEvent(0)
	if is_inside_tree():
		if levelData:
			levelData.apply_to(self, get_world_3d().space)
		_configureGroundRays()

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

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if fly:
		axis_lock_linear_y = true
		linear_velocity.y = 0.0
		position.y = y
	else:
		axis_lock_linear_y = false

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or (not isLive and LevelManager.GameState != LevelManager.GameStatus.Moving) or LevelManager.GameState == LevelManager.GameStatus.Waiting:
		return

	if LevelManager.GameState == LevelManager.GameStatus.Playing or LevelManager.GameState == LevelManager.GameStatus.Moving:
		_move_head(delta)

	var isOnFloorNow: bool = checkGrounded() or fly
	if LevelManager.GameState == LevelManager.GameStatus.Playing or LevelManager.GameState == LevelManager.GameStatus.Moving:
		if isOnFloorNow and not pastIsOnFloorEffect:
			_play_land_effect()
			emitGameEvent(4)
	pastIsOnFloorEffect = isOnFloorNow

	if isOnFloorNow:
		if previousFrameIsGrounded != isOnFloorNow:
			CreateTail()
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
				CreateTail()
			if $MeshInstance3D:
				$MeshInstance3D.visible = true
			didCreateTail = true

func _syncPhysicsXZ() -> void:
	var physicsTransform: Transform3D = PhysicsServer3D.body_get_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	var synced: Transform3D = global_transform
	synced.origin.y = physicsTransform.origin.y
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, synced)
	global_transform = synced

func _move_head(delta: float) -> void:
	var forward: Vector3 = basis * Vector3.BACK
	position += forward * Speed * delta
	_syncPhysicsXZ()

func checkGrounded() -> bool:
	# RayCast3D 的碰撞结果由物理帧更新；普通帧/输入回调只读取缓存，避免访问 Jolt 空间。
	for groundRay: RayCast3D in groundRays:
		if groundRay and groundRay.is_colliding():
			return true
	return false

func _configureGroundRays() -> void:
	if not collisionShape or not collisionShape.shape is BoxShape3D:
		return

	var box: BoxShape3D = collisionShape.shape as BoxShape3D
	var halfSize: Vector3 = box.size * 0.5
	var rayPositions: Array[Vector3] = [
		collisionShape.position + Vector3(-halfSize.x, -halfSize.y + GROUNDED_RAY_START_OFFSET, -halfSize.z),
		collisionShape.position + Vector3(halfSize.x, -halfSize.y + GROUNDED_RAY_START_OFFSET, -halfSize.z),
		collisionShape.position + Vector3(-halfSize.x, -halfSize.y + GROUNDED_RAY_START_OFFSET, halfSize.z),
		collisionShape.position + Vector3(halfSize.x, -halfSize.y + GROUNDED_RAY_START_OFFSET, halfSize.z)
	]
	for index: int in range(groundRays.size()):
		var groundRay: RayCast3D = groundRays[index]
		if groundRay:
			groundRay.position = rayPositions[index]
			groundRay.target_position = Vector3(0.0, -(GROUNDED_RAY_DISTANCE + GROUNDED_RAY_START_OFFSET), 0.0)

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
					PlayerDeath(LevelManager.DieReason.Hit, false, true, false)
			KEY_D:
				if OS.is_debug_build():
					debug = not debug
			KEY_C:
				if Engine.is_editor_hint() and SoundTrack and SoundTrack.playing:
					print("Music time: %.3f" % SoundTrack.get_playback_position())

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

func CreateTail() -> void:
	if not allowCreateTail:
		return
	var tailHolder: Node3D = _get_or_create_player_tail_holder()
	if not tailHolder:
		return

	var nowForward: Vector3 = basis * Vector3.BACK
	nowForward.y = 0.0
	if nowForward.length_squared() > 0.0:
		nowForward = nowForward.normalized()
	var joinOffset: float = 0.5
	if is_instance_valid(line):
		var previousBody: RigidBody3D = line.get_parent() as RigidBody3D
		if previousBody:
			var previousForward: Vector3 = previousBody.basis * Vector3.BACK
			previousForward.y = 0.0
			if previousForward.length_squared() > 0.0:
				previousForward = previousForward.normalized()
			var directionDot: float = clampf(previousForward.dot(nowForward), -1.0, 1.0)
			var angle: float = rad_to_deg(acos(directionDot))
			if angle <= 90.0:
				joinOffset = 0.5 * tan(deg_to_rad(angle * 0.5))
			else:
				joinOffset = -0.5 * tan(deg_to_rad((180.0 - angle) * 0.5))
			var horizontalOffset: Vector3 = position - tailPosition
			horizontalOffset.y = 0.0
			var end: Vector3 = tailPosition + previousForward * (horizontalOffset.length() + joinOffset)
			_update_tail_body(line, Vector3.ZERO, tailPosition.distance_to(end))

	tailPosition = position - nowForward * absf(joinOffset)
	line = _get_from_pool()
	line.name = "TailMesh"
	line.mesh = mesh
	line.position = Vector3.ZERO
	line.rotation = Vector3.ZERO
	line.scale = Vector3.ONE
	line.set_surface_override_material(0, material)
	line.visible = showLineTail or not henShin

	var body: RigidBody3D = _create_tail_body()
	body.position = tailPosition
	body.rotation = rotation
	tailHolder.add_child(body)
	body.add_child(line)
	_update_tail_body(line, Vector3.ZERO, position.distance_to(tailPosition))

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

func get_current_gravity() -> Vector3:
	if hasGravityOverride:
		return gravityOverride
	return levelData.gravity if levelData else Vector3(0.0, -9.8, 0.0)

func set_gravity_override(value: Vector3) -> void:
	gravityOverride = value
	hasGravityOverride = true
	gravity_scale = 0.0
	constant_force = value * mass

func clear_gravity_override() -> void:
	gravityOverride = Vector3.ZERO
	hasGravityOverride = false
	gravity_scale = 1.0
	constant_force = Vector3.ZERO

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
func GetAnimatorProgresses() -> void:
	managedAnimationStates.clear()
	for animator: AnimationPlayer in playedAnimators:
		if animator and not animator.current_animation.is_empty():
			managedAnimationStates.append({
				"animator": animator,
				"animation": animator.current_animation,
				"position": animator.current_animation_position,
				"playing": animator.is_playing()
			})

func SetAnimatorProgresses() -> void:
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

func _resume_managed_animators() -> void:
	for animator: AnimationPlayer in playedAnimators:
		if animator and not animator.current_animation.is_empty():
			animator.play()

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
	if not (checkGrounded() or fly):
		return

	# 动画设置 — 所有路径都立即执行
	if animationNode and not animationNode.is_playing():
		if LevelManager.lineCrossingCrown == 0 and (not SoundTrack or not SoundTrack.stream_paused):
			LevelManager.animTime = 0
		animationNode.play("level")
		animationNode.seek(LevelManager.animTime)

	if gameStarts:
		_currentDirection = 1 - _currentDirection
		rotation_degrees = currentDirection
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
		_sync_henshin_rotation()
		linear_velocity = Vector3.ZERO
		CreateTail()
		emit_signal("OnTurn")
		emitGameEvent(2)
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
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
		_sync_henshin_rotation()
		_resume_managed_animators()
		Timeline.Play()

		if delayApplied:
			_play_music_from_level_data()
			LevelManager.GameState = LevelManager.GameStatus.Playing
			_resume_fake_players()
			linear_velocity = Vector3.ZERO
			CreateTail()
		elif musicDelay > 0:
			delayApplied = true
			# 正值：线立即移动，音乐延后播放（对齐 Unity delay > 0 分支）
			LevelManager.GameState = LevelManager.GameStatus.Playing
			_resume_fake_players()
			linear_velocity = Vector3.ZERO
			CreateTail()
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
			linear_velocity = Vector3.ZERO
			CreateTail()
			_play_music_from_level_data()

## 从 levelData 启动音乐播放（处理 stream_paused / not playing 两种情况）
func _play_music_from_level_data() -> void:
	if not levelData or not levelData.levelAudioClip:
		return
	if not SoundTrack:
		SoundTrack = AudioManager.PlayTrack(levelData.levelAudioClip, musicVolume)
		if not SoundTrack:
			return
		AudioManager.Stop()
	SoundTrack.pitch_scale = levelData.timeScale
	if SoundTrack.stream_paused:
		SoundTrack.stream_paused = false
		SoundTrack.volume_db = linear_to_db(max(musicVolume, 0.001))
	elif not SoundTrack.playing:
		SoundTrack.stream = levelData.levelAudioClip
		var startTime: float = levelData.get_audio_start_time()
		_play_music(startTime)

## 播放音乐，补偿系统音频延迟（AudioServer）并应用用户音量设置
## latency: AudioServer.get_output_latency() — 系统硬件延迟自动补偿
## musicVolume: 用户手动调节的音量
func _play_music(startTime: float) -> void:
	if not SoundTrack:
		return
	SoundTrack.volume_db = linear_to_db(max(musicVolume, 0.001))
	var latency: float = AudioServer.get_output_latency()
	if latency > 0.0:
		var adjustedTime: float = max(startTime - latency, 0.0)
		SoundTrack.play(adjustedTime)
	else:
		SoundTrack.play(startTime)


## musicDelay < 0 时：timer 回调，启动游戏移动（对齐 Unity delay < 0 分支的 yield 之后逻辑）
func _start_game_after_delay() -> void:
	LevelManager.GameState = LevelManager.GameStatus.Playing
	_resume_fake_players()
	linear_velocity = Vector3.ZERO

	CreateTail()

func _on_Area_body_entered(_body: Node) -> void:
	if not isLive or noDeath or LevelManager.GameState != LevelManager.GameStatus.Playing:
		return

	# 对齐 Unity Player.cs：!showLineBody 时传 null cubesPrefab，仅不生成碎片。
	var revive: bool = LevelManager.checkpointCount > 0 or LevelManager.crown > 0
	PlayerDeath(LevelManager.DieReason.Hit, revive, showLineBody, true)

func RevivePlayer(checkpoint: Node) -> void:
	if checkpoint and checkpoint.has_method("revive"):
		checkpoint.revive()

func PlayerDeath(reason: LevelManager.DieReason = LevelManager.DieReason.Hit, revive: bool = false, spawnCubes: bool = true, hasCollision: bool = true) -> void:
	if noclip:
		return

	isLive = false
	match reason:
		LevelManager.DieReason.Hit:
			LevelManager.GameState = LevelManager.GameStatus.Died
			linear_velocity = Vector3.ZERO
			AudioManager.PlayClip(HIT_CLIP, 1.0)
		LevelManager.DieReason.Drowned:
			LevelManager.GameState = LevelManager.GameStatus.Moving
			AudioManager.PlayClip(DROWNED_CLIP, 1.0)
		LevelManager.DieReason.Border:
			LevelManager.GameState = LevelManager.GameStatus.Moving

	emitGameEvent(5)
	if animationNode:
		animationNode.pause()
	Timeline.Pause()
	AudioManager.FadeOut()

	if reason == LevelManager.DieReason.Hit and spawnCubes and deathParticle and hasCollision:
		var deathParticleInstance: Node3D = deathParticle.instantiate() as Node3D
		deathParticleInstance.add_to_group("death_particles")
		var parent: Node = get_parent()
		if not parent:
			push_error("Player.gd: 不在场景树中，无法生成死亡粒子")
		else:
			parent.add_child(deathParticleInstance)
			deathParticleInstance.global_position = global_position
			deathParticleInstance.rotation = rotation
			var playerCubes: PlayerCubes = deathParticleInstance as PlayerCubes
			if playerCubes:
				playerCubes.play()

	if not revive:
		LevelManager.GameOverNormal(false)
	else:
		LevelManager.GameOverRevive()

## StartPage 设置变化回调：更新 Player 字段 + 立即持久化 + 实时应用音量
## 对齐 Unity SetLatency.cs 的 AddLatency/SubtractLatency/AddVolume/SubtractVolume + SetText + PlayerPrefs.SetFloat
func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"latency":
			musicDelay = float(value)
			SetLatency.save_settings(musicDelay, musicVolume)
		"volume":
			musicVolume = float(value)
			if SoundTrack and SoundTrack.playing:
				SoundTrack.volume_db = linear_to_db(max(musicVolume, 0.001))
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
