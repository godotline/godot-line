@tool
extends Node3D
## ChangeSpeedTrigger - 速度改变触发器
## 当玩家进入时改变其移动速度

@export var new_speed: float = 12.0

func trigger(body: Node3D) -> void:
	if "speed" in body:
		body.speed = new_speed
		# 同步更新当前速度向量，使速度变化立即生效
		if body is CharacterBody3D:
			var current_vel: Vector3 = body.velocity
			var horizontal: Vector3 = Vector3(current_vel.x, 0.0, current_vel.z)
			if horizontal.length() > 0.01:
				var direction: Vector3 = horizontal.normalized()
				body.velocity = direction * new_speed + Vector3(0.0, current_vel.y, 0.0)
