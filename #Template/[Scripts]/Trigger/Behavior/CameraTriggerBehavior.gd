@tool
extends TriggerBehavior
class_name CameraTriggerBehavior

## CameraTriggerBehavior - 新相机变换行为组件
## 当父 BaseTrigger 被触发时改变相机参数

@export_group("Camera Settings")
@export var offset: Vector3 = Vector3.ZERO
@export var camera_rotation: Vector3 = Vector3(54, 45, 0)
@export var camera_scale: Vector3 = Vector3.ONE
@export_range(0.0, 179.0) var field_of_view: float = 80.0
@export var follow: bool = true

@export_group("Animation")
@export var duration: float = 2.0
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("时间判定")
@export var use_time: bool = false
@export var trigger_time: float = 0.0

signal on_finished

var _follower: CameraFollower = null
var _triggered_by_time: bool = false

func _process(_delta: float) -> void:
	if use_time and not _triggered_by_time:
		var current_time = LevelManager.anim_time
		if current_time >= trigger_time:
			_triggered_by_time = true
			_trigger()

func _on_triggered(_body: Node3D) -> void:
	if not use_time:
		_trigger()

func _trigger() -> void:
	if not _follower:
		_follower = CameraFollower.instance
	
	if not _follower:
		return
	
	_follower.follow = follow
	_follower.trigger(offset, camera_rotation, camera_scale, field_of_view, duration, transition_type, ease_type, func() -> void:
		on_finished.emit()
	)

## Public method to trigger manually
func trigger_manually() -> void:
	_trigger()
