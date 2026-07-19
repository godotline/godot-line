@tool
extends Node3D
@export var GuideTap: PackedScene
@export_tool_button("Add","AcceptDialog")
var add_action: Callable = func() -> void:
	# 获取当前节点的所有子节点
	var children: Array[Node] = get_children()
	var created_nodes: Array[Node] = []
	
	# 遍历每个子节点，在其位置添加新的taper实例
	for child in children:
		var child_node: Node = GuideTap.instantiate()
		if not child_node:
			push_error("addtap.gd: GuideTap 场景未指定，无法实例化")
			return
		
		# 如果实例已经有父节点，先移除（安全措施）
		if child_node.get_parent():
			child_node.get_parent().remove_child(child_node)
		
		# 将新节点添加到当前节点下
		add_child(child_node)
		
		# 设置新节点的位置与对应子节点相同
		child_node.position = child.position
		
		# 设置owner以便保存到场景中（重要！）
		child_node.owner = get_tree().edited_scene_root
		created_nodes.append(child_node)
	
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("添加 GuideTap")
	for node in created_nodes:
		undo_redo.add_do_reference(node)
	undo_redo.add_do_method(self, "_on_add_completed", children.size())
	undo_redo.add_undo_method(self, "_undo_add", created_nodes)
	undo_redo.commit_action(false)
	notify_property_list_changed()

func _on_add_completed(count: int) -> void:
	print("已在 %d 个子节点位置添加了taper实例" % count)

func _undo_add(nodes: Array[Node]) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	print("已撤销添加 taper 实例")
