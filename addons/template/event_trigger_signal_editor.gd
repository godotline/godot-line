@tool
extends VBoxContainer
class_name EventTriggerSignalEditor

var _source: Node
var _target_node: Node
var _target_status: Label
var _method_label: Label
var _method_picker: OptionButton
var _connect_button: Button
var _connections_box: VBoxContainer


func _ready() -> void:
	_build_ui()
	_bind_source()
	_refresh_target_editor()
	_refresh_connection_list()


func inspect(source: Node) -> void:
	_unbind_source()
	_source = source
	if is_node_ready():
		_bind_source()
		_refresh_target_editor()
		_refresh_connection_list()


func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	var title: Label = Label.new()
	title.text = "triggered 回调"
	title.add_theme_font_size_override("font_size", 13)
	add_child(title)

	var description: Label = Label.new()
	description.text = "在下方 targetNode 属性中拖入节点，再选择无参数方法。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	add_child(description)

	_target_status = Label.new()
	_target_status.text = "未选择目标节点"
	_target_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_target_status)

	_method_label = Label.new()
	_method_label.text = "选择无参数方法"
	add_child(_method_label)

	_method_picker = OptionButton.new()
	_method_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_method_picker.item_selected.connect(_on_method_selected)
	add_child(_method_picker)

	var actionRow: HBoxContainer = HBoxContainer.new()
	add_child(actionRow)

	_connect_button = Button.new()
	_connect_button.text = "连接回调"
	_connect_button.tooltip_text = "将选中的无参数方法连接到 triggered 信号"
	_connect_button.pressed.connect(_connect_selected_callback)
	actionRow.add_child(_connect_button)

	var refreshButton: Button = Button.new()
	refreshButton.text = "刷新"
	refreshButton.tooltip_text = "重新读取目标节点和信号连接"
	refreshButton.pressed.connect(_refresh_editor)
	actionRow.add_child(refreshButton)

	var separator: HSeparator = HSeparator.new()
	add_child(separator)

	var connectionsTitle: Label = Label.new()
	connectionsTitle.text = "已连接回调"
	add_child(connectionsTitle)

	_connections_box = VBoxContainer.new()
	_connections_box.add_theme_constant_override("separation", 4)
	add_child(_connections_box)


func _bind_source() -> void:
	if not is_instance_valid(_source) or not _source.has_signal(&"target_node_changed"):
		return
	var callback: Callable = Callable(self, "_on_target_node_changed")
	if not _source.is_connected(&"target_node_changed", callback):
		_source.connect(&"target_node_changed", callback)


func _unbind_source() -> void:
	if not is_instance_valid(_source) or not _source.has_signal(&"target_node_changed"):
		return
	var callback: Callable = Callable(self, "_on_target_node_changed")
	if _source.is_connected(&"target_node_changed", callback):
		_source.disconnect(&"target_node_changed", callback)


func _refresh_editor() -> void:
	_refresh_target_editor()
	_refresh_connection_list()


func _on_target_node_changed() -> void:
	_refresh_editor()


func _on_method_selected(_index: int) -> void:
	_update_connect_button()


func _refresh_target_editor() -> void:
	if not is_instance_valid(_method_picker):
		return
	_method_picker.clear()
	_target_node = null

	if not is_instance_valid(_source):
		_set_method_editor_enabled(false)
		return

	_target_node = _source.get("targetNode") as Node
	if not is_instance_valid(_target_node):
		_target_status.text = "未选择目标节点"
		_method_label.text = "选择无参数方法"
		_set_method_editor_enabled(false)
		return

	_target_status.text = "目标：%s" % _get_scene_tree_path(_target_node)
	var methods: Array[String] = _get_callback_methods(_target_node)
	for method_index: int in range(methods.size()):
		_method_picker.add_item(methods[method_index], method_index)

	if methods.is_empty():
		_method_label.text = "该节点没有可连接的无参数脚本方法"
		_set_method_editor_enabled(false)
		return

	_method_label.text = "选择无参数方法"
	var connectedMethod: StringName = _get_connected_method(_target_node)
	var selectedIndex: int = methods.find(String(connectedMethod))
	if selectedIndex < 0:
		selectedIndex = 0
	_method_picker.select(selectedIndex)
	_set_method_editor_enabled(true)


func _get_connected_method(target: Node) -> StringName:
	if not is_instance_valid(_source) or not is_instance_valid(target):
		return StringName()
	for connection: Dictionary in _source.get_signal_connection_list(&"triggered"):
		var callback: Callable = connection.get("callable", Callable())
		if callback.get_object() == target:
			return callback.get_method()
	return StringName()


func _get_scene_tree_path(target: Node) -> String:
	if not is_instance_valid(target):
		return ""
	var sceneRoot: Node = EditorInterface.get_edited_scene_root()
	if is_instance_valid(sceneRoot) and (target == sceneRoot or sceneRoot.is_ancestor_of(target)):
		var relativePath: String = str(sceneRoot.get_path_to(target))
		if relativePath == "." or relativePath.is_empty():
			return sceneRoot.name
		return "%s/%s" % [sceneRoot.name, relativePath]
	return str(target.get_path()).trim_prefix("/root/")


func _set_method_editor_enabled(enabled: bool) -> void:
	_method_picker.disabled = not enabled
	_update_connect_button()


