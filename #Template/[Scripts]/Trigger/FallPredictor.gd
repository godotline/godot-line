@tool
extends Node3D
class_name FallPredictor

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

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "PredictorLine"
	add_child(_mesh_instance)
	_draw_line()

func _draw_line() -> void:
	if not _mesh_instance:
		return

	if count <= 0:
		_mesh_instance.mesh = null
		return

	var gravity_strength: float = 9.8
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravity_strength = ProjectSettings.get_setting("physics/3d/default_gravity")

	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	var x: float = 0.0
	var y: float = 0.0

	for i in count:
		immediate_mesh.surface_add_vertex(Vector3(x, y, 0.0))
		x += 1.0
		y = -(0.5 * gravity_strength * pow(x / speed, 2))

	immediate_mesh.surface_end()

	_mesh_instance.mesh = immediate_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_instance.material_override = material
