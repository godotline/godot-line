@tool
extends TriggerBehavior
class_name OldCameraTriggerBehavior

## OldCameraTriggerBehavior - 旧相机变换行为组件
## 当父 BaseTrigger 被触发时改变旧相机（OldCameraFollower）参数

@export_group("Camera Settings")
@export var offset: Vector3 = Vector3.ZERO
@export var camera_rotation: Vector3 = Vector3(54, 45, 0)
@export var distance: float = 10.0
@export var follow: bool = true

@export_group("Animation")
@export var duration: float = 2.0
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

var _original_offset: Vector3
var _original_rotation: Vector3
var _original_distance: float
var _original_follow: bool
var _saved: bool = false

func _on_triggered(_body: Node3D) -> void:
	var ocf := OldCameraFollower.instance
	if not ocf:
		return

	if not _saved:
		_original_offset = ocf.add_position
		_original_rotation = ocf.rotation_degrees
		_original_distance = ocf.distance_from_object
		_original_follow = ocf.following
		_saved = true

	ocf.following = follow

	if duration > 0.0:
		var tween := create_tween()
		tween.set_ease(ease_type)
		tween.set_trans(transition_type)
		tween.tween_property(ocf, "add_position", offset, duration)
		tween.parallel().tween_property(ocf, "rotation_degrees", camera_rotation, duration)
		tween.parallel().tween_property(ocf, "distance_from_object", distance, duration)
	else:
		ocf.add_position = offset
		ocf.rotation_degrees = camera_rotation
		ocf.distance_from_object = distance

	_register_revive()

func _on_revive() -> void:
	if not _saved:
		return
	var ocf := OldCameraFollower.instance
	if ocf:
		ocf.add_position = _original_offset
		ocf.rotation_degrees = _original_rotation
		ocf.distance_from_object = _original_distance
		ocf.following = _original_follow
