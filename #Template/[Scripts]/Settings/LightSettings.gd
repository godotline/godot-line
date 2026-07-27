class_name LightSettings
extends Resource

@export var rotation: Vector3 = Vector3.ZERO
@export var color: Color = Color.WHITE
@export var intensity: float = 1.0
@export_range(0.0, 1.0) var shadow_strength: float = 0.8

func apply(light: DirectionalLight3D) -> void:
	if not light:
		return
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = intensity
	# Godot 4 exposes shadow enablement, but not Unity's shadow opacity.
	light.shadow_enabled = shadow_strength > 0.0

func apply_tweened(light: DirectionalLight3D, duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if not light:
		return
	var tween: Tween = light.create_tween().set_trans(trans_type).set_ease(ease_type)
	tween.tween_property(light, "rotation_degrees", rotation, duration)
	tween.parallel().tween_property(light, "light_color", color, duration)
	tween.parallel().tween_property(light, "light_energy", intensity, duration)
	light.shadow_enabled = shadow_strength > 0.0
