extends Node
class_name SetMaterialColor

## Godot 移植自 Unity 模板 SetMaterialColor.cs（对应导入器 trigger type 8）。

@export var colors: Array[SingleColor] = []
@export var color: Color = Color.WHITE
@export var duration: float = 2.0
@export var TransitionType: Tween.TransitionType = Tween.TRANS_LINEAR
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT
@export var targetNodes: Array[Node] = []

var _tween: Tween = null


func trigger(_body: Node3D = null) -> void:
	if not colors.is_empty():
		for s: SingleColor in colors:
			s.apply_tweened(self, duration, int(TransitionType), int(EaseType))
		return

	var roots: Array[Node] = targetNodes
	if roots.is_empty() and get_parent() != null:
		roots.append(get_parent())

	var materials: Array[StandardMaterial3D] = []
	for root: Node in roots:
		var mesh := _resolveMesh(root)
		if mesh == null:
			continue
		var mat := mesh.material_override as Material
		if mat == null:
			var active: Material = mesh.get_active_material(0)
			if active == null:
				continue
			mat = active.duplicate()
			mesh.material_override = mat
		if mat is StandardMaterial3D:
			materials.append(mat as StandardMaterial3D)

	if materials.is_empty():
		push_warning("SetMaterialColor: 未解析到任何 StandardMaterial3D 目标")
		return

	if _tween != null and _tween.is_valid():
		_tween.kill()

	if duration <= 0.0:
		for stdMat: StandardMaterial3D in materials:
			stdMat.albedo_color = color
		return

	_tween = create_tween().set_parallel(true)
	for stdMat: StandardMaterial3D in materials:
		_tween.tween_property(stdMat, "albedo_color", color, duration).set_trans(TransitionType).set_ease(EaseType)


func _resolveMesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null
