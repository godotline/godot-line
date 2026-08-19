@tool
extends Node
class_name EventTrigger

## 事件触发器 - Unity EventTrigger 的 Godot 组件实现
## 纯组件模式：作为 BaseTrigger 的子节点，依赖父节点处理碰撞

## 等效于 Unity 版的 onTriggerEnter UnityEvent。
## 目标回调由 EventTrigger Inspector 插件连接到这个信号。
signal triggered
signal target_node_changed

@export_group("事件回调")
@export var targetNode: Node = null:
	set(value):
		if targetNode == value:
			return
		targetNode = value
		target_node_changed.emit()

@export_group("触发模式")
@export var invokeOnAwake: bool = false
@export var invokeOnClick: bool = false

@export_group("调试")
@export var debugMode: bool = false

var invoked: bool = false
var waitingClick: bool = false
var index: int = -1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if invokeOnAwake:
		_invoke()

## 由父节点 BaseTrigger 调用的入口方法
func trigger(body: Node3D) -> void:
	if invokeOnAwake or invoked:
		return
	if not invokeOnClick:
		_invoke()
	elif not waitingClick:
		waitingClick = true
		if Player.instance and Player.instance.has_signal("onturn") and not Player.instance.onturn.is_connected(_on_player_turn):
			Player.instance.onturn.connect(_on_player_turn)

## 由父节点 BaseTrigger 调用的离开方法
func on_exit(body: Node3D) -> void:
	if invokeOnAwake or not invokeOnClick:
		return
	if waitingClick and Player.instance and Player.instance.has_signal("onturn"):
		if Player.instance.onturn.is_connected(_on_player_turn):
			Player.instance.onturn.disconnect(_on_player_turn)
	waitingClick = false

func _on_player_turn() -> void:
	if waitingClick:
		if Player.instance and Player.instance.has_signal("onturn"):
			if Player.instance.onturn.is_connected(_on_player_turn):
				Player.instance.onturn.disconnect(_on_player_turn)
		waitingClick = false
		_invoke()

func _invoke() -> void:
	if invoked:
		return
	invoked = true
	index = LevelManager.checkpointCount
	if debugMode:
		print("[EventTrigger] %s 触发 (checkpoint: %d)" % [name, index])
	triggered.emit()
	LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	if not is_instance_valid(self):
		return
	LevelManager.remove_revive_listener(_on_revive)
	LevelManager.CompareCheckpointIndex(index, func():
		if not is_instance_valid(self):
			return
		invoked = false
		waitingClick = false
	)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	LevelManager.remove_revive_listener(_on_revive)
	if waitingClick and Player.instance and Player.instance.has_signal("onturn"):
		if Player.instance.onturn.is_connected(_on_player_turn):
			Player.instance.onturn.disconnect(_on_player_turn)