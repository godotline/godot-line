@tool
extends EditorContextMenuPlugin

const OVERRIDE_ICON := preload("res://addons/scene_instance_overrides/icons/scene_instance_overrides.svg")

var _host_plugin: Object


func setup(host_plugin: Object) -> void:
	_host_plugin = host_plugin


func _popup_menu(paths: PackedStringArray) -> void:
	if not is_instance_valid(_host_plugin) or paths.size() < 2:
		return

	var edited_object := instance_from_id(paths[0].to_int())
	var property_name := StringName(paths[1])
	if not edited_object is Node:
		return
	if not _host_plugin.has_supported_property_override(edited_object, property_name):
		return

	add_context_menu_item(
		"Apply to Base Scene",
		_on_apply_property_requested,
		OVERRIDE_ICON
	)
	add_context_menu_item(
		"Revert Override",
		_on_revert_property_requested,
		EditorInterface.get_editor_theme().get_icon("Reload", "EditorIcons")
	)


func _on_apply_property_requested(editor_property: EditorProperty) -> void:
	if is_instance_valid(_host_plugin):
		_host_plugin.apply_property_from_editor(editor_property)


func _on_revert_property_requested(editor_property: EditorProperty) -> void:
	if is_instance_valid(_host_plugin):
		_host_plugin.revert_property_from_editor(editor_property)
