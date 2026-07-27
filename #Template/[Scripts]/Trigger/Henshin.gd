extends Node3D

## Switches the player to a scene-authored alternative visual.
enum Facing { DontChange, FirstDirection, SecondDirection }

@export var enable_henshin: bool = true
@export var henshin_object: Node3D
@export var object_offset: Vector3 = Vector3.ZERO
@export var show_line_tail: bool = true
@export var show_line_body: bool = true
@export_range(0.0, 10.0, 0.05) var animation_time: float = 0.0
@export var facing: Facing = Facing.DontChange

func trigger(body: Node3D) -> void:
	var player: Player = body as Player
	if not player:
		return
	if not enable_henshin:
		player.reset_henshin_state()
		return
	player.enable_henshin(henshin_object, object_offset, show_line_tail, show_line_body, animation_time)
	match facing:
		Facing.FirstDirection:
			henshin_object.rotation_degrees = player.firstDirection if henshin_object else Vector3.ZERO
		Facing.SecondDirection:
			henshin_object.rotation_degrees = player.secondDirection if henshin_object else Vector3.ZERO
