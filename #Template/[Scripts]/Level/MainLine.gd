@tool
extends CharacterBody3D

signal new_line1
signal on_sky
signal onturn

@onready var y = $".".position.y
@export var speed := 12.0
@export var rot := -90
@export var color := Color(0,0,0): get = get_color, set = set_color
@export var fly := false
@export var noclip := false
@export var animation:NodePath
@export var is_turn := false

@onready var mesh:Mesh = $MeshInstance3D.mesh
@onready var past_translation := position
@onready var material:StandardMaterial3D = $MeshInstance3D.get_surface_override_material(0)
@onready var tree := get_tree()
@onready var animation_node:AnimationPlayer = get_node(animation) if animation else null
@onready var land_effect: GPUParticles3D = $LandEffect

@export var music: AudioStream

const DEATH_PARTICLE = preload("res://#Template/DeathParticle.tscn")

var level_manager
var timeout := 0.1
var is_live := true
var line:MeshInstance3D
var past_is_on_floor := false
var past_is_on_floor_effect := false
var v := Vector3(0,0,0)
var is_start := false
var tailScale = 1
var _last_floor_y := 0.0
var floor_segment_lines: Array[MeshInstance3D] = []

var start_transform = transform
@export var allowTurn := true

func _ready() -> void:
	if not Engine.is_editor_hint():
		level_manager = get_tree().current_scene
		if State.is_end == true:
			State.is_end = false
			reload()
		State.load_checkpoint_to_main_line(self)
	if is_inside_tree():
		_last_floor_y = global_position.y

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and is_live:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		velocity.x = v.x
		velocity.z = v.z
		move_and_slide()
		if is_on_wall():
			die()
		v = Vector3(velocity.x, v.y, velocity.z)
		if fly:
			$".".position.y = y

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_live:
		return

	# TODO: 不知道有没有用
	if music and $MusicPlayer.playing and animation_node and animation_node.is_playing():
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
		if event.is_action_pressed("turn") and is_live and allowTurn:
			turn()

func reload() -> void:
	State.main_line_transform = start_transform
	State.reset_camera_checkpoint()
	State.is_turn = $".".is_turn
	State.anim_time = 0.0
	tree.reload_current_scene()

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
			if State.line_crossing_crown == 0:
				State.anim_time = level_manager.calculate_anim_start_time()
			animation_node.play("level")
			animation_node.seek(State.anim_time)
			if music:
				$MusicPlayer.stream = music
				var music_start_time := State.music_checkpoint_time if State.music_checkpoint_time > 0.0 else State.anim_time
				if music_start_time > 0.0:
					$MusicPlayer.play(music_start_time)
				else:
					$MusicPlayer.play()
		if is_start :
			emit_signal("onturn")
			rotation_degrees += Vector3(0,1,0) * rot if is_turn else Vector3.DOWN * rot
			is_turn = not is_turn
		else:
			is_start = true
		v = to_global(Vector3(0,0,1) * speed) - position
		past_translation = position
		new_line()

func set_color(value: Color):
	if not is_instance_valid(material):
		material = StandardMaterial3D.new()
		$MeshInstance3D.set_surface_override_material(0, material)
	material.albedo_color = value

func get_color() -> Color:
	return material.albedo_color if is_instance_valid(material) else Color(0, 0, 0)

func _on_Area_body_entered(_body: Node) -> void:
	die()
func die():
	if !noclip:
		is_live = false
		if animation_node: animation_node.pause()
		$MusicPlayer.stop()
		$AudioStreamPlayer.play()
		
		var forward_dir := velocity.normalized() if velocity.length() > 0.01 else Vector3.FORWARD
		var backward_dir := -forward_dir

		for i in 8:
			var death_particle_instance: RigidBody3D = DEATH_PARTICLE.instantiate()
			get_parent().add_child(death_particle_instance)
			death_particle_instance.get_node("MeshInstance3D").mesh = mesh
			death_particle_instance.get_node("MeshInstance3D").material_override = material
			death_particle_instance.global_position = global_position
			death_particle_instance.linear_damp = 0.5
			var random_rot := _random_rotation()
			death_particle_instance.rotation = random_rot

			var direction := forward_dir if i < 4 else backward_dir
			var impulse := direction * speed + _rand_dir() * 0.5
			death_particle_instance.apply_central_impulse(impulse)
			death_particle_instance.apply_torque(_rand_dir())

func _rand_dir() -> Vector3:
	return Vector3(randf_range(-speed, speed), randf_range(-speed, speed), randf_range(-speed, speed))

func _random_rotation() -> Vector3:
	return Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
