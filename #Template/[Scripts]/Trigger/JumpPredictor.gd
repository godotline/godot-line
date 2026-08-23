@tool
extends Node
class_name JumpPredictor
## JumpPredictor - 跳跃轨迹预测器
## 发射模拟玩家显示跳跃轨迹

enum LineDirection {
	Left,
	Right
}

@export var speedX: float = 12.0:
	set(value):
		speedX = value
		_redraw()
@export var direction: LineDirection = LineDirection.Right:
	set(value):
		direction = value
		_redraw()
@export var reverse: bool = false:
	set(value):
		reverse = value
		_redraw()
@export var showInGame: bool = false
@export var count: int = 100:
	set(value):
		count = max(0, value)
		_redraw()
@export var stepInterval: float = 0.05:
	set(value):
		stepInterval = value
		_redraw()
@export var color: Color = Color.RED:
	set(value):
		color = value
		_redraw()

@export var drawPreview: bool = false:
	set(value):
		drawPreview = value
		if value and Engine.is_editor_hint():
			_connect_to_jump()
			_draw_line()
@export var clearPreview: bool = false:
	set(value):
		clearPreview = value
		if value:
			_clear()

var jumpNode: Node
var lineRenderer: MeshInstance3D

func _ready() -> void:
	if not Engine.is_editor_hint() and showInGame:
		_start_simulation()
	elif Engine.is_editor_hint() and drawPreview:
		call_deferred("_connect_to_jump")
		call_deferred("_draw_line")

func _check_parent() -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	for sibling in parent.get_children():
		if sibling == self:
			continue
		var script: Script = sibling.get_script()
		if script and script.resource_path.ends_with("Jump.gd"):
			jumpNode = sibling
			return

func _connect_to_jump() -> void:
	if jumpNode:
		return
	_check_parent()
	if jumpNode and jumpNode.has_signal("power_changed"):
		if not jumpNode.power_changed.is_connected(_on_power_changed):
			jumpNode.power_changed.connect(_on_power_changed)

func _on_power_changed(_newPower: float) -> void:
	_redraw()

func _redraw() -> void:
	if not Engine.is_editor_hint():
		return
	if not jumpNode:
		return
	_draw_line()

func _start_simulation() -> void:
	if not jumpNode:
		_check_parent()
		if not jumpNode:
			return
	_draw_line()

func _clear() -> void:
	if lineRenderer and is_instance_valid(lineRenderer):
		lineRenderer.queue_free()
		lineRenderer = null

func _draw_line() -> void:
	if not is_inside_tree():
		return
	if not lineRenderer:
		lineRenderer = MeshInstance3D.new()
		lineRenderer.name = "TrajectoryLine"
		lineRenderer.top_level = true
		add_child(lineRenderer)
		lineRenderer.global_position = Vector3.ZERO

	if count <= 0:
		lineRenderer.mesh = null
		return

	var parent: Node3D = get_parent() as Node3D
	var basePos: Vector3 = parent.global_position if parent else Vector3.ZERO

	# Unity Jump.power / Player 刚体质量(100) -> 初速度
	var jumpPower: float = jumpNode.get("power") if jumpNode else 500.0
	var jumpSpeed: float = jumpPower / 100.0
	var gravityStrength: float = 9.8
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravityStrength = ProjectSettings.get_setting("physics/3d/default_gravity")

	var immediateMesh: ImmediateMesh = ImmediateMesh.new()
	immediateMesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	var pos: Vector3 = basePos
	var vel: Vector3 = Vector3.ZERO

	match direction:
		LineDirection.Left:
			vel = Vector3(0, jumpSpeed, -speedX if reverse else speedX)
		LineDirection.Right:
			vel = Vector3(-speedX if reverse else speedX, jumpSpeed, 0)

	for i in count:
		immediateMesh.surface_add_vertex(pos)
		vel.y -= gravityStrength * stepInterval
		pos += vel * stepInterval

	immediateMesh.surface_end()
	lineRenderer.mesh = immediateMesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lineRenderer.material_override = material