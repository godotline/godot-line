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
@export var animation:NodePath
@export var is_turn := false

@onready var mesh:Mesh = $MeshInstance3D.mesh
@onready var past_translation := position
@onready var material:StandardMaterial3D = $MeshInstance3D.get_surface_override_material(0)
@onready var tree := get_tree()
@onready var animation_node:AnimationPlayer = get_node(animation) if animation else null

var level_manager
var is_live := true
var line:MeshInstance3D
@warning_ignore("shadowed_variable_base_class")
#var velocity := Vector3.ZERO
var past_is_on_floor := false
var v := Vector3(0,0,0)
var is_start := false
var tailScale = 1

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
	if not Engine.is_editor_hint() and line and is_live:
		@warning_ignore("shadowed_variable_base_class")
		var is_on_floor := is_on_floor() or fly
		if is_on_floor:
			if past_is_on_floor != is_on_floor: 
				new_line()
			var offset = position - past_translation
			var distance = offset.length()
			
			# 设置线段位置为中点
			line.position = past_translation + offset / 2
			
			# 设置线段长度（沿Z轴拉伸）
			line.scale = Vector3(1, 1, distance + tailScale)
		else:
			if past_is_on_floor != is_on_floor: emit_signal("on_sky")
		past_is_on_floor = is_on_floor

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
	State.is_turn = $".".is_turn
	State.anim_time = 0.0
	tree.reload_current_scene()

func new_line():
	line = MeshInstance3D.new()
	line.mesh = mesh
	line.position = position
	line.rotation = rotation  # 继承当前旋转
	line.set_surface_override_material(0, material)
	line.name = "Line"
	tree.current_scene.add_child(line)
	past_translation = position
	emit_signal("new_line1")

func turn():
	if is_on_floor() or fly:
		if animation_node and not animation_node.is_playing(): 
			State.anim_time = level_manager.calculate_anim_start_time()
			animation_node.play("level")
			animation_node.seek(State.anim_time)
		if is_start :
			emit_signal("onturn")
			rotation_degrees += Vector3(0,1,0) * rot if is_turn else Vector3.DOWN * rot
			is_turn = not is_turn
		else:
			is_start = true
		v = to_global(Vector3(0,0,-1) * speed) - position
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
	is_live = false
	if animation_node: animation_node.pause()
	$AudioStreamPlayer.play()
func _on_button_pressed() -> void:
	$RoadMaker.save()
