@tool
extends AnimatorBase
class_name LocalTransformAnimator

enum TargetProperty {
	POSITION,
	ROTATION_DEGREES,
}

@export var target_property: TargetProperty = TargetProperty.POSITION

func _get_value() -> Vector3:
	if target_property == TargetProperty.ROTATION_DEGREES:
		return rotation_degrees
	return position

func _set_value(_value: Vector3) -> void:
	if target_property == TargetProperty.ROTATION_DEGREES:
		rotation_degrees = _value
		return
	position = _value

func _get_property_name() -> String:
	if target_property == TargetProperty.ROTATION_DEGREES:
		return "rotation_degrees"
	return "position"
