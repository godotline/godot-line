extends Node3D
@export var tag := 1

func _ready() -> void:
	$AnimationPlayer.play("RESET")

func _process(_delta: float) -> void:
	if State.line_crossing_crown >= tag and tag >= 1 and tag <= 3:
		if State.crowns[tag - 1] == 1:
			$AnimationPlayer.play("crown_change")
			await $AnimationPlayer.animation_finished
			tag = 0
