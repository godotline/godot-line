@tool
extends BaseTrigger
## ChangeSpeedTrigger - 速度改变触发器
## 当玩家进入时改变其移动速度

@export var new_speed: float = 12.0

func _on_triggered(body: Node3D) -> void:
	# 检查 body 是否有 speed 属性
	if "speed" in body:
		body.speed = new_speed
		# 立即更新速度向量（如果玩家已开始移动）
		if "is_start" in body and body.is_start:
			body.v = body.to_global(Vector3(0, 0, -1) * new_speed) - body.position
