@tool
extends VBoxContainer
class_name EventTriggerSignalEditor

var _source: Node
var _connections_box: VBoxContainer
var _dialog: ConfirmationDialog
var _node_tree: Tree
var _method_picker: OptionButton
var _selected_target: Node


func _ready() -> void:
	_build_ui()
	_refresh_connection_list()


func inspect(source: Node) -> void:
	_source = source
	if is_node_ready():
		_refresh_connection_list()


func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	var title: Label = Label.new()
	title.text = "触发信号：triggered"
	title.add_theme_font_size_override("font_size", 13)
	add_child(title)

	var description: Label = Label.new()
	description.text = "连接目标方法，等效于 Unity 的 onTriggerEnter UnityEvent。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	add_child(description)

	var action_row: HBoxContainer = HBoxContainer.new()
	add_child(action_row)
	var add_button: Button = Button.new()
	add_button.text = "添加回调"
	add_button.tooltip_text = "选择场景节点和无参数方法，连接到 triggered 信号"
	add_button.pressed.connect(_show_add_dialog)
	action_row.add_child(add_button)

	var refresh_button: Button = Button.new()
	refresh_button.text = "刷新"
	refresh_button.tooltip_text = "刷新当前信号连接列表"
	refresh_button.pressed.connect(_refresh_connection_list)
	action_row.add_child(refresh_button)

	var separator: HSeparator = HSeparator.new()
	add_child(separator)

	var connections_title: Label = Label.new()
	connections_title.text = "已连接回调"
	add_child(connections_title)

	_connections_box = VBoxContainer.new()
	_connections_box.add_theme_constant_override("separation", 4)
	add_child(_connections_box)


func _refresh_connection_list() -> void:
	if not is_instance_valid(_connections_box):
		return
	for child: Node in _connections_box.get_children():
		child.queue_free()

	if not is_instance_valid(_source) or not _source.has_signal(&"triggered"):
		_add_status("EventTrigger.triggered 不可用")
		return

	var connections: Array = _source.get_signal_connection_list(&"triggered")
	if connections.is_empty():
		_add_status("暂无回调")
		return

	for connection: Dictionary in connections:
		var callback: Callable = connection.get("callable", Callable())
		var target: Node = callback.get_object() as Node
		if not is_instance_valid(target):
			continue

		var row: HBoxContainer = HBoxContainer.new()
		var callback_label: Label = Label.new()
		callback_label.text = "%s.%s()" % [str(target.get_path()), String(callback.get_method())]
		callback_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		callback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(callback_label)

		var disconnect_button: Button = Button.new()
		disconnect_button.text = "断开"
		disconnect_button.tooltip_text = "断开这条 triggered 回调"
		disconnect_button.pressed.connect(_disconnect_callback.bind(target, callback.get_method()))
		row.add_child(disconnect_button)
		_connections_box.add_child(row)


func _add_status(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_connections_box.add_child(label)


func _show_add_dialog() -> void:
	if not is_instance_valid(_source):
		return
	if not is_instance_valid(_dialog):
		_build_dialog()
	_populate_node_tree()
	_dialog.popup_centered()


func _build_dialog() -> void:
	_dialog = ConfirmationDialog.new()
	_dialog.title = "添加 EventTrigger 回调"
	_dialog.ok_button_text = "连接"
	_dialog.cancel_button_text = "取消"
	_dialog.min_size = Vector2i(620, 480)
	_dialog.confirmed.connect(_on_dialog_confirmed)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_dialog.add_child(content)

	var target_label: Label = Label.new()
	target_label.text = "选择目标节点"
	content.add_child(target_label)

	_node_tree = Tree.new()
	_node_tree.custom_minimum_size = Vector2(0, 300)
	_node_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_node_tree.hide_root = false
	_node_tree.columns = 1
	_node_tree.item_selected.connect(_on_node_selected)
	content.add_child(_node_tree)

	var method_label: Label = Label.new()
	method_label.text = "选择无参数方法"
	content.add_child(method_label)

	_method_picker = OptionButton.new()
	_method_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_method_picker)

	var base_control: Control = EditorInterface.get_base_control()
	base_control.add_child(_dialog)


