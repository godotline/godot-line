@tool
extends VBoxContainer
class_name ComponentAddPanel

## 通用「添加组件」面板：显示在任意 Node 的 Inspector 底部。
## 1. 收集并展示当前节点下所有子组件，支持折叠/展开直接内联编辑子组件属性。
## 2. 提供 Add Component 按钮，点击调用原生快速加载对话框（popup_quick_open）选择脚本添加为子节点组件。

var _host: Node
var _components_container: VBoxContainer
var _add_button: Button
var _expanded_components: Dictionary = {} # Dictionary[String, bool] (node_path -> is_expanded)


func _ready() -> void:
	_build_ui()
	refresh_components_list()


func inspect(host: Node) -> void:
	if _host and is_instance_valid(_host):
		if _host.child_entered_tree.is_connected(_on_host_children_changed):
			_host.child_entered_tree.disconnect(_on_host_children_changed)
		if _host.child_exiting_tree.is_connected(_on_host_children_changed):
			_host.child_exiting_tree.disconnect(_on_host_children_changed)
		if _host.child_order_changed.is_connected(_on_host_children_changed):
			_host.child_order_changed.disconnect(_on_host_children_changed)

	_host = host

	if _host and is_instance_valid(_host):
		_host.child_entered_tree.connect(_on_host_children_changed)
		_host.child_exiting_tree.connect(_on_host_children_changed)
		_host.child_order_changed.connect(_on_host_children_changed)

	_scrub_stale_base_meta()
	_attach_save_watcher()

	refresh_components_list()


func _exit_tree() -> void:
	_detach_save_watcher()
	_clear_base_node_meta()
	if _host and is_instance_valid(_host):
		if _host.child_entered_tree.is_connected(_on_host_children_changed):
			_host.child_entered_tree.disconnect(_on_host_children_changed)
		if _host.child_exiting_tree.is_connected(_on_host_children_changed):
			_host.child_exiting_tree.disconnect(_on_host_children_changed)
		if _host.child_order_changed.is_connected(_on_host_children_changed):
			_host.child_order_changed.disconnect(_on_host_children_changed)


func _on_host_children_changed(_arg: Variant = null) -> void:
	call_deferred("refresh_components_list")


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)

	_components_container = VBoxContainer.new()
	_components_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_components_container.add_theme_constant_override("separation", 4)
	add_child(_components_container)

	_add_button = Button.new()
	_add_button.text = "Add Component"
	_add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button.tooltip_text = "打开快速加载对话框，选择组件脚本并作为子节点添加到当前节点"
	_add_button.pressed.connect(_open_script_dialog)
	add_child(_add_button)


