@tool
class_name JoltNegativeScaleFixer extends RefCounted

## 修复 Jolt 不支持的碰撞体全局变换。
##
## Jolt 只看每个 CollisionObject3D 自身的全局变换。会报
## "Failed to correctly scale body" 的是：
## 1. 全局基行列式 < 0（本地负缩放或祖先镜像）。
## 2. 剪切（基不正交）。正交的非均匀缩放是合法的：Box 可任意轴比，
##    Cylinder/Capsule 只要 X=Z，凸/凹网格也可非均匀。Trigger / Ground
##    拉长盒子不要被平均成均匀缩放。
## 3. 挂在「已剪切」或「非均匀且带旋转」的祖先下：父节点一转，
##    子节点全局基就被剪。轴对齐的纯拉长（Trigger / Ground）不重挂。
##
## 修复顺序：
## - CollisionObject3D 若祖先本地基被剪，提到最近的正交祖先。
## - 再对全局 det < 0 翻转一个列向量。
## - 自身基被剪，或形状不允许当前轴比时，才 bake / 正交化。
## 视觉 MeshInstance3D 一律不修改。

const MESH_SHAPES_WARNING := [
	"ConcavePolygonShape3D",
	"ConvexPolygonShape3D",
	"HeightMapShape3D",
]

const UNIFORM_EPSILON := 0.001


## 扫描并修复 scene_root 下所有 Jolt 不接受的物理节点变换。
## undo_redo 传 null 时直接写入（脚本通道），否则以单个可撤销动作提交。
## 返回 {"fixed": int, "reparented": int, "degenerate": int, "warnings": PackedStringArray}
static func repair(scene_root: Node, undo_redo: EditorUndoRedoManager) -> Dictionary:
	var result: Dictionary = {
		"fixed": 0,
		"reparented": 0,
		"degenerate": 0,
		"warnings": PackedStringArray(),
	}
	var reparents: Array[Dictionary] = []
	_collect_reparents(scene_root, scene_root, reparents, result)
	var reparentByNode: Dictionary = {}
	for move: Dictionary in reparents:
		reparentByNode[move["node"]] = move
	var edits: Array[Dictionary] = []
	var bakedShapes: Dictionary = {}
	_walk(scene_root, Transform3D.IDENTITY, Transform3D.IDENTITY, null,
			edits, result, reparentByNode, bakedShapes)
	if reparents.is_empty() and edits.is_empty():
		return result

	if undo_redo != null:
		undo_redo.create_action("修复 Jolt 缩放")
	for move: Dictionary in reparents:
		_apply_reparent(move, undo_redo, scene_root)
	for edit: Dictionary in edits:
		_apply_edit(edit, undo_redo)
	if undo_redo != null:
		undo_redo.commit_action()
	result["reparented"] = reparents.size()
	var editedNodes: Dictionary = {}
	for move: Dictionary in reparents:
		editedNodes[move["node"]] = true
	for edit: Dictionary in edits:
		editedNodes[edit["node"]] = true
	result["fixed"] = editedNodes.size()
	return result


static func _apply_reparent(move: Dictionary, undo_redo: EditorUndoRedoManager, scene_root: Node) -> void:
	var node: Node3D = move["node"]
	var oldParent: Node = move["old_parent"]
	var newParent: Node = move["new_parent"]
	var oldIndex: int = move["old_index"]
	var oldOwner: Node = move["old_owner"]
	var newOwner: Node = scene_root if oldOwner != null else null
	var oldLocal: Transform3D = move["old_local"]
	var newLocal: Transform3D = move["new_local"]
	if undo_redo != null:
		undo_redo.add_do_method(node, "reparent", newParent, false)
		undo_redo.add_do_property(node, "transform", newLocal)
		if newOwner != null:
			undo_redo.add_do_method(node, "set_owner", newOwner)
		# undo 按添加的逆序执行：先还原 local，再 reparent 回旧父，最后 move_child。
		undo_redo.add_undo_method(oldParent, "move_child", node, oldIndex)
		if oldOwner != null:
			undo_redo.add_undo_method(node, "set_owner", oldOwner)
		undo_redo.add_undo_method(node, "reparent", oldParent, false)
		undo_redo.add_undo_property(node, "transform", oldLocal)
	else:
		node.reparent(newParent, false)
		node.transform = newLocal
		if newOwner != null:
			node.owner = newOwner


