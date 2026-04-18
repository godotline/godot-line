@tool
extends CharacterBody3D
class_name Player

static var instance: Player

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

func _ready() -> void:
	instance = self
	if not Engine.is_editor_hint():
		if LevelManager.is_end == true:
			LevelManager.is_end = false
			reload()
		LevelManager.load_checkpoint_to_main_line(self)
		speed = level_data.speed
		rotation_degrees = current_direction
	if is_inside_tree():
		if level_data:
				level_data.apply_to(self, get_world_3d().space)
		_last_floor_y = global_position.y

	var debug_overlay_scene := load("res://#Template/[Resources]/DebugOverlay.tscn") as PackedScene
	if debug_overlay_scene:
		var overlay := debug_overlay_scene.instantiate()
		add_child(overlay)

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and is_live:
		if not is_on_floor():
			var gravity_strength: float = level_data.gravity.length() if level_data else 9.8
			velocity.y -= gravity_strength * delta
		move_and_slide()
		if is_on_wall():
			die()
		if fly:
			$".".position.y = y

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_live:
		return

	# TODO: 不知道有没有用
	if level_data and level_data.levelAudioClip and $MusicPlayer.playing and animation_node and animation_node.is_playing():
		var time = $MusicPlayer.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		animation_node.seek(time, true)

	var is_on_floor_now := is_on_floor() or fly
	if is_on_floor_now and not past_is_on_floor_effect:
		_play_land_effect()
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
			floor_segment_lines.clear()
	past_is_on_floor = is_on_floor_now

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		var can_turn := LevelManager.game_state == LevelManager.GameStatus.Playing or (LevelManager.game_state == LevelManager.GameStatus.Waiting and not is_start)
		if event.is_action_pressed("turn") and is_live and allowTurn and can_turn:
			turn()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				if not Engine.is_editor_hint() and not loading:
					loading = true
					reload()
			KEY_K:
				if not Engine.is_editor_hint() and is_live:
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
			child.queue_free()

func _get_or_create_player_tail_holder() -> Node3D:
	var root := tree.current_scene

	var tail_holder := root.get_node_or_null("PlayerTailHolder") as Node3D
	if not tail_holder:
		tail_holder = Node3D.new()
		tail_holder.name = "PlayerTailHolder"
		root.add_child(tail_holder)

	return tail_holder

func new_line():
	line = MeshInstance3D.new()
	line.mesh = mesh
	line.position = position
	line.rotation = rotation  # 继承当前旋转
	line.set_surface_override_material(0, material)

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
			if LevelManager.line_crossing_crown == 0:
				LevelManager.anim_time = 0
			animation_node.play("level")
			animation_node.seek(LevelManager.anim_time)
			if level_data and level_data.levelAudioClip and not $MusicPlayer.playing:
				$MusicPlayer.stream = level_data.levelAudioClip
				var music_start_time: float = level_data.get_audio_start_time()
				if music_start_time > 0.0:
					$MusicPlayer.play(music_start_time)
				else:
					$MusicPlayer.play()
		if is_start :
			emit_signal("onturn")
			_currentDirection = 1 - _currentDirection
			rotation_degrees = current_direction
		else:
			is_start = true
			LevelManager.game_state = LevelManager.GameStatus.Playing
			rotation_degrees = current_direction
		velocity = to_global(Vector3(0,0,1) * speed) - position
		past_translation = position
		new_line()



func _on_Area_body_entered(_body: Node) -> void:
	die()
func die():
	if !noclip:
		is_live = false
		velocity = Vector3.ZERO
		if animation_node: animation_node.pause()
		$MusicPlayer.stop()
		$AudioStreamPlayer.play()
		
		if not deathParticle:
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
