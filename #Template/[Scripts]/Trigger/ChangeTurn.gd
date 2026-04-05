@tool
extends BaseTrigger
## ChangeTurnTrigger - 转向改变触发器
## 当玩家进入时切换其转向状态

func _on_triggered(body: Node3D) -> void:
	# 检查 body 是否有 is_turn 属性
	if "is_turn" in body:
		body.is_turn = not body.is_turn
