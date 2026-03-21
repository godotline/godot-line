@tool
extends Node3D

@export var selected_percent := 10 : set = _set_selected_percent

var _percent_nodes: Dictionary = {}
var _percent_values: Array[int] = []
var _is_ready := false
var _owner_restore: Dictionary = {}
var _display_node: MeshInstance3D
var _pending_refresh := false

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_is_ready = true
	_refresh()

func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_prepare_scene_for_save()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_restore_scene_after_save()

func _refresh() -> void:
	_collect_percent_nodes()
	if _percent_values.is_empty():
		return
	if _display_node == null or not is_instance_valid(_display_node):
		_display_node = _percent_nodes[_percent_values[0]]
	if selected_percent not in _percent_nodes:
		selected_percent = _percent_values[0]
	_apply_selection(selected_percent)
	_pending_refresh = false

func _collect_percent_nodes() -> void:
	_percent_nodes.clear()
	_percent_values.clear()
	for child in get_children():
		if child is MeshInstance3D:
			var name_str := str(child.name)
			if name_str.is_valid_int():
				var value := int(name_str)
				_percent_nodes[value] = child
				_percent_values.append(value)
	_percent_values.sort()

func _set_selected_percent(value: int) -> void:
	selected_percent = value
	if not Engine.is_editor_hint():
		return
	if not _is_ready:
		_pending_refresh = true
		call_deferred("_refresh")
		return
	if _percent_nodes.is_empty():
		_collect_percent_nodes()
		if _percent_values.is_empty():
			return
		if _display_node == null:
			_display_node = _percent_nodes[_percent_values[0]]
	if selected_percent in _percent_nodes:
		_apply_selection(selected_percent)

func _apply_selection(value: int) -> void:
	if _display_node != null and _display_node.mesh is TextMesh:
		var text_mesh := _display_node.mesh as TextMesh
		text_mesh.text = "%d%%" % value
	for key in _percent_nodes.keys():
		var node: MeshInstance3D = _percent_nodes[key]
		node.visible = node == _display_node

func _prepare_scene_for_save() -> void:
	_collect_percent_nodes()
	if _percent_values.is_empty():
		return
	if _display_node == null:
		_display_node = _percent_nodes[_percent_values[0]]
	_apply_selection(selected_percent)
	_owner_restore.clear()
	var root := get_tree().edited_scene_root
	if root == null:
		return
	for key in _percent_nodes.keys():
		var node: MeshInstance3D = _percent_nodes[key]
		_owner_restore[node] = node.owner
		if node == _display_node:
			node.owner = root
		else:
			node.owner = null

func _restore_scene_after_save() -> void:
	for node in _owner_restore.keys():
		if is_instance_valid(node):
			node.owner = _owner_restore[node]
	_owner_restore.clear()
