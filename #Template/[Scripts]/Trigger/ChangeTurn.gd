@tool
extends BaseTrigger
## ChangeTurnTrigger - 转向改变触发器
## 当玩家进入时切换其转向状态

func _on_triggered(body: Node3D) -> void:
	# 检查 body 是否有 _currentDirection 属性
	if "_currentDirection" in body:
		body._currentDirection = 1 - body._currentDirection
	if "is_turn" in body:
		body.is_turn = body._currentDirection == 1
