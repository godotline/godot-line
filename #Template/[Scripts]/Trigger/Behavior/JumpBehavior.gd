@tool
extends TriggerBehavior
class_name JumpBehavior

## JumpBehavior - 跳跃行为组件
## 当父 BaseTrigger 被触发时给予玩家垂直方向的速度跳跃

signal height_changed(new_height: float)

@export var height: float = 1.0:
	set(value):
		height = value
		height_changed.emit(value)
		if Engine.is_editor_hint():
			_update_predictor()

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		_update_predictor()

func _update_predictor() -> void:
	# 信号会自动通知 JumpPredictor，不需要手动查找
	pass

func _on_triggered(body: Node3D) -> void:
	var character := body as CharacterBody3D
	if character:
		# 根据高度计算初速度: v = sqrt(2*g*h)
		var jump_speed = sqrt(2 * 9.8 * height)
		character.velocity += Vector3(0, jump_speed, 0)
		if Player.instance and Player.instance.has_signal("on_player_jump"):
			Player.instance.on_player_jump.emit()