static func _apply_edit(edit: Dictionary, undo_redo: EditorUndoRedoManager) -> void:
	var node: Node3D = edit["node"]
	if undo_redo != null:
		undo_redo.add_do_property(node, "transform", edit["fixed"])
		undo_redo.add_undo_property(node, "transform", edit["original"])
	else:
		node.transform = edit["fixed"]
	var shapeEdits: Array = edit.get("shape_edits", [])
	for shapeEdit: Dictionary in shapeEdits:
		var shapeNode: CollisionShape3D = shapeEdit["node"]
		if undo_redo != null:
			undo_redo.add_do_property(shapeNode, "transform", shapeEdit["fixed_xform"])
			undo_redo.add_undo_property(shapeNode, "transform", shapeEdit["original_xform"])
		else:
			shapeNode.transform = shapeEdit["fixed_xform"]
		var shape: Shape3D = shapeEdit.get("shape") as Shape3D
		if shape == null:
			continue
		var prop: StringName = shapeEdit["prop"]
		if undo_redo != null:
			undo_redo.add_do_property(shape, prop, shapeEdit["fixed_value"])
			undo_redo.add_undo_property(shape, prop, shapeEdit["original_value"])
		else:
			shape.set(prop, shapeEdit["fixed_value"])
		if shapeEdit.has("radius_prop"):
			var radiusProp: StringName = shapeEdit["radius_prop"]
			if undo_redo != null:
				undo_redo.add_do_property(shape, radiusProp, shapeEdit["fixed_radius"])
				undo_redo.add_undo_property(shape, radiusProp, shapeEdit["original_radius"])
			else:
				shape.set(radiusProp, shapeEdit["fixed_radius"])


## CollisionObject3D 挂在本地已剪切的 Node3D 祖先下时，
## 提到最近的正交祖先。仅非均匀、仍正交的祖先不重挂。
static func _collect_reparents(node: Node, scene_root: Node, reparents: Array[Dictionary],
		result: Dictionary) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		if not _has_queued_ancestor(body, reparents):
			var safeParent: Node = _nearest_orthogonal_ancestor(body, scene_root)
			if safeParent != null and safeParent != body.get_parent():
				var parent3d := safeParent as Node3D
				var parentGlobal: Transform3D = parent3d.global_transform if parent3d else Transform3D.IDENTITY
				var newLocal: Transform3D = parentGlobal.affine_inverse() * body.global_transform
				reparents.append({
					"node": body,
					"old_parent": body.get_parent(),
					"new_parent": safeParent,
					"old_index": body.get_index(),
					"old_owner": body.owner,
					"old_local": body.transform,
					"new_local": newLocal,
				})
			elif _chain_has_shear(body):
				_append_warning(result, "%s（祖先链没有正交的 Node3D 可挂，仅就地处理剪切）" % body.get_path())
	for child: Node in node.get_children():
		_collect_reparents(child, scene_root, reparents, result)


static func _has_queued_ancestor(node: Node, reparents: Array[Dictionary]) -> bool:
	for move: Dictionary in reparents:
		var ancestor: Node = move["node"]
		if ancestor.is_ancestor_of(node):
			return true
	return false


## 返回最近的祖先 P：P 到根的整条 Node3D 链本地基都正交。
## 当前父已满足则返回 null。中间夹着单位变换节点不能当安全父——
## 已剪切的祖先一旋转，单位子节点的全局基仍会被剪。
static func _nearest_orthogonal_ancestor(node: Node, _scene_root: Node) -> Node:
	var parent: Node = node.get_parent()
	if parent == null:
		return null
	var chain: Array[Node] = []
	var current: Node = parent
	while current != null:
		chain.append(current)
		current = current.get_parent()
	var unsafeFromRoot: bool = false
	var flags: Array[bool] = []
	flags.resize(chain.size())
	for i: int in range(chain.size() - 1, -1, -1):
		var as3d := chain[i] as Node3D
		if as3d != null and _ancestor_can_shear_descendants(as3d):
			unsafeFromRoot = true
		flags[i] = unsafeFromRoot
	if not flags[0]:
		return null
	for i: int in range(chain.size()):
		if not flags[i]:
			return chain[i]
	return null


