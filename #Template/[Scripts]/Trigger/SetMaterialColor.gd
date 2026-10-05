extends Node
class_name SetMaterialColor

@export var colors: Array[SingleColor] = []
@export var duration: float = 2.0
@export var ease: Tween.EaseType = Tween.EASE_IN_OUT


func trigger(body: Node3D) -> bool:
	if not (body is Player or body.is_in_group("Player")):
		return false
	for s: SingleColor in colors:
		s.apply_tweened(self, duration, int(Tween.TRANS_LINEAR), int(ease))
	return true
