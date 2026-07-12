extends Node3D
class_name OldCameraFollower

## Godot port of Unity's deprecated OldCameraFollower.
## Expected hierarchy: OldCameraFollower/Rotator/Scale/Camera3D.

enum RotateMode {
	FAST,
	FAST_BEYOND_360,
	WORLD_AXIS_ADD,
	LOCAL_AXIS_ADD,
}

static var instance

@export var follow_speed = Vector3(1.5, 1.5, 1.5)
@export var follow: bool = true
@export var smooth: bool = true

var rotator: Node3D
var scale_node: Node3D
var camera: Camera3D

var offset_tween: Tween
var rotation_tween: Tween
var scale_tween: Tween
var shake_tween: Tween
var fov_tween: Tween
var shake_power: float = 0.0

var _target_node: Node3D
var _checkpoint_applied := false

## Compatibility state used by the existing checkpoint code.
var _tween: Tween
var _current_rotate_mode: RotateMode = RotateMode.FAST
var _target_rotation := Vector3.ZERO
var _start_rotation := Vector3.ZERO
var _rotation_progress: float = 0.0
var _is_rotating: bool = false
var _base_rotation := Vector3.ZERO
var _target_add_position := Vector3.ZERO
var _target_follow_speed = Vector3(1.5, 1.5, 1.5)
var _target_distance: float = 0.0

## Compatibility aliases for the former Godot OldCameraFollower API.
var following: bool:
	get:
		return follow
	set(value):
		follow = value

var line: Node3D:
	get:
		return _target_node

var add_position: Vector3:
	get:
		return rotator.position if rotator else _target_add_position
	set(value):
		_target_add_position = value
		if rotator:
			rotator.position = value

var rotation_offset: Vector3:
	get:
		return rotator.rotation_degrees if rotator else _target_rotation
	set(value):
		_target_rotation = value
		if rotator:
			rotator.rotation_degrees = value

var distance_from_object: float:
	get:
		if camera:
			return absf(camera.position.z)
		return _target_distance
	set(value):
		_target_distance = value
		if camera:
			camera.position.z = -value


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	rotator = get_node_or_null("Rotator") as Node3D
	if rotator:
		scale_node = rotator.get_node_or_null("Scale") as Node3D
	if scale_node:
		camera = scale_node.get_node_or_null("Camera3D") as Camera3D
		if not camera:
			camera = scale_node.get_node_or_null("Camera") as Camera3D
		if not camera:
			for child in scale_node.get_children():
				if child is Camera3D:
					camera = child
					break

	if not rotator or not scale_node or not camera:
		push_warning("OldCameraFollower requires Rotator/Scale/Camera3D children")

	_resolve_target()
	_target_add_position = rotator.position if rotator else Vector3.ZERO
	_target_follow_speed = follow_speed
	_target_rotation = rotator.rotation_degrees if rotator else Vector3.ZERO
	_target_distance = absf(camera.position.z) if camera else 0.0
	LevelManager.add_revive_listener(_on_player_revive)

	if LevelManager.camera_checkpoint.has_checkpoint and LevelManager.camera_checkpoint.restore_pending:
		call_deferred("_apply_state_checkpoint")


func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_player_revive)
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if LevelManager.camera_checkpoint.has_checkpoint \
			and LevelManager.camera_checkpoint.restore_pending \
			and not _checkpoint_applied:
		_apply_state_checkpoint()
	_set_position(delta)


func _resolve_target() -> void:
	var player_instance = Player.instance
	_target_node = player_instance if is_instance_valid(player_instance) else null


func _on_player_revive() -> void:
	if not is_instance_valid(_target_node):
		_resolve_target()
	if _target_node:
		global_position = _target_node.global_position


func update_follow_position() -> void:
	_set_position(get_process_delta_time())


func _set_position(delta: float) -> void:
	if not is_instance_valid(_target_node):
		_resolve_target()
	if not _target_node or not follow:
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return

	if not smooth:
		global_position = _target_node.global_position
		return

	var translation := _target_node.global_position - global_position
	var speed := _follow_speed_vector()
	var local_step := Vector3(
		translation.x * speed.x * delta,
		translation.y * speed.y * delta,
		translation.z * speed.z * delta
	)
	# Unity Transform.Translate(Vector3) applies the displacement in local space.
	global_position += global_basis.orthonormalized() * local_step


func _follow_speed_vector() -> Vector3:
	if typeof(follow_speed) == TYPE_VECTOR3:
		return follow_speed
	var scalar := float(follow_speed)
	return Vector3(scalar, scalar, scalar)


func trigger(add_offset: bool, new_offset: Vector3, new_rotation: Vector3,
		new_scale: Vector3, new_fov: float, duration: float,
		trans_type: Tween.TransitionType = Tween.TRANS_SINE,
		ease_type: Tween.EaseType = Tween.EASE_IN_OUT,
		mode: RotateMode = RotateMode.FAST_BEYOND_360,
		callback: Callable = Callable()) -> void:
	_set_offset(add_offset, new_offset, duration, trans_type, ease_type)
	_set_rotation(new_rotation, duration, mode, trans_type, ease_type)
	_set_scale(new_scale, duration, trans_type, ease_type)
	_set_fov(new_fov, duration, trans_type, ease_type)
	if rotation_tween and callback.is_valid():
		rotation_tween.finished.connect(callback, CONNECT_ONE_SHOT)


