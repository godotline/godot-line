@tool
extends BaseTrigger
## @deprecated: 推荐使用 EventBehavior 作为 BaseTrigger 的子节点
## EventTrigger - 事件触发器（向后兼容包装）

class_name EventTrigger

## 事件触发器 - 可配置多个目标节点和方法

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
var _trigger_index: int = -1

func _ready() -> void:
	# 先断开场景中的旧 body_entered 连接，避免与 BaseTrigger 链冲突
	for conn in body_entered.get_connections():
		if conn["callable"].get_method() == "_on_body_entered":
			body_entered.disconnect(conn["callable"])

	super._ready()

	if Engine.is_editor_hint():
		return

	# body_exited 仍需要手动连接（BaseTrigger 不处理退出）
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if invoke_on_awake:
		_invoke()

func _on_triggered(_body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if invoke_on_awake or _invoked:
		return
	if not invoke_on_click:
		_invoke()
	elif not _waiting_click:
		_waiting_click = true
		if Player.instance and Player.instance.has_signal("onturn") and not Player.instance.onturn.is_connected(_on_player_turn):
			Player.instance.onturn.connect(_on_player_turn)

func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if not body is CharacterBody3D:
		return
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
	_invoke_targets()
	LevelManager.add_revive_listener(_on_revive)

## 调用所有配置的目标节点方法
func _invoke_targets() -> void:
	if debug_mode:
		print("[EventTrigger] %s 调用 %d 个目标" % [name, target_nodes.size()])

	for i in range(target_nodes.size()):
		var node: Node = target_nodes[i]
		if node == null:
			push_warning("[EventTrigger] 目标节点 #%d 为空，跳过" % i)
			continue

		# 获取方法名，如果索引越界则使用默认值 "Trigger"
		var method: String = "Trigger"
		if i < target_methods.size() and target_methods[i] != "":
			method = target_methods[i]

		if node.has_method(method):
			if debug_mode:
				print("[EventTrigger]   -> %s.%s()" % [node.name, method])
			node.call(method)
		else:
			push_warning("[EventTrigger] 节点 '%s' 没有方法 '%s'" % [node.name, method])

func _on_revive() -> void:
	LevelManager.remove_revive_listener(_on_revive)
	LevelManager.CompareCheckpointIndex(_trigger_index, func():
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
