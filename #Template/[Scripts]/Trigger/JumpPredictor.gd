@tool
extends Node3D
class_name JumpPredictor
## JumpPredictor - 跳跃轨迹预测器
## 发射模拟玩家显示跳跃轨迹

enum LineDirection {
	Left,
	Right
}

@export_group("预测设置")
@export var speed_x: float = 12.0:
	set(value):
		speed_x = value
		_redraw()
@export var direction: LineDirection = LineDirection.Right:
	set(value):
		direction = value
		_redraw()
@export var reverse: bool = false:
	set(value):
		reverse = value
		_redraw()
@export var show_in_game: bool = true
@export var count: int = 100:
	set(value):
		count = max(0, value)
		_redraw()
@export var step_interval: float = 0.05:
	set(value):
		step_interval = value
		_redraw()
@export var color: Color = Color.RED:
	set(value):
		color = value
		_redraw()

@export_group("预览控制")
@export var draw_preview: bool = false:
	set(value):
		draw_preview = value
		if value and Engine.is_editor_hint():
			_connect_to_jump()
			_draw_line()
@export var clear_preview: bool = false:
	set(value):
		clear_preview = value
		if value:
			_clear()

var _jump_node: Node
var _line_mesh: MeshInstance3D

func _ready() -> void:
	top_level = true
	
	if not Engine.is_editor_hint() and show_in_game:
		_start_simulation()
	elif Engine.is_editor_hint() and draw_preview:
		call_deferred("_connect_to_jump")
		call_deferred("_draw_line")

func _check_parent() -> void:
	var parent = get_parent()
	if parent is Area3D:
		var script = parent.get_script()
		if script and script.resource_path.ends_with("Jump.gd"):
			_jump_node = parent
			print("[JumpPredictor] 找到Jump节点: ", parent.name)
			return
	print("[JumpPredictor] 父节点不是Area3D或没有Jump.gd脚本")

func _connect_to_jump() -> void:
	if _jump_node:
		return
	_check_parent()
	if _jump_node and _jump_node.has_signal("height_changed"):
		if not _jump_node.height_changed.is_connected(_on_height_changed):
			_jump_node.height_changed.connect(_on_height_changed)

func _on_height_changed(_new_height: float) -> void:
	_redraw()

func _redraw() -> void:
	if not Engine.is_editor_hint():
		return
	if not _jump_node:
		return
	_draw_line()

func _start_simulation() -> void:
	if not _jump_node:
		_check_parent()
		if not _jump_node:
			return
	_draw_line()

func _clear() -> void:
	if _line_mesh and is_instance_valid(_line_mesh):
		_line_mesh.queue_free()
		_line_mesh = null

func _draw_line() -> void:
	if not _line_mesh:
		_line_mesh = MeshInstance3D.new()
		_line_mesh.name = "TrajectoryLine"
		_line_mesh.top_level = true
		add_child(_line_mesh)
		_line_mesh.global_position = Vector3.ZERO

	if count <= 0:
		_line_mesh.mesh = null
		return

	var parent = get_parent()
	var base_pos = parent.global_position if parent else global_position

	var height: float = _jump_node.get("height") if _jump_node else 1.0
	var gravity_strength: float = 9.8
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravity_strength = ProjectSettings.get_setting("physics/3d/default_gravity")
	var jump_speed = sqrt(2 * gravity_strength * height)

	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	var pos: Vector3 = base_pos
	var vel: Vector3 = Vector3.ZERO

	match direction:
		LineDirection.Left:
			vel = Vector3(0, jump_speed, -speed_x if reverse else speed_x)
		LineDirection.Right:
			vel = Vector3(-speed_x if reverse else speed_x, jump_speed, 0)

	for i in count:
		immediate_mesh.surface_add_vertex(pos)
		vel.y -= gravity_strength * step_interval
		pos += vel * step_interval

	immediate_mesh.surface_end()
	_line_mesh.mesh = immediate_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mesh.material_override = material