func _update_connect_button() -> void:
	if not is_instance_valid(_connect_button) or not is_instance_valid(_method_picker):
		return
	var canConnect: bool = is_instance_valid(_target_node) and not _method_picker.disabled and _method_picker.selected >= 0
	if canConnect:
		var method: StringName = StringName(_method_picker.get_item_text(_method_picker.selected))
		var callback: Callable = Callable(_target_node, method)
		if _source.is_connected(&"triggered", callback):
			var connectionFlags: int = _get_connection_flags(callback)
			_connect_button.text = "已连接" if connectionFlags & CONNECT_PERSIST else "保存连接"
			_connect_button.disabled = (connectionFlags & CONNECT_PERSIST) != 0
			return
	_connect_button.text = "连接回调"
	_connect_button.disabled = not canConnect


func _connect_selected_callback() -> void:
	if not is_instance_valid(_target_node) or _method_picker.selected < 0:
		return
	var method: StringName = StringName(_method_picker.get_item_text(_method_picker.selected))
	var callback: Callable = Callable(_target_node, method)
	if _source.is_connected(&"triggered", callback):
		_persist_callback(callback)
	else:
		_connect_callback(_target_node, method)


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
		var callbackPath: String = "%s.%s()" % [_get_scene_tree_path(target), String(callback.get_method())]
		var callbackLink: LinkButton = LinkButton.new()
		callbackLink.text = callbackPath
		callbackLink.tooltip_text = "%s\n点击跳转到目标节点" % callbackPath
		callbackLink.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		callbackLink.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		callbackLink.pressed.connect(_select_callback_target.bind(target))
		row.add_child(callbackLink)

		var disconnectButton: Button = Button.new()
		disconnectButton.text = "断开"
		disconnectButton.tooltip_text = "断开这条 triggered 回调"
		disconnectButton.pressed.connect(_disconnect_callback.bind(target, callback.get_method()))
		row.add_child(disconnectButton)
		_connections_box.add_child(row)


func _select_callback_target(target: Node) -> void:
	if not is_instance_valid(target):
		return
	call_deferred("_edit_callback_target", target)


func _edit_callback_target(target: Node) -> void:
	if not is_instance_valid(target):
		return
	EditorInterface.edit_node(target)


func _add_status(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_connections_box.add_child(label)


func _get_callback_methods(target: Node) -> Array[String]:
	var methodNames: Array[String] = []
	var script: Script = target.get_script() as Script
	while script:
		var methodList: Array = script.get_script_method_list()
		for method_info: Dictionary in methodList:
			var methodName: String = String(method_info.get("name", ""))
			var arguments: Array = method_info.get("args", [])
			if methodName.is_empty() or methodName.begins_with("_") or not arguments.is_empty():
				continue
			if not target.has_method(methodName) or methodName in methodNames:
				continue
			methodNames.append(methodName)
		script = script.get_base_script() as Script
	methodNames.sort()
	return methodNames


func _get_connection_flags(callback: Callable) -> int:
	if not is_instance_valid(_source):
		return 0
	for connection: Dictionary in _source.get_signal_connection_list(&"triggered"):
		var connectedCallback: Callable = connection.get("callable", Callable())
		if connectedCallback == callback:
			return int(connection.get("flags", 0))
	return 0


func _connect_callback(target: Node, method: StringName) -> void:
	if not is_instance_valid(_source) or not is_instance_valid(target):
		return
	var callback: Callable = Callable(target, method)
	if _source.is_connected(&"triggered", callback):
		return

	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("连接 EventTrigger 回调")
	undoRedo.add_do_method(_source, "connect", &"triggered", callback, CONNECT_PERSIST)
	undoRedo.add_undo_method(_source, "disconnect", &"triggered", callback)
	undoRedo.commit_action()
	_source.notify_property_list_changed()
	EditorInterface.mark_scene_as_unsaved()
	_refresh_editor()


func _persist_callback(callback: Callable) -> void:
	if not is_instance_valid(_source) or not _source.is_connected(&"triggered", callback):
		return
	var connectionFlags: int = _get_connection_flags(callback)
	if connectionFlags & CONNECT_PERSIST:
		return

	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("保存 EventTrigger 回调")
	undoRedo.add_do_method(_source, "disconnect", &"triggered", callback)
	undoRedo.add_do_method(_source, "connect", &"triggered", callback, CONNECT_PERSIST)
	undoRedo.add_undo_method(_source, "disconnect", &"triggered", callback)
	undoRedo.add_undo_method(_source, "connect", &"triggered", callback, connectionFlags)
	undoRedo.commit_action()
	_source.notify_property_list_changed()
	EditorInterface.mark_scene_as_unsaved()
	_refresh_editor()


func _disconnect_callback(target: Node, method: StringName) -> void:
	if not is_instance_valid(_source) or not is_instance_valid(target):
		return
	var callback: Callable = Callable(target, method)
	if not _source.is_connected(&"triggered", callback):
		return

	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("断开 EventTrigger 回调")
	undoRedo.add_do_method(_source, "disconnect", &"triggered", callback)
	undoRedo.add_undo_method(_source, "connect", &"triggered", callback, _get_connection_flags(callback))
	undoRedo.commit_action()
	_source.notify_property_list_changed()
	EditorInterface.mark_scene_as_unsaved()
	_refresh_editor()


func _exit_tree() -> void:
	_unbind_source()
