@tool
extends Node
class_name EventTrigger

## 事件触发器 - Unity EventTrigger 的 Godot 组件实现
## 纯组件模式：作为 BaseTrigger 的子节点，依赖父节点处理碰撞

## 等效于 Unity 版的 onTriggerEnter UnityEvent。
## 目标回调由 EventTrigger Inspector 插件连接到这个信号。
signal triggered

@export_group("触发模式")
@export var invoke_on_awake: bool = false
@export var invoke_on_click: bool = false

@export_group("调试")
@export var debug_mode: bool = false

var _invoked: bool = false
var _waiting_click: bool = false
var _trigger_index: int = -1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if invoke_on_awake:
		_invoke()

## 由父节点 BaseTrigger 调用的入口方法
func trigger(body: Node3D) -> void:
	if invoke_on_awake or _invoked:
		return
	if not invoke_on_click:
		_invoke()
	elif not _waiting_click:
		_waiting_click = true
		if Player.instance and Player.instance.has_signal("onturn") and not Player.instance.onturn.is_connected(_on_player_turn):
			Player.instance.onturn.connect(_on_player_turn)

## 由父节点 BaseTrigger 调用的离开方法
func on_exit(body: Node3D) -> void:
	if invoke_on_awake or not invoke_on_click:
		return
	if _waiting_click and Player.instance and Player.instance.has_signal("onturn"):
		if Player.instance.onturn.is_connected(_on_player_turn):
			Player.instance.onturn.disconnect(_on_player_turn)
	_waiting_click = false

func _on_player_turn() -> void:
	if _waiting_click:
		if Player.instance and Player.instance.has_signal("onturn"):
			if Player.instance.onturn.is_connected(_on_player_turn):
				Player.instance.onturn.disconnect(_on_player_turn)
		_waiting_click = false
		_invoke()

func _invoke() -> void:
	if _invoked:
		return
	_invoked = true
	_trigger_index = LevelManager.checkpoint_count
	if debug_mode:
		print("[EventTrigger] %s 触发 (checkpoint: %d)" % [name, _trigger_index])
	triggered.emit()
	LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	if not is_instance_valid(self):
		return
	LevelManager.remove_revive_listener(_on_revive)
	LevelManager.CompareCheckpointIndex(_trigger_index, func():
		if not is_instance_valid(self):
			return
		_invoked = false
		_waiting_click = false
	)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	LevelManager.remove_revive_listener(_on_revive)
	if _waiting_click and Player.instance and Player.instance.has_signal("onturn"):
		if Player.instance.onturn.is_connected(_on_player_turn):
			Player.instance.onturn.disconnect(_on_player_turn)
