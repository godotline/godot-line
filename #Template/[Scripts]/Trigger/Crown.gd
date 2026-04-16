extends Checkpoint

@export var tag := 1

func _process(delta: float) -> void:
	$Crown.rotate_y(delta)
func _on_Crown_body_entered(_line) -> void:
	State.line_crossing_crown = tag
	if State.line_crossing_crown >= 1 and State.line_crossing_crown <= 3:
		State.crowns[State.line_crossing_crown - 1] = 1
	$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
	$Crown.visible = false
