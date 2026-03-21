extends Area3D

@export var speed := 1.0
@export var tag := 1

func _get_camera_follower() -> Node3D:
	var current_scene := get_tree().current_scene
	if not current_scene:
		return null

	var follower = current_scene.get_node_or_null("%CameraFollower") as Node3D
	if follower:
		return follower

	follower = current_scene.find_child("CameraFollower", true, false) as Node3D
	if follower:
		return follower

	return current_scene.find_child("BaseCam", true, false) as Node3D

#皇冠旋转
func _process(delta: float) -> void:
	rotate_y(delta * speed)
#玩家碰皇冠事件
func _on_Crown_body_entered(main_line: PhysicsBody3D) -> void:
	State.crown += 1
	State.main_line_transform = main_line.transform
	var camera_follower := _get_camera_follower()
	if camera_follower:
		State.camera_follower_has_checkpoint = true
		if "add_position" in camera_follower:
			State.camera_follower_add_position = camera_follower.add_position
		if "rotation_offset" in camera_follower:
			State.camera_follower_rotation_offset = camera_follower.rotation_offset
		if "distance_from_object" in camera_follower:
			State.camera_follower_distance = camera_follower.distance_from_object
		if "follow_speed" in camera_follower:
			State.camera_follower_follow_speed = camera_follower.follow_speed
	if "is_turn" in main_line:
		State.is_turn = main_line.is_turn
	if "animation_node" in main_line and main_line.animation_node and main_line.animation_node.current_animation:
		State.anim_time = main_line.animation_node.current_animation_position
	State.line_crossing_crown = tag
	$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
	queue_free()