## 收集并刷新当前节点下的所有子组件
func refresh_components_list() -> void:
	if _components_container == null or not is_instance_valid(_components_container):
		return

	_clear_base_node_meta()
	for child: Node in _components_container.get_children():
		child.queue_free()

	if not is_instance_valid(_host):
		return

	_expanded_refs.clear()

	var components: Array[Node] = _collect_child_components(_host)
	if components.is_empty():
		return

	# 组件列表标题
	var headerBox: HBoxContainer = HBoxContainer.new()
	headerBox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var headerLabel: Label = Label.new()
	headerBox.add_child(headerLabel)
	_components_container.add_child(headerBox)

	# 遍历各个子组件渲染卡片
	for component: Node in components:
		var card: PanelContainer = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cardStyle: StyleBoxFlat = StyleBoxFlat.new()
		cardStyle.bg_color = Color(0.18, 0.19, 0.22, 0.9)
		cardStyle.corner_radius_top_left = 4
		cardStyle.corner_radius_top_right = 4
		cardStyle.corner_radius_bottom_right = 4
		cardStyle.corner_radius_bottom_left = 4
		cardStyle.content_margin_left = 6
		cardStyle.content_margin_right = 6
		cardStyle.content_margin_top = 4
		cardStyle.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", cardStyle)

		var cardVbox: VBoxContainer = VBoxContainer.new()
		cardVbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cardVbox.add_theme_constant_override("separation", 4)
		card.add_child(cardVbox)

		# 顶部栏
		var topHbox: HBoxContainer = HBoxContainer.new()
		topHbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		topHbox.add_theme_constant_override("separation", 6)
		cardVbox.add_child(topHbox)

		var pathKey: String = str(component.get_path())
		var isExpanded: bool = _expanded_components.get(pathKey, false)

		var foldBtn: Button = Button.new()
		foldBtn.text = "▼" if isExpanded else "▶"
		foldBtn.flat = true
		topHbox.add_child(foldBtn)

		var script: Script = component.get_script() as Script
		var typeText: String = ""
		if script:
			typeText = script.resource_path.get_file().get_basename()
		else:
			typeText = component.get_class()

		var titleBtn: Button = Button.new()
		titleBtn.text = typeText
		titleBtn.flat = true
		titleBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		titleBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		titleBtn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		topHbox.add_child(titleBtn)

		# 快捷删除按钮
		var deleteBtn: Button = Button.new()
		deleteBtn.text = "×"
		deleteBtn.flat = true
		deleteBtn.pressed.connect(func(): _remove_component(component))
		topHbox.add_child(deleteBtn)

		# 展开的内联属性编辑器
		var inspectorContainer: VBoxContainer = VBoxContainer.new()
		inspectorContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inspectorContainer.visible = isExpanded
		cardVbox.add_child(inspectorContainer)

		if isExpanded:
			_expanded_refs.append(component)
			_build_component_inspector(component, inspectorContainer)

		var toggleCollapse: Callable = func():
			var curState: bool = _expanded_components.get(pathKey, false)
			_expanded_components[pathKey] = not curState
			refresh_components_list()

		foldBtn.pressed.connect(toggleCollapse)
		titleBtn.pressed.connect(toggleCollapse)

		_components_container.add_child(card)


const BASE_NODE_META := "__base_node_relative"
const SAVE_WATCHER_PATH := "res://addons/template/component_save_watcher.gd"
# 防止共享 Resource 被多组件复用时重复清理掉别家设的 meta：只清理我们自己设的。
var _meta_owned_resources: Array[Resource] = []
# 当前展开卡片的组件引用，保存后恢复 meta 用。
var _expanded_refs: Array[Node] = []
var _saveWatcher: Node = null

enum MetaWalkMode { TAG, SCRUB }


func _build_component_inspector(component: Node, container: VBoxContainer) -> void:
	var separator: HSeparator = HSeparator.new()
	container.add_child(separator)

	# 嵌入式 Inspector 编辑 component 的 Resource 属性时，引擎 EditorPropertyNodePath
	# 会因 Resource 不是 Node 而回退到 InspectorDock 选中节点作为 NodePath 基准，
	# 导致相对路径算错（如 ../../Node 变成 ../Node）。这里给所有可达 Resource 设
	# __base_node_relative meta 指向 component，引擎优先级高于 InspectorDock 回退。
	# 该 meta 仅存在于编辑期：Godot 4 会把它连同引用的整个节点序列化进 .tscn，
	# 重开后成为不在场景树里的幽灵副本（NodePath picker 因此报 not in a scene tree），
	# 故保存前由哨兵节点清除、保存后恢复；旧场景残留的幽灵 meta 由 scrub 自愈。
	_apply_base_node_meta(component, component)

	var subInspector: EditorInspector = EditorInspector.new()
	subInspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subInspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subInspector.custom_minimum_size = Vector2(0, 300)
	subInspector.edit(component)
	container.add_child(subInspector)


## 为 node 所有可达 Resource 打 TAG：设置 __base_node_relative 指向 baseNode。
func _apply_base_node_meta(node: Node, baseNode: Node) -> void:
	_walk_node_resources(node, baseNode, MetaWalkMode.TAG, [])


