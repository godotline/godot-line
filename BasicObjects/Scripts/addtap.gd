@tool
extends Node3D
@export var taper: PackedScene
@export_tool_button("Add","AcceptDialog")

var add_action = func():
	# 获取当前节点的所有子节点
	var children = get_children()
	
	# 遍历每个子节点，在其位置添加新的taper实例
	for child in children:
		var child_node = taper.instantiate()
		
		# 如果实例已经有父节点，先移除（安全措施）
		if child_node.get_parent():
			child_node.get_parent().remove_child(child_node)
		
		# 将新节点添加到当前节点下
		add_child(child_node)
		
		# 设置新节点的位置与对应子节点相同
		child_node.position = child.position
		
		# 设置owner以便保存到场景中（重要！）
		child_node.owner = get_tree().edited_scene_root
	
	print("已在 %d 个子节点位置添加了taper实例" % children.size())