static func _chain_has_shear(node: Node) -> bool:
	var current: Node = node.get_parent()
	while current != null:
		var as3d := current as Node3D
		if as3d != null and _ancestor_can_shear_descendants(as3d):
			return true
		current = current.get_parent()
	return false


## 深度优先遍历。ancestorCorr / ancestorOrig 用于把最近一个已修复祖先的
## 全局修正量沿未修改的中间节点传递到后代：
## corrected(desc) = ancestorCorr * (ancestorOrig^-1 * global(desc))。
static func _walk(node: Node, ancestor_corr: Transform3D, ancestor_orig: Transform3D,
		fixed_ancestor: Node, edits: Array[Dictionary], result: Dictionary,
		reparent_by_node: Dictionary, baked_shapes: Dictionary) -> void:
	var node3d := node as Node3D
	if node3d == null:
		for child: Node in node.get_children():
			_walk(child, ancestor_corr, ancestor_orig, fixed_ancestor,
					edits, result, reparent_by_node, baked_shapes)
		return

	var originalGlobal: Transform3D = node3d.global_transform
	var effectiveGlobal: Transform3D = originalGlobal
	if fixed_ancestor != null:
		effectiveGlobal = ancestor_corr * (ancestor_orig.affine_inverse() * originalGlobal)

	if node3d is CollisionObject3D:
		var det: float = effectiveGlobal.basis.determinant()
		if absf(det) < 0.000001:
			result["degenerate"] += 1
		else:
			var corrected: Transform3D = effectiveGlobal
			var didFix: bool = false
			var shapeEdits: Array = []
			if det < 0.0:
				corrected.basis.x = -effectiveGlobal.basis.x
				didFix = true
				_collect_shape_warnings(node3d, effectiveGlobal, result)
			if _is_basis_sheared(corrected.basis) or not _shapes_accept_scale(node3d, corrected.basis):
				var baked: Dictionary = _repair_invalid_scale(node3d, corrected, result)
				corrected = baked["global"]
				shapeEdits = baked["shape_edits"]
				didFix = true
			if didFix:
				var parentNode: Node = node3d.get_parent()
				var originalLocal: Transform3D = node3d.transform
				if reparent_by_node.has(node3d):
					parentNode = reparent_by_node[node3d]["new_parent"]
					originalLocal = reparent_by_node[node3d]["new_local"]
				var parentGlobal: Transform3D = _parent_global_after_fix(
						parentNode, fixed_ancestor, ancestor_corr, ancestor_orig)
				var newLocal: Transform3D = parentGlobal.affine_inverse() * corrected
				edits.append({
					"node": node3d,
					"original": originalLocal,
					"fixed": newLocal,
					"shape_edits": shapeEdits,
				})
				for shapeEdit: Dictionary in shapeEdits:
					baked_shapes[shapeEdit["node"]] = true
				ancestor_corr = corrected
				ancestor_orig = originalGlobal
				fixed_ancestor = node3d

	for child: Node in node.get_children():
		_walk(child, ancestor_corr, ancestor_orig, fixed_ancestor,
				edits, result, reparent_by_node, baked_shapes)


static func _parent_global_after_fix(parent_node: Node, fixed_ancestor: Node,
		ancestor_corr: Transform3D, ancestor_orig: Transform3D) -> Transform3D:
	var parent3d := parent_node as Node3D
	if parent3d == null:
		return Transform3D.IDENTITY
	if fixed_ancestor == null:
		return parent3d.global_transform
	if parent_node == fixed_ancestor:
		return ancestor_corr
	if fixed_ancestor.is_ancestor_of(parent_node):
		return ancestor_corr * (ancestor_orig.affine_inverse() * parent3d.global_transform)
	return parent3d.global_transform


static func _is_basis_sheared(basis: Basis) -> bool:
	var x: Vector3 = basis.x
	var y: Vector3 = basis.y
	var z: Vector3 = basis.z
	if x.length_squared() < 0.000001 or y.length_squared() < 0.000001 or z.length_squared() < 0.000001:
		return true
	return absf(x.normalized().dot(y.normalized())) > UNIFORM_EPSILON \
			or absf(y.normalized().dot(z.normalized())) > UNIFORM_EPSILON \
			or absf(x.normalized().dot(z.normalized())) > UNIFORM_EPSILON


