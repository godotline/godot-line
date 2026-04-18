@tool
extends Resource
class_name MovingPosPoint

@export var pos: Vector3
@export var ease: Tween.TransitionType = Tween.TransitionType.TRANS_SINE
@export var postime: float = 1.0
@export var waittime: float = 0.0
