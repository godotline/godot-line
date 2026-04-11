extends Control
@export var line : CharacterBody3D
@export var levelname := "level name"
@export var crown_no_light: Texture2D
var 一 := false

## 皇冠动画名称数组，按数量索引
const CROWN_ANIMS: Array[String] = ["", "1crown", "2crown", "3crown"]

func _ready() -> void:
	$".".visible = false

func _process(_delta: float) -> void:
	if not 一:
		if not line.is_live:
			visible()
		if State.is_end:
			visible()

func visible() -> void:
	一 = true
	if State.is_relive == true:
		State.crown -= 1
	$diamond.text = str(State.diamond,"/10")
	$title.text = levelname
	_update_crown_display(State.crown)
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
	State.is_end = false
	State.is_relive = false
	State.camera_checkpoint.restore_pending = false
	State.diamond = 0
	State.crown = 0
	State.percent = 0

func _on_gameplay_pressed() -> void:
	line.tree.reload_current_scene()
	if State.crown > 0 :
		State.is_relive = true
	State.camera_checkpoint.restore_pending = true
	State.diamond = 0
	State.crown = 0
	State.percent = 0
	State.line_crossing_crown = 0
	State.crowns = [0, 0, 0]
	State.music_checkpoint_time = 0.0

func _on_gamereplay_pressed() -> void:
	line.reload()
	State.reset_to_defaults()
