class_name LevelUI
extends Control

static var instance: LevelUI = null

var levelname: String = "level name"
var shown: bool = false
var replayRequested: bool = false

@onready var normalPage: Control = $NormalPage
@onready var revivePage: Control = $RevivePage
@onready var background: ColorRect = $ColorRect
@onready var hideScreen: ColorRect = $HideScreen
@onready var title: Label = $NormalPage/title
@onready var percentage: Label = $NormalPage/percentage
@onready var barFill: TextureRect = $NormalPage/ProgressFrame/Fill
@onready var block: Label = $NormalPage/Collectible/diamond
@onready var percentageRevive: Label = $RevivePage/percentage
@onready var barFillRevive: TextureRect = $RevivePage/ProgressFrame/Fill

func _ready() -> void:
	instance = self
	if Player.instance and Player.instance.levelData:
		levelname = Player.instance.levelData.levelTitle
	else:
		push_error("LevelUI.gd: Player.instance 或 levelData 为空，无法读取关卡标题")
	visible = false

func _exit_tree() -> void:
	if instance == self:
		instance = null

## 对齐 Unity LevelUI.cs NormalPage/RevivePage：由 LevelManager.GameOver 直接调用
func show_end_ui() -> void:
	if shown:
		return
	shown = true

	var progress: float = clampf(float(LevelManager.percent) / 100.0, 0.0, 1.0)
	var percentageText: String = "%d%%" % LevelManager.percent
	title.text = levelname
	percentage.text = percentageText
	percentageRevive.text = percentageText
	block.text = "%d/10" % LevelManager.gem
	_set_progress(barFill, progress)
	_set_progress(barFillRevive, progress)

	var canRevive: bool = Player.instance != null and not Player.instance.isEnd \
		and is_instance_valid(LevelManager.currentCheckpoint)
	normalPage.visible = not canRevive
	revivePage.visible = canRevive
	background.color.a = 0.0 if canRevive else 0.639216
	visible = true
	# 对齐 Unity LevelManager.PlayerDeath：死亡/结算时恢复鼠标显示
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## 对齐 Unity LevelUI.cs：复活页 E = 复活，Q = 取消复活（R 重开由 Player._input 全局处理）
func _input(event: InputEvent) -> void:
	if not shown or not revivePage.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_on_revive_pressed()
			KEY_Q:
				_on_cancel_revive_pressed()

func _set_progress(fill: TextureRect, progress: float) -> void:
	fill.anchor_right = progress
	fill.offset_right = -6.0 if progress >= 0.02 else 6.0

func _on_back_pressed() -> void:
	get_tree().quit()
	LevelManager.isEnd = false
	LevelManager.isRelive = false
	LevelManager.cameraCheckpoint.restore_pending = false
	LevelManager.gem = 0
	LevelManager.crown = 0
	LevelManager.percent = 0

func _on_cancel_revive_pressed() -> void:
	revivePage.visible = false
	normalPage.visible = true
	background.color.a = 0.639216

func _on_revive_pressed() -> void:
	shown = false
	LevelManager.isEnd = false
	if not Player.instance:
		push_error("LevelUI.gd: Player.instance 为空，无法复活")
		_on_gamereplay_pressed()
		return
	if Player.instance.isEnd:
		_on_gamereplay_pressed()
	elif is_instance_valid(LevelManager.currentCheckpoint):
		# The UI stays visible while Checkpoint.revive() runs the HideScreen
		# fog-colored fade, matching Unity's Revival() -> LevelUI.HideScreen.
		LevelManager.currentCheckpoint.revive()
	else:
		_on_gamereplay_pressed()

## Unity parity: LevelUI.HideScreen. Fades a full-screen overlay to `color`,
## runs `fadeIn` while the screen is opaque (the scene reset happens hidden),
## then fades back out and runs `fadeOut`.
func HideScreen(color: Color, duration: float, fadeIn: Callable, fadeOut: Callable) -> void:
	hideScreen.color = Color(color.r, color.g, color.b, 0.0)
	hideScreen.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(hideScreen, "color:a", 1.0, duration)
	tween.tween_callback(func() -> void:
		_reset_ui()
		fadeIn.call()
	)
	tween.tween_property(hideScreen, "color:a", 0.0, duration)
	tween.tween_callback(func() -> void:
		hideScreen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fadeOut.call()
	)

func _reset_ui() -> void:
	normalPage.visible = false
	revivePage.visible = false
	background.color.a = 0.0

func _on_gamereplay_pressed() -> void:
	if replayRequested:
		return
	replayRequested = true
	LevelManager.reset_to_defaults()

	# Wait for a previous scene switch to settle before reading currentScene.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var currentScene: Node = get_tree().current_scene
	if not is_instance_valid(currentScene):
		replayRequested = false
		push_error("LevelUI.gd: 当前场景为空，无法重新加载关卡")
		return

	var loadingScene: PackedScene = load("res://#Template/[Resources]/LoadingPage.tscn") as PackedScene
	if loadingScene:
		var loadingPage: LoadingPage = loadingScene.instantiate() as LoadingPage
		if loadingPage:
			currentScene.add_child(loadingPage)
			var revealTween: Tween = loadingPage.reveal(_get_loading_background_color())
			await revealTween.finished
	if not is_inside_tree():
		return
	var player: Player = Player.instance
	if is_instance_valid(player):
		player.reload()
	else:
		replayRequested = false
		push_error("LevelUI.gd: Player.instance 为空，无法重新加载关卡")

func _get_loading_background_color() -> Color:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and camera.environment:
		return camera.environment.background_color
	return RenderingServer.get_default_clear_color()
