# LocalPosAnimator.gd (或 poser.gd)
@tool
extends AnimatorBase

func _get_value() -> Vector3:
	return position

func _set_value(_value: Vector3) -> void:
	position = _value

func _get_property_name() -> String:
	return "position"
