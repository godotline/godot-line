extends Area3D

@export var G = 9.8

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.G = G
func _ready():
	if has_node("MeshInstance3D"):
		$MeshInstance3D.queue_free()
