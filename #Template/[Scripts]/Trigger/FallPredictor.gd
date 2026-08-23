@tool
extends Node3D
class_name FallPredictor

@export var showInGame: bool = false
@export var speed: int = 12:
	set(value):
		speed = value
		_draw_line()

@export var width: float = 0.2:
	set(value):
		width = value
		_draw_line()

@export var count: int = 80:
	set(value):
		count = max(0, value)
		_draw_line()

@export var color: Color = Color.GREEN:
	set(value):
		color = value
		_draw_line()

var lineRenderer: MeshInstance3D

func _ready() -> void:
	lineRenderer = MeshInstance3D.new()
	lineRenderer.name = "PredictorLine"
	add_child(lineRenderer)
	if Engine.is_editor_hint() or showInGame:
		_draw_line()

func _draw_line() -> void:
	if not lineRenderer:
		return

	if count <= 0:
		lineRenderer.mesh = null
		return

	var gravityStrength: float = 9.8
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravityStrength = ProjectSettings.get_setting("physics/3d/default_gravity")

	var immediateMesh: ImmediateMesh = ImmediateMesh.new()
	immediateMesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	var x: float = 0.0
	var y: float = 0.0

	for i in count:
		immediateMesh.surface_add_vertex(Vector3(x, y, 0.0))
		x += 1.0
		y = -(0.5 * gravityStrength * pow(x / speed, 2))

	immediateMesh.surface_end()

	lineRenderer.mesh = immediateMesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lineRenderer.material_override = material