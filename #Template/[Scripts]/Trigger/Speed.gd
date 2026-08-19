extends Node
## ChangeSpeedTrigger - 速度改变触发器
## 当玩家进入时改变其移动速度

@export var speed: float = 12.0

func trigger(body: Node3D) -> void:
	if "speed" in body:
		body.Speed = speed
		# 同步更新当前速度向量，使速度变化立即生效
		if body is CharacterBody3D:
			var currentVel: Vector3 = body.velocity
			var horizontal: Vector3 = Vector3(currentVel.x, 0.0, currentVel.z)
			if horizontal.length() > 0.01:
				var direction: Vector3 = horizontal.normalized()
				body.velocity = direction * speed + Vector3(0.0, currentVel.y, 0.0)