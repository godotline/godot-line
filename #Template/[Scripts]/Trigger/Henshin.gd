extends Node

## Switches the player to a scene-authored alternative visual.
enum Facing { DontChange, FirstDirection, SecondDirection }

@export var enableHenshin: bool = true
@export var henshinObject: Node3D
@export var objectOffset: Vector3 = Vector3.ZERO
@export var showLineTail: bool = true
@export var showLineBody: bool = true
@export_range(0.0, 10.0, 0.05) var animationTime: float = 0.0
@export var facing: Facing = Facing.DontChange

func trigger(body: Node3D) -> void:
	var player: Player = body as Player
	if not player:
		return
	if not enableHenshin:
		player.ResetHenshinState()
		return
	player.enable_henshin(henshinObject, objectOffset, showLineTail, showLineBody, animationTime)
	match facing:
		Facing.FirstDirection:
			henshinObject.rotation_degrees = player.firstDirection if henshinObject else Vector3.ZERO
		Facing.SecondDirection:
			henshinObject.rotation_degrees = player.secondDirection if henshinObject else Vector3.ZERO
