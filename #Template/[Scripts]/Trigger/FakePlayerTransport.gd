@tool
class_name FakePlayerTransport
extends Area3D

## 假线传送触发器 — 当玩家进入时传送 FakePlayer（与 Unity FakePlayerTransport.cs 一致）

enum TransportMode {
	Transform,
	Vector3
}

@export var fakePlayer: FakePlayer
@export var tpToPlayer: bool = false
@export var offset: Vector3 = Vector3.ZERO
@export var transportMode: TransportMode = TransportMode.Transform
@export var targetNode: Node3D
@export var targetPosition: Vector3 = Vector3.ZERO

var _connected: bool = false

func _ready() -> void:
	if not _connected:
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		_connected = true

func _on_body_entered(body: Node3D) -> void:
	if not fakePlayer or not body is CharacterBody3D:
		return

	if tpToPlayer:
		fakePlayer.global_position = body.global_position + offset
	else:
		match transportMode:
			TransportMode.Transform:
				if targetNode:
					fakePlayer.global_position = targetNode.global_position
			TransportMode.Vector3:
				fakePlayer.global_position = targetPosition
