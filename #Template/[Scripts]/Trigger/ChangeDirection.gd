extends Node
## ChangeDirection - 方向改变触发器
## 当玩家进入时切换方向或转向

enum ChangeType {
	Direction,  # 设置方向
	Turn        # 立即转向
}

@export_group("设置")
@export var type: ChangeType = ChangeType.Direction

@export_group("Direction 模式")
@export var first_direction: Vector3 = Vector3(0, 90, 0)
@export var second_direction: Vector3 = Vector3.ZERO

func trigger(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	
	match type:
		ChangeType.Direction:
			if "firstDirection" in body:
				body.firstDirection = first_direction
			if "secondDirection" in body:
				body.secondDirection = second_direction
		ChangeType.Turn:
			if body.has_method("turn"):
				body.turn()
