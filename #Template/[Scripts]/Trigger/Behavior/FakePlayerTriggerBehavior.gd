@tool
extends TriggerBehavior
class_name FakePlayerTriggerBehavior

## FakePlayerTriggerBehavior - 假线控制行为组件
## 当父 BaseTrigger 被触发时控制 FakePlayer 的状态/方向/Turn

enum SetType {
	Turn,             ## 转向
	ChangeDirection,  ## 改变方向
	SetState          ## 设置状态
}

@export var target_player: FakePlayer
@export var type: SetType = SetType.Turn
@export var first_direction: Vector3 = Vector3(0, 90, 0)
@export var second_direction: Vector3 = Vector3.ZERO
@export var target_state: FakePlayer.State = FakePlayer.State.Moving

var _used: bool = false

func _on_triggered(body: Node3D) -> void:
	if not target_player:
		return

	var is_player := body is Player
	var is_fake_player := body is FakePlayer
	var is_obstacle := body.is_in_group("obstacle")

	# ChangeDirection 和 SetState 由真实玩家触发
	if is_player:
		match type:
			SetType.ChangeDirection:
				target_player.firstDirection = first_direction
				target_player.secondDirection = second_direction

			SetType.SetState:
				target_player.state = target_state
				target_player.playing = target_state == FakePlayer.State.Moving

	# Turn 由假线或障碍物触发
	if is_fake_player or is_obstacle:
		match type:
			SetType.Turn:
				if not _used:
					target_player.turn()
					_used = true
					_register_revive()

func _on_revive() -> void:
	_used = false
