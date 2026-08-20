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
	if Engine.is_editor_hint():
		return

	container = get_parent() as BaseTrigger
	if container and not container.body_entered.is_connected(_on_container_body_entered):
		container.body_entered.connect(_on_container_body_entered)

## BaseTrigger 默认只分发 CharacterBody3D；FakePlayer 尾线使用 StaticBody3D，
## 因此在本组件内补充静态障碍物这一种专用输入。
func _on_container_body_entered(body: Node3D) -> void:
	if body is StaticBody3D or _find_fake_player(body) != null:
		trigger(body)

## 由父节点 BaseTrigger 调用的入口方法。
func trigger(body: Node3D) -> void:
	if not targetPlayer:
		return

	var isPlayer: bool = body is Player
	var fakeBody: FakePlayer = _find_fake_player(body)
	var isFakePlayer: bool = fakeBody != null
	var isObstacle: bool = body.is_in_group("obstacle")

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

func _find_fake_player(body: Node3D) -> FakePlayer:
	var directComponent: FakePlayer = body as FakePlayer
	if directComponent:
		return directComponent
	for child: Node in body.get_children():
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
	if container and is_instance_valid(container):
		if container.body_entered.is_connected(_on_container_body_entered):
			container.body_entered.disconnect(_on_container_body_entered)
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_reset_data)
