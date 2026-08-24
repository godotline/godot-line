@tool
extends RefCounted

## 合并当前场景中所有节点的相同材质：
## 收集场景内 GeometryInstance3D 的 material_override 与 MeshInstance3D 的
## surface_override_material，按材质的存储属性序列化结果分组，把属性完全
## 一致的材质统一指向同一份资源。保存场景后，重复的内联子资源会自动收敛
## 为一份，减小文件体积，并让相同 mesh + material 组合可被渲染器合批。
##
## 只处理节点自身的材质覆盖属性，不修改网格内嵌材质与外部资源文件。

class MaterialRef:
	var node: Node
	var property: String
	var material: Material
	var groupIndex: int


## 只读统计当前场景的材质引用与唯一材质数：{ "refs": int, "unique": int }
static func analyze(sceneRoot: Node) -> Dictionary:
	var groups: Array[Array] = _scan_groups(sceneRoot)
	var refCount: int = 0
	for group: Array in groups:
		refCount += group.size()
	return { "refs": refCount, "unique": groups.size() }


## 执行合并，返回统计：{ "refs": 引用总数, "unique": 唯一材质数, "replaced": 已替换引用数 }
static func merge(sceneRoot: Node, undoRedo: EditorUndoRedoManager) -> Dictionary:
	var groups: Array[Array] = _scan_groups(sceneRoot)

	var canonicals: Array[Material] = []
	for group: Array in groups:
		canonicals.append(_pick_canonical(group))

	undoRedo.create_action("合并相同材质")
	var refCount: int = 0
	var replacedCount: int = 0
	for i: int in range(groups.size()):
		var canonical: Material = canonicals[i]
		for member: MaterialRef in groups[i]:
			refCount += 1
			if member.material == canonical:
				continue
			replacedCount += 1
			undoRedo.add_do_property(member.node, member.property, canonical)
			undoRedo.add_undo_property(member.node, member.property, member.material)

	if replacedCount == 0:
		undoRedo.commit_action(false)
	else:
		undoRedo.commit_action()

	return { "refs": refCount, "unique": groups.size(), "replaced": replacedCount }


static func _scan_groups(sceneRoot: Node) -> Array[Array]:
	var refs: Array[MaterialRef] = []
	_collect_refs(sceneRoot, sceneRoot, refs)
	var groups: Array[Array] = []
	var indexByKey: Dictionary = {}
	for ref: MaterialRef in refs:
		var key: String = _resource_key(ref.material)
		if indexByKey.has(key):
			ref.groupIndex = indexByKey[key]
			groups[indexByKey[key]].append(ref)
		else:
			ref.groupIndex = groups.size()
			indexByKey[key] = groups.size()
			groups.append([ref])
	return groups


## 资源身份键：序列化全部存储属性（嵌套资源递归），属性完全一致 ⇒ 键相同。
## 不用 var_to_bytes：它含实例级元数据，逐份复制的内联材质永远互不相等。
static func _resource_key(resource: Resource) -> String:
	var props: Dictionary = {}
	var script: Script = resource.get_script()
	props["script"] = script.resource_path if script else ""
	for p: Dictionary in resource.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE:
			var propertyName: String = p["name"]
			props[propertyName] = _value_key(resource.get(propertyName))
	return var_to_str(props)


static func _value_key(value: Variant) -> String:
	# 注意：value 为 int/float/Color 等值类型时不能用 as Resource（运行时报 Invalid cast）
	if value is Resource:
		var resource: Resource = value
		if not resource.resource_path.is_empty():
			return resource.resource_path
		return _resource_key(resource)
	return var_to_str(value)


## 规范材质优先选已有外部路径的资源（如 #Template/[Materials]/ 下的 .tres），否则取组内第一个
static func _pick_canonical(group: Array) -> Material:
	for member: MaterialRef in group:
		if not member.material.resource_path.is_empty():
			return member.material
	return (group[0] as MaterialRef).material


static func _collect_refs(node: Node, sceneRoot: Node, out: Array[MaterialRef]) -> void:
	# 只处理属于当前编辑场景的节点，避免污染实例化子场景内部
	if node == sceneRoot or node.owner == sceneRoot:
		var geometry := node as GeometryInstance3D
		if geometry:
			var override := geometry.material_override
			if override:
				out.append(_make_ref(geometry, "material_override", override))
		var meshInstance := node as MeshInstance3D
		if meshInstance and meshInstance.mesh:
			for surface: int in range(meshInstance.mesh.get_surface_count()):
				var surfaceMaterial := meshInstance.get_surface_override_material(surface)
				if surfaceMaterial:
					out.append(_make_ref(meshInstance, "surface_override_material/%d" % surface, surfaceMaterial))
	for child: Node in node.get_children():
		_collect_refs(child, sceneRoot, out)


static func _make_ref(node: Node, property: String, material: Material) -> MaterialRef:
	var ref := MaterialRef.new()
	ref.node = node
	ref.property = property
	ref.material = material
	return ref
