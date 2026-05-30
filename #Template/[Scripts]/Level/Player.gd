@tool
extends CharacterBody3D
class_name Player

static var instance: Player

## ========== 事件信号（GameEvents 系统） ==========
signal on_game_awake			## 游戏初始化完成
signal on_player_start			## 玩家开始移动（第一次转向）
signal on_change_direction		## 玩家转向
signal on_leave_ground			## 玩家离开地面
signal on_touch_ground			## 玩家落地
signal on_game_over				## 玩家死亡
signal on_get_gem				## 收集宝石
signal on_player_jump			## 玩家跳跃

signal new_line1
signal on_sky
signal onturn

@onready var y = $".".position.y
var speed:float
@export var firstDirection := Vector3(0, 0, 0)
@export var secondDirection := Vector3(0, 90, 0)
var _currentDirection := 0

var current_direction: Vector3:
	get:
		return secondDirection if _currentDirection == 1 else firstDirection

@export var fly := false
@export var noclip := false
@export var animation:NodePath
@export var is_turn := false
@export var is_end := false

@onready var mesh:Mesh = $MeshInstance3D.mesh
@onready var past_translation := position
@onready var material:StandardMaterial3D = $MeshInstance3D.get_surface_override_material(0)
@onready var tree := get_tree()
@onready var animation_node:AnimationPlayer = get_node(animation) if animation else null
@onready var land_effect: GPUParticles3D = $LandEffect

@export var level_data: LevelData

@export var deathParticle: PackedScene

var timeout := 0.1
var is_live := true
var line:MeshInstance3D
var past_is_on_floor := false
var past_is_on_floor_effect := false

var is_start := false
var tailScale = 1
var _last_floor_y := 0.0
var floor_segment_lines: Array[MeshInstance3D] = []

var start_transform = transform
var loading := false
var debug := false
@export var allowTurn := true
@export var disallow_input := false

## 音画延迟补偿（秒），用户可配置。与 AudioServer.get_output_latency() 独立并存。
var music_delay: float = 0.0

## 音量 (0.0~1.0)
var music_volume: float = 1.0

## ========== Tail 对象池 ==========
const TAIL_POOL_SIZE := 256
var _tail_pool: Array[MeshInstance3D] = []

func _ready() -> void:
	instance = self
	if not Engine.is_editor_hint():
		if not LevelManager.camera_checkpoint.has_checkpoint:
			LevelManager.reset_to_defaults()

		if LevelManager.is_end == true:
			LevelManager.is_end = false
			reload()
		LevelManager.load_checkpoint_to_main_line(self)
		speed = level_data.speed
		rotation_degrees = current_direction
		emit_signal("on_game_awake")
	if is_inside_tree():
		if level_data:
				level_data.apply_to(self, get_world_3d().space)
		_last_floor_y = global_position.y

	var debug_overlay_scene := load("res://#Template/[Resources]/DebugOverlay.tscn") as PackedScene
	if debug_overlay_scene:
		var overlay := debug_overlay_scene.instantiate()
		add_child(overlay)

	# 实例化 StartPage（启动界面）
	var start_page_scene := load("res://#Template/[Resources]/StartPage.tscn") as PackedScene
	if start_page_scene and not Engine.is_editor_hint():
		var page := start_page_scene.instantiate()
		add_child(page)
		page.set_setting("latency", music_delay)
		page.set_setting("volume", music_volume)

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and (is_live or LevelManager.GameState == LevelManager.GameStatus.Moving):
		if not is_on_floor():
			var gravity_strength: float = level_data.gravity.length() if level_data else 9.8
			velocity.y -= gravity_strength * delta
		move_and_slide()
		if is_live and is_on_wall():
			die()
		if fly:
			$".".position.y = y

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or (not is_live and LevelManager.GameState != LevelManager.GameStatus.Moving):
		return

	var is_on_floor_now := is_on_floor() or fly
	if is_on_floor_now and not past_is_on_floor_effect:
		_play_land_effect()
		emit_signal("on_touch_ground")
	past_is_on_floor_effect = is_on_floor_now

	if not line:
		return

	if is_on_floor_now:
		if past_is_on_floor != is_on_floor_now:
			new_line()
		var offset = position - past_translation
		var distance = offset.length()

		line.position = past_translation + offset / 2
		line.position.y = global_position.y

		line.scale = Vector3(1, 1, distance + tailScale)

		var current_y := global_position.y
		if abs(current_y - _last_floor_y) > 0.001:
			for segment in floor_segment_lines:
				if is_instance_valid(segment):
					segment.global_position.y = current_y
			_last_floor_y = current_y
	else:
		if past_is_on_floor != is_on_floor_now:
			emit_signal("on_sky")
			emit_signal("on_leave_ground")
			floor_segment_lines.clear()
	past_is_on_floor = is_on_floor_now

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		var can_turn := LevelManager.GameState == LevelManager.GameStatus.Playing or (LevelManager.GameState == LevelManager.GameStatus.Waiting and not is_start)
		if event.is_action_pressed("turn") and is_live and allowTurn and can_turn and not disallow_input:
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

