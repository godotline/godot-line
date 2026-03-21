extends Area3D

@export var new_speed: float = 12.0
@export var one_shot: bool = true

var used: bool = false

func _ready() -> void:
	# Hide the visual mesh in game
	if has_node("MeshInstance3D"):
		$MeshInstance3D.visible = false

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if one_shot and used:
			return
		body.speed = new_speed
		# 立即更新速度向量
		if body.is_start:
			body.v = body.to_global(Vector3(0,0,-1) * new_speed) - body.position
		if one_shot:
			used = true
