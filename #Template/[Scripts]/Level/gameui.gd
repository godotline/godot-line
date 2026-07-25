extends Control

var levelname: String = "level name"
var _shown: bool = false

@onready var normal_page: Control = $NormalPage
@onready var revive_page: Control = $RevivePage
@onready var backdrop: ColorRect = $ColorRect
@onready var title_label: Label = $NormalPage/title
@onready var normal_percentage: Label = $NormalPage/percentage
@onready var normal_fill: TextureRect = $NormalPage/ProgressFrame/Fill
@onready var collectible_label: Label = $NormalPage/Collectible/diamond
@onready var revive_percentage: Label = $RevivePage/percentage
@onready var revive_fill: TextureRect = $RevivePage/ProgressFrame/Fill

func _ready() -> void:
	if Player.instance and Player.instance.level_data:
		levelname = Player.instance.level_data.levelTitle
	else:
		push_error("gameui.gd: Player.instance 或 level_data 为空，无法读取关卡标题")
	visible = false
	set_process(false)
	if Player.instance:
		Player.instance.on_game_end.connect(_on_game_end)

func _on_game_end() -> void:
	_show_ui()

func _show_ui() -> void:
	if _shown:
		return
	_shown = true
	if LevelManager.is_relive:
		LevelManager.crown -= 1

	var progress: float = clampf(float(LevelManager.percent) / 100.0, 0.0, 1.0)
	var percentage_text: String = "%d%%" % LevelManager.percent
	title_label.text = levelname
	normal_percentage.text = percentage_text
	revive_percentage.text = percentage_text
	collectible_label.text = "%d/10" % LevelManager.gem
	_set_progress(normal_fill, progress)
	_set_progress(revive_fill, progress)

	var can_revive: bool = Player.instance != null and not Player.instance.is_end and LevelManager.current_checkpoint != null
	normal_page.visible = not can_revive
	revive_page.visible = can_revive
	backdrop.color.a = 0.0 if can_revive else 0.639216
	visible = true

func _set_progress(fill: TextureRect, progress: float) -> void:
	fill.anchor_right = progress
	fill.offset_right = -6.0 if progress >= 0.02 else 6.0

func _on_back_pressed() -> void:
	get_tree().quit()
	LevelManager.is_end = false
	LevelManager.is_relive = false
	LevelManager.camera_checkpoint.restore_pending = false
	LevelManager.gem = 0
	LevelManager.crown = 0
	LevelManager.percent = 0

func _on_cancel_revive_pressed() -> void:
	revive_page.visible = false
	normal_page.visible = true
	backdrop.color.a = 0.639216

func _on_revive_pressed() -> void:
	_shown = false
	visible = false
	LevelManager.is_end = false
	if not Player.instance:
		push_error("gameui.gd: Player.instance 为空，无法复活")
		_on_gamereplay_pressed()
		return
	if Player.instance.is_end:
		_on_gamereplay_pressed()
	elif LevelManager.current_checkpoint:
		LevelManager.current_checkpoint.revive()
		if LevelManager.crown > 0:
			LevelManager.is_relive = true
	else:
		_on_gamereplay_pressed()

func _on_gamereplay_pressed() -> void:
	LevelManager.reset_to_defaults()
	var loading_scene: PackedScene = load("res://#Template/[Resources]/LoadingPage.tscn") as PackedScene
	if loading_scene:
		var loading_page: Node = loading_scene.instantiate()
		get_tree().current_scene.add_child(loading_page)
		var reveal_tween: Tween = loading_page.call("reveal", _get_loading_background_color()) as Tween
		await reveal_tween.finished
	if Player.instance:
		Player.instance.reload()

func _get_loading_background_color() -> Color:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and camera.environment:
		return camera.environment.background_color
	return RenderingServer.get_default_clear_color()