func kill_all() -> void:
	offset_tween = _kill_tween(offset_tween)
	rotation_tween = _kill_tween(rotation_tween)
	scale_tween = _kill_tween(scale_tween)
	shake_tween = _kill_tween(shake_tween)
	fov_tween = _kill_tween(fov_tween)
	_tween = null


func kill_all_camera_tweens() -> void:
	kill_all()


func _set_offset(add_offset: bool, new_offset: Vector3, duration: float,
		trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	offset_tween = _kill_tween(offset_tween)
	if not rotator:
		return
	var destination := rotator.position + new_offset if add_offset else new_offset
	_target_add_position = destination
	offset_tween = create_tween().set_trans(trans_type).set_ease(ease_type)
	offset_tween.tween_property(rotator, "position", destination, maxf(duration, 0.0))


func _set_rotation(new_rotation: Vector3, duration: float, mode: RotateMode,
		trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	rotation_tween = _kill_tween(rotation_tween)
	if not rotator:
		return

	_current_rotate_mode = mode
	_start_rotation = rotator.rotation_degrees
	_base_rotation = _start_rotation
	_target_rotation = new_rotation
	rotation_tween = create_tween().set_trans(trans_type).set_ease(ease_type)
	var tween_duration := maxf(duration, 0.0)

	if mode == RotateMode.FAST or mode == RotateMode.FAST_BEYOND_360:
		var destination := new_rotation
		if mode == RotateMode.FAST:
			destination = _short_rotation_target(_start_rotation, new_rotation)
		_target_rotation = destination
		rotation_tween.tween_property(rotator, "rotation_degrees", destination, tween_duration)
	else:
		var initial_basis := rotator.basis
		var initial_global_basis := rotator.global_basis
		rotation_tween.tween_method(func(weight: float) -> void:
			var added_basis := Basis.from_euler(new_rotation * weight * (PI / 180.0))
			if mode == RotateMode.WORLD_AXIS_ADD:
				rotator.global_basis = added_basis * initial_global_basis
			else:
				rotator.basis = initial_basis * added_basis,
			0.0, 1.0, tween_duration)
	_tween = rotation_tween


func _set_scale(new_scale: Vector3, duration: float,
		trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	scale_tween = _kill_tween(scale_tween)
	if not scale_node:
		return
	scale_tween = create_tween().set_trans(trans_type).set_ease(ease_type)
	scale_tween.tween_property(scale_node, "scale", new_scale, maxf(duration, 0.0))


func _set_fov(new_fov: float, duration: float,
		trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	fov_tween = _kill_tween(fov_tween)
	if not camera:
		return
	fov_tween = create_tween().set_trans(trans_type).set_ease(ease_type)
	fov_tween.tween_property(camera, "fov", new_fov, maxf(duration, 0.0))


func do_shake(power: float = 1.0, duration: float = 3.0) -> void:
	shake_tween = _kill_tween(shake_tween)
	shake_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	var half_duration := maxf(duration * 0.5, 0.0)
	var initial_power := shake_power
	shake_tween.tween_method(_set_shake_power, initial_power, power, half_duration)
	shake_tween.tween_method(_set_shake_power, power, 0.0, half_duration)
	shake_tween.finished.connect(_shake_finished, CONNECT_ONE_SHOT)


func _set_shake_power(value: float) -> void:
	shake_power = value
	if scale_node:
		scale_node.position = Vector3(randf(), randf(), randf()) * shake_power


func reset_shake() -> void:
	shake_tween = _kill_tween(shake_tween)
	_shake_finished()


func _shake_finished() -> void:
	shake_power = 0.0
	if scale_node:
		scale_node.position = Vector3.ZERO
	shake_tween = null


func _kill_tween(tween: Tween) -> Tween:
	if tween:
		tween.kill()
	return null


func _short_rotation_target(initial: Vector3, requested: Vector3) -> Vector3:
	return Vector3(
		initial.x + rad_to_deg(angle_difference(deg_to_rad(initial.x), deg_to_rad(requested.x))),
		initial.y + rad_to_deg(angle_difference(deg_to_rad(initial.y), deg_to_rad(requested.y))),
		initial.z + rad_to_deg(angle_difference(deg_to_rad(initial.z), deg_to_rad(requested.z)))
	)


func _apply_state_checkpoint() -> void:
	if _checkpoint_applied:
		return
	var cp := LevelManager.camera_checkpoint
	if not cp.has_checkpoint or not cp.restore_pending:
		return
	if not is_instance_valid(_target_node):
		_resolve_target()
	if not _target_node:
		push_warning("OldCameraFollower: checkpoint restore failed, target is null")
		return

	LevelManager.load_to_camera_follower(self)
	global_position = _target_node.global_position
	if rotator:
		rotator.rotation_degrees = cp.rotation_degrees
	_checkpoint_applied = true
	cp.restore_pending = false
