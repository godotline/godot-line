# roter.gd
@tool
extends AnimatorBase

func _get_value() -> Vector3:
	return rotation_degrees

func _set_value(_value: Vector3) -> void:
	rotation_degrees = _value

func _get_property_name() -> String:
	return "rotation_degrees"
