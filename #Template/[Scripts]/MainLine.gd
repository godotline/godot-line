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
@warning_ignore("shadowed_variable_base_class")
#var velocity := Vector3.ZERO
var past_is_on_floor := false
var past_is_on_floor_effect := false
var v := Vector3(0,0,0)
var is_start := false
var tailScale = 1
var _last_floor_y := 0.0
var floor_segment_lines: Array[MeshInstance3D] = []

var start_transform = transform

func _ready() -> void:
	if not Engine.is_editor_hint():
		level_manager = get_tree().current_scene
		if State.is_end == true:
			State.is_end = false
			reload()
		if State.main_line_transform:
			transform = State.main_line_transform
			is_turn = State.is_turn
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
		
		# 设置线段位置为中点
		line.position = past_translation + offset / 2
		line.position.y = global_position.y
		
		# 设置线段长度（沿Z轴拉伸）
		line.scale = Vector3(1, 1, distance + tailScale)

		# 地面阶段：同步该阶段所有 tail 段的全局 Y，使其跟随主线高度
		var current_y := global_position.y
		if abs(current_y - _last_floor_y) > 0.001:
			for segment in floor_segment_lines:
				if is_instance_valid(segment):
					segment.global_position.y = current_y
			_last_floor_y = current_y
	else:
		if past_is_on_floor != is_on_floor_now:
			emit_signal("on_sky")
			# 离地后冻结上一段地面 tail 窗口
			floor_segment_lines.clear()
	past_is_on_floor = is_on_floor_now

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		if event.is_action_pressed("turn") and is_live:
			turn()
		#if event.is_action_pressed("retry"):
			#tree.reload_current_scene()
		#if event.is_action_pressed("reload"):
			#reload()

func reload() -> void:
	State.main_line_transform = start_transform
	State.camera_follower_has_checkpoint = false
	State.camera_follower_add_position = Vector3.ZERO
	State.camera_follower_rotation_offset = Vector3.ZERO
	State.camera_follower_distance = 0.0
	State.camera_follower_follow_speed = 0.0
	State.camera_follower_restore_pending = false
	State.is_turn = $".".is_turn
	State.anim_time = 0.0
	tree.reload_current_scene()

func _get_or_create_player_tail_holder() -> Node3D:
	var root := tree.current_scene
	if not root:
		return null

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
	line.name = "Line"
	line.top_level = true
	
	# 将线段添加到场景根节点下的 PlayerTailHolder（不存在则自动创建）
	var tail_holder := _get_or_create_player_tail_holder()
	if tail_holder:
		tail_holder.add_child(line)
	else:
		# 回退到场景根节点，避免线段丢失
		tree.current_scene.add_child(line)
		push_warning("PlayerTailHolder 创建失败，线段已添加到场景根节点")

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
			#await get_tree().create_timer(timeout).timeout
			animation_node.seek(State.anim_time)
			# 音乐同步播放
			if music:
				$MusicPlayer.stream = music
				if State.anim_time > 0.0:
					$MusicPlayer.play(State.anim_time)
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
		for i in 8:
			var death_particle_instance: RigidBody3D = DEATH_PARTICLE.instantiate()
			get_parent().add_child(death_particle_instance)
			death_particle_instance.get_node("MeshInstance3D").mesh = mesh
			death_particle_instance.get_node("MeshInstance3D").material_override = material
			death_particle_instance.global_position = global_position
			var random_rot := _random_rotation()
			death_particle_instance.rotation = random_rot
			var impulse_dir := random_rot.normalized() * speed
			death_particle_instance.apply_central_impulse(impulse_dir)
			death_particle_instance.apply_torque(_rand_dir())

func _rand_dir() -> Vector3:
	return Vector3(randf_range(-speed, speed), randf_range(-speed, speed), randf_range(-speed, speed))

func _random_rotation() -> Vector3:
	# 仿照Unity版本: Random.rotation -> 随机欧拉角
	return Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
func _on_button_pressed() -> void:
	$RoadMaker.save()
func set_timeout(delay :float):
	timeout = delay
