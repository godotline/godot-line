extends Node3D
class_name CameraTrigger3

## Pure component trigger for CameraFollower3. Add it below a BaseTrigger node.

@export_group("Camera")
@export var set_camera: CameraFollower3
@export var active_position: bool = true
@export var new_add_position: Vector3 = Vector3.ZERO
@export var active_rotate: bool = true
@export var new_rotation: Vector3 = Vector3(45.0, 45.0, 0.0)
@export var active_distance: bool = true
@export var new_distance: float = 25.0
@export var active_speed: bool = true
@export var new_follow_speed: float = 1.2

@export_group("Animation")
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var need_time: float = 2.0

@export_group("Time Trigger")
@export var use_time: bool = false
@export var trigger_time: float = 0.0

signal on_finished

var done: bool = false
var _done_when_crown_picked: bool = false
var _last_checkpoint_count: int = 0


func _ready() -> void:
	_last_checkpoint_count = LevelManager.checkpoint_count
	if use_time:
		LevelManager.add_revive_listener(_on_player_revive)
	set_process(use_time)


func _exit_tree() -> void:
	if use_time:
		LevelManager.remove_revive_listener(_on_player_revive)


func _process(_delta: float) -> void:
	if not use_time:
		return
	_update_checkpoint_state()
	if not done and LevelManager.anim_time >= trigger_time:
		_apply_camera()
		done = true


func _update_checkpoint_state() -> void:
	var checkpoint_count: int = LevelManager.checkpoint_count
	if checkpoint_count == _last_checkpoint_count:
		return
	_done_when_crown_picked = done if checkpoint_count > _last_checkpoint_count else false
	_last_checkpoint_count = checkpoint_count


func _on_player_revive() -> void:
	done = _done_when_crown_picked
	set_process(use_time)


## Called by BaseTrigger after it has filtered the entering body.
func trigger(body: Node3D) -> void:
	if use_time or not body is Player:
		return
	_apply_camera()


func trigger_manually() -> void:
	_apply_camera()


func _apply_camera() -> void:
	var follower: CameraFollower3 = set_camera if is_instance_valid(set_camera) else CameraFollower3.instance
	if not follower:
		push_warning("CameraTrigger3.gd: CameraFollower3 was not found")
		return

	follower.trigger(
		active_position,
		new_add_position,
		active_rotate,
		new_rotation,
		active_distance,
		new_distance,
		active_speed,
		new_follow_speed,
		need_time,
		transition_type,
		ease_type,
		func() -> void: on_finished.emit()
	)
