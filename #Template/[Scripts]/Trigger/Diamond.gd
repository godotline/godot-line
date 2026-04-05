@tool
extends Area3D

@export var speed := 1.0

func _on_Diamond_body_entered(_body: Node) -> void:
	State.diamond += 1
	$AnimationPlayer.play("diamond")
	$RemainParticle.emitting = true
	await $RemainParticle.finished
	queue_free()
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		rotate_y(delta * speed)
