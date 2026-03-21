extends Node3D
@export var tag := 1
var change := false

func _process(delta: float) -> void:
	if State.line_crossing_crown == tag and change == false:
		change = true
		$AnimationPlayer.play("crown_change")
