extends Area3D

@export_group("Camera Settings")
@export var add_offset: bool = false
@export var offset: Vector3 = Vector3.ZERO
@export var camera_rotation: Vector3 = Vector3(54.0, 45.0, 0.0)
@export var camera_scale: Vector3 = Vector3.ONE
@export_range(0.0, 179.0) var field_of_view: float = 80.0
@export var follow: bool = true

@export_group("Animation")
@export var duration: float = 2.0
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var rotation_mode: OldCameraFollower.RotateMode = OldCameraFollower.RotateMode.FAST_BEYOND_360
@export var can_be_triggered: bool = true

@export_group("时间判定")
@export var use_time: bool = false
@export var trigger_time: float = 0.0

signal on_finished

var _follower: OldCameraFollower
var _time_triggered: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	set_process(use_time)


func _process(_delta: float) -> void:
	if use_time and not _time_triggered and LevelManager.anim_time >= trigger_time:
		_time_triggered = true
		_apply_camera()
		set_process(false)


func _on_body_entered(body: Node3D) -> void:
	trigger(body)


func trigger(body: Node3D) -> void:
	if use_time or not can_be_triggered:
		return
	if body is CharacterBody3D:
		_apply_camera()


## Matches Unity OldCameraTrigger.Trigger(): manual use is enabled when
## collision triggering has been disabled.
func trigger_manually() -> void:
	if not can_be_triggered:
		_apply_camera()


func _apply_camera() -> void:
	if not _follower:
		_follower = OldCameraFollower.instance
	if not _follower:
		return

	_follower.follow = follow
	_follower.trigger(
		add_offset,
		offset,
		camera_rotation,
		camera_scale,
		field_of_view,
		duration,
		transition_type,
		ease_type,
		rotation_mode,
		func() -> void: on_finished.emit()
	)
