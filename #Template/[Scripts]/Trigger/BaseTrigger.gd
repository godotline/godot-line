extends Area3D
class_name BaseTrigger

## BaseTrigger - 触发器容器
## 负责碰撞检测和分发给子 TriggerBehavior 组件

signal triggered(body: Node3D)

@export_group("触发器设置")
@export var one_shot: bool = false
@export var require_playing: bool = true

@export_group("调试设置")
@export var debug_mode: bool = false

var _used: bool = false
var _behaviors: Array[Node] = []

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
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

## 重新收集行为组件
func refresh_behaviors() -> void:
	_collect_behaviors()
