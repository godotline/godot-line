extends Area3D

@export var camera_parent: Node3D  # 这是Camera3D的父节点
@export var shake_intensity: float = 0.5
@export var shake_duration: float = 0.3

var shake_timer: float = 0.0
var original_position: Vector3

func _ready():
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	body_entered.connect(_on_body_entered)
	$MeshInstance3D.queue_free()

func _process(delta):
	if shake_timer > 0 and camera_parent:
		shake_timer -= delta

		if shake_timer <= 0:
			camera_parent.position = original_position
		else:
			var shake_offset = Vector3(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
			camera_parent.position = original_position + shake_offset

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if camera_parent:
			original_position = camera_parent.position
			shake_timer = shake_duration
		else:
			print("Camera parent未指定")
