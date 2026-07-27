extends Node3D

@export var ambient_settings: AmbientSettings = AmbientSettings.new()
@export_range(0.0, 60.0, 0.05) var duration: float = 2.0
@export var trans_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

func trigger(body: Node3D) -> void:
	if body is Player and ambient_settings:
		ambient_settings.apply_tweened(self, duration, trans_type, ease_type)
