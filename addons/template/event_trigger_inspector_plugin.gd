@tool
extends EditorInspectorPlugin

const EVENT_TRIGGER_SCRIPT := preload("res://#Template/[Scripts]/Trigger/EventTrigger.gd")
const SignalEditorPanel := preload("res://addons/template/event_trigger_signal_editor.gd")


func _can_handle(object: Object) -> bool:
	var node: Node = object as Node
	return node != null and node.get_script() == EVENT_TRIGGER_SCRIPT


func _parse_begin(object: Object) -> void:
	var node: Node = object as Node
	if node == null:
		return
	var panel: Control = SignalEditorPanel.new()
	panel.call("inspect", node)
	add_custom_control(panel)
