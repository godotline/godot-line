extends BaseTrigger

@export var Offset: Vector3 = Vector3(0, 0, 0)
var _camera_follower: Node3D = null

func _on_triggered(body: Node3D) -> void:
	if not body:
		return
	
	_camera_follower = CameraFollower.instance
	
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
	var face_dir = Vector3(0, rounded_angle_deg, 0)
	body.firstDirection = face_dir
	body.secondDirection = face_dir
	body.tailScale = 0
	body.turn()
	body.is_end = true
	body.allowTurn = false
