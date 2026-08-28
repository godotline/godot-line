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

func trigger(body: Node3D) -> bool:
	var player: Player = body as Player
	if not player:
		return
	if not enableHenshin:
		Player.instance.ResetHenshinState()
	else:
		Player.instance.henShin = enableHenshin
		Player.instance.henshinObject = henshinObject
		Player.instance.objectOffset = objectOffset
		Player.instance.showLineTail = showLineTail
		Player.instance.showLineBody = showLineBody
		Player.instance.rotationTime = animationTime

		if facing == Facing.FirstDirection:
			Player.instance.henshinObject.rotation_degrees = Player.instance.firstDirection
		elif facing == Facing.SecondDirection:
			Player.instance.henshinObject.rotation_degrees = Player.instance.secondDirection
