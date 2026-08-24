@tool
class_name JoltNegativeScaleFixer extends RefCounted

## 修复 Jolt 不支持的负缩放碰撞体。
##
## Jolt 只看每个 CollisionObject3D 自身的全局变换：只要全局基行列式 < 0
## （无论来自本地 scale 还是祖先镜像，如导入器的 X 轴镜像载体），
## 运行期就会报 "Failed to correctly scale body" 并静默改用错误 scale。
##
## 修复方式：对全局基翻转一个列向量（x 轴取反）。Box/Capsule/Sphere/Cylinder
## 等图元形状对自身轴向反射对称，翻转后碰撞足迹逐点不变，而缩放全转为正。
## 非图元网格形状没有该对称性，仅修复并列入警告返回。
## 视觉 MeshInstance3D 一律不修改。

const MESH_SHAPES_WARNING := [
	"ConcavePolygonShape3D",
	"ConvexPolygonShape3D",
	"HeightMapShape3D",
]


## 扫描并修复 scene_root 下所有全局负缩放的物理节点。
## undo_redo 传 null 时直接写入（脚本通道），否则以单个可撤销动作提交。
## 返回 {"fixed": int, "degenerate": int, "warnings": PackedStringArray}
static func repair(scene_root: Node, undo_redo: EditorUndoRedoManager) -> Dictionary:
	var result: Dictionary = {"fixed": 0, "degenerate": 0, "warnings": PackedStringArray()}
	var edits: Array[Dictionary] = []
	_walk(scene_root, Transform3D.IDENTITY, Transform3D.IDENTITY, false,
			edits, result)
	if edits.is_empty():
		return result

	if undo_redo != null:
		undo_redo.create_action("修复 Jolt 负缩放")
	for edit: Dictionary in edits:
		var node: Node3D = edit["node"]
		if undo_redo != null:
			undo_redo.add_do_property(node, "transform", edit["fixed"])
			undo_redo.add_undo_property(node, "transform", edit["original"])
		else:
			node.transform = edit["fixed"]
	if undo_redo != null:
		undo_redo.commit_action()
	result["fixed"] = edits.size()
	return result


## 深度优先遍历。ancestorCorr / ancestorOrig 用于把最近一个已修复祖先的
## 全局修正量沿未修改的中间节点传递到后代：
## corrected(desc) = ancestorCorr * (ancestorOrig^-1 * global(desc))。
static func _walk(node: Node, ancestor_corr: Transform3D, ancestor_orig: Transform3D,
		has_fixed_ancestor: bool, edits: Array[Dictionary], result: Dictionary) -> void:
	var node3d := node as Node3D
	if node3d == null:
		for child: Node in node.get_children():
			_walk(child, ancestor_corr, ancestor_orig, has_fixed_ancestor, edits, result)
		return

	var originalGlobal: Transform3D = node3d.global_transform
	var effectiveGlobal: Transform3D = originalGlobal
	if has_fixed_ancestor:
		effectiveGlobal = ancestor_corr * (ancestor_orig.affine_inverse() * originalGlobal)

	if _is_physics_node(node3d):
		var det: float = effectiveGlobal.basis.determinant()
		if absf(det) < 0.000001:
			result["degenerate"] += 1
		elif det < 0.0:
			var corrected: Transform3D = effectiveGlobal
			corrected.basis.x = -effectiveGlobal.basis.x
			var parentNode := node3d.get_parent()
			var parent3d := parentNode as Node3D
			# Node3D 的父级若不是 Node3D，其全局即自身变换
			var parentGlobal: Transform3D = parent3d.global_transform if parent3d else Transform3D.IDENTITY
			var newLocal: Transform3D = parentGlobal.affine_inverse() * corrected
			edits.append({"node": node3d, "original": node3d.transform, "fixed": newLocal})
			_collect_shape_warnings(node3d, effectiveGlobal, result)
			ancestor_corr = corrected
			ancestor_orig = originalGlobal
			has_fixed_ancestor = true
		else:
			# 物理节点本身干净：其后代以原全局为基准继续检查
			pass

	for child: Node in node.get_children():
		_walk(child, ancestor_corr, ancestor_orig, has_fixed_ancestor, edits, result)


static func _is_physics_node(node: Node3D) -> bool:
	return node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D


static func _collect_shape_warnings(fixedNode: Node3D, _global_xform: Transform3D,
		result: Dictionary) -> void:
	for child: Node in fixedNode.get_children():
		var shapeNode := child as CollisionShape3D
		if shapeNode == null:
			continue
		if shapeNode.shape != null and shapeNode.shape.get_class() in MESH_SHAPES_WARNING:
			_append_warning(result, "%s（%s 无反射对称性，请验证碰撞）"
					% [shapeNode.get_path(), shapeNode.shape.get_class()])
		elif not _is_signed_permutation(shapeNode.transform.basis):
			_append_warning(result, "%s（本地基含旋转，翻转后足迹非逐点不变，请验证）"
					% shapeNode.get_path())


## 行/列均为符号置换矩阵（每个元素绝对值要么 0 要么彼此相等）时返回 true。
static func _is_signed_permutation(basis: Basis) -> bool:
	var rows: Array = [basis.x, basis.y, basis.z]
	var magnitudes: Array[float] = []
	for row: Vector3 in rows:
		for value: float in [absf(row.x), absf(row.y), absf(row.z)]:
			if value > 0.000001 and not magnitudes.has(value):
				magnitudes.append(value)
	if magnitudes.size() != 1:
		return false
	var magnitude: float = magnitudes[0]
	for row: Vector3 in rows:
		var nonZero: int = 0
		for value: float in [row.x, row.y, row.z]:
			if absf(value) > 0.000001:
				nonZero += 1
		if nonZero != 1 or not is_equal_approx(absf([row.x, row.y, row.z].max()), magnitude):
			return false
	return true


static func _append_warning(result: Dictionary, message: String) -> void:
	var warnings: PackedStringArray = result["warnings"]
	warnings.append(message)
	result["warnings"] = warnings
