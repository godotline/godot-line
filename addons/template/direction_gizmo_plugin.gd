@tool
extends EditorNode3DGizmoPlugin

const DIRECTION_LENGTH: float = 4.0

const ICON_0: Texture2D = preload("res://#Template/[Resources]/Gizmos/Directions/0.png")
const ICON_90: Texture2D = preload("res://#Template/[Resources]/Gizmos/Directions/90.png")
const ICON_180: Texture2D = preload("res://#Template/[Resources]/Gizmos/Directions/180.png")
const ICON_270: Texture2D = preload("res://#Template/[Resources]/Gizmos/Directions/270.png")

var _quad_mesh: QuadMesh

func _init() -> void:
	create_material("positive_x", Color(0.2, 0.45, 1.0), false, false)
	create_material("negative_x", Color(0.2, 1.0, 0.35), false, false)
	create_material("forward_z", Color(1.0, 0.2, 0.2), false, false)
	create_material("back_z", Color(1.0, 0.85, 0.15), false, false)

	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2(0.8, 0.8)

	_create_billboard_material("icon_0", ICON_0)
	_create_billboard_material("icon_90", ICON_90)
	_create_billboard_material("icon_180", ICON_180)
	_create_billboard_material("icon_270", ICON_270)

func _create_billboard_material(mat_name: String, texture: Texture2D) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = texture
	mat.no_depth_test = false
	add_material(mat_name, mat)

func _get_gizmo_name() -> String:
	return "Player Direction"

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is Player or _find_fake_player(for_node_3d) != null

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var target: Node3D = gizmo.get_node_3d()
	if not _is_direction_enabled(target):
		return

	# Unity 原版映射:
	# Right (+X) -> 90
	# Left (-X) -> 270
	# Forward (+Z) -> 0
	# Back (-Z) -> 180
	_add_world_direction(gizmo, target, Vector3.RIGHT, "positive_x", "icon_90")
	_add_world_direction(gizmo, target, Vector3.LEFT, "negative_x", "icon_270")
	_add_world_direction(gizmo, target, Vector3.FORWARD, "forward_z", "icon_0")
	_add_world_direction(gizmo, target, Vector3.BACK, "back_z", "icon_180")

func _is_direction_enabled(target: Node3D) -> bool:
	if target is Player:
		return (target as Player).drawDirection
	var fakePlayer: FakePlayer = _find_fake_player(target)
	if fakePlayer:
		return fakePlayer.drawDirection
	return false

func _find_fake_player(node: Node3D) -> FakePlayer:
	if node.is_in_group("FakePlayer"):
		for child: Node in node.get_children():
			var component: FakePlayer = child as FakePlayer
			if component:
				return component
	return null

func _add_world_direction(gizmo: EditorNode3DGizmo, target: Node3D, world_direction: Vector3, line_material_name: String, icon_material_name: String) -> void:
	var localDirection: Vector3 = target.global_basis.inverse() * world_direction.normalized()
	var endPoint: Vector3 = localDirection * DIRECTION_LENGTH
	var points: PackedVector3Array = PackedVector3Array([Vector3.ZERO, endPoint])
	gizmo.add_lines(points, get_material(line_material_name, gizmo), false)
	var xform: Transform3D = Transform3D(Basis(), endPoint)
	gizmo.add_mesh(_quad_mesh, get_material(icon_material_name, gizmo), xform)
