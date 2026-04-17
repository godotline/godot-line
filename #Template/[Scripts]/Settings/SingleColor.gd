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
