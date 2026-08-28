extends Node

@export var ambient: AmbientSettings = AmbientSettings.new()
@export_range(0.0, 60.0, 0.05) var duration: float = 2.0
@export var transType: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease: Tween.EaseType = Tween.EASE_IN_OUT

func trigger(body: Node3D) -> bool:
	if not (body is Player and ambient):
		return false
	ambient.apply_tweened(self, duration, transType, ease)
	return true
