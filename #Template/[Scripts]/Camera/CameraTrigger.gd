extends Node
## CameraTrigger - 相机触发器（纯组件模式）
## 作为 BaseTrigger 的子节点，依赖父节点处理碰撞
## 与 Unity CameraTrigger.cs 一比一对应，变量名保持一致

@export var offset: Vector3 = Vector3.ZERO
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees,or_greater,or_less") var rotation: Vector3 = Vector3(deg_to_rad(54), deg_to_rad(45), 0)
@export var scale: Vector3 = Vector3.ONE
@export_range(0.0, 179.0) var fieldOfView: float = 80.0
@export var follow: bool = true
@export var duration: float = 2.0
@export var useCurve: bool = false
@export var ease: CameraFollower.Ease = CameraFollower.Ease.InOutSine
@export var curve: Curve
@export var mode: CameraFollower.RotateMode = CameraFollower.RotateMode.FastBeyond360
@export var canBeTriggered: bool = true

signal onFinished

var _follower: CameraFollower = null


## 由父节点 BaseTrigger 调用的入口方法
func trigger(_body: Node3D) -> void:
	if canBeTriggered:
		_apply_camera()


## 公开方法：手动触发。对应 Unity CameraTrigger.Trigger()：
## 当碰撞触发被禁用（canBeTriggered == false）时用于手动调用
func trigger_manually() -> void:
	if not canBeTriggered:
		_apply_camera()


func _apply_camera() -> void:
	if not _follower:
		_follower = CameraFollower.instance

	if not _follower:
		return

	_follower.follow = follow
	_follower.Trigger(
		offset,
		rotation * (180.0 / PI),
		scale,
		fieldOfView,
		duration,
		ease,
		mode,
		func() -> void: onFinished.emit(),
		useCurve,
		curve
	)