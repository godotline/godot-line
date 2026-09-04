extends Node
class_name DebugOverlay

# Debug HUD implemented with dear-imgui-godot, matching the Unity Player.cs #if UNITY_EDITOR OnGUI panel.
# This node handles visibility and content; rendering is provided by the ImGui autoload.
# The default plugin font is ASCII-only, so the panel uses English labels.

var imgui: Object = null
var previousDebug: bool = false
var shown: bool = false
var panelHovered: bool = false
var lastAppliedShown: bool = true
var pollTimer: Timer
const DEBUG_FONT_SCALE: float = 1.5

func _ready() -> void:
	shown = false
	# ImGui autoload 可能不存在（无 imgui 版源码包），为空时面板 no-op。
	imgui = get_node_or_null("/root/ImGui")
	if imgui == null:
		return
	imgui.imgui_layout.connect(_onImguiLayout)

	# Poll the debug switch so the HUD is only shown when debug mode is enabled.
	pollTimer = Timer.new()
	pollTimer.wait_time = 0.25
	pollTimer.one_shot = false
	pollTimer.autostart = true
	pollTimer.timeout.connect(_pollDebug)
	add_child(pollTimer)

func _exit_tree() -> void:
	if imgui and imgui.imgui_layout.is_connected(_onImguiLayout):
		imgui.imgui_layout.disconnect(_onImguiLayout)

func _onImguiLayout() -> void:
	if imgui == null:
		return
	var p: Player = Player.instance
	if not p:
		return

	# D toggles the window between expanded and collapsed states. Apply changes only when needed.
	if shown != lastAppliedShown:
		lastAppliedShown = shown
		imgui.set_next_window_collapsed(not shown, 1)
		imgui.set_next_window_pos(20.0, 20.0, 4) # 4 = CondFirstUseEver; preserve a user-dragged position.
	imgui.set_next_window_bg_alpha(0.0)
	# Mouse visibility follows the actual window state and hover detection.
	# Only intervene while Playing; LevelUI owns the cursor during death and results screens.
	# Android touch-to-mouse events can carry the previous mouse position, which makes
	# an outside tap look like a window drag. Keep the debug window fixed on Android.
	var windowFlags: int = imgui.WINDOW_NO_BACKGROUND | imgui.WINDOW_NO_SCROLLBAR | imgui.WINDOW_NO_RESIZE | imgui.WINDOW_ALWAYS_AUTO_RESIZE
	if OS.get_name() == "Android":
		windowFlags |= imgui.WINDOW_NO_MOVE
	var expanded: bool = imgui.begin_ex("DebugOverlay", windowFlags)
	imgui.set_window_font_scale(DEBUG_FONT_SCALE)
	# begin returns false when collapsed, leaving the title bar available for reopening.
	panelHovered = imgui.is_window_hovered(0)
	if expanded:
		imgui.text("FPS: %d" % Engine.get_frames_per_second())

		if p.levelData:
			var soundTrack: AudioStreamPlayer = p.SoundTrack
			if soundTrack and soundTrack.stream:
				var progress: float = AudioManager.Progress
				var currentSec: float = AudioManager.time
				var totalSec: float = p.levelData.levelTotalTime if p.levelData.useCustomLevelTime else soundTrack.stream.get_length()
				imgui.text("Progress: %d%% (%ds/%ds)" % [int(progress * 100), int(currentSec), int(totalSec)])

		imgui.text("Game Status: %s" % LevelManager.GameStatus.keys()[LevelManager.GameState])

		imgui.text("Line Position: (%.2f, %.2f, %.2f)" % [p.position.x, p.position.y, p.position.z])
		imgui.text("Line Rotation: (%.1f, %.1f, %.1f)" % [p.rotation_degrees.x, p.rotation_degrees.y, p.rotation_degrees.z])

		imgui.text("Gems: %d" % LevelManager.gem)
		imgui.text("Crowns: %d/3" % LevelManager.crown)

		var cam: OldCameraFollower = OldCameraFollower.instance
		if cam:
			imgui.text("Camera Offset: (%.2f, %.2f, %.2f)" % [cam.addPosition.x, cam.addPosition.y, cam.addPosition.z])
			imgui.text("Camera Angle: (%.1f, %.1f, %.1f)" % [cam.rotation_degrees.x, cam.rotation_degrees.y, cam.rotation_degrees.z])
			if cam.scaleNode:
				imgui.text("Camera Scale: (%.2f, %.2f, %.2f)" % [cam.scaleNode.scale.x, cam.scaleNode.scale.y, cam.scaleNode.scale.z])
			if cam.camera:
				imgui.text("FOV: %.1f" % cam.camera.fov)
		else:
			var cam3d: Camera3D = get_viewport().get_camera_3d()
			if cam3d:
				imgui.text("Camera Position: (%.2f, %.2f, %.2f)" % [cam3d.global_position.x, cam3d.global_position.y, cam3d.global_position.z])
				imgui.text("Camera Angle: (%.1f, %.1f, %.1f)" % [cam3d.rotation_degrees.x, cam3d.rotation_degrees.y, cam3d.rotation_degrees.z])
				imgui.text("FOV: %.1f" % cam3d.fov)

		imgui.text("")
		if imgui.small_button("Reload (R)"):
			p.reload()
		# Match the K-key gate: only allow killing the player while Playing.
		if imgui.small_button("Kill (K)") and LevelManager.GameState == LevelManager.GameStatus.Playing:
			p.PlayerDeath(LevelManager.DieReason.Hit, false, true, false)
	imgui.end()

	# While Playing, show the cursor only over the expanded panel; LevelUI handles other states.
	if LevelManager.GameState == LevelManager.GameStatus.Playing:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (expanded and panelHovered) else Input.MOUSE_MODE_HIDDEN

func _pollDebug() -> void:
	if not is_instance_valid(self):
		return
	if not Player.instance:
		return
	var debugOn: bool = Player.instance.debug
	if debugOn != previousDebug:
		previousDebug = debugOn
		shown = debugOn
