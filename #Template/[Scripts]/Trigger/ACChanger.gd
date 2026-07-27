extends Node3D

@export var ambient_color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export_range(0.0, 60.0, 0.05) var duration: float = 1.0

func trigger(body: Node3D) -> void:
	if not body is Player:
		return
	var environment: Environment = (body as Player).get_scene_environment()
	if not environment:
		return
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	create_tween().tween_property(environment, "ambient_light_color", ambient_color, duration)
