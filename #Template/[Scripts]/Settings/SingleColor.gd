@tool
class_name SingleColor
extends Resource

## 单颜色配置类

@export var material: Material
@export var color: Color = Color.WHITE
@export var has_emission: bool = false
@export var intensity: float = 0.0

func capture_state() -> Dictionary:
	var state: Dictionary = {}
	var base_material: BaseMaterial3D = material as BaseMaterial3D
	if not base_material:
		return state
	state["setting"] = self
	state["material"] = base_material
	state["albedo_color"] = base_material.albedo_color
	state["emission_enabled"] = base_material.emission_enabled
	state["emission"] = base_material.emission
	state["emission_energy_multiplier"] = base_material.emission_energy_multiplier
	return state

func restore_state(state: Dictionary) -> void:
	var base_material: BaseMaterial3D = state.get("material") as BaseMaterial3D
	if not base_material:
		return

	var albedo_color: Variant = state.get("albedo_color", base_material.albedo_color)
	if albedo_color is Color:
		base_material.albedo_color = albedo_color
	var emission_enabled: Variant = state.get("emission_enabled", base_material.emission_enabled)
	if emission_enabled is bool:
		base_material.emission_enabled = emission_enabled
	var emission: Variant = state.get("emission", base_material.emission)
	if emission is Color:
		base_material.emission = emission
	var emission_energy: Variant = state.get(
		"emission_energy_multiplier", base_material.emission_energy_multiplier
	)
	if emission_energy is float or emission_energy is int:
		base_material.emission_energy_multiplier = float(emission_energy)

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