## 非均匀缩放的祖先一旦再带旋转（或已剪切），子节点运行时全局基会被剪。
## 纯轴对齐拉长（Trigger / Ground）返回 false，子碰撞体留在原处。
static func _ancestor_can_shear_descendants(node: Node3D) -> bool:
	var basis: Basis = node.transform.basis
	if _is_basis_sheared(basis):
		return true
	if _is_scale_uniform(basis.get_scale()):
		return false
	return not _is_axis_aligned(basis)


static func _is_axis_aligned(basis: Basis) -> bool:
	var axes: Array[Vector3] = [basis.x.normalized(), basis.y.normalized(), basis.z.normalized()]
	for axis: Vector3 in axes:
		var aligned: int = 0
		if absf(axis.x) > 1.0 - UNIFORM_EPSILON:
			aligned += 1
		if absf(axis.y) > 1.0 - UNIFORM_EPSILON:
			aligned += 1
		if absf(axis.z) > 1.0 - UNIFORM_EPSILON:
			aligned += 1
		if aligned != 1:
			return false
	return true


static func _is_scale_uniform(scale: Vector3) -> bool:
	var absScale := Vector3(absf(scale.x), absf(scale.y), absf(scale.z))
	return absf(absScale.x - absScale.y) <= UNIFORM_EPSILON \
			and absf(absScale.y - absScale.z) <= UNIFORM_EPSILON \
			and absf(absScale.x - absScale.z) <= UNIFORM_EPSILON


## Jolt 对正交非均匀缩放：Box / 凸凹网格任意轴比都合法；
## Sphere 必须均匀；Capsule / Cylinder 必须 X=Z。
static func _shapes_accept_scale(body: CollisionObject3D, basis: Basis) -> bool:
	var scale: Vector3 = basis.get_scale()
	var absScale := Vector3(absf(scale.x), absf(scale.y), absf(scale.z))
	for child: Node in body.get_children():
		var shapeNode := child as CollisionShape3D
		if shapeNode == null or shapeNode.shape == null:
			continue
		var className: String = shapeNode.shape.get_class()
		match className:
			"BoxShape3D", "ConvexPolygonShape3D", "ConcavePolygonShape3D", "HeightMapShape3D":
				continue
			"SphereShape3D":
				if not _is_scale_uniform(absScale):
					return false
			"CapsuleShape3D", "CylinderShape3D":
				if absf(absScale.x - absScale.z) > UNIFORM_EPSILON:
					return false
			_:
				if not _is_scale_uniform(absScale):
					return false
	return true


## 剪切：去掉剪切、保留各轴长度（正交非均匀）。
## 形状不允许的轴比：把差异 bake 进 size/radius，身体改为均匀缩放。
static func _repair_invalid_scale(node: Node3D, global_xform: Transform3D, result: Dictionary) -> Dictionary:
	var sheared: bool = _is_basis_sheared(global_xform.basis)
	var scale: Vector3 = global_xform.basis.get_scale()
	var absScale := Vector3(absf(scale.x), absf(scale.y), absf(scale.z))
	var rotation: Basis = global_xform.basis.orthonormalized()
	if global_xform.basis.determinant() < 0.0:
		rotation.x = -rotation.x
	var shapeEdits: Array = []
	var corrected: Transform3D
	if sheared:
		corrected = Transform3D(rotation.scaled(absScale), global_xform.origin)
		if node is CollisionObject3D and not _shapes_accept_scale(node, corrected.basis):
			return _bake_to_uniform(node, corrected, result)
		return {"global": corrected, "shape_edits": shapeEdits}
	return _bake_to_uniform(node, global_xform, result)


