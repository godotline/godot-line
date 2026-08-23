# LocalScaleAnimator.gd — 组件模式，tween 父节点的 scale（scale 没有 global，用 local）
@tool
extends AnimatorBase

# 对齐 Unity LocalScaleAnimator.scale 字段默认 Vector3.one；场景显式存储的 endOffset 在 _init 之后反序列化，仍优先生效
func _init() -> void:
	if endOffset == Vector3.ZERO:
		endOffset = Vector3.ONE

func _get_value(target: Node3D) -> Vector3:
	return target.scale

func _set_value(target: Node3D, value: Vector3) -> void:
	target.scale = value

func _get_property_name() -> String:
	return "scale"