## 清除宿主各组件上指向已不在场景树的陈旧 __base_node_relative（旧版本曾把该
## meta 序列化进 .tscn，重开后成为幽灵节点副本）。
func _scrub_stale_base_meta() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var removedAny: bool = false
	for component: Node in _collect_child_components(_host):
		var removedFlag: Array[bool] = [false]
		_walk_node_resources(component, component, MetaWalkMode.SCRUB, removedFlag)
		removedAny = removedAny or removedFlag[0]
	if removedAny:
		EditorInterface.mark_scene_as_unsaved()


func _walk_node_resources(node: Node, baseNode: Node, mode: MetaWalkMode, removedFlag: Array[bool]) -> void:
	for propInfo: Dictionary in node.get_property_list():
		var usage: int = propInfo.get("usage", 0)
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var propName: String = propInfo.get("name", "")
		if propName.is_empty() or propName == "script":
			continue
		_walk_resources(node.get(propName), baseNode, {}, mode, removedFlag)


func _walk_resources(value: Variant, baseNode: Node, visited: Dictionary, mode: MetaWalkMode, removedFlag: Array[bool]) -> void:
	if value is Resource:
		_visit_resource(value as Resource, baseNode, visited, mode, removedFlag)
	elif value is Array:
		for item: Variant in value as Array:
			_walk_resources(item, baseNode, visited, mode, removedFlag)
	elif value is Dictionary:
		for item: Variant in (value as Dictionary).values():
			_walk_resources(item, baseNode, visited, mode, removedFlag)


func _visit_resource(res: Resource, baseNode: Node, visited: Dictionary, mode: MetaWalkMode, removedFlag: Array[bool]) -> void:
	if res == null:
		return
	# 防止 Resource 自引用导致无限递归
	var id: int = res.get_instance_id()
	if visited.has(id):
		return
	visited[id] = true

	match mode:
		MetaWalkMode.TAG:
			# 已指向当前组件则跳过；否则一律接管——包括旧场景残留的幽灵节点 meta，
			# 覆写为活组件即完成自愈。
			var existing: Variant = null
			if res.has_meta(BASE_NODE_META):
				existing = res.get_meta(BASE_NODE_META)
			if existing != baseNode:
				res.set_meta(BASE_NODE_META, baseNode)
				if not _meta_owned_resources.has(res):
					_meta_owned_resources.append(res)
		MetaWalkMode.SCRUB:
			if res.has_meta(BASE_NODE_META):
				var val: Variant = res.get_meta(BASE_NODE_META)
				if val is Node and not (val as Node).is_inside_tree():
					res.remove_meta(BASE_NODE_META)
					removedFlag[0] = true

	# 递归该 Resource 自身的 Resource 属性（如 SingleActive 里再嵌 Resource）。
	for propInfo: Dictionary in res.get_property_list():
		var usage: int = propInfo.get("usage", 0)
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var propName: String = propInfo.get("name", "")
		if propName.is_empty() or propName == "script":
			continue
		_walk_resources(res.get(propName), baseNode, visited, mode, removedFlag)


func _clear_base_node_meta() -> void:
	for res: Resource in _meta_owned_resources:
		if is_instance_valid(res) and res.has_meta(BASE_NODE_META):
			res.remove_meta(BASE_NODE_META)
	_meta_owned_resources.clear()


func _attach_save_watcher() -> void:
	if _saveWatcher != null and is_instance_valid(_saveWatcher) and _saveWatcher.get_parent() == _host:
		return
	_detach_save_watcher()
	if _host == null or not _host.is_inside_tree():
		return
	var script: GDScript = load(SAVE_WATCHER_PATH) as GDScript
	if script == null:
		push_error("[组件] 无法加载保存哨兵脚本: %s" % SAVE_WATCHER_PATH)
		return
	_saveWatcher = script.new() as Node
	_saveWatcher.name = "ComponentPanelSaveWatcher"
	_saveWatcher.set("onPreSave", _on_pre_save)
	_saveWatcher.set("onPostSave", _on_post_save)
	# 无 owner 内部子节点：不序列化进场景，仅用于接收保存前后通知。
	_host.add_child(_saveWatcher, false, Node.INTERNAL_MODE_BACK)


