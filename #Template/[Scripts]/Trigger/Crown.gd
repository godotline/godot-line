extends Area3D

var speed := 1.0
@export var tag := 1

func _ready() -> void:
	$RevivePos.visible = false
func _get_camera_follower() -> Node3D:
	var game_manager := get_tree().current_scene
	if game_manager and game_manager.Camera:
		return game_manager.Camera.get_parent() as Node3D
	return null
func _process(delta: float) -> void:
	$Crown.rotate_y(delta * speed)
func _on_Crown_body_entered(main_line) -> void:
	State.crown += 1
	State.save_checkpoint(main_line, _get_camera_follower(), tag, $RevivePos)
	$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
	$Crown.visible = false
