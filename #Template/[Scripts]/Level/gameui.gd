extends Control
var levelname := "level name"
@export var crown_no_light: Texture2D
var 一 := false

## 皇冠动画名称数组，按数量索引
const CROWN_ANIMS: Array[String] = ["", "1crown", "2crown", "3crown"]

func _ready() -> void:
	levelname = Player.instance.level_data.levelTitle
	$".".visible = false

func _process(_delta: float) -> void:
	if not 一:
		if Player.instance and not Player.instance.is_live:
			visible()
		if LevelManager.is_end:
			visible()

func visible() -> void:
	一 = true
	if LevelManager.is_relive == true:
		LevelManager.crown -= 1
	$diamond.text = str(LevelManager.diamond,"/10")
	$title.text = levelname
	_update_crown_display(LevelManager.crown)
	$".".visible = true


## 根据皇冠数量更新显示（使用数组替代多重 if-elif）
func _update_crown_display(count: int) -> void:
	# 获取所有皇冠节点
	var crown_nodes := [
		$PerfactCrownNoLight,
		$PerfactCrownNoLight2,
		$PerfactCrownNoLight3,
	]
	if count >= 1 and count <= 3:
		$AnimationPlayer.play(CROWN_ANIMS[count])
	else:
		for node in crown_nodes:
			node.texture = crown_no_light


func _on_back_pressed() -> void:
	get_tree().quit()
	LevelManager.is_end = false
	LevelManager.is_relive = false
	LevelManager.camera_checkpoint.restore_pending = false
	LevelManager.diamond = 0
	LevelManager.crown = 0
	LevelManager.percent = 0

func _on_revive_pressed() -> void:
	一 = false
	$".".visible = false
	if Player.instance.is_end:
		_on_gamereplay_pressed()
	elif LevelManager.current_checkpoint:
		LevelManager.current_checkpoint.revive()
		if LevelManager.crown > 0:
			LevelManager.is_relive = true
	else:
		_on_gamereplay_pressed()

func _on_gamereplay_pressed() -> void:
	if Player.instance:
		Player.instance.reload()
	LevelManager.reset_to_defaults()
