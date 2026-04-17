extends BaseTrigger

@export var Offset: Vector3 = Vector3(0, 0, 0)
var _camera_follower: Node3D = null

func _on_triggered(body: Node3D) -> void:
	if not body:
		return
	
	var game_manager := get_tree().current_scene as GameManager
	_camera_follower = game_manager.get_camera_follower() if game_manager else null
	
	#body.allowTurn = false
	if _camera_follower:
		var direction = (body.global_position - _camera_follower.global_position).normalized()
		var target_rot = Vector3(
			-45.0,
			rad_to_deg(atan2(-direction.x, -direction.z)),
			0.0
		)
		_camera_follower.lerp_to(_camera_follower.position + Offset, target_rot, 0.1)
	$AnimationPlayer.play("jinzita")
	body.look_at(to_global(self.position))
	var angle_deg = rad_to_deg(body.rotation.y)
	var rounded_angle_deg = round(angle_deg / 5.0) * 5.0
	body.rotation.y = deg_to_rad(rounded_angle_deg)
	body.rot=body.rotation.y
	body.tailScale=0
	body.turn()
	body.is_end = true