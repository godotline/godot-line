@tool
extends CharacterBody3D
class_name Player

static var instance: Player
static var _scene_reload_in_progress: bool = false

## ========== 事件信号（GameEvents 系统） ==========
signal on_game_awake			## 游戏初始化完成
signal on_player_start			## 玩家开始移动（第一次转向）
signal on_change_direction		## 玩家转向
signal on_leave_ground			## 玩家离开地面
signal on_touch_ground			## 玩家落地
signal on_game_over				## 玩家死亡
signal on_game_end				## 游戏结束（死亡或完成）
signal on_get_gem				## 收集宝石
signal on_player_jump			## 玩家跳跃

signal new_line1
signal on_sky
signal onturn

@onready var y: float = $".".position.y
var speed: float
@export var firstDirection: Vector3 = Vector3(0, 0, 0)
@export var secondDirection: Vector3 = Vector3(0, 90, 0)
var _currentDirection: int = 0

var current_direction: Vector3:
	get:
		return secondDirection if _currentDirection == 1 else firstDirection

var fly: bool = false
var noclip: bool = false
@export var animation: NodePath
var is_turn: bool = false
var is_end: bool = false
var tail_holder: Node3D
@export var sceneCamera: Camera3D
@export var sceneLight: DirectionalLight3D
@export var noDeath: bool = false
@export var drawDirection: bool = false
@export var playedAnimators: Array[AnimationPlayer] = []

@onready var mesh: Mesh = $MeshInstance3D.mesh
@onready var past_translation: Vector3 = position
@onready var material: StandardMaterial3D = $MeshInstance3D.get_surface_override_material(0)
@onready var tree: SceneTree = get_tree()
@onready var animation_node: AnimationPlayer = get_node(animation) if animation else null
@onready var land_effect: GPUParticles3D = $LandEffect

var _managed_animation_states: Array[Dictionary] = []
var _gravity_override: Vector3 = Vector3.ZERO
var _has_gravity_override: bool = false

var hen_shin: bool = false
var henshin_object: Node3D
var henshin_offset: Vector3 = Vector3.ZERO
var show_line_tail: bool = true
var show_line_body: bool = true
var henshin_rotation_time: float = 0.0

@export var levelData: LevelData

@export var deathParticle: PackedScene

var timeout: float = 0.1
var is_live: bool = true
var line: MeshInstance3D
var past_is_on_floor: bool = false
var past_is_on_floor_effect: bool = false

var is_start: bool = false
var tailScale: int = 1

var start_transform: Transform3D = transform
var loading: bool = false
var _reload_queued: bool = false
var debug: bool = false
@export var allowTurn: bool = true
var disallowInput: bool = false

## 音画延迟补偿（秒），用户可配置。与 AudioServer.get_output_latency() 独立并存。
var musicDelay: float = 0.0

## 音量 (0.0~1.0)
var musicVolume: float = 1.0

## 标记首次启动延迟是否已应用（复活时不重置，对齐 Unity gameStarts）
var _delay_applied: bool = false

## ========== Tail 对象池 ==========
const TAIL_POOL_SIZE: int = 256
const TAIL_COLLISION_LAYER: int = 1 << 3
const TAIL_COLLISION_MASK: int = (1 << 1) | (1 << 2)
const TAIL_JOIN_OVERLAP: float = 0.025
const TAIL_COLLISION_MARGIN: float = 0.001
const TAIL_INITIAL_LENGTH: float = 1.0
const TAIL_MASS: float = 1000.0
const TAIL_LINEAR_DAMP: float = 1.0
const TAIL_ANGULAR_DAMP: float = 2.0
var _tail_pool: ObjectPool = ObjectPool.new(TAIL_POOL_SIZE)
var _tail_body_pool: ObjectPool = ObjectPool.new(TAIL_POOL_SIZE)

