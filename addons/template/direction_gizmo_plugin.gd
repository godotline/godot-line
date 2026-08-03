@tool
extends EditorNode3DGizmoPlugin

const DIRECTION_LENGTH: float = 4.0

func _init() -> void:
	create_material("positive_x", Color(0.2, 0.45, 1.0))
	create_material("negative_x", Color(0.2, 1.0, 0.35))
	create_material("forward_z", Color(1.0, 0.2, 0.2))
	create_material("back_z", Color(1.0, 0.85, 0.15))

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is Player or _find_fake_player(for_node_3d) != null

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var target: Node3D = gizmo.get_node_3d()
	if not _is_direction_enabled(target):
		return

	_add_world_direction(gizmo, target, Vector3.RIGHT, "positive_x")
	_add_world_direction(gizmo, target, Vector3.LEFT, "negative_x")
	_add_world_direction(gizmo, target, Vector3.FORWARD, "forward_z")
	_add_world_direction(gizmo, target, Vector3.BACK, "back_z")

func _is_direction_enabled(target: Node3D) -> bool:
	if target is Player:
		return (target as Player).draw_direction
	var fake_player: FakePlayer = _find_fake_player(target)
	if fake_player:
		return fake_player.drawDirection
	return false

func _find_fake_player(node: Node3D) -> FakePlayer:
	var direct: FakePlayer = node as FakePlayer
	if direct:
		return direct
	for child: Node in node.get_children():
		var component: FakePlayer = child as FakePlayer
		if component:
			return component
	return null

func _add_world_direction(gizmo: EditorNode3DGizmo, target: Node3D, world_direction: Vector3, material_name: String) -> void:
	var local_direction: Vector3 = target.global_basis.inverse() * world_direction.normalized()
	var points: PackedVector3Array = PackedVector3Array([Vector3.ZERO, local_direction * DIRECTION_LENGTH])
	gizmo.add_lines(points, get_material(material_name, gizmo), false)
