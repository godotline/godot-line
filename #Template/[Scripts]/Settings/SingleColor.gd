@tool
class_name SingleColor
extends Resource

## 单颜色配置类

@export var material: Material
@export var color: Color = Color.WHITE
@export var hasEmission: bool = false
@export var intensity: float = 0.0

func capture_state() -> Dictionary:
	var state: Dictionary = {}
	var baseMaterial: BaseMaterial3D = material as BaseMaterial3D
	if not baseMaterial:
		return state
	state["setting"] = self
	state["material"] = baseMaterial
	state["albedo_color"] = baseMaterial.albedo_color
	state["emission_enabled"] = baseMaterial.emission_enabled
	state["emission"] = baseMaterial.emission
	state["emission_energy_multiplier"] = baseMaterial.emission_energy_multiplier
	return state

func restore_state(state: Dictionary) -> void:
	var baseMaterial: BaseMaterial3D = state.get("material") as BaseMaterial3D
	if not baseMaterial:
		return

	var albedoColor: Variant = state.get("albedo_color", baseMaterial.albedo_color)
	if albedoColor is Color:
		baseMaterial.albedo_color = albedoColor
	var emissionEnabled: Variant = state.get("emission_enabled", baseMaterial.emission_enabled)
	if emissionEnabled is bool:
		baseMaterial.emission_enabled = emissionEnabled
	var emission: Variant = state.get("emission", baseMaterial.emission)
	if emission is Color:
		baseMaterial.emission = emission
	var emissionEnergy: Variant = state.get(
		"emission_energy_multiplier", baseMaterial.emission_energy_multiplier
	)
	if emissionEnergy is float or emissionEnergy is int:
		baseMaterial.emission_energy_multiplier = float(emissionEnergy)

func apply() -> void:
	if material:
		material.albedo_color = color
		if material is StandardMaterial3D:
			material.emission_enabled = hasEmission
			if hasEmission:
				material.emission = color
				material.emission_energy_multiplier = intensity


func apply_tweened(node: Node, duration: float, trans_type: int = 0, ease_type: int = 0) -> void:
	if not material:
		return
	var tween: Tween = node.create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(trans_type)
	tween.tween_property(material, "albedo_color", color, duration)
	if material is StandardMaterial3D:
		material.emission_enabled = hasEmission
		if hasEmission:
			material.emission = color
			material.emission_energy_multiplier = intensity
