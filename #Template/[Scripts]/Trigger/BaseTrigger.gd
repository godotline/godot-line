extends Area3D
class_name BaseTrigger

signal triggered(body: Node3D)

@export_group("触发器设置")
@export var one_shot: bool = false

@export_group("调试设置")
@export var debug_mode: bool = false

var _used: bool = false
var _signal_connected: bool = false

func _ready() -> void:
	_setup_trigger()

func _setup_trigger() -> void:
	if not _signal_connected:
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		_signal_connected = true

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if one_shot and _used:
			if debug_mode:
				print("[BaseTrigger] ", name, " 已触发过，忽略 (one_shot)")
			return
		_used = true
		
		if debug_mode:
			print("[BaseTrigger] ", name, " 被触发")
		triggered.emit(body)
		_on_triggered(body)

func _on_triggered(_body: Node3D) -> void:
	pass