extends Node3D
@export var tag := 1

func _ready() -> void:
	$AnimationPlayer.play("RESET")

func _process(delta: float) -> void:
	if State.line_crossing_crown == tag:
		if tag == 1 and State.firstcrown == 1:
			$AnimationPlayer.play("crown_change")
			await $AnimationPlayer.animation_finished
			tag = 0
		if tag == 2 and State.secondcrown == 1:
			$AnimationPlayer.play("crown_change")
			await $AnimationPlayer.animation_finished
			tag = 0
		if tag == 3 and State.thridcrown == 1:
			$AnimationPlayer.play("crown_change")
			await $AnimationPlayer.animation_finished
			tag = 0
