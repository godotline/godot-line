extends Area3D
class_name BaseTrigger

## BaseTrigger - 触发器容器
## 负责碰撞检测和分发给子 TriggerBehavior 组件

signal triggered(body: Node3D)
signal exited(body: Node3D)  # 新增：玩家离开区域信号

@export_group("触发器设置")
@export var one_shot: bool = false
@export var require_playing: bool = true
@export var track_exit: bool = false  # 新增：是否追踪离开事件

@export_group("调试设置")
@export var debug_mode: bool = false

var _used: bool = false
var _behaviors: Array[Node] = []

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if track_exit:
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
	_collect_behaviors()

func _collect_behaviors() -> void:
	_behaviors.clear()
	for child in get_children():
		if child.has_method("trigger"):
			_behaviors.append(child)

func _on_body_entered(body: Node3D) -> void:
	if one_shot and _used:
		if debug_mode:
			print("[BaseTrigger] ", name, " 已触发过")
		return
	if require_playing and LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if not body is CharacterBody3D:
		return

	_used = true
	if debug_mode:
		print("[BaseTrigger] ", name, " 被触发")

	triggered.emit(body)

	for behavior in _behaviors:
		if is_instance_valid(behavior):
			behavior.trigger(body)

## 新增：离开区域处理
func _on_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	if debug_mode:
		print("[BaseTrigger] ", name, " 玩家离开")

	exited.emit(body)

	for behavior in _behaviors:
		if is_instance_valid(behavior) and behavior.has_method("on_exit"):
			behavior.on_exit(body)

## 重新收集行为组件
func refresh_behaviors() -> void:
	_collect_behaviors()
