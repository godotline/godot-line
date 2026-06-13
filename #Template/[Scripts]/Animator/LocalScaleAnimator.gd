# LocalScaleAnimator.gd — 组件模式，tween 父节点的 scale（scale 没有 global，用 local）
@tool
extends AnimatorBase

func _get_value(target: Node3D) -> Vector3:
	return target.scale

func _set_value(target: Node3D, value: Vector3) -> void:
	target.scale = value

func _get_property_name() -> String:
	return "scale"
