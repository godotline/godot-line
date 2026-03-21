extends Node3D
@export var target: CharacterBody3D
var originpos

func _ready() -> void:
	originpos = rotation

func _process(delta: float) -> void:
	var target_position = target.global_position
	look_at(target_position, Vector3.UP)
	rotation += originpos
