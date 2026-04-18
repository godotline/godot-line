extends Checkpoint

@export var tag := 1

func _process(delta: float) -> void:
	$Crown.rotate_y(delta)
func _on_Crown_body_entered(_line) -> void:
	LevelManager.line_crossing_crown = tag
	if LevelManager.line_crossing_crown >= 1 and LevelManager.line_crossing_crown <= 3:
		LevelManager.crowns[LevelManager.line_crossing_crown - 1] = 1
	$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
	$Crown.visible = false
