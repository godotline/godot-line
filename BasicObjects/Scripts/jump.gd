@tool
extends Area3D
@export var height := 1.0: set = _set_height
@export var preview_enabled := true: set = _set_preview_enabled
@export_range(2, 128, 1) var preview_steps := 20: set = _set_preview_steps
@export var preview_color := Color(1, 0.8, 0.2): set = _set_preview_color
@export var marker_size := 0.2: set = _set_marker_size
@export var mainline_path: NodePath: set = _set_mainline_path

var _preview_line: MeshInstance3D
var _preview_mesh: ImmediateMesh
var _landing_marker: MeshInstance3D
var _warned_missing_mainline := false

func _update_preview_if_editor() -> void:
	if Engine.is_editor_hint():
		_update_preview()

func _set_height(value: float) -> void:
	height = value
	_update_preview_if_editor()

func _set_preview_enabled(value: bool) -> void:
	preview_enabled = value
	_update_preview_if_editor()

func _set_preview_steps(value: int) -> void:
	preview_steps = value
	_update_preview_if_editor()

func _set_preview_color(value: Color) -> void:
	preview_color = value
	_update_preview_if_editor()

func _set_marker_size(value: float) -> void:
	marker_size = value
	_update_preview_if_editor()

func _set_mainline_path(value: NodePath) -> void:
	mainline_path = value
	_warned_missing_mainline = false
	_update_preview_if_editor()

func _find_mainline_node() -> Node:
	var root := get_tree().edited_scene_root
	if not root:
		return null
	if mainline_path != NodePath():
		var from_self := get_node_or_null(mainline_path)
		if from_self:
			return from_self
		return root.get_node_or_null(mainline_path)
	for n in root.get_children():
		if n is Node and n.get_script() and n.get_script().resource_path == "res://Scripts/MainLine.gd":
			return n
	return null

func _get_preview_speed() -> float:
	var mainline := _find_mainline_node()
	if not mainline:
		if Engine.is_editor_hint() and not _warned_missing_mainline:
			_warned_missing_mainline = true
			push_warning("Jump preview: MainLine not found. Assign mainline_path or add a MainLine node to the scene.")
		return 0.0
	_warned_missing_mainline = false
	return mainline.speed

func _get_preview_dir() -> Vector3:
	return -global_transform.basis.z

func _ensure_preview_nodes() -> void:
	if _preview_line == null:
		_preview_line = MeshInstance3D.new()
		_preview_mesh = ImmediateMesh.new()
		_preview_line.mesh = _preview_mesh
		_preview_line.owner = null
		add_child(_preview_line)
	if _landing_marker == null:
		_landing_marker = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = marker_size
		_landing_marker.mesh = sphere
		_landing_marker.owner = null
		add_child(_landing_marker)
	elif _landing_marker.mesh is SphereMesh:
		var sphere := _landing_marker.mesh as SphereMesh
		sphere.radius = marker_size

func _clear_preview() -> void:
	if _preview_line:
		_preview_line.queue_free()
		_preview_line = null
		_preview_mesh = null
	if _landing_marker:
		_landing_marker.queue_free()
		_landing_marker = null

func _update_preview() -> void:
	if not preview_enabled or height <= 0 or preview_steps < 2:
		_clear_preview()
		return
	var speed := _get_preview_speed()
	if speed <= 0:
		_clear_preview()
		return
	_ensure_preview_nodes()
	var g := 9.8
	var v0y := sqrt(2.0 * g * height)
	var t_end := 2.0 * v0y / g
	var dir := _get_preview_dir().normalized()
	var start := global_position

	_preview_mesh.clear_surfaces()
	_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(preview_steps):
		var t := (t_end * i) / float(preview_steps - 1)
		var p := start + dir * speed * t + Vector3.UP * (v0y * t - 0.5 * g * t * t)
		_preview_mesh.surface_set_color(preview_color)
		_preview_mesh.surface_add_vertex(to_local(p))
	_preview_mesh.surface_end()

	var end_pos := start + dir * speed * t_end
	_landing_marker.position = to_local(end_pos)

func _on_body_entered(body: PhysicsBody3D) -> void:
	if body is CharacterBody3D:
		var character := body as CharacterBody3D
		var jump_speed = sqrt(2 * 9.8 * height)
		character.velocity += jump_speed * Vector3.UP

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_preview()
	else:
		_clear_preview()
		if bool(State.get("is_restoring_checkpoint")):
			return
		$MeshInstance3D.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_update_preview()
