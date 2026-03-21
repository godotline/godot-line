@tool
extends EditorScript

func _run():
	var player = get_scene().get_node("AnimationPlayer") as AnimationPlayer
	if not player:
		print("错误：未找到 AnimationPlayer 节点")
		return
	
	var parent = player.get_parent()
	
	var anim_list = player.get_animation_list()
	print("发现 ", anim_list.size(), " 个动画：", anim_list)
	
	for anim_name in anim_list:
		# 创建新 AnimationPlayer
		var new_player = AnimationPlayer.new()
		new_player.name = anim_name
		
		# 复制动画资源
		var anim = player.get_animation(anim_name)
		var anim_copy = anim.duplicate()
		
		# 过滤轨道：只保留第一个节点的动画
		filter_animation_to_first_node(anim_copy)
		
		# 如果过滤后没有轨道，跳过
		if anim_copy.get_track_count() == 0:
			print("警告：动画 '", anim_name, "' 没有有效轨道，已跳过")
			continue
		
		# 添加到新 player
		var lib = AnimationLibrary.new()
		lib.add_animation(anim_name, anim_copy)
		new_player.add_animation_library("", lib)
		
		# 设置根节点（假设和原 player 一样）
		new_player.root_node = player.root_node
		
		# 添加到场景
		parent.add_child(new_player)
		new_player.owner = get_scene()
		
		print("创建: ", anim_name, " (", anim_copy.get_track_count(), " 个轨道)")
	
	print("完成！共创建 ", anim_list.size(), " 个 AnimationPlayer")

# 过滤动画，只保留第一个被动画化的节点的轨道
func filter_animation_to_first_node(anim: Animation) -> void:
	if anim.get_track_count() == 0:
		return
	
	# 获取第一个轨道的节点路径（如 "Node3D"）
	var first_track_node_path = anim.track_get_path(0).get_concatenated_names()
	
	# 遍历所有轨道，删除不指向该节点的轨道（从后往前删除避免索引问题）
	for i in range(anim.get_track_count() - 1, -1, -1):
		var track_path = anim.track_get_path(i)
		var track_node_path = track_path.get_concatenated_names()
		
		# 如果轨道不属于第一个节点，删除它
		if track_node_path != first_track_node_path:
			anim.remove_track(i)
