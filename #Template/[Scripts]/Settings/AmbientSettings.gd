class_name AmbientSettings
extends Resource

enum EnvironmentLightingType { Skybox, Color, Gradient }

@export var lighting_type: EnvironmentLightingType = EnvironmentLightingType.Color
@export_range(0.0, 8.0) var intensity: float = 1.0
@export var ambient_color: Color = Color(0.67, 0.67, 0.67)
@export var sky_color: Color = Color(0.67, 0.67, 0.67)
@export var equator_color: Color = Color(0.114, 0.125, 0.133)
@export var ground_color: Color = Color(0.047, 0.043, 0.035)
