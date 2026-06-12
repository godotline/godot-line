@tool
extends BaseTrigger
## @deprecated: 推荐使用 ChangeTurnBehavior 作为 BaseTrigger 的子节点
## ChangeTurnTrigger - 转向改变触发器（向后兼容包装）

func _on_triggered(body: Node3D) -> void:
	# 检查 body 是否有 _currentDirection 属性
	if "_currentDirection" in body:
		body._currentDirection = 1 - body._currentDirection
	if "is_turn" in body:
		body.is_turn = body._currentDirection == 1
