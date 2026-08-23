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

	refresh_components_list()


func _exit_tree() -> void:
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

	for child: Node in _components_container.get_children():
		child.queue_free()

	if not is_instance_valid(_host):
		return

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
			_build_component_inspector(component, inspectorContainer)

		var toggleCollapse: Callable = func():
			var curState: bool = _expanded_components.get(pathKey, false)
			_expanded_components[pathKey] = not curState
			refresh_components_list()

		foldBtn.pressed.connect(toggleCollapse)
		titleBtn.pressed.connect(toggleCollapse)

		_components_container.add_child(card)


func _build_component_inspector(component: Node, container: VBoxContainer) -> void:
	var separator: HSeparator = HSeparator.new()
	container.add_child(separator)

	var subInspector: EditorInspector = EditorInspector.new()
	subInspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subInspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subInspector.custom_minimum_size = Vector2(0, 300)
	subInspector.edit(component)
	container.add_child(subInspector)


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
