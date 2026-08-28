extends Node

@export var newAmbientColor: Color = Color(0.5, 0.5, 0.5, 1.0)
@export_range(0.0, 60.0, 0.05) var duration: float = 1.0

func trigger(body: Node3D) -> bool:
	if not body is Player:
		return false
	var environment: Environment = (body as Player).get_scene_environment()
	if not environment:
		return false
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	create_tween().tween_property(environment, "ambient_light_color", newAmbientColor, duration)
	return true
