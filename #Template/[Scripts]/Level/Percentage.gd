@tool
extends Node3D

@export_range(10, 90, 10, "or_greater", "or_less") var percent: int = 10 : set = _set_selected_percent

var percentNodes: Dictionary = {}
var percentValues: Array[int] = []
var isReady: bool = false
var displayNode: MeshInstance3D
var pendingRefresh: bool = false

func _ready() -> void:
	isReady = true
	_refresh()

func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_prepare_scene_for_save()

func _refresh() -> void:
	_collect_percent_nodes()
	if percentValues.is_empty():
		return
	if displayNode == null or not is_instance_valid(displayNode):
		displayNode = percentNodes.get(percent, percentNodes[percentValues[0]])
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
	if not isReady:
		pendingRefresh = true
		call_deferred("_refresh")
		return
	if percentNodes.is_empty():
		_collect_percent_nodes()
	_apply_selection(percent)

func _apply_selection(value: int) -> void:
	# 有同名子节点则切换显示节点；否则直接改当前显示节点的文字（单节点工作流）
	if percentNodes.has(value):
		displayNode = percentNodes[value]
	if displayNode != null and is_instance_valid(displayNode) and displayNode.mesh is TextMesh:
		(displayNode.mesh as TextMesh).text = "%d%%" % value
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
