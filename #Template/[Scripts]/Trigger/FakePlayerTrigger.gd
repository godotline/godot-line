@tool
class_name FakePlayerTrigger
extends Node

## 假线控制触发器组件 — Turn / ChangeDirection / SetState。
## 作为 BaseTrigger 的子节点使用，由父节点负责碰撞检测。

enum SetType {
	Turn,
	ChangeDirection,
	SetState
}

@export var targetPlayer: FakePlayer
@export var type: SetType = SetType.Turn
@export var firstDirection: Vector3 = Vector3(0, 90, 0)
@export var secondDirection: Vector3 = Vector3.ZERO
@export var state: FakePlayer.State = FakePlayer.State.Moving

var used: bool = false
var index: int = 0
var container: BaseTrigger

func _ready() -> void:
	pass


## 由父节点 BaseTrigger 调用的入口方法。
func trigger(other: Node3D) -> bool:
	if not targetPlayer:
		return false

	var isPlayer: bool = other is Player
	var fakeBody: FakePlayer = _find_fake_player(other)
	var isFakePlayer: bool = fakeBody != null
	var isObstacle: bool = other.is_in_group("obstacle")

	# ChangeDirection 和 SetState 由真实玩家触发。
	if isPlayer:
		match type:
			SetType.ChangeDirection:
				targetPlayer.firstDirection = firstDirection
				targetPlayer.secondDirection = secondDirection

			SetType.SetState:
				targetPlayer.state = state
				targetPlayer.playing = (state == FakePlayer.State.Moving)

	# Turn 由假线或障碍物触发。
	if isFakePlayer or isObstacle:
		if type == SetType.Turn and not used:
			index = LevelManager.checkpointCount
			LevelManager.add_revive_listener(_reset_data)
			targetPlayer.Turn()
			used = true
		return true

	if isPlayer:
		return true
	
	return false

func _find_fake_player(other: Node3D) -> FakePlayer:
	if other.is_in_group("FakePlayer"):
		for child: Node in other.get_children():
			var component: FakePlayer = child as FakePlayer
			if component:
				return component
	return null

func _reset_data() -> void:
	LevelManager.remove_revive_listener(_reset_data)
	LevelManager.CompareCheckpointIndex(index, func() -> void:
		used = false
	)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_reset_data)
