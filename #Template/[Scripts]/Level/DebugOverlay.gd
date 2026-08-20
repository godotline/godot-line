extends CanvasLayer
class_name DebugOverlay

var label: Label
var previousDebug: bool = false
var pollTimer: Timer
var refreshTimer: Timer
var cachedCamera: Camera3D

func _ready() -> void:
	layer = 100
	visible = false

	label = Label.new()
	label.position = Vector2(10, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

	# 创建轮询定时器
	pollTimer = Timer.new()
	pollTimer.wait_time = 0.5
	pollTimer.one_shot = false
	pollTimer.autostart = true
	pollTimer.timeout.connect(_poll_debug)
	add_child(pollTimer)

	# 创建刷新定时器（初始停止）
	refreshTimer = Timer.new()
	refreshTimer.wait_time = 0.1
	refreshTimer.one_shot = false
	refreshTimer.autostart = false
	refreshTimer.timeout.connect(_update_label)
	add_child(refreshTimer)

	# 缓存相机引用
	cachedCamera = get_viewport().get_camera_3d()


func _poll_debug() -> void:
	if not is_instance_valid(self):
		return
	if not Player.instance:
		return
	var debugOn: bool = Player.instance.debug
	if debugOn != previousDebug:
		previousDebug = debugOn
		visible = debugOn
		if debugOn:
			refreshTimer.start()
		else:
			refreshTimer.stop()


func _update_label() -> void:
	var p: Player = Player.instance
	var lines: Array[String] = []

	var fps: int = Engine.get_frames_per_second()
	lines.append("FPS: %d" % fps)

	if p.levelData:
		var musicPlayer: AudioStreamPlayer = p.get_node_or_null("MusicPlayer") as AudioStreamPlayer
		if musicPlayer and musicPlayer.stream:
			var progress: float = musicPlayer.get_playback_position() / musicPlayer.stream.get_length() if musicPlayer.stream.get_length() > 0 else 0.0
			var currentSec: float = musicPlayer.get_playback_position()
			var totalSec: float = p.levelData.levelTotalTime if p.levelData.useCustomLevelTime else musicPlayer.stream.get_length()
			lines.append("进度: %d%% (%.1f秒/%.1f秒)" % [int(progress * 100), currentSec, totalSec])

	lines.append("游戏状态: %s" % LevelManager.GameStatus.keys()[LevelManager.GameState])

	lines.append("线的坐标: (%.2f, %.2f, %.2f)" % [p.position.x, p.position.y, p.position.z])
	lines.append("线的朝向: (%.1f, %.1f, %.1f)" % [p.rotation_degrees.x, p.rotation_degrees.y, p.rotation_degrees.z])

	lines.append("已获取宝石数量: %d" % LevelManager.gem)
	lines.append("已获取皇冠数量: %d/3" % LevelManager.crown)

	var cam: OldCameraFollower = OldCameraFollower.instance
	if cam:
		lines.append("相机偏移: (%.2f, %.2f, %.2f)" % [cam.addPosition.x, cam.addPosition.y, cam.addPosition.z])
		lines.append("相机角度: (%.1f, %.1f, %.1f)" % [cam.rotation_degrees.x, cam.rotation_degrees.y, cam.rotation_degrees.z])
		lines.append("相机距离: %.1f" % cam.distanceFromObject)
	elif cachedCamera:
		lines.append("相机位置: (%.2f, %.2f, %.2f)" % [cachedCamera.global_position.x, cachedCamera.global_position.y, cachedCamera.global_position.z])
		lines.append("相机角度: (%.1f, %.1f, %.1f)" % [cachedCamera.rotation_degrees.x, cachedCamera.rotation_degrees.y, cachedCamera.rotation_degrees.z])
	if cachedCamera:
		lines.append("视场大小: %.1f" % cachedCamera.fov)

	label.text = "\n".join(lines)
