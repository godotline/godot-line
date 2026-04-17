class_name LightSettings
extends Resource

@export var rotation: Vector3 = Vector3.ZERO
@export var color: Color = Color.WHITE
@export var intensity: float = 1.0
@export_range(0.0, 1.0) var shadow_strength: float = 0.8