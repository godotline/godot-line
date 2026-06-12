@tool
extends TriggerBehavior
class_name EventBehavior

## EventBehavior - 事件调用行为组件
## 当父 BaseTrigger 被触发时调用目标节点的方法

signal event_triggered

@export_group("触发目标")
## 目标节点列表
@export var target_nodes: Array[Node] = []
## 对应的方法名列表（默认为 "Trigger"）
@export var target_methods: Array[String] = []

@export_group("触发模式")
@export var invoke_on_awake: bool = false
@export var invoke_on_click: bool = false

var _invoked: bool = false
var _waiting_click: bool = false

func _ready() -> void:
	super._ready()
	if invoke_on_awake and not Engine.is_editor_hint():
		_invoke()

func _on_triggered(_body: Node3D) -> void:
	if invoke_on_awake or _invoked:
		return
	if not invoke_on_click:
		_invoke()
	elif not _waiting_click:
		_waiting_click = true
		if Player.instance and Player.instance.has_signal("onturn") and not Player.instance.onturn.is_connected(_on_player_turn):
			Player.instance.onturn.connect(_on_player_turn)

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
	event_triggered.emit()
	_invoke_targets()
	_register_revive()

## 调用所有配置的目标节点方法
func _invoke_targets() -> void:
	for i in range(target_nodes.size()):
		var node: Node = target_nodes[i]
		if node == null:
			push_warning("[EventBehavior] 目标节点 #%d 为空，跳过" % i)
			continue

		# 获取方法名，如果索引越界则使用默认值 "Trigger"
		var method: String = "Trigger"
		if i < target_methods.size() and target_methods[i] != "":
			method = target_methods[i]

		if node.has_method(method):
			node.call(method)
		else:
			push_warning("[EventBehavior] 节点 '%s' 没有方法 '%s'" % [node.name, method])

func _on_revive() -> void:
	_invoked = false
	_waiting_click = false

func _exit_tree() -> void:
	super._exit_tree()
	if _waiting_click and Player.instance and Player.instance.has_signal("onturn"):
		if Player.instance.onturn.is_connected(_on_player_turn):
			Player.instance.onturn.disconnect(_on_player_turn)
