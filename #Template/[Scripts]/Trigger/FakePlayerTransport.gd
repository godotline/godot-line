@tool
class_name FakePlayerTransport
extends Node3D

## 假线传送组件 — 由父级 BaseTrigger 在玩家进入时调用。

enum TransportType {
	Transform,
	Vector3
}

@export var fakePlayer: FakePlayer
@export var tpToPlayer: bool = false
@export var offset: Vector3 = Vector3.ZERO
@export var transportType: TransportType = TransportType.Transform
@export var target: Node3D

@export var transport_position: Vector3 = Vector3.ZERO

func trigger(body: Node3D) -> void:
	if not fakePlayer or not body is CharacterBody3D:
		return

	if tpToPlayer:
		_set_fake_player_position(body.global_position + offset)
	else:
		match transportType:
			TransportType.Transform:
				if target:
					_set_fake_player_position(target.global_position)
			TransportType.Vector3:
				_set_fake_player_position(transport_position)

func _set_fake_player_position(value: Vector3) -> void:
	if fakePlayer.has_method("set_world_position"):
		fakePlayer.set_world_position(value)
	else:
		fakePlayer.global_position = value