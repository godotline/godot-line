extends CanvasLayer
class_name DebugOverlay

var _label: Label
var _previous_debug: bool = false
var _poll_timer: Timer
var _refresh_timer: Timer
var _cached_camera: Camera3D

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

	# 创建轮询定时器
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.5
	_poll_timer.one_shot = false
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_poll_debug)
	add_child(_poll_timer)

	# 创建刷新定时器（初始停止）
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.1
	_refresh_timer.one_shot = false
	_refresh_timer.autostart = false
	_refresh_timer.timeout.connect(_update_label)
	add_child(_refresh_timer)

	# 缓存相机引用
	_cached_camera = get_viewport().get_camera_3d()


func _poll_debug() -> void:
	if not is_instance_valid(self):
		return
	if not Player.instance:
		return
	var debug_on: bool = Player.instance.debug
	if debug_on != _previous_debug:
		_previous_debug = debug_on
		visible = debug_on
		if debug_on:
			_refresh_timer.start()
		else:
			_refresh_timer.stop()


func _update_label() -> void:
	var p: Player = Player.instance
	var lines: Array[String] = []

	var fps: int = Engine.get_frames_per_second()
	lines.append("FPS: %d" % fps)

	if p.level_data:
		var music_player: AudioStreamPlayer = p.get_node_or_null("MusicPlayer") as AudioStreamPlayer
		if music_player and music_player.stream:
			var progress: float = music_player.get_playback_position() / music_player.stream.get_length() if music_player.stream.get_length() > 0 else 0.0
			var current_sec: float = music_player.get_playback_position()
			var total_sec: float = p.level_data.levelTotalTime if p.level_data.useCustomLevelTime else music_player.stream.get_length()
			lines.append("进度: %d%% (%.1f秒/%.1f秒)" % [int(progress * 100), current_sec, total_sec])

	lines.append("游戏状态: %s" % LevelManager.GameStatus.keys()[LevelManager.GameState])

	lines.append("线的坐标: (%.2f, %.2f, %.2f)" % [p.position.x, p.position.y, p.position.z])
	lines.append("线的朝向: (%.1f, %.1f, %.1f)" % [p.rotation_degrees.x, p.rotation_degrees.y, p.rotation_degrees.z])

	lines.append("已获取宝石数量: %d" % LevelManager.gem)
	lines.append("已获取皇冠数量: %d/3" % LevelManager.crown)

	var cam: OldCameraFollower = OldCameraFollower.instance
	if cam:
		lines.append("相机偏移: (%.2f, %.2f, %.2f)" % [cam.add_position.x, cam.add_position.y, cam.add_position.z])
		lines.append("相机角度: (%.1f, %.1f, %.1f)" % [cam.rotation_degrees.x, cam.rotation_degrees.y, cam.rotation_degrees.z])
		lines.append("相机距离: %.1f" % cam.distance_from_object)
	elif _cached_camera:
		lines.append("相机位置: (%.2f, %.2f, %.2f)" % [_cached_camera.global_position.x, _cached_camera.global_position.y, _cached_camera.global_position.z])
		lines.append("相机角度: (%.1f, %.1f, %.1f)" % [_cached_camera.rotation_degrees.x, _cached_camera.rotation_degrees.y, _cached_camera.rotation_degrees.z])
	if _cached_camera:
		lines.append("视场大小: %.1f" % _cached_camera.fov)

	_label.text = "\n".join(lines)