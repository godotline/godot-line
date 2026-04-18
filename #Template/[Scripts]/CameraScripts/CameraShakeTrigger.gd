extends Area3D
class_name CameraShakeTrigger

@export var power: float = 1.0
@export var duration: float = 2.0

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var follower = CameraFollower.instance
		if follower:
			follower.do_shake(power, duration)
