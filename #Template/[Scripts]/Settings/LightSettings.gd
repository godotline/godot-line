class_name LightSettings
extends Resource

@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees,or_greater,or_less") var rotation: Vector3 = Vector3.ZERO
@export var color: Color = Color.WHITE
@export var intensity: float = 1.0
@export_range(0.0, 1.0) var shadowStrength: float = 0.8

func apply(light: DirectionalLight3D) -> void:
	if not light:
		return
	light.rotation = rotation
	light.light_color = color
	light.light_energy = intensity
	# Godot 4 exposes shadow enablement, but not Unity's shadow opacity.
	light.shadow_enabled = shadowStrength > 0.0

func apply_tweened(light: DirectionalLight3D, duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if not light:
		return
	var tween: Tween = light.create_tween().set_trans(trans_type).set_ease(ease_type)
	tween.tween_property(light, "rotation", rotation, duration)
	tween.parallel().tween_property(light, "light_color", color, duration)
	tween.parallel().tween_property(light, "light_energy", intensity, duration)
	light.shadow_enabled = shadowStrength > 0.0
