@tool
extends CharacterBody3D
var is_live := true

signal new_line1
signal on_sky
signal onturn

@onready var y = $".".position.y
@export var speed := 10.0
@export var color := Color(0,0,0): get = get_color, set = set_color
@export var fly := false
@export var animation:NodePath
@export var is_turn := false
@export var turn_rotation := Vector3(0,90,0)
@export var tag := 0
@export var autoplay := false
@export var check := false
@export var control := true
@export var subline : CharacterBody3D

@onready var mesh:Mesh = $skin/normal.mesh
@onready var past_translation := position
@onready var material:StandardMaterial3D = $skin/normal.get_surface_override_material(0)
@onready var tree := get_tree()
@onready var animation_node:AnimationPlayer = get_node(animation) if animation else null
@onready var land_effect: GPUParticles3D = $LandEffect


var line:MeshInstance3D
@warning_ignore("shadowed_variable_base_class")
#var velocity := Vector3.ZERO
var past_is_on_floor := false
var past_is_on_floor_effect := false
var v := Vector3(0,0,0)
var is_start := false

var start_transform = transform
var start_is_turn = false
var start_anim_time = 0.0
var G := 0.0
var _last_floor_y := 0.0

# Array to track tail segments created during current on-floor window
var floor_segment_lines: Array[MeshInstance3D] = []

func _ready() -> void:
	G = 9.8 * (speed/10)
	if State.is_end == true:
		State.is_end = false
		reload()
	if not Engine.is_editor_hint() and State.main_line_transform:
		transform = State.main_line_transform
		is_turn = State.is_turn
		if animation_node and State.anim_time > 0:
			animation_node.assigned_animation = "level"
			animation_node.seek(State.anim_time, true, false)
	_last_floor_y = global_position.y

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and is_live:
		if not is_on_floor():
			velocity.y -= G * delta
		velocity.x = v.x
		velocity.z = v.z
		move_and_slide()
		if is_on_wall():
			die()
		v = Vector3(velocity.x, v.y, velocity.z)

func _process(_delta: float) -> void:
	if is_start:
		v = to_global(Vector3(0,0,-1) * speed) - position
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
		line.position = offset / 2 + past_translation
		line.position.y = global_position.y
		# Keep tail thickness stable on ground; only stretch in movement plane.
		line.scale = Vector3(offset.abs().x + 1.0, 1.0, offset.abs().z + 1.0)
		
		# Sync Y of all floor segments to MainLine global Y only when Y changes.
		var current_y := global_position.y
		if abs(current_y - _last_floor_y) > 0.001:
			for segment in floor_segment_lines:
				if is_instance_valid(segment):
					segment.global_position.y = current_y
			_last_floor_y = current_y
	else:
		if past_is_on_floor != is_on_floor_now:
			emit_signal("on_sky")
			# Clear floor segments when leaving floor (freeze window)
			floor_segment_lines.clear()
	past_is_on_floor = is_on_floor_now


func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		if event.is_action_pressed("turn") and is_live:
			if not is_start:
				turn()
			elif not State.is_end:# and not State.autoplay:
				if tag == 0 and not subline:
					turn()
				elif tag == 0 and subline:
					if subline.check == true and check == true:
						subline.turn()
						turn()
					elif subline.check == true:subline.turn()
					else:turn()


func reload() -> void:
	State.main_line_transform = start_transform
	State.is_turn = $".".is_turn
	State.anim_time = 0.0
	tree.reload_current_scene()

func new_line():
	if $skin/normal.visible == true:
		line = MeshInstance3D.new()
		line.mesh = mesh
		line.position = position
		past_translation = position
		line.set_surface_override_material(0,material)
		line.name = "Line"
		tree.current_scene.add_child(line)
		emit_signal("new_line1")
		
		# Track segment if created while on floor
		if is_on_floor() or fly:
			floor_segment_lines.append(line)

func _play_land_effect() -> void:
	if is_instance_valid(land_effect):
		land_effect.restart()
		land_effect.emitting = true

func turn():
	if is_on_floor() and control:
		if animation_node and not animation_node.is_playing(): 
			if State.music_delay < 0.0:
				v = to_global(Vector3(0,0,-1) * speed) - position
				new_line()
				await get_tree().create_timer(-State.music_delay/1000.0).timeout
			Engine.time_scale = State.speed
			animation_node.get_child(0).pitch_scale = Engine.time_scale
			animation_node.play("level")
		if is_start :
			rotation_degrees += turn_rotation if is_turn else -turn_rotation
			is_turn = not is_turn
			emit_signal("onturn")
		else:
			is_start = true
			if State.music_delay >= 0.0:
				await get_tree().create_timer(State.music_delay/1000.0).timeout
		v = to_global(Vector3(0,0,-1) * speed) - position
		new_line()
		check = false
		
		if State.skin == 2 and State.autoplay:
			$skin/earphones.note()

func set_color(value: Color):
	if not is_instance_valid(material):
		material = StandardMaterial3D.new()
	material.albedo_color = value

func get_color() -> Color:
	return material.albedo_color if is_instance_valid(material) else Color(0, 0, 0)

func _on_Area_body_entered(_body: Node) -> void:
	die()

func die() -> void:
	if not is_live:
		return
	is_live = false
	if subline:
		subline.is_live = false
	if animation_node:
		animation_node.pause()
	$AudioStreamPlayer.play()

func stop() -> void:
	pass
