# LocalRotAnimator.gd — 组件模式，tween 父节点的 global rotation (radians)
@tool
extends AnimatorBase

func _validate_property(property: Dictionary) -> void:
	if property.name in ["startValue", "endOffset"]:
		property.hint = PROPERTY_HINT_RANGE
		property.hint_string = "-360,360,0.1,radians_as_degrees,or_greater,or_less"

func _get_value(target: Node3D) -> Vector3:
	return target.global_rotation

func _set_value(target: Node3D, value: Vector3) -> void:
	target.global_rotation = value

func _get_property_name() -> String:
	return "global_rotation"
