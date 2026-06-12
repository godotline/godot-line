@tool
extends TriggerBehavior
class_name ChangeSpeedBehavior

## ChangeSpeedBehavior - 速度改变行为组件
## 当父 BaseTrigger 被触发时改变玩家移动速度

@export var new_speed: float = 12.0

## 原始速度，用于 revive 恢复
var _original_speed: float = 12.0

func _on_triggered(body: Node3D) -> void:
	if "speed" in body:
		_original_speed = body.speed
		body.speed = new_speed
		# 同步更新当前速度向量，使速度变化立即生效
		if body is CharacterBody3D:
			var current_vel: Vector3 = body.velocity
			var horizontal := Vector3(current_vel.x, 0.0, current_vel.z)
			if horizontal.length() > 0.01:
				var direction := horizontal.normalized()
				body.velocity = direction * new_speed + Vector3(0.0, current_vel.y, 0.0)
		_register_revive()

func _on_revive() -> void:
	var player := Player.instance
	if player:
		player.speed = _original_speed
