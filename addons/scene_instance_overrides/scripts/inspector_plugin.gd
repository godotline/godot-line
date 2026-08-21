@tool
extends EditorInspectorPlugin

const INSPECTOR_OVERRIDE_CONTROL_SCENE := preload("res://addons/scene_instance_overrides/inspector_override_control.tscn")

var _host_plugin: Object
var _visible_override_control: WeakRef
var _visible_inspected_object_id := 0


func setup(host_plugin: Object) -> void:
	_host_plugin = host_plugin


func _can_handle(object: Object) -> bool:
	return object is Node and is_instance_valid(_host_plugin)


func _parse_begin(object: Object) -> void:
	_visible_override_control = null
	_visible_inspected_object_id = object.get_instance_id() if is_instance_valid(object) else 0
	if not object is Node or not is_instance_valid(_host_plugin):
		return

	var context: Dictionary = _host_plugin.scan_overrides_for_node(object)
	if not context.get("valid", false) or context.get("entries", []).is_empty():
		return
	if not _host_plugin.should_show_override_button_for_node(object, context):
		return

	var instance_root := context.get("instance_root") as Node
	var expected_instance_root_id := instance_root.get_instance_id() if is_instance_valid(instance_root) else 0
	var expected_source_path := str(context.get("source_path", ""))
	var control := INSPECTOR_OVERRIDE_CONTROL_SCENE.instantiate()
	control.configure(context)
	_remember_visible_override_control(object, control)
	control.popup_requested.connect(
		_host_plugin.show_override_popup_from_inspector.bind(
			object,
			expected_instance_root_id,
			expected_source_path
		)
	)
	add_custom_control(control)


func refresh_visible_override_control(object: Object, context: Dictionary) -> bool:
	if (
		not is_instance_valid(object)
		or object.get_instance_id() != _visible_inspected_object_id
		or _visible_override_control == null
	):
		return false
	var control := _visible_override_control.get_ref() as Control
	if not is_instance_valid(control):
		_visible_override_control = null
		return false
	control.configure(context)
	return true


func _remember_visible_override_control(object: Object, control: Control) -> void:
	_visible_inspected_object_id = object.get_instance_id() if is_instance_valid(object) else 0
	_visible_override_control = weakref(control) if is_instance_valid(control) else null
