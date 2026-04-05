@tool
extends BaseTrigger
## JumpTrigger - 跳跃触发器
## 当玩家进入时给予垂直方向的速度跳跃

@export var height: float = 1.0

func _on_triggered(body: Node3D) -> void:
	var character := body as CharacterBody3D
	if character:
		var jump_speed = sqrt(2 * 9.8 * height)
		character.velocity += jump_speed * Vector3.UP
