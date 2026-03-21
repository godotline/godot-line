@tool
extends Node

## 根据节点名称筛选（支持通配符 * 和 ?）
@export var node_pattern: String = "*Anim*"
## 目标循环模式
@export_enum("None:0", "Linear:1", "PingPong:2") var target_loop_mode: int = Animation.LOOP_LINEAR
## 游戏运行时自动执行
@export var auto_apply_on_start: bool = false

@export_group("编辑器操作")
@export var 执行批量设置: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_batch_process()
			执行批量设置 = false
			notify_property_list_changed()

@export var 播放测试: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_batch_play()
			播放测试 = false

@export var 停止测试: bool = false:
		set(value):
			if value and Engine.is_editor_hint():
				_batch_stop()
				停止测试 = false

func _ready():
	if Engine.is_editor_hint():
		return
	
	# 游戏运行时自动处理
	if auto_apply_on_start:
		_batch_process()
		_batch_play()

## 核心：批量设置 autoplay = 节点名称
func _batch_process():
	var players = _find_animation_players()
	if players.is_empty():
		push_warning("[批量动画] 未找到匹配 '%s' 的 AnimationPlayer" % node_pattern)
		return
	
	for player in players:
		# 关键：autoplay 设置为该 AnimationPlayer 的节点名称
		player.autoplay = StringName(player.name)
		
		# 批量修改循环模式
		var anim_list = player.get_animation_list()
		for anim_name in anim_list:
			var anim = player.get_animation(anim_name)
			if anim:
				anim.loop_mode = target_loop_mode
		
		print("[批量动画] %s -> autoplay='%s', loop_mode=%d, 动画数=%d" % [
			player.name, 
			player.autoplay, 
			target_loop_mode,
			anim_list.size()
		])
	
	# 编辑器中标记场景已修改（提示保存）
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()

## 查找匹配的 AnimationPlayer
func _find_animation_players() -> Array[AnimationPlayer]:
	var result: Array[AnimationPlayer] = []
	_collect_recursive(get_tree().root if is_inside_tree() else self, result)
	return result

func _collect_recursive(node: Node, result: Array[AnimationPlayer]):
	if node is AnimationPlayer and node.name.match(node_pattern):
		result.append(node)
	
	for child in node.get_children():
		_collect_recursive(child, result)

## 播放（使用 autoplay 设置的名称，即节点名）
func _batch_play():
	var players = _find_animation_players()
	for player in players:
		# 播放 autoplay 中指定的动画（即节点名称）
		if player.autoplay != "":
			player.play(player.autoplay)
			print("[批量播放] %s: %s" % [player.name, player.autoplay])
		else:
			# 如果没有设置 autoplay，则播放第一个可用动画
			var first_anim = player.get_animation_list()
			if first_anim.size() > 0:
				player.play(first_anim[0])

func _batch_stop():
	var players = _find_animation_players()
	for player in players:
		player.stop()
