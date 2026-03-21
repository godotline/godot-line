extends Area3D

func _ready():
	if bool(State.get("is_restoring_checkpoint")):
		return
	monitoring = true
	$CollisionShape3D/MeshInstance3D.visible = false

func _on_body_entered_jinzita(body: Node3D) -> void:
	if body is CharacterBody3D:
		$AnimationPlayer.play("jinzita")
		body.look_at(-to_global(self.position))
		body.rot=body.rotation.y
		body.tailScale=0
		body.turn()
		State.is_end = true
