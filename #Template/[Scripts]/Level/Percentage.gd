@tool
extends Node3D

@export var percent: int = 10 : set = _set_selected_percent

var percentNodes: Dictionary = {}
var percentValues: Array[int] = []
var isReady: bool = false
var ownerRestore: Dictionary = {}
var displayNode: MeshInstance3D
var pendingRefresh: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	isReady = true
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
	if percentValues.is_empty():
		return
	if displayNode == null or not is_instance_valid(displayNode):
		displayNode = percentNodes[percentValues[0]]
	if percent not in percentNodes:
		percent = percentValues[0]
	_apply_selection(percent)
	pendingRefresh = false

func _collect_percent_nodes() -> void:
	percentNodes.clear()
	percentValues.clear()
	for child in get_children():
		if child is MeshInstance3D:
			var nameStr: String = str(child.name)
			if nameStr.is_valid_int():
				var value: int = int(nameStr)
				percentNodes[value] = child
				percentValues.append(value)
	percentValues.sort()

func _set_selected_percent(value: int) -> void:
	percent = value
	if not Engine.is_editor_hint():
		return
	if not isReady:
		pendingRefresh = true
		call_deferred("_refresh")
		return
	if percentNodes.is_empty():
		_collect_percent_nodes()
		if percentValues.is_empty():
			return
		if displayNode == null:
			displayNode = percentNodes[percentValues[0]]
	if percent in percentNodes:
		_apply_selection(percent)

func _apply_selection(value: int) -> void:
	if displayNode != null and displayNode.mesh is TextMesh:
		var textMesh: TextMesh = displayNode.mesh as TextMesh
		textMesh.text = "%d%%" % value
	for key in percentNodes.keys():
		var node: MeshInstance3D = percentNodes[key]
		node.visible = node == displayNode

func _prepare_scene_for_save() -> void:
	_collect_percent_nodes()
	if percentValues.is_empty():
		return
	if displayNode == null:
		displayNode = percentNodes[percentValues[0]]
	_apply_selection(percent)
	ownerRestore.clear()
	var root: Node = get_tree().edited_scene_root
	if root == null:
		return
	for key in percentNodes.keys():
		var node: MeshInstance3D = percentNodes[key]
		ownerRestore[node] = node.owner
		if node == displayNode:
			node.owner = root
		else:
			node.owner = null

func _restore_scene_after_save() -> void:
	for node in ownerRestore.keys():
		if is_instance_valid(node):
			node.owner = ownerRestore[node]
	ownerRestore.clear()