func _ready() -> void:
	instance = self
	if not Engine.is_editor_hint():
		if not LevelManager.camera_checkpoint.has_checkpoint:
			LevelManager.reset_to_defaults()

		if LevelManager.is_end == true:
			LevelManager.is_end = false
			reload()
		LevelManager.load_checkpoint_to_main_line(self)
		if not levelData:
			push_error("Player.gd: levelData 未设置，无法应用速度")
		else:
			speed = levelData.speed
		rotation_degrees = current_direction
		_cache_scene_references()
		_pause_managed_animators()
		emit_signal("on_game_awake")
	if is_inside_tree():
		if levelData:
			levelData.apply_to(self, get_world_3d().space)

	var debug_overlay_scene: PackedScene = load("res://#Template/[Resources]/DebugOverlay.tscn") as PackedScene
	if debug_overlay_scene:
		var overlay: DebugOverlay = debug_overlay_scene.instantiate()
		add_child(overlay)

	# 实例化 StartPage（启动界面）
	var start_page_scene: PackedScene = load("res://#Template/[Resources]/StartPage.tscn") as PackedScene
	if start_page_scene and not Engine.is_editor_hint():
		# 加载持久化设置（对齐 Unity PlayerPrefs）
		var saved: Dictionary = SetLatency.load_settings()
		musicDelay = saved.delay
		musicVolume = saved.volume
		GraphicsQuality.load_settings()

		var page: StartPage = start_page_scene.instantiate()
		add_child(page)
		page.set_setting("latency", musicDelay)
		page.set_setting("volume", musicVolume)
		page.set_setting("quality", GraphicsQuality.get_quality_label())
		page.set_setting("antialiasing", GraphicsQuality.get_antialiasing_label())
		page.shadow_checkbox.button_pressed = GraphicsQuality.shadows_enabled
		page.post_checkbox.button_pressed = GraphicsQuality.post_process_enabled
		page.start_requested.connect(_on_start_from_startpage)
		page.setting_changed.connect(_on_setting_changed)
		page.shadow_toggled.connect(_on_shadow_toggled)
		page.post_toggled.connect(_on_post_toggled)
		GraphicsQuality.apply_to_scene(get_viewport(), get_tree(), get_scene_environment())
	if not Engine.is_editor_hint():
		call_deferred("_clear_scene_reload_guard")

func _clear_scene_reload_guard() -> void:
	_scene_reload_in_progress = false

func _on_start_from_startpage() -> void:
	turn()

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and (is_live or LevelManager.GameState == LevelManager.GameStatus.Moving):
		# Unity 版在 Update() 中推进水平位移；物理帧只处理垂直运动和碰撞状态。
		var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity += get_current_gravity() * delta
		move_and_slide()
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		if is_live and is_on_wall() and not noDeath:
			die()
		if fly:
			$".".position.y = y

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or (not is_live and LevelManager.GameState != LevelManager.GameStatus.Moving):
		return

	if LevelManager.GameState == LevelManager.GameStatus.Playing or LevelManager.GameState == LevelManager.GameStatus.Moving:
		_move_head(delta)

	var is_on_floor_now: bool = is_on_floor() or fly
	if is_on_floor_now and not past_is_on_floor_effect:
		_play_land_effect()
		emit_signal("on_touch_ground")
	past_is_on_floor_effect = is_on_floor_now

	if is_on_floor_now:
		if past_is_on_floor != is_on_floor_now:
			new_line()
		if line:
			var tail_position: Vector3 = position
			tail_position.y = past_translation.y
			var offset: Vector3 = tail_position - past_translation
			var distance: float = offset.length()
			var center: Vector3 = past_translation + offset / 2

			_update_tail_body(line, center, distance)
	else:
		if past_is_on_floor != is_on_floor_now:
			line = null
			emit_signal("on_sky")
			emit_signal("on_leave_ground")
	past_is_on_floor = is_on_floor_now

	if hen_shin and is_instance_valid(henshin_object):
		henshin_object.global_position = global_position + henshin_offset

func _move_head(delta: float) -> void:
	var forward: Vector3 = basis * Vector3.BACK
	position += forward * speed * delta

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		# StartPage 显示时，鼠标点击由 StartPage 的信号处理
		if not is_start and event is InputEventMouseButton:
			var page: CanvasLayer = get_node_or_null("StartPage") as CanvasLayer
			if page and page.visible:
				return
		var canStart: bool = LevelManager.GameState == LevelManager.GameStatus.Waiting and not is_start
		var canPlay: bool = LevelManager.GameState == LevelManager.GameStatus.Playing and not disallowInput
		# Autoplay blocks gameplay turns, but Unity still accepts the click that starts a revived run.
		if event.is_action_pressed("turn") and is_live and allowTurn and (canStart or canPlay):
			turn()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				if not Engine.is_editor_hint() and not loading:
					loading = true
					reload()
			KEY_K:
				if not Engine.is_editor_hint() and (is_live or LevelManager.GameState == LevelManager.GameStatus.Moving):
					die()
			KEY_D:
				if OS.is_debug_build():
					debug = not debug
			KEY_C:
				if Engine.is_editor_hint() and $MusicPlayer.playing:
					print("Music time: %.3f" % $MusicPlayer.get_playback_position())

