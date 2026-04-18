extends Area3D
class_name CameraTrigger

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

@export_group("Trigger")
@export var can_be_triggered: bool = true
@export_group("时间判定")
@export var use_time: bool = false
@export var trigger_time: float = 0.0

signal on_finished

var _follower: CameraFollower = null
var _triggered: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and can_be_triggered and not use_time:
		_trigger()

func _process(_delta: float) -> void:
	if use_time and not _triggered:
		var current_time = LevelManager.anim_time
		if current_time >= trigger_time:
			_trigger()

func _trigger() -> void:
	if _triggered:
		return
	
	_triggered = true
	
	if not _follower:
		_follower = CameraFollower.instance
	
	if not _follower:
		return
	
	_follower.follow = follow
	_follower.trigger(offset, camera_rotation, camera_scale, field_of_view, duration, transition_type, ease_type, func() -> void:
		on_finished.emit()
	)

## Public method to trigger manually (when canBeTriggered is false)
func trigger_manually() -> void:
	if not _follower:
		_follower = CameraFollower.instance
	
	if not _follower:
		return
	
	_follower.follow = follow
	_follower.trigger(offset, camera_rotation, camera_scale, field_of_view, duration, transition_type, ease_type, func() -> void:
		on_finished.emit()
	)
