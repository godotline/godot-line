extends Node
class_name DebugOverlay

# 调试 HUD（imgui-godot 实现）。对齐 Unity Player.cs #if UNITY_EDITOR 的 OnGUI 调试面板：
# 本节点只负责开关与内容，绘制由 ImGui autoload（addons/imgui-godot）完成。
# 字体使用 MiSans（ImGuiConfig.tres），支持中文，标签与 Unity 保持一致。

var previousDebug: bool = false
var shown: bool = false
var panelHovered: bool = false
var lastAppliedShown: bool = true
var pollTimer: Timer

func _ready() -> void:
	shown = false

	# 轮询 debug 开关（对齐 Unity：调试 HUD 仅在 debug 开启时绘制）
	pollTimer = Timer.new()
	pollTimer.wait_time = 0.25
	pollTimer.one_shot = false
	pollTimer.autostart = true
	pollTimer.timeout.connect(_pollDebug)
	add_child(pollTimer)

func _process(_delta: float) -> void:
	_drawLayout()

func _drawLayout() -> void:
	var p: Player = Player.instance
	if not p:
		return

	# D 键仅展开/收起：窗口常驻，收起时保留标题栏。仅在状态变化时应用，避免每帧强制覆盖
	if shown != lastAppliedShown:
		lastAppliedShown = shown
		ImGui.SetNextWindowCollapsed(not shown, 1)
	ImGui.SetNextWindowBgAlpha(0.0)
	ImGui.SetNextWindowPos(Vector2(10.0, 10.0), 4) # 4 = CondFirstUseEver，允许用户拖动后记忆位置
	# 鼠标可见性基于真实窗口状态（begin 返回值=是否折叠/裁剪）与悬停检测。
	# 仅 Playing 状态下干预；死亡/结算时鼠标交给 LevelUI 保持显示。
	var expanded: bool = ImGui.Begin("DebugOverlay")
	# 收起时 begin 返回 false，仅剩标题栏；此时悬停标题栏也应能显示鼠标（否则无法点开）
	panelHovered = ImGui.IsWindowHovered(0)
	if expanded:
		ImGui.Text("FPS：%d" % Engine.get_frames_per_second())

		if p.levelData:
			var musicPlayer: AudioStreamPlayer = p.get_node_or_null("MusicPlayer") as AudioStreamPlayer
			if musicPlayer and musicPlayer.stream:
				var progress: float = musicPlayer.get_playback_position() / musicPlayer.stream.get_length() if musicPlayer.stream.get_length() > 0 else 0.0
				var currentSec: float = musicPlayer.get_playback_position()
				var totalSec: float = p.levelData.levelTotalTime if p.levelData.useCustomLevelTime else musicPlayer.stream.get_length()
				ImGui.Text("关卡进度：%d%%（%d秒/%d秒）" % [int(progress * 100), int(currentSec), int(totalSec)])

		ImGui.Text("游戏状态：%s" % LevelManager.GameStatus.keys()[LevelManager.GameState])

		ImGui.Text("线的坐标：（%.2f， %.2f， %.2f）" % [p.position.x, p.position.y, p.position.z])
		ImGui.Text("线的朝向：（%.1f， %.1f， %.1f）" % [p.rotation_degrees.x, p.rotation_degrees.y, p.rotation_degrees.z])

		ImGui.Text("已获取方块数量：%d" % LevelManager.gem)
		ImGui.Text("已获取皇冠数量：%d/3" % LevelManager.crown)

		var cam: OldCameraFollower = OldCameraFollower.instance
		if cam:
			ImGui.Text("相机偏移：（%.2f， %.2f， %.2f）" % [cam.addPosition.x, cam.addPosition.y, cam.addPosition.z])
			ImGui.Text("相机角度：（%.1f， %.1f， %.1f）" % [cam.rotation_degrees.x, cam.rotation_degrees.y, cam.rotation_degrees.z])
			if cam.scaleNode:
				ImGui.Text("相机缩放：（%.2f， %.2f， %.2f）" % [cam.scaleNode.scale.x, cam.scaleNode.scale.y, cam.scaleNode.scale.z])
			if cam.camera:
				ImGui.Text("视场大小：%.1f" % cam.camera.fov)
		else:
			var cam3d: Camera3D = get_viewport().get_camera_3d()
			if cam3d:
				ImGui.Text("相机位置：（%.2f， %.2f， %.2f）" % [cam3d.global_position.x, cam3d.global_position.y, cam3d.global_position.z])
				ImGui.Text("相机角度：（%.1f， %.1f， %.1f）" % [cam3d.rotation_degrees.x, cam3d.rotation_degrees.y, cam3d.rotation_degrees.z])
				ImGui.Text("视场大小：%.1f" % cam3d.fov)

		ImGui.Text("")
		if ImGui.SmallButton("重载 (R)"):
			p.reload()
		# 与键盘 K 同一状态门控：仅 Playing 可判死，防止死亡后反复鞭尸
		if ImGui.SmallButton("击杀 (K)") and LevelManager.GameState == LevelManager.GameStatus.Playing:
			p.PlayerDeath(true, LevelManager.GameStatus.Died, false)
	ImGui.End()

	# Playing 状态下：展开 + 悬停面板才显示鼠标；折叠或移出即隐藏。其余状态（死亡/结算）交给 LevelUI
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
