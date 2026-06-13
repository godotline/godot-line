# LocalRotAnimator.gd — 组件模式，tween 父节点的 global rotation (degrees)
@tool
extends AnimatorBase

func _get_value(target: Node3D) -> Vector3:
	return target.global_rotation_degrees

func _set_value(target: Node3D, value: Vector3) -> void:
	target.global_rotation_degrees = value

func _get_property_name() -> String:
	return "global_rotation_degrees"
