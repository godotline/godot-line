extends Node3D
func _ready() -> void:
	$"..".visible = true

func _on_taper_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
			body.turn()
			$"../AnimationPlayer".play("taper")
			await $"../AnimationPlayer".animation_finished
			$"..".visible = false
