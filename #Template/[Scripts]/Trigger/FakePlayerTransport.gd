@tool
class_name FakePlayerTransport
extends Area3D

## 假线传送触发器 — 当玩家进入时传送 FakePlayer（与 Unity FakePlayerTransport.cs 一致）

enum TransportType {
	Transform,
	Vector3
}

@export var fakePlayer: FakePlayer
@export var tpToPlayer: bool = false
@export var offset: Vector3 = Vector3.ZERO
@export var transportType: TransportType = TransportType.Transform
@export var target: Node3D
@export var position: Vector3 = Vector3.ZERO

var _connected: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if not _connected:
		body_entered.connect(_on_body_entered)
		_connected = true

func _on_body_entered(body: Node3D) -> void:
	if not fakePlayer or not body is CharacterBody3D:
		return

	if tpToPlayer:
		fakePlayer.global_position = body.global_position + offset
	else:
		match transportType:
			TransportType.Transform:
				if target:
					fakePlayer.global_position = target.global_position
			TransportType.Vector3:
				fakePlayer.global_position = position
