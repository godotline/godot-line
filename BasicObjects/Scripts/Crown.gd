extends Area3D

@export var speed := 1.0
@export var tag := 1

#皇冠旋转
func _process(delta: float) -> void:
	rotate_y(delta * speed)
#玩家碰皇冠事件
func _on_Crown_body_entered(main_line: PhysicsBody3D) -> void:
	State.crown += 1
	var current_is_turn := false
	if "is_turn" in main_line:
		current_is_turn = main_line.is_turn
	State.save_checkpoint(main_line.transform, current_is_turn, tag)
	var root := get_tree().current_scene
	if is_instance_valid(root):
		var removed_path := root.get_path_to(self)
		State.save_scene_checkpoint(root, [str(removed_path)])
	$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
	queue_free()