func _populate_node_tree() -> void:
	_node_tree.clear()
	_selected_target = null
	_method_picker.clear()

	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(scene_root):
		_set_dialog_enabled(false)
		return

	var root_item: TreeItem = _node_tree.create_item()
	root_item.set_text(0, "%s (%s)" % [scene_root.name, scene_root.get_class()])
	root_item.set_metadata(0, NodePath("."))
	_add_node_items(root_item, scene_root, scene_root)
	_set_dialog_enabled(false)


func _add_node_items(parent_item: TreeItem, parent_node: Node, scene_root: Node) -> void:
	for child: Node in parent_node.get_children():
		var item: TreeItem = _node_tree.create_item(parent_item)
		item.set_text(0, "%s (%s)" % [child.name, child.get_class()])
		item.set_metadata(0, scene_root.get_path_to(child))
		_add_node_items(item, child, scene_root)


func _on_node_selected(item: TreeItem, _column: int) -> void:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(scene_root):
		_set_dialog_enabled(false)
		return

	var path: NodePath = NodePath(item.get_metadata(0))
	_selected_target = scene_root.get_node_or_null(path)
	_method_picker.clear()
	if not is_instance_valid(_selected_target) or _selected_target == _source:
		_set_dialog_enabled(false)
		return

	var methods: Array[String] = _get_callback_methods(_selected_target)
	for method_index: int in range(methods.size()):
		_method_picker.add_item(methods[method_index], method_index)
	_set_dialog_enabled(not methods.is_empty())


func _get_callback_methods(target: Node) -> Array[String]:
	var method_names: Array[String] = []
	var script: Script = target.get_script() as Script
	while script:
		var method_list: Array = script.get_script_method_list()
		for method_info: Dictionary in method_list:
			var method_name: String = String(method_info.get("name", ""))
			var arguments: Array = method_info.get("args", [])
			if method_name.is_empty() or method_name.begins_with("_") or not arguments.is_empty():
				continue
			if not target.has_method(method_name) or method_name in method_names:
				continue
			method_names.append(method_name)
		script = script.get_base_script() as Script

	if method_names.is_empty() and not script:
		for method_info: Dictionary in target.get_method_list():
			var method_name: String = String(method_info.get("name", ""))
			var arguments: Array = method_info.get("args", [])
			if method_name.is_empty() or method_name.begins_with("_") or not arguments.is_empty():
				continue
			if method_name in method_names:
				continue
			method_names.append(method_name)
	method_names.sort()
	return method_names


func _set_dialog_enabled(enabled: bool) -> void:
	if not is_instance_valid(_dialog):
		return
	var ok_button: Button = _dialog.get_ok_button()
	if ok_button:
		ok_button.disabled = not enabled
	_method_picker.disabled = not enabled


func _on_dialog_confirmed() -> void:
	if not is_instance_valid(_selected_target) or _method_picker.selected < 0:
		return
	var method: StringName = StringName(_method_picker.get_item_text(_method_picker.selected))
	_connect_callback(_selected_target, method)
	_dialog.hide()


func _connect_callback(target: Node, method: StringName) -> void:
	if not is_instance_valid(_source) or not is_instance_valid(target):
		return
	var callback: Callable = Callable(target, method)
	if _source.is_connected(&"triggered", callback):
		return

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("连接 EventTrigger 回调")
	undo_redo.add_do_method(_source, "connect", &"triggered", callback)
	undo_redo.add_undo_method(_source, "disconnect", &"triggered", callback)
	undo_redo.commit_action()
	_source.notify_property_list_changed()
	_refresh_connection_list()


func _disconnect_callback(target: Node, method: StringName) -> void:
	if not is_instance_valid(_source) or not is_instance_valid(target):
		return
	var callback: Callable = Callable(target, method)
	if not _source.is_connected(&"triggered", callback):
		return

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("断开 EventTrigger 回调")
	undo_redo.add_do_method(_source, "disconnect", &"triggered", callback)
	undo_redo.add_undo_method(_source, "connect", &"triggered", callback)
	undo_redo.commit_action()
	_source.notify_property_list_changed()
	_refresh_connection_list()


func _exit_tree() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
		_dialog = null
