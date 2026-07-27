class_name AmbientSettings
extends Resource

enum EnvironmentLightingType { Skybox, Color, Gradient }

@export var lighting_type: EnvironmentLightingType = EnvironmentLightingType.Color
@export_range(0.0, 8.0) var intensity: float = 1.0
@export var ambient_color: Color = Color(0.67, 0.67, 0.67)
@export var sky_color: Color = Color(0.67, 0.67, 0.67)
@export var equator_color: Color = Color(0.114, 0.125, 0.133)
@export var ground_color: Color = Color(0.047, 0.043, 0.035)

func apply(environment: Environment) -> void:
	if not environment:
		return
	match lighting_type:
		EnvironmentLightingType.Skybox:
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		EnvironmentLightingType.Color, EnvironmentLightingType.Gradient:
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = intensity
	match lighting_type:
		EnvironmentLightingType.Color:
			environment.ambient_light_color = ambient_color
		EnvironmentLightingType.Gradient:
			environment.ambient_light_sky_color = sky_color
			environment.ambient_light_horizon_color = equator_color
			environment.ambient_light_ground_color = ground_color

func apply_tweened(node: Node, duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	var environment: Environment = _get_environment(node)
	if not environment:
		return
	match lighting_type:
		EnvironmentLightingType.Skybox:
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		EnvironmentLightingType.Color, EnvironmentLightingType.Gradient:
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var tween: Tween = node.create_tween().set_trans(trans_type).set_ease(ease_type)
	tween.tween_property(environment, "ambient_light_energy", intensity, duration)
	match lighting_type:
		EnvironmentLightingType.Color:
			tween.parallel().tween_property(environment, "ambient_light_color", ambient_color, duration)
		EnvironmentLightingType.Gradient:
			tween.parallel().tween_property(environment, "ambient_light_sky_color", sky_color, duration)
			tween.parallel().tween_property(environment, "ambient_light_horizon_color", equator_color, duration)
			tween.parallel().tween_property(environment, "ambient_light_ground_color", ground_color, duration)

static func _get_environment(node: Node) -> Environment:
	if Player.instance:
		var player_environment: Environment = Player.instance.get_scene_environment()
		if player_environment:
			return player_environment
	return node.get_viewport().get_world_3d().environment