func reload() -> void:
	LevelManager.main_line_transform = start_transform
	LevelManager.reset_camera_checkpoint()
	LevelManager.player_direction_index = _currentDirection
	LevelManager.player_first_direction = firstDirection
	LevelManager.player_second_direction = secondDirection
	LevelManager.anim_time = 0.0
	_clear_tail()
	tree.reload_current_scene()

func _clear_tail() -> void:
	line = null
	past_translation = position
	floor_segment_lines.clear()
	var tail_holder := tree.current_scene.get_node_or_null("PlayerTailHolder") as Node3D
	if tail_holder:
		for child in tail_holder.get_children():
			var tail := child as MeshInstance3D
			if tail:
				_return_to_pool(tail)
			else:
				child.queue_free()

func _return_to_pool(tail: MeshInstance3D) -> void:
	if tail.get_parent():
		tail.get_parent().remove_child(tail)
	tail.visible = false
	if _tail_pool.size() < TAIL_POOL_SIZE:
		_tail_pool.append(tail)
	else:
		tail.queue_free()

func _get_from_pool() -> MeshInstance3D:
	if _tail_pool.is_empty():
		return MeshInstance3D.new()
	return _tail_pool.pop_back()

func _get_or_create_player_tail_holder() -> Node3D:
	var root := tree.current_scene

	var tail_holder := root.get_node_or_null("PlayerTailHolder") as Node3D
	if not tail_holder:
		tail_holder = Node3D.new()
		tail_holder.name = "PlayerTailHolder"
		root.add_child(tail_holder)

	return tail_holder

func new_line():
	line = _get_from_pool()
	line.mesh = mesh
	line.position = position
	line.rotation = rotation
	line.set_surface_override_material(0, material)
	line.visible = true

	var tail_holder := _get_or_create_player_tail_holder()
	tail_holder.add_child(line)

	if is_on_floor() or fly:
		floor_segment_lines.append(line)

	past_translation = position
	emit_signal("new_line1")

func _play_land_effect() -> void:
	if is_instance_valid(land_effect):
		land_effect.restart()
		land_effect.emitting = true

func turn():
	if is_on_floor() or fly:
		if animation_node and not animation_node.is_playing():
			if LevelManager.line_crossing_crown == 0 and not $MusicPlayer.stream_paused:
				LevelManager.anim_time = 0
			animation_node.play("level")
			animation_node.seek(LevelManager.anim_time)
			if level_data and level_data.levelAudioClip:
				if $MusicPlayer.stream_paused:
					$MusicPlayer.stream_paused = false
				elif not $MusicPlayer.playing:
					$MusicPlayer.stream = level_data.levelAudioClip
					var music_start_time: float = level_data.get_audio_start_time()
					_start_music_with_latency(music_start_time)
		if is_start :
			emit_signal("onturn")
			emit_signal("on_change_direction")
			_currentDirection = 1 - _currentDirection
			rotation_degrees = current_direction
		else:
			is_start = true

			# 隐藏 StartPage
			var page := get_node_or_null("StartPage")
			if page and page is CanvasLayer:
				page.hide_animated()

			emit_signal("on_player_start")
			LevelManager.GameState = LevelManager.GameStatus.Playing
			rotation_degrees = current_direction
		velocity = to_global(Vector3(0,0,1) * speed) - position
		past_translation = position
		new_line()

func _start_music_with_latency(music_start_time: float) -> void:
	var latency := AudioServer.get_output_latency()
	if latency > 0.0:
		var adjusted_time = max(music_start_time - latency, 0.0)
		$MusicPlayer.play(adjusted_time)
	else:
		$MusicPlayer.play(music_start_time)


func _on_Area_body_entered(_body: Node) -> void:
	die()
func die(spawn_particles: bool = true, death_state: LevelManager.GameStatus = LevelManager.GameStatus.Died):
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

		var forward_dir := velocity.normalized() if velocity.length() > 0.01 else Vector3.FORWARD
		var backward_dir := -forward_dir

		for i in 8:
			var deathParticle_instance: RigidBody3D = deathParticle.instantiate()
			deathParticle_instance.add_to_group("death_particles")
			get_parent().add_child(deathParticle_instance)
			deathParticle_instance.get_node("MeshInstance3D").mesh = mesh
			deathParticle_instance.get_node("MeshInstance3D").material_override = material
			deathParticle_instance.global_position = global_position
			deathParticle_instance.linear_damp = 0.5
			var random_rot := _random_rotation()
			deathParticle_instance.rotation = random_rot

			var direction := forward_dir if i < 4 else backward_dir
			var impulse := direction * speed + _rand_dir() * 0.5
			deathParticle_instance.apply_central_impulse(impulse)
			deathParticle_instance.apply_torque(_rand_dir())

func _rand_dir() -> Vector3:
	return Vector3(randf_range(-speed, speed), randf_range(-speed, speed), randf_range(-speed, speed))

func _random_rotation() -> Vector3:
	return Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
