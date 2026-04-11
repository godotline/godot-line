extends Area3D

func _ready():
	monitoring = true

func _on_body_entered_jinzita(body: Node3D) -> void:
	if body is CharacterBody3D:
		State.is_end = true