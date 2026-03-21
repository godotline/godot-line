extends Node3D
@export var target: CharacterBody3D
var originpos

func _ready() -> void:
	if bool(State.get("is_restoring_checkpoint")):
		return
	originpos = rotation

func _process(delta: float) -> void:
	var target_position = Vector3(global_position.x,global_position.y,target.position.z)
	look_at(target_position, Vector3.UP)
	rotation += originpos
