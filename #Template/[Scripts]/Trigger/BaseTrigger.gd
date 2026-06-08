extends Area3D
class_name BaseTrigger

signal triggered(body: Node3D)

@export_group("触发器设置")
@export var one_shot: bool = false
@export var require_playing: bool = true  ## 是否只在 Playing 状态下触发

@export_group("调试设置")
@export var debug_mode: bool = false

var _used: bool = false
var _signal_connected: bool = false
var _behaviors: Array[BaseTrigger] = []
var _is_behavior: bool = false

func _ready() -> void:
	## 如果父节点是 BaseTrigger，则作为行为组件，禁用自身 Area3D 功能
	if get_parent() is BaseTrigger:
		_is_behavior = true
		monitoring = false
		monitorable = false
		return
	_setup_trigger()
	_collect_behaviors()

func _collect_behaviors() -> void:
	_behaviors.clear()
	for child in get_children():
		if child is BaseTrigger:
			_behaviors.append(child)

func _setup_trigger() -> void:
	if not _signal_connected:
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		_signal_connected = true

func _on_body_entered(body: Node3D) -> void:
	if one_shot and _used:
		if debug_mode:
			print("[BaseTrigger] ", name, " 已触发过，忽略 (one_shot)")
		return
	if require_playing and LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if not body is CharacterBody3D:
		return
	
	_used = true
	if debug_mode:
		print("[BaseTrigger] ", name, " 被触发")
	
	triggered.emit(body)
	
	## 依次调用所有子行为组件
	for behavior in _behaviors:
		if is_instance_valid(behavior):
			behavior._on_triggered(body)
	
	_on_triggered(body)

func _on_triggered(_body: Node3D) -> void:
	pass
