extends Node3D
## CameraTrigger - 相机触发器（纯组件模式）
## 作为 BaseTrigger 的子节点，依赖父节点处理碰撞
## 也支持 use_time 模式基于时间自动触发

@export_group("Camera Settings")
@export var offset: Vector3 = Vector3.ZERO
@export var camera_rotation: Vector3 = Vector3(54, 45, 0)
@export var camera_scale: Vector3 = Vector3.ONE
@export_range(0.0, 179.0) var field_of_view: float = 80.0
@export var follow: bool = true

@export_group("Animation")
@export var duration: float = 2.0
@export var use_curve: bool = false
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var curve: Curve
@export var rotation_mode: CameraFollower.RotateMode = CameraFollower.RotateMode.FAST_BEYOND_360
@export var can_be_triggered: bool = true

@export_group("时间判定")
@export var use_time: bool = false
@export var trigger_time: float = 0.0

signal on_finished

var _follower: CameraFollower = null
var _time_triggered: bool = false

func _ready() -> void:
	if use_time:
		set_process(true)
	else:
		set_process(false)

func _process(_delta: float) -> void:
	if use_time and not _time_triggered:
		var current_time: float = LevelManager.anim_time
		if current_time >= trigger_time:
			_time_triggered = true
			_apply_camera()
			set_process(false)

## 由父节点 BaseTrigger 调用的入口方法
func trigger(_body: Node3D) -> void:
	if use_time:
		return
	if can_be_triggered:
		_apply_camera()

## 公开方法：手动触发
func trigger_manually() -> void:
	# Mirrors CameraTrigger.Trigger(): manual invocation is used when collision
	# triggering has been disabled.
	if not can_be_triggered:
		_apply_camera()

func _apply_camera() -> void:
	if not _follower:
		_follower = CameraFollower.instance

	if not _follower:
		return

	_follower.follow = follow
	_follower.trigger(
		offset,
		camera_rotation,
		camera_scale,
		field_of_view,
		duration,
		transition_type,
		ease_type,
		rotation_mode,
		func() -> void: on_finished.emit(),
		use_curve,
		curve
	)
