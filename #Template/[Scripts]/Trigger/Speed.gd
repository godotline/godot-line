extends Node
## Speed - 速度改变触发器
## 默认模式: 玩家进入时改变移动速度 (Unity Speed.cs: !setFakePlayer)
## setFakePlayer 模式: 假线/障碍物进入时改变目标 FakePlayer 的速度

@export var setFakePlayer: bool = false
@export var player: FakePlayer
@export var speed: float = 12.0

var container: BaseTrigger

func _ready() -> void:
	pass


func trigger(other: Node3D) -> bool:
	if not setFakePlayer:
		if other is Player or other.is_in_group("Player"):
			other.Speed = speed
			_sync_velocity(other)
			return true
	elif player and (_find_fake_player(other) != null or other.is_in_group("obstacle")):
		player.speed = speed
		return true
	return false

func _find_fake_player(other: Node3D) -> FakePlayer:
	if other.is_in_group("FakePlayer"):
		for child: Node in other.get_children():
			var component: FakePlayer = child as FakePlayer
			if component:
				return component
	return null

func _sync_velocity(other: CharacterBody3D) -> void:
	var currentVel: Vector3 = other.velocity
	var horizontal: Vector3 = Vector3(currentVel.x, 0.0, currentVel.z)
	if horizontal.length() > 0.01:
		var direction: Vector3 = horizontal.normalized()
		other.velocity = direction * speed + Vector3(0.0, currentVel.y, 0.0)

func _exit_tree() -> void:
	pass