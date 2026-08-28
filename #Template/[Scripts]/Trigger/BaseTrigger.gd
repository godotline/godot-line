@tool
extends Area3D
class_name BaseTrigger

## BaseTrigger - 触发器容器
## 负责碰撞检测和分发给子 TriggerBehavior 组件

signal triggered(body: Node3D)
signal exited(body: Node3D)  # 新增：玩家离开区域信号

@export_group("触发器设置")
@export var oneShot: bool = false
@export var requirePlaying: bool = true
@export var trackExit: bool = false  # 新增：是否追踪离开事件

@export_group("调试设置")
@export var debugMode: bool = false

var used: bool = false
var behaviors: Array[Node] = []

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if trackExit:
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
	_collect_behaviors()

func _collect_behaviors() -> void:
	behaviors.clear()
	for child: Node in get_children():
		if child.has_method("trigger"):
			behaviors.append(child)

func _on_body_entered(other: Node3D) -> void:
	if oneShot and used:
		if debugMode:
			print("[BaseTrigger] ", name, " 已触发过")
		return
	if requirePlaying and LevelManager.GameState != LevelManager.GameStatus.Playing:
		return

	var any_triggered = false
	for behavior: Node in behaviors:
		if is_instance_valid(behavior):
			var result = behavior.trigger(other)
			# 如果组件返回 true 或者没有返回值（null），我们认为它触发了。
			# 严格来说，Unity 风格里组件自决是否触发，如果有任意一个触发了，并且配置了 oneShot，那么就消耗掉。
			if typeof(result) == TYPE_BOOL:
				if result:
					any_triggered = true
			else:
				# 兼容没有返回 bool 的老组件
				any_triggered = true

	if any_triggered:
		used = true
		if debugMode:
			print("[BaseTrigger] ", name, " 被触发")
		triggered.emit(other)

## 新增：离开区域处理
func _on_body_exited(other: Node3D) -> void:
	if not other is CharacterBody3D:
		return
	if debugMode:
		print("[BaseTrigger] ", name, " 玩家离开")

	exited.emit(other)

	for behavior: Node in behaviors:
		if is_instance_valid(behavior) and behavior.has_method("on_exit"):
			behavior.on_exit(other)

## 重新收集行为组件
func refresh_behaviors() -> void:
	_collect_behaviors()
