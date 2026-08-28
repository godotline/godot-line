extends Node
## ChangeDirection - 方向改变触发器
## 当玩家进入时切换方向或转向

enum ChangeType {
	Direction,  # 设置方向
	Turn        # 立即转向
}

@export var type: ChangeType = ChangeType.Direction

@export var firstDirection: Vector3 = Vector3(0, 90, 0)
@export var secondDirection: Vector3 = Vector3.ZERO

func trigger(body: Node3D) -> bool:
	if not body is CharacterBody3D:
		return
	
	match type:
		ChangeType.Direction:
			if "firstDirection" in body:
				body.firstDirection = firstDirection
			if "secondDirection" in body:
				body.secondDirection = secondDirection
		ChangeType.Turn:
			if body.has_method("Turn"):
				body.Turn()