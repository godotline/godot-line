@tool
extends EditorContextMenuPlugin

const OVERRIDE_ICON := preload("res://addons/scene_instance_overrides/icons/scene_instance_overrides.svg")

var _host_plugin: Object


func setup(host_plugin: Object) -> void:
	_host_plugin = host_plugin


func _popup_menu(paths: PackedStringArray) -> void:
	if not is_instance_valid(_host_plugin) or paths.size() != 1:
		return

	var node: Node = _host_plugin.find_node_from_editor_context_path(paths[0]) as Node
	if not is_instance_valid(node) or not _host_plugin.has_added_node_override(node):
		return

	add_context_menu_item(
		"Add to Base Scene",
		_on_apply_added_node_requested,
		OVERRIDE_ICON
	)
	add_context_menu_item(
		"Revert Added Node",
		_on_revert_added_node_requested,
		EditorInterface.get_editor_theme().get_icon("Remove", "EditorIcons")
	)


func _on_apply_added_node_requested(nodes: Array) -> void:
	if is_instance_valid(_host_plugin) and not nodes.is_empty() and nodes[0] is Node:
		_host_plugin.apply_added_node_from_scene_tree(nodes[0])


func _on_revert_added_node_requested(nodes: Array) -> void:
	if is_instance_valid(_host_plugin) and not nodes.is_empty() and nodes[0] is Node:
		_host_plugin.revert_added_node_from_scene_tree(nodes[0])
