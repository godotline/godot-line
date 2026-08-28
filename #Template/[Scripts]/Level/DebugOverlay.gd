extends Node
class_name DebugOverlay

# Debug HUD implemented with dear-imgui-godot, matching the Unity Player.cs #if UNITY_EDITOR OnGUI panel.
# This node handles visibility and content; rendering is provided by the ImGui autoload.
# The default plugin font is ASCII-only, so the panel uses English labels.

var previousDebug: bool = false
var shown: bool = false
var panelHovered: bool = false
var lastAppliedShown: bool = true
var pollTimer: Timer

func _ready() -> void:
	shown = false
	ImGui.imgui_layout.connect(_onImguiLayout)

	# Poll the debug switch so the HUD is only shown when debug mode is enabled.
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
	var p: Player = Player.instance
	if not p:
		return

	# D toggles the window between expanded and collapsed states. Apply changes only when needed.
	if shown != lastAppliedShown:
		lastAppliedShown = shown
		ImGui.set_next_window_collapsed(not shown, 1)
		ImGui.set_next_window_pos(20.0, 20.0, 4) # 4 = CondFirstUseEver; preserve a user-dragged position.
	ImGui.set_next_window_bg_alpha(0.0)
	# Mouse visibility follows the actual window state and hover detection.
	# Only intervene while Playing; LevelUI owns the cursor during death and results screens.
	var expanded: bool = ImGui.begin("DebugOverlay")
	# begin returns false when collapsed, leaving the title bar available for reopening.
	panelHovered = ImGui.is_window_hovered(0)
	if expanded:
		ImGui.text("FPS: %d" % Engine.get_frames_per_second())

		if p.levelData:
			var musicPlayer: AudioStreamPlayer = p.get_node_or_null("MusicPlayer") as AudioStreamPlayer
			if musicPlayer and musicPlayer.stream:
				var progress: float = musicPlayer.get_playback_position() / musicPlayer.stream.get_length() if musicPlayer.stream.get_length() > 0 else 0.0
				var currentSec: float = musicPlayer.get_playback_position()
				var totalSec: float = p.levelData.levelTotalTime if p.levelData.useCustomLevelTime else musicPlayer.stream.get_length()
				ImGui.text("Progress: %d%% (%ds/%ds)" % [int(progress * 100), int(currentSec), int(totalSec)])

		ImGui.text("Game Status: %s" % LevelManager.GameStatus.keys()[LevelManager.GameState])

		ImGui.text("Line Position: (%.2f, %.2f, %.2f)" % [p.position.x, p.position.y, p.position.z])
		ImGui.text("Line Rotation: (%.1f, %.1f, %.1f)" % [p.rotation_degrees.x, p.rotation_degrees.y, p.rotation_degrees.z])

		ImGui.text("Gems: %d" % LevelManager.gem)
		ImGui.text("Crowns: %d/3" % LevelManager.crown)

		var cam: OldCameraFollower = OldCameraFollower.instance
		if cam:
			ImGui.text("Camera Offset: (%.2f, %.2f, %.2f)" % [cam.addPosition.x, cam.addPosition.y, cam.addPosition.z])
			ImGui.text("Camera Angle: (%.1f, %.1f, %.1f)" % [cam.rotation_degrees.x, cam.rotation_degrees.y, cam.rotation_degrees.z])
			if cam.scaleNode:
				ImGui.text("Camera Scale: (%.2f, %.2f, %.2f)" % [cam.scaleNode.scale.x, cam.scaleNode.scale.y, cam.scaleNode.scale.z])
			if cam.camera:
				ImGui.text("FOV: %.1f" % cam.camera.fov)
		else:
			var cam3d: Camera3D = get_viewport().get_camera_3d()
			if cam3d:
				ImGui.text("Camera Position: (%.2f, %.2f, %.2f)" % [cam3d.global_position.x, cam3d.global_position.y, cam3d.global_position.z])
				ImGui.text("Camera Angle: (%.1f, %.1f, %.1f)" % [cam3d.rotation_degrees.x, cam3d.rotation_degrees.y, cam3d.rotation_degrees.z])
				ImGui.text("FOV: %.1f" % cam3d.fov)

		ImGui.text("")
		if ImGui.small_button("Reload (R)"):
			p.reload()
		# Match the K-key gate: only allow killing the player while Playing.
		if ImGui.small_button("Kill (K)") and LevelManager.GameState == LevelManager.GameStatus.Playing:
			p.PlayerDeath(true, LevelManager.GameStatus.Died, false)
	ImGui.end()

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
