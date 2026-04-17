extends Checkpoint

func _process(delta: float) -> void:
	$Rotator.rotate_y(delta)
func _on_Crown_body_entered(_line) -> void:
	if used:
		return
	$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