func _detach_save_watcher() -> void:
	if _saveWatcher != null and is_instance_valid(_saveWatcher):
		_saveWatcher.queue_free()
	_saveWatcher = null


func _on_pre_save() -> void:
	_clear_base_node_meta()


func _on_post_save() -> void:
	for component: Node in _expanded_refs:
		if is_instance_valid(component) and component.is_inside_tree():
			_apply_base_node_meta(component, component)


func _collect_child_components(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		if child.get_script() != null and child.get_class() == "Node":
			result.append(child)
	return result


func _remove_component(component: Node) -> void:
	if not is_instance_valid(component) or not is_instance_valid(_host):
		return
	var sceneRoot: Node = EditorInterface.get_edited_scene_root()
	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var componentName: String = component.name
	var originalOwner: Node = component.owner
	var pathKey: String = str(component.get_path())

	undoRedo.create_action("移除组件: %s" % componentName)
	undoRedo.add_do_method(_host, "remove_child", component)
	undoRedo.add_undo_method(_host, "add_child", component, true)
	if originalOwner:
		undoRedo.add_undo_method(component, "set_owner", originalOwner)
	if _host.has_method("refresh_behaviors"):
		undoRedo.add_do_method(_host, "refresh_behaviors")
		undoRedo.add_undo_method(_host, "refresh_behaviors")
	undoRedo.add_undo_reference(component)
	undoRedo.commit_action()

	_expanded_components.erase(pathKey)
	EditorInterface.mark_scene_as_unsaved()
	_host.notify_property_list_changed()
	refresh_components_list()


func _open_script_dialog() -> void:
	EditorInterface.popup_quick_open(_on_quick_open_selected, [&"Script"])


func _on_quick_open_selected(path: String) -> void:
	if path.is_empty():
		return
	var script: Script = load(path) as Script
	if script == null:
		push_error("[组件] 无法加载脚本: %s" % path)
		return
	_add_component(_host, script)


func _add_component(host: Node, script: Script) -> void:
	if not is_instance_valid(host):
		push_error("[组件] 目标节点无效")
		return
	var sceneRoot: Node = EditorInterface.get_edited_scene_root()
	if sceneRoot == null or not (host == sceneRoot or sceneRoot.is_ancestor_of(host)):
		return

	var component: Node = script.new() as Node
	if component == null:
		push_error("[组件] 脚本必须继承 Node: %s" % script.resource_path)
		return

	var scriptName: String = script.resource_path.get_file().get_basename()
	if scriptName.is_empty():
		scriptName = script.resource_name
	component.name = scriptName if not scriptName.is_empty() else "Component"

	var sceneOwner: Node = host.owner
	if sceneOwner == null:
		sceneOwner = sceneRoot
	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("添加组件: %s" % scriptName)
	undoRedo.add_do_method(host, "add_child", component, true)
	if sceneOwner:
		undoRedo.add_do_method(component, "set_owner", sceneOwner)
	if host.has_method("refresh_behaviors"):
		undoRedo.add_do_method(host, "refresh_behaviors")
		undoRedo.add_undo_method(host, "refresh_behaviors")
	undoRedo.add_undo_method(host, "remove_child", component)
	undoRedo.add_do_reference(component)
	undoRedo.commit_action()

	EditorInterface.mark_scene_as_unsaved()
	host.notify_property_list_changed()

	# 默认展开新添加的组件
	var pathKey: String = str(component.get_path())
	_expanded_components[pathKey] = true

	refresh_components_list()
