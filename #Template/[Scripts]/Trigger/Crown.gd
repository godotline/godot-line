extends Area3D

@export var speed := 1.0
@export var tag := 1

func _get_camera_follower() -> Node3D:
	var game_manager := get_tree().current_scene
	if game_manager and game_manager.Camera:
		return game_manager.Camera.get_parent() as Node3D
	return null

#皇冠旋转
func _process(delta: float) -> void:
	rotate_y(delta * speed)
#玩家碰皇冠事件
func _on_Crown_body_entered(main_line: PhysicsBody3D) -> void:
	State.crown += 1
	State.save_checkpoint(main_line, _get_camera_follower(), tag)
	$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
	queue_free()
