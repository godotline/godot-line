# LocalRotAnimator.gd — 组件模式，tween 父节点的 global rotation (radians)
@tool
extends AnimatorBase

## 对齐 Unity DOTween.RotateMode（LocalRotAnimator.cs rotateMode 字段）
enum RotateMode {
	Fast,          # 最短路径：每轴角度差收敛到 ±180° 内
	FastBeyond360, # 不做最短路径限制，可旋转超过 360°
	LocalAxisAdd,  # 将 endOffset 视为相对当前角度的增量（本地轴）
	WorldAxisAdd,  # 将 endOffset 视为相对当前角度的增量（世界轴）
}

@export var rotateMode: RotateMode = RotateMode.Fast

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

func _adjust_target_value(start: Vector3, targetValue: Vector3, isAdd: bool) -> Vector3:
	match rotateMode:
		RotateMode.Fast:
			return Vector3(
				start.x + wrapf(targetValue.x - start.x, -PI, PI),
				start.y + wrapf(targetValue.y - start.y, -PI, PI),
				start.z + wrapf(targetValue.z - start.z, -PI, PI)
			)
		RotateMode.FastBeyond360:
			return targetValue
		RotateMode.LocalAxisAdd, RotateMode.WorldAxisAdd:
			return targetValue if isAdd else start + targetValue
	return targetValue
