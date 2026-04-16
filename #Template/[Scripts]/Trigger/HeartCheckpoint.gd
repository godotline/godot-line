extends Checkpoint

func _on_Crown_body_entered(_line) -> void:
	$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
	queue_free()
