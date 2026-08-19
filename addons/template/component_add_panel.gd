@tool
extends VBoxContainer
class_name ComponentAddPanel

## 通用「添加组件」面板：显示在任意 Node 的 Inspector 底部，无需附加脚本。
## 点击 Add Component 按钮弹出原生快速加载对话框（EditorInterface.popup_quick_open，
## 限 Script 类型），选中脚本后作为子节点添加（带 Undo/Redo 与场景保存）。

var _host: Node
var _add_button: Button


func _ready() -> void:
	_build_ui()


func inspect(host: Node) -> void:
	_host = host


func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	_add_button = Button.new()
	_add_button.text = "Add Component"
	_add_button.tooltip_text = "打开快速加载对话框，选择组件脚本并作为子节点添加到当前节点"
	_add_button.pressed.connect(_open_script_dialog)
	add_child(_add_button)


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
	call_deferred("_edit_component", component)


func _edit_component(component: Node) -> void:
	if is_instance_valid(component):
		EditorInterface.edit_node(component)