static func _bake_to_uniform(node: Node3D, global_xform: Transform3D, result: Dictionary) -> Dictionary:
	var scale: Vector3 = global_xform.basis.get_scale()
	var absScale := Vector3(absf(scale.x), absf(scale.y), absf(scale.z))
	var uniform: float = (absScale.x + absScale.y + absScale.z) / 3.0
	if uniform < 0.000001:
		uniform = 1.0
	var rotation: Basis = global_xform.basis.orthonormalized()
	if global_xform.basis.determinant() < 0.0:
		rotation.x = -rotation.x
	var corrected := Transform3D(rotation * uniform, global_xform.origin)
	var shapeEdits: Array = []
	var relative := Vector3(absScale.x / uniform, absScale.y / uniform, absScale.z / uniform)
	if node is CollisionObject3D:
		for child: Node in node.get_children():
			var shapeNode := child as CollisionShape3D
			if shapeNode == null or shapeNode.shape == null:
				continue
			var bakedShape: Dictionary = _bake_shape_scale(shapeNode, relative, result)
			if not bakedShape.is_empty():
				shapeEdits.append(bakedShape)
	else:
		_append_warning(result, "%s（无法 bake 的物理节点，已改为均匀缩放，请验证碰撞）" % node.get_path())
	return {"global": corrected, "shape_edits": shapeEdits}


static func _bake_shape_scale(shapeNode: CollisionShape3D, relative: Vector3, result: Dictionary) -> Dictionary:
	var shape: Shape3D = shapeNode.shape
	var className: String = shape.get_class()
	if className in MESH_SHAPES_WARNING:
		_append_warning(result, "%s（%s 无法把非均匀缩放 bake 进尺寸，已正交化，请验证碰撞）"
				% [shapeNode.get_path(), className])
		return {}
	if not _is_signed_permutation(shapeNode.transform.basis) \
			and not shapeNode.transform.basis.is_conformal():
		_append_warning(result, "%s（本地基含旋转/剪切，bake 后足迹请验证）" % shapeNode.get_path())
	var localScale: Vector3 = shapeNode.transform.basis.get_scale()
	var combined := Vector3(
			relative.x * absf(localScale.x),
			relative.y * absf(localScale.y),
			relative.z * absf(localScale.z))
	var localRotation: Basis = shapeNode.transform.basis.orthonormalized()
	if shapeNode.transform.basis.determinant() < 0.0:
		localRotation.x = -localRotation.x
	var fixedXform := Transform3D(localRotation, shapeNode.transform.origin)
	match className:
		"BoxShape3D":
			var size: Vector3 = shape.get("size")
			return {
				"node": shapeNode,
				"original_xform": shapeNode.transform,
				"fixed_xform": fixedXform,
				"shape": shape,
				"prop": &"size",
				"original_value": size,
				"fixed_value": Vector3(size.x * combined.x, size.y * combined.y, size.z * combined.z),
			}
		"SphereShape3D":
			var radius: float = float(shape.get("radius"))
			var mean: float = (combined.x + combined.y + combined.z) / 3.0
			if not _is_uniform_vec(combined):
				_append_warning(result, "%s（SphereShape3D 非均匀已按平均轴 bake，请验证碰撞）" % shapeNode.get_path())
			return {
				"node": shapeNode,
				"original_xform": shapeNode.transform,
				"fixed_xform": fixedXform,
				"shape": shape,
				"prop": &"radius",
				"original_value": radius,
				"fixed_value": radius * mean,
			}
		"CapsuleShape3D", "CylinderShape3D":
			if absf(combined.x - combined.z) > UNIFORM_EPSILON:
				_append_warning(result, "%s（%s 的 X/Z 必须均匀，已正交化，请验证碰撞）"
						% [shapeNode.get_path(), className])
				return {}
			var height: float = float(shape.get("height"))
			var originalRadius: float = float(shape.get("radius"))
			return {
				"node": shapeNode,
				"original_xform": shapeNode.transform,
				"fixed_xform": fixedXform,
				"shape": shape,
				"prop": &"height",
				"original_value": height,
				"fixed_value": height * combined.y,
				"radius_prop": &"radius",
				"original_radius": originalRadius,
				"fixed_radius": originalRadius * combined.x,
			}
		_:
			_append_warning(result, "%s（%s 未支持 bake，已正交化，请验证碰撞）"
					% [shapeNode.get_path(), className])
			return {}


static func _is_uniform_vec(scale: Vector3) -> bool:
	return absf(scale.x - scale.y) <= UNIFORM_EPSILON \
			and absf(scale.y - scale.z) <= UNIFORM_EPSILON \
			and absf(scale.x - scale.z) <= UNIFORM_EPSILON


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
