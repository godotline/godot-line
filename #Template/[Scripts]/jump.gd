@tool
extends Area3D
@export var height := 1.0

func _on_body_entered(body: PhysicsBody3D) -> void:
	if body is CharacterBody3D:
		var character := body as CharacterBody3D
		var jump_speed = sqrt(2 * 9.8 * height)
		character.velocity += jump_speed * Vector3.UP

func _ready() -> void:
	if not Engine.is_editor_hint():
		$MeshInstance3D.visible = false
