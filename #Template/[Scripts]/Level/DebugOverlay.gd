extends Node
class_name DebugOverlay

# 调试 HUD（dear-imgui-godot 实现）。对齐 Unity Player.cs #if UNITY_EDITOR 的 OnGUI 调试面板：
# 本节点只负责开关与内容，绘制由 ImGui autoload（addons/dear-imgui-godot）完成。
# 注意：ImGui 默认字体仅含 ASCII，面板文本须使用英文。

var previousDebug: bool = false
var shown: bool = false
var pollTimer: Timer

func _ready() -> void:
	shown = false
	ImGui.imgui_layout.connect(_onImguiLayout)

	# 轮询 debug 开关（对齐 Unity：调试 HUD 仅在 debug 开启时绘制）
	pollTimer = Timer.new()
	pollTimer.wait_time = 0.25
	pollTimer.one_shot = false
	pollTimer.autostart = true
	pollTimer.timeout.connect(_pollDebug)
	add_child(pollTimer)

func _exit_tree() -> void:
	if ImGui.imgui_layout.is_connected(_onImguiLayout):
		ImGui.imgui_layout.disconnect(_onImguiLayout)

func _onImguiLayout() -> void:
	if not shown:
		return
	var p: Player = Player.instance
	if not p:
		return

	ImGui.set_next_window_pos(10.0, 10.0, 4) # 4 = CondFirstUseEver，允许用户拖动后记忆位置
	if ImGui.begin("DebugOverlay"):
		ImGui.text("FPS: %d" % Engine.get_frames_per_second())

		if p.levelData:
			var musicPlayer: AudioStreamPlayer = p.get_node_or_null("MusicPlayer") as AudioStreamPlayer
			if musicPlayer and musicPlayer.stream:
				var progress: float = musicPlayer.get_playback_position() / musicPlayer.stream.get_length() if musicPlayer.stream.get_length() > 0 else 0.0
				var currentSec: float = musicPlayer.get_playback_position()
				var totalSec: float = p.levelData.levelTotalTime if p.levelData.useCustomLevelTime else musicPlayer.stream.get_length()
				ImGui.text("Progress: %d%% (%.1fs/%.1fs)" % [int(progress * 100), currentSec, totalSec])

		ImGui.text("Game Status: %s" % LevelManager.GameStatus.keys()[LevelManager.GameState])

		ImGui.text("Line Position: (%.2f, %.2f, %.2f)" % [p.position.x, p.position.y, p.position.z])
		ImGui.text("Line Rotation: (%.1f, %.1f, %.1f)" % [p.rotation_degrees.x, p.rotation_degrees.y, p.rotation_degrees.z])

		ImGui.text("Gems: %d" % LevelManager.gem)
		ImGui.text("Crowns: %d/3" % LevelManager.crown)

		var cam: OldCameraFollower = OldCameraFollower.instance
		if cam:
			ImGui.text("Camera Offset: (%.2f, %.2f, %.2f)" % [cam.addPosition.x, cam.addPosition.y, cam.addPosition.z])
			ImGui.text("Camera Angle: (%.1f, %.1f, %.1f)" % [cam.rotation_degrees.x, cam.rotation_degrees.y, cam.rotation_degrees.z])
			ImGui.text("Camera Distance: %.1f" % cam.distanceFromObject)
		else:
			var cam3d: Camera3D = get_viewport().get_camera_3d()
			if cam3d:
				ImGui.text("Camera Position: (%.2f, %.2f, %.2f)" % [cam3d.global_position.x, cam3d.global_position.y, cam3d.global_position.z])
				ImGui.text("Camera Angle: (%.1f, %.1f, %.1f)" % [cam3d.rotation_degrees.x, cam3d.rotation_degrees.y, cam3d.rotation_degrees.z])
				ImGui.text("FOV: %.1f" % cam3d.fov)
	ImGui.end()

func _pollDebug() -> void:
	if not is_instance_valid(self):
		return
	if not Player.instance:
		return
	var debugOn: bool = Player.instance.debug
	if debugOn != previousDebug:
		previousDebug = debugOn
		shown = debugOn
