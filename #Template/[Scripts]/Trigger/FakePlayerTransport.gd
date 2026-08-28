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

func trigger(body: Node3D) -> bool:
	if not fakePlayer or not body is CharacterBody3D:
		return false
	if tpToPlayer:
		_set_fake_player_position(body.global_position + offset)
	else:
		match transportType:
			TransportType.Transform:
				if target:
					_set_fake_player_position(target.global_position)
			TransportType.Vector3:
				_set_fake_player_position(transport_position)
	return true

func _set_fake_player_position(value: Vector3) -> void:
	fakePlayer.set_world_position(value)