func reload() -> void:
	if _reload_queued or _scene_reload_in_progress:
		return
	_reload_queued = true
	_scene_reload_in_progress = true
	LevelManager.main_line_transform = start_transform
	LevelManager.reset_camera_checkpoint()
	LevelManager.player_direction_index = _currentDirection
	LevelManager.player_first_direction = firstDirection
	LevelManager.player_second_direction = secondDirection
	LevelManager.anim_time = 0.0
	_clear_tail()
	call_deferred("_reload_current_scene")

func _reload_current_scene() -> void:
	if not is_inside_tree():
		_reload_queued = false
		return
	var current_scene: Node = tree.current_scene
	if not is_instance_valid(current_scene):
		_reload_queued = false
		_scene_reload_in_progress = false
		loading = false
		push_error("Player.gd: 当前场景为空，无法重新加载关卡")
		return
	var reload_error: Error = tree.reload_current_scene()
	if reload_error != OK:
		_reload_queued = false
		_scene_reload_in_progress = false
		loading = false
		push_error("Player.gd: 重新加载关卡失败，错误码: %s" % reload_error)

func _clear_tail() -> void:
	line = null
	past_translation = position
	var holder: Node3D = _get_or_create_player_tail_holder()
	if not holder:
		tail_holder = null
		return
	tail_holder = holder
	for child in tail_holder.get_children():
		var tail: MeshInstance3D = child as MeshInstance3D
		if child is RigidBody3D:
			tail = child.get_node_or_null("TailMesh") as MeshInstance3D
		if tail:
			_return_to_pool(tail)
		else:
			child.queue_free()

func _return_to_pool(tail: MeshInstance3D) -> void:
	var body: RigidBody3D = tail.get_parent() as RigidBody3D
	if body:
		body.remove_child(tail)
		if body.get_parent():
			body.get_parent().remove_child(body)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
		if not _tail_body_pool.is_full():
			_tail_body_pool.add(body)
		else:
			body.queue_free()
	elif tail.get_parent():
		tail.get_parent().remove_child(tail)
	tail.position = Vector3.ZERO
	tail.rotation = Vector3.ZERO
	tail.scale = Vector3.ONE
	tail.visible = false
	if not _tail_pool.is_full():
		_tail_pool.add(tail)
	else:
		tail.queue_free()

func _get_from_pool() -> MeshInstance3D:
	var tail: MeshInstance3D = _tail_pool.pop() as MeshInstance3D
	if not tail:
		return MeshInstance3D.new()
	return tail

func _get_or_create_player_tail_holder() -> Node3D:
	var root: Node = tree.current_scene
	if not is_instance_valid(root):
		return null

	var holder: Node3D = root.get_node_or_null("PlayerTailHolder") as Node3D
	if not holder:
		holder = Node3D.new()
		holder.name = "PlayerTailHolder"
		root.add_child(holder)

	tail_holder = holder
	return holder

func new_line() -> void:
	var tail_holder: Node3D = _get_or_create_player_tail_holder()
	if not tail_holder:
		return
	_finish_tail_join(line)
	_spawn_corner_tail(position, rotation)
	line = _get_from_pool()
	line.name = "TailMesh"
	line.mesh = mesh
	line.position = Vector3.ZERO
	line.rotation = Vector3.ZERO
	var initial_scale: Vector3 = Vector3.ONE
	line.scale = initial_scale
	line.set_surface_override_material(0, material)
	line.visible = show_line_tail or not hen_shin

	var body: RigidBody3D = _create_tail_body()
	past_translation = position
	body.position = position
	body.rotation = rotation
	tail_holder.add_child(body)
	body.add_child(line)
	_update_tail_collision(line, initial_scale)

	emit_signal("new_line1")

