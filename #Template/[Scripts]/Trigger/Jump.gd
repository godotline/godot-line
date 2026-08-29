@tool
extends Node
signal power_changed(new_power: float)

@export var power: float = 500.0:
	set(value):
		power = value
		power_changed.emit(value)
		if Engine.is_editor_hint():
			_update_predictor()

@export var changeDirection: bool = false  # Unity Jump.changeDirection

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_predictor()

## 由父节点 BaseTrigger 调用的入口方法
func trigger(other: Node3D) -> bool:
	var player: Player = other as Player
	if not player:
		return false
	if changeDirection:
		player.Turn()
	player.apply_impulse(Vector3(0.0, power, 0.0))
	player.emitGameEvent(7)
	return true

## 通知子 JumpPredictor/FallPredictor 刷新预览
func _update_predictor() -> void:
	for child in get_children():
		if child is JumpPredictor:
			child._redraw()
		if child is FallPredictor:
			child._draw_line()
