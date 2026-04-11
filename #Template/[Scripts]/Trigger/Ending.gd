extends Area3D

func _ready():
	monitoring = true

func _on_body_entered_jinzita(body: Node3D) -> void:
	if body is CharacterBody3D:
		$AnimationPlayer.play("jinzita")
		body.look_at(to_global(self.position))
		# 将旋转角度整除5取整
		var angle_deg = rad_to_deg(body.rotation.y)
		var rounded_angle_deg = round(angle_deg / 5.0) * 5.0
		body.rotation.y = deg_to_rad(rounded_angle_deg)
		body.rot=body.rotation.y
		body.tailScale=0
		body.turn()
		State.is_end = true
