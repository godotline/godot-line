@tool
extends Area3D
class_name EventTrigger

signal triggered

@export_group("触发模式")
@export var invoke_on_awake: bool = false
@export var invoke_on_click: bool = false

var _invoked: bool = false
var _waiting_click: bool = false
var _trigger_index: int = -1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if invoke_on_awake:
		_invoke()

func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if not body is CharacterBody3D:
		return
	if invoke_on_awake or _invoked:
		return
	if not invoke_on_click:
		_invoke()
	else:
		_waiting_click = true
		if Player.instance and Player.instance.has_signal("onturn"):
			Player.instance.onturn.connect(_on_player_turn)

func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if not body is CharacterBody3D:
		return
	if invoke_on_awake or not invoke_on_click:
		return
	if _waiting_click and Player.instance and Player.instance.has_signal("onturn"):
		Player.instance.onturn.disconnect(_on_player_turn)
	_waiting_click = false

func _on_player_turn() -> void:
	if _waiting_click:
		if Player.instance and Player.instance.has_signal("onturn"):
			Player.instance.onturn.disconnect(_on_player_turn)
		_waiting_click = false
		_invoke()

func _invoke() -> void:
	if _invoked:
		return
	_invoked = true
	_trigger_index = LevelManager.checkpoint_count
	triggered.emit()
	LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	LevelManager.remove_revive_listener(_on_revive)
	LevelManager.CompareCheckpointIndex(_trigger_index, func():
		_invoked = false
		_waiting_click = false
	)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)
		if _waiting_click and Player.instance and Player.instance.has_signal("onturn"):
			Player.instance.onturn.disconnect(_on_player_turn)
