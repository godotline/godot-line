@tool
extends EditorScript

func _run():
	# ⭐ 1. 指定要处理的动画文件
	var anim_path = "res://Assets/TheInvertedWorld/Scene3/Scene3.anim"
	
	# ⭐ 2. 加载动画
	var anim = load(anim_path) as Animation
	if not anim:
		print("加载失败")
		return
	
	# ⭐ 3. 遍历所有轨道（从后往前，避免索引问题）
	for i in range(anim.get_track_count() - 1, -1, -1):
		var old_path = str(anim.track_get_path(i))
		
		# ⭐ 4. 核心功能：检查并替换 "." 为 "_"
		if "." in old_path:
			var new_path = old_path.replace(".", "_")
			print("修改: %s -> %s" % [old_path, new_path])
			
			# ⭐ 5. 备份轨道数据
			var data = {
				"type": anim.track_get_type(i),
				"interp": anim.track_get_interpolation_type(i),
				"enabled": anim.track_is_enabled(i),
				"keys": []
			}
			
			for k in range(anim.track_get_key_count(i)):
				data.keys.append({
					"t": anim.track_get_key_time(i, k),
					"v": anim.track_get_key_value(i, k),
					"tr": anim.track_get_key_transition(i, k)
				})
			
			# ⭐ 6. 删除旧轨道，创建新轨道
			anim.remove_track(i)
			var idx = anim.add_track(data.type, i)
			
			# ⭐ 7. 设置新路径（这里是关键！）
			anim.track_set_path(idx, NodePath(new_path))
			
			# ⭐ 8. 恢复属性和关键帧
			anim.track_set_interpolation_type(idx, data.interp)
			anim.track_set_enabled(idx, data.enabled)
			
			for key in data.keys:
				anim.track_insert_key(idx, key.t, key.v, key.tr)
	
	# ⭐ 9. 保存文件
	ResourceSaver.save(anim, anim_path)
	print("完成！")
