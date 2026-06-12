@tool
class_name FakePlayerTrigger
## @deprecated: 此脚本保持向后兼容
## FakePlayerTrigger - 假线控制触发器（向后兼容包装）
extends Area3D

## 假线控制触发器 — Turn / ChangeDirection / SetState（与 Unity FakePlayerTrigger.cs 一致）

enum SetType {
	Turn,
	ChangeDirection,
	SetState
}

@export var targetPlayer: FakePlayer
@export var type: SetType = SetType.Turn
@export var firstDirection: Vector3 = Vector3(0, 90, 0)
@export var secondDirection: Vector3 = Vector3.ZERO
@export var targetState: FakePlayer.State = FakePlayer.State.Moving

var _used: bool = false
var _index: int = 0
var _connected: bool = false

func _ready() -> void:
	if not _connected:
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		_connected = true

func _on_body_entered(body: Node3D) -> void:
	if not targetPlayer:
		return

	var is_player := body is Player
	var is_fake_player := body is FakePlayer
	var is_obstacle := body.is_in_group("obstacle")

	# ChangeDirection 和 SetState 由真实玩家触发
	if is_player:
		match type:
			SetType.ChangeDirection:
				targetPlayer.firstDirection = firstDirection
				targetPlayer.secondDirection = secondDirection

			SetType.SetState:
				targetPlayer.state = targetState
				targetPlayer.playing = targetState == FakePlayer.State.Moving

	# Turn 由假线或障碍物触发
	if is_fake_player or is_obstacle:
		match type:
			SetType.Turn:
				if not _used:
					_index = LevelManager.checkpoint_count
					LevelManager.add_revive_listener(_reset_data)
					targetPlayer.turn()
					_used = true

func _reset_data() -> void:
	LevelManager.remove_revive_listener(_reset_data)
	if _index < LevelManager.checkpoint_count:
		_used = false

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_reset_data)
