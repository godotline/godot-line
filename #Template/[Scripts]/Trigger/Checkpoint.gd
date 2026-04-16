extends Area3D
class_name Checkpoint

@export var RevivePosition: Node3D

func _ready() -> void:
	$RevivePosition.visible = false
	if not body_entered.is_connected(_on_checkpoint_body_entered):
		body_entered.connect(_on_checkpoint_body_entered)

func _get_camera_follower() -> Node3D:
	var game_manager := get_tree().current_scene
	if game_manager and game_manager.Camera:
		return game_manager.Camera.get_parent() as Node3D
	return null

func _on_checkpoint_body_entered(body: Node3D) -> void:
	State.save_checkpoint(body, _get_camera_follower(), RevivePosition)
