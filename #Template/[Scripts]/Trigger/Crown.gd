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
	State.main_line_transform = main_line.transform
	var camera_follower := _get_camera_follower()
	if camera_follower:
		State.camera_follower_add_position = camera_follower.add_position
		State.camera_follower_rotation_offset = camera_follower.rotation_offset
		State.camera_follower_distance = camera_follower.distance_from_object
		State.camera_follower_follow_speed = camera_follower.follow_speed
		State.camera_follower_has_checkpoint = true
	State.is_turn = main_line.is_turn
	if main_line.animation_node and main_line.animation_node.current_animation:
		State.anim_time = main_line.animation_node.current_animation_position
	
	State.line_crossing_crown = tag
	if tag >= 1 and tag <= 3:
		State.crowns[tag - 1] = 1
	# 记录音乐检查点时间
	var music_player := main_line.get_node("MusicPlayer") as AudioStreamPlayer
	if music_player and music_player.playing:
		State.music_checkpoint_time = music_player.get_playback_position()
	$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
	queue_free()