func _finish_tail_join(tail: MeshInstance3D) -> void:
	var half_width: float = float(tailScale) * 0.5
	if not is_instance_valid(tail):
		return

	var body: RigidBody3D = tail.get_parent() as RigidBody3D
	if not body:
		return

	var previous_forward: Vector3 = body.basis * Vector3.BACK
	previous_forward.y = 0.0
	previous_forward = previous_forward.normalized()
	var current_forward: Vector3 = basis * Vector3.BACK
	current_forward.y = 0.0
	current_forward = current_forward.normalized()

	var direction_dot: float = clampf(previous_forward.dot(current_forward), -1.0, 1.0)
	var angle: float = rad_to_deg(acos(direction_dot))
	var join_offset: float
	if angle <= 90.0:
		join_offset = half_width * tan(deg_to_rad(angle * 0.5))
	else:
		join_offset = -half_width * tan(deg_to_rad((180.0 - angle) * 0.5))

	var horizontal_offset: Vector3 = position - past_translation
	horizontal_offset.y = 0.0
	if horizontal_offset.length() < TAIL_INITIAL_LENGTH:
		_update_tail_body(tail, past_translation, TAIL_INITIAL_LENGTH)
		return
	var end: Vector3 = past_translation + previous_forward * (horizontal_offset.length() + join_offset + TAIL_JOIN_OVERLAP)
	end.y = past_translation.y
	var join_length: float = maxf(past_translation.distance_to(end), TAIL_INITIAL_LENGTH)
	_update_tail_body(tail, (past_translation + end) / 2, join_length)

func _create_tail_body() -> RigidBody3D:
	var body: RigidBody3D = _tail_body_pool.pop() as RigidBody3D
	if not body:
		body = RigidBody3D.new()
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var box: BoxShape3D = BoxShape3D.new()
		box.margin = TAIL_COLLISION_MARGIN
		collision.shape = box
		body.add_child(collision)
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

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 1.0
	physics_material.rough = true
	physics_material.bounce = 0.0
	physics_material.absorbent = true
	body.physics_material_override = physics_material

func _update_tail_body(tail: MeshInstance3D, _center: Vector3, length: float) -> void:
	var body: RigidBody3D = tail.get_parent() as RigidBody3D
	if not body:
		return
	var tail_scale: Vector3 = Vector3(1.0, 1.0, length)
	tail.scale = tail_scale
	tail.position = Vector3(0, 0, length * 0.5)
	_update_tail_collision(tail, tail_scale)

func _update_tail_collision(tail: MeshInstance3D, tail_scale: Vector3) -> void:
	var body: RigidBody3D = tail.get_parent() as RigidBody3D
	if not body or not tail.mesh:
		return
	var collision: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision or not collision.shape is BoxShape3D:
		return
	var mesh_aabb: AABB = tail.mesh.get_aabb()
	var box: BoxShape3D = collision.shape as BoxShape3D
	box.size = mesh_aabb.size * tail_scale.abs()
	collision.position = tail.position + mesh_aabb.get_center() * tail_scale

func _spawn_corner_tail(at_position: Vector3, at_rotation: Vector3) -> void:
	# 拐角只保留一个可模拟刚体，避免无碰撞网格盖住真正的物理尾。
	var body: RigidBody3D = _create_tail_body()
	body.name = "CornerTail"
	body.position = at_position
	body.rotation = at_rotation

	var tail_mesh: MeshInstance3D = _get_from_pool()
	tail_mesh.name = "TailMesh"
	tail_mesh.mesh = mesh
	tail_mesh.position = Vector3.ZERO
	tail_mesh.rotation = Vector3.ZERO
	tail_mesh.scale = Vector3.ONE
	tail_mesh.set_surface_override_material(0, material)
	tail_mesh.visible = show_line_tail or not hen_shin

	var tail_holder: Node3D = _get_or_create_player_tail_holder()
	tail_holder.add_child(body)
	body.add_child(tail_mesh)
	_update_tail_collision(tail_mesh, Vector3.ONE)

func get_current_gravity() -> Vector3:
	if _has_gravity_override:
		return _gravity_override
	return levelData.gravity if levelData else Vector3(0.0, -9.8, 0.0)

func set_gravity_override(value: Vector3) -> void:
	_gravity_override = value
	_has_gravity_override = true

func clear_gravity_override() -> void:
	_gravity_override = Vector3.ZERO
	_has_gravity_override = false

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

