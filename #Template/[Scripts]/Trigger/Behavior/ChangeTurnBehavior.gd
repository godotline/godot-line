@tool
extends TriggerBehavior
class_name ChangeTurnBehavior

## ChangeTurnBehavior - 转向改变行为组件
## 当父 BaseTrigger 被触发时切换玩家转向状态

## 记录原始方向用于 revive 恢复
var _original_direction: int = 0
var _original_is_turn: bool = false

func _on_triggered(body: Node3D) -> void:
	# 检查 body 是否有 _currentDirection 属性
	if "_currentDirection" in body:
		_original_direction = body._currentDirection
		_original_is_turn = body.is_turn if "is_turn" in body else false
		body._currentDirection = 1 - body._currentDirection
	if "is_turn" in body:
		body.is_turn = body._currentDirection == 1
	_register_revive()

func _on_revive() -> void:
	var player := Player.instance
	if player and "_currentDirection" in player:
		player._currentDirection = _original_direction
		player.is_turn = _original_is_turn
