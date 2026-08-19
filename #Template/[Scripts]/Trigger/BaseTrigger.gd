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

func _on_body_entered(body: Node3D) -> void:
	if oneShot and used:
		if debugMode:
			print("[BaseTrigger] ", name, " 已触发过")
		return
	if requirePlaying and LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	# Unity triggers compare the incoming collider's Tag. Ordinary trigger
	# components are Player-only; FakePlayerTrigger handles its extra tags
	# through the raw body_entered signal.
	if not _has_player_tag(body):
		return

	used = true
	if debugMode:
		print("[BaseTrigger] ", name, " 被触发")

	triggered.emit(body)

	for behavior: Node in behaviors:
		if is_instance_valid(behavior):
			behavior.trigger(body)

func _has_player_tag(body: Node3D) -> bool:
	return body is Player or body.is_in_group("Player")

## 新增：离开区域处理
func _on_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	if debugMode:
		print("[BaseTrigger] ", name, " 玩家离开")

	exited.emit(body)

	for behavior: Node in behaviors:
		if is_instance_valid(behavior) and behavior.has_method("on_exit"):
			behavior.on_exit(body)

## 重新收集行为组件
func refresh_behaviors() -> void:
	_collect_behaviors()