func enable_henshin(model: Node3D, offset: Vector3, show_tail: bool, show_body: bool, rotation_time: float) -> void:
	if not model:
		push_warning("Player.gd: Henshin requires a henshin_object")
		return
	if henshin_object and henshin_object != model:
		henshin_object.visible = false
	hen_shin = true
	henshin_object = model
	henshin_offset = offset
	show_line_tail = show_tail
	show_line_body = show_body
	henshin_rotation_time = rotation_time
	henshin_object.visible = true
	henshin_object.global_position = global_position + henshin_offset
	_sync_henshin_rotation()
	$MeshInstance3D.visible = show_line_body
	if not show_line_tail:
		_clear_tail()

func reset_henshin_state() -> void:
	if henshin_object:
		henshin_object.visible = false
	hen_shin = false
	henshin_object = null
	henshin_offset = Vector3.ZERO
	show_line_tail = true
	show_line_body = true
	henshin_rotation_time = 0.0
	$MeshInstance3D.visible = true

func _sync_henshin_rotation() -> void:
	if not hen_shin or not is_instance_valid(henshin_object):
		return
	if henshin_rotation_time <= 0.0:
		henshin_object.rotation_degrees = rotation_degrees
		return
	henshin_object.create_tween().tween_property(henshin_object, "rotation_degrees", rotation_degrees, henshin_rotation_time)

func capture_managed_animation_state() -> void:
	_managed_animation_states.clear()
	for animator: AnimationPlayer in playedAnimators:
		if animator and not animator.current_animation.is_empty():
			_managed_animation_states.append({
				"animator": animator,
				"animation": animator.current_animation,
				"position": animator.current_animation_position,
				"playing": animator.is_playing()
			})

func restore_managed_animation_state() -> void:
	for state: Dictionary in _managed_animation_states:
		var animator: AnimationPlayer = state.get("animator") as AnimationPlayer
		if not animator:
			continue
		var animation_name: StringName = state.get("animation", StringName()) as StringName
		if animation_name.is_empty() or not animator.has_animation(animation_name):
			continue
		animator.play(animation_name)
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
	for fake_node: Node in get_tree().get_nodes_in_group("fake_players"):
		var fake: FakePlayer = fake_node as FakePlayer
		if fake and fake.playing:
			fake.state = FakePlayer.State.Moving

func _play_land_effect() -> void:
	if is_instance_valid(land_effect):
		land_effect.restart()
		land_effect.emitting = true

func turn() -> void:
	if not (is_on_floor() or fly):
		return

	# 动画设置 — 所有路径都立即执行
	if animation_node and not animation_node.is_playing():
		if LevelManager.line_crossing_crown == 0 and not $MusicPlayer.stream_paused:
			LevelManager.anim_time = 0
		animation_node.play("level")
		animation_node.seek(LevelManager.anim_time)

	if is_start:
		# 常规转向
		emit_signal("onturn")
		emit_signal("on_change_direction")
		_currentDirection = 1 - _currentDirection
		rotation_degrees = current_direction
		_sync_henshin_rotation()
		velocity = to_global(Vector3(0, 0, 1) * speed) - position
		new_line()
		_play_music_from_level_data()
	else:
		# —— 首次转向（游戏启动）——
		is_start = true
		var page: CanvasLayer = get_node_or_null("StartPage") as CanvasLayer
		if page and page is CanvasLayer:
			page.hide_animated()
		emit_signal("on_player_start")
		rotation_degrees = current_direction
		_sync_henshin_rotation()
		_resume_managed_animators()

		if _delay_applied:
			_play_music_from_level_data()
			LevelManager.GameState = LevelManager.GameStatus.Playing
			_resume_fake_players()
			velocity = to_global(Vector3(0, 0, 1) * speed) - position
			new_line()
		elif musicDelay > 0:
			_delay_applied = true
			# 正值：线立即移动，音乐延后播放（对齐 Unity delay > 0 分支）
			LevelManager.GameState = LevelManager.GameStatus.Playing
			_resume_fake_players()
			velocity = to_global(Vector3(0, 0, 1) * speed) - position
			new_line()
			get_tree().create_timer(musicDelay).timeout.connect(_play_music_from_level_data)
		elif musicDelay < 0:
			_delay_applied = true
			# 负值：音乐立即播放，线原地不动等待后移动（对齐 Unity delay < 0 分支）
			_play_music_from_level_data()
			get_tree().create_timer(-musicDelay).timeout.connect(_start_game_after_delay)
		else:
			_delay_applied = true
			# 零值：音画同步启动（原行为）
			LevelManager.GameState = LevelManager.GameStatus.Playing
			_resume_fake_players()
			velocity = to_global(Vector3(0, 0, 1) * speed) - position
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
		var start_time: float = levelData.get_audio_start_time()
		_play_music(start_time)

