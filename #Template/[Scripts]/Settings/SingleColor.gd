@tool
class_name SingleColor
extends Resource

## 单颜色配置类

@export var material: Material
@export var color: Color = Color.WHITE
@export var has_emission: bool = false
@export var intensity: float = 0.0

func apply() -> void:
	if material:
		material.albedo_color = color
		if has_emission and material is StandardMaterial3D:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = intensity


func apply_tweened(node: Node, duration: float, trans_type: int = 0, ease_type: int = 0) -> void:
	if not material:
		return
	var tween: Tween = node.create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(trans_type)
	tween.tween_property(material, "albedo_color", color, duration)
	if has_emission and material is StandardMaterial3D:
		material.emission_enabled = true
		tween.tween_property(material, "emission", color, duration)
		tween.parallel().tween_property(material, "emission_energy_multiplier", intensity, duration)
