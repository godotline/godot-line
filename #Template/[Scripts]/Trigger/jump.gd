@tool
extends Node3D
signal height_changed(new_height: float)

@export var height: float = 1.0:
	set(value):
		height = value
		height_changed.emit(value)
		if Engine.is_editor_hint():
			_update_predictor()

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_predictor()

## 由父节点 BaseTrigger 调用的入口方法
func trigger(body: Node3D) -> void:
	var character := body as CharacterBody3D
	if character:
		var jump_speed = sqrt(2 * 9.8 * height)
		character.velocity += Vector3(0, jump_speed, 0)
		if Player.instance and Player.instance.has_signal("on_player_jump"):
			Player.instance.on_player_jump.emit()

## 通知子 JumpPredictor/FallPredictor 刷新预览
func _update_predictor() -> void:
	for child in get_children():
		if child is JumpPredictor:
			child._redraw()
		if child is FallPredictor:
			child._draw_line()
