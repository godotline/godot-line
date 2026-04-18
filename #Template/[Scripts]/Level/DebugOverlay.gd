extends CanvasLayer
class_name DebugOverlay

var _label: Label

func _ready() -> void:
	layer = 100
	visible = false

	_label = Label.new()
	_label.position = Vector2(10, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)

func _process(_delta: float) -> void:
	if not Player.instance or not Player.instance.debug:
		visible = false
		return
	visible = true
	_update_label()

func _update_label() -> void:
	var p := Player.instance
	var lines: Array[String] = []

	var fps := Engine.get_frames_per_second()
	lines.append("FPS: %d" % fps)

	if p.level_data:
		var music_player := p.get_node_or_null("MusicPlayer") as AudioStreamPlayer
		if music_player and music_player.stream:
			var progress := music_player.get_playback_position() / music_player.stream.get_length() if music_player.stream.get_length() > 0 else 0.0
			var current_sec := music_player.get_playback_position()
			var total_sec := p.level_data.levelTotalTime if p.level_data.useCustomLevelTime else music_player.stream.get_length()
			lines.append("进度: %d%% (%.1f秒/%.1f秒)" % [int(progress * 100), current_sec, total_sec])

	lines.append("游戏状态: %s" % LevelManager.GameStatus.keys()[LevelManager.game_state])

	lines.append("线的坐标: (%.2f, %.2f, %.2f)" % [p.position.x, p.position.y, p.position.z])
	lines.append("线的朝向: (%.1f, %.1f, %.1f)" % [p.rotation_degrees.x, p.rotation_degrees.y, p.rotation_degrees.z])

	lines.append("已获取方块数量: %d" % 	LevelManager.diamond)
	lines.append("已获取皇冠数量: %d/3" % 	LevelManager.crown)

	var cam := CameraFollower.instance
	var camera := get_viewport().get_camera_3d()
	if cam:
		lines.append("相机偏移: (%.2f, %.2f, %.2f)" % [cam.add_position.x, cam.add_position.y, cam.add_position.z])
		lines.append("相机角度: (%.1f, %.1f, %.1f)" % [cam.rotation_degrees.x, cam.rotation_degrees.y, cam.rotation_degrees.z])
		lines.append("相机距离: %.1f" % cam.distance_from_object)
	elif camera:
		lines.append("相机位置: (%.2f, %.2f, %.2f)" % [camera.global_position.x, camera.global_position.y, camera.global_position.z])
		lines.append("相机角度: (%.1f, %.1f, %.1f)" % [camera.rotation_degrees.x, camera.rotation_degrees.y, camera.rotation_degrees.z])
	if camera:
		lines.append("视场大小: %.1f" % camera.fov)

	_label.text = "\n".join(lines)
