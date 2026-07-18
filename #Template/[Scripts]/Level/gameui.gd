extends Control
var levelname := "level name"
@export var crown_no_light: Texture2D
var 一 := false

## 皇冠动画名称数组，按数量索引
const CROWN_ANIMS: Array[String] = ["", "1crown", "2crown", "3crown"]

func _ready() -> void:
	if Player.instance and Player.instance.level_data:
		levelname = Player.instance.level_data.levelTitle
	else:
		push_error("gameui.gd: Player.instance 或 level_data 为空，无法读取关卡标题")
	$".".visible = false
	set_process(false)  ## 信号驱动，不需要轮询

	# 连接 Player 游戏结束信号（信号驱动，替代轮询）
	if Player.instance:
		Player.instance.on_game_end.connect(_on_game_end)

func _on_game_end() -> void:
	_show_ui()

func _show_ui() -> void:
	if 一:
		return
	一 = true
	if LevelManager.is_relive == true:
		LevelManager.crown -= 1
	var diamond_node: Node = get_node_or_null("diamond")
	if diamond_node:
		diamond_node.text = str(LevelManager.gem,"/10")
	else:
		push_error("gameui.gd: diamond 节点未找到")
	var title_node: Label = get_node_or_null("title") as Label
	if title_node:
		title_node.text = levelname
	else:
		push_error("gameui.gd: title 节点未找到")
	_update_crown_display(LevelManager.crown)
	$".".visible = true


## 根据皇冠数量更新显示（使用数组替代多重 if-elif）
func _update_crown_display(count: int) -> void:
	# 获取所有皇冠节点
	var crown_nodes := [
		get_node_or_null("PerfactCrownNoLight"),
		get_node_or_null("PerfactCrownNoLight2"),
		get_node_or_null("PerfactCrownNoLight3"),
	]
	if count >= 1 and count <= 3:
		var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player:
			anim_player.play(CROWN_ANIMS[count])
		else:
			push_error("gameui.gd: AnimationPlayer 节点未找到，无法播放皇冠动画")
	else:
		for node in crown_nodes:
			if node:
				node.texture = crown_no_light
			else:
				push_error("gameui.gd: 皇冠节点未找到，无法更新纹理")


func _on_back_pressed() -> void:
	get_tree().quit()
	LevelManager.is_end = false
	LevelManager.is_relive = false
	LevelManager.camera_checkpoint.restore_pending = false
	LevelManager.gem = 0
	LevelManager.crown = 0
	LevelManager.percent = 0

func _on_revive_pressed() -> void:
	一 = false
	$".".visible = false
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
	if Player.instance:
		Player.instance.reload()
	LevelManager.reset_to_defaults()
