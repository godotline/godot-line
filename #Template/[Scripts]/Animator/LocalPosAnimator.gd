# LocalPosAnimator.gd — 组件模式，tween 父节点的 position（对齐 Unity DOLocalMove 的 localPosition 语义）
@tool
extends AnimatorBase

func _get_value(target: Node3D) -> Vector3:
	return target.position

func _set_value(target: Node3D, value: Vector3) -> void:
	target.position = value

func _get_property_name() -> String:
	return "position"