## 播放音乐，补偿系统音频延迟（AudioServer）并应用用户音量设置
## latency: AudioServer.get_output_latency() — 系统硬件延迟自动补偿
## musicVolume: 用户手动调节的音量
func _play_music(start_time: float) -> void:
	$MusicPlayer.volume_db = linear_to_db(max(musicVolume, 0.001))
	var latency: float = AudioServer.get_output_latency()
	if latency > 0.0:
		var adjusted_time: float = max(start_time - latency, 0.0)
		$MusicPlayer.play(adjusted_time)
	else:
		$MusicPlayer.play(start_time)


## musicDelay < 0 时：timer 回调，启动游戏移动（对齐 Unity delay < 0 分支的 yield 之后逻辑）
func _start_game_after_delay() -> void:
	LevelManager.GameState = LevelManager.GameStatus.Playing
	_resume_fake_players()
	velocity = to_global(Vector3(0, 0, 1) * speed) - position

	new_line()

func _on_Area_body_entered(_body: Node) -> void:
	if not is_live or noDeath:
		return

	die()
func die(spawn_particles: bool = true, death_state: LevelManager.GameStatus = LevelManager.GameStatus.Died) -> void:
	if !noclip:
		is_live = false
		LevelManager.GameState = death_state
		emit_signal("on_game_over")
		if death_state == LevelManager.GameStatus.Died:
			velocity = Vector3.ZERO
		if animation_node: animation_node.pause()
		LevelManager.GameOverNormal(false)
		AudioManager.fade_out()
		if spawn_particles:
			$AudioStreamPlayer.play()

		if not spawn_particles or not deathParticle:
			return

		var forward_dir: Vector3 = velocity.normalized() if velocity.length() > 0.01 else Vector3.FORWARD
		var backward_dir: Vector3 = -forward_dir

		for i in 8:
			var deathParticle_instance: RigidBody3D = deathParticle.instantiate()
			deathParticle_instance.collision_layer = 1
			deathParticle_instance.add_to_group("death_particles")
			var parent: Node = get_parent()
			if not parent:
				push_error("Player.gd: 不在场景树中，无法生成死亡粒子")
				return
			parent.add_child(deathParticle_instance)
			var death_mesh: MeshInstance3D = deathParticle_instance.get_node_or_null("MeshInstance3D") as MeshInstance3D
			if death_mesh:
				death_mesh.mesh = mesh
				death_mesh.material_override = material
			else:
				push_error("Player.gd: 死亡粒子实例缺少 MeshInstance3D 子节点")
			deathParticle_instance.global_position = global_position
			deathParticle_instance.linear_damp = 0.5
			var random_rot: Vector3 = _random_rotation()
			deathParticle_instance.rotation = random_rot

			var direction: Vector3 = forward_dir if i < 4 else backward_dir
			var impulse: Vector3 = direction * speed + _rand_dir() * 0.5
			deathParticle_instance.apply_central_impulse(impulse)
			deathParticle_instance.apply_torque(_rand_dir())

func _rand_dir() -> Vector3:
	return Vector3(randf_range(-speed, speed), randf_range(-speed, speed), randf_range(-speed, speed))

func _random_rotation() -> Vector3:
	return Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))

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
			var quality_level: int = GraphicsQuality.quality_level_from_value(value)
			GraphicsQuality.set_level(quality_level)
			get_tree().call_group("active_by_quality", "apply_quality", quality_level)
			GraphicsQuality.save_settings()
		"antialiasing":
			GraphicsQuality.antialiasing = GraphicsQuality.antialiasing_level_from_value(value)
			GraphicsQuality.apply_antialiasing(get_viewport())
			GraphicsQuality.save_settings()

func _on_shadow_toggled(is_on: bool) -> void:
	GraphicsQuality.shadows_enabled = is_on
	GraphicsQuality.apply_shadows(get_tree())
	GraphicsQuality.save_settings()

func _on_post_toggled(is_on: bool) -> void:
	GraphicsQuality.post_process_enabled = is_on
	GraphicsQuality.apply_post_process(get_scene_environment())
	GraphicsQuality.save_settings()
