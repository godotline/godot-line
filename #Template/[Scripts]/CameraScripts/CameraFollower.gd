extends Node3D
class_name CameraFollower

## Mirrors DOTween's RotateMode values used by the Unity implementation.
enum RotateMode {
	FAST,
	FAST_BEYOND_360,
	WORLD_AXIS_ADD,
	LOCAL_AXIS_ADD,
}

static var instance: CameraFollower

@export_node_path("Node3D") var target: NodePath
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

var follow_speed: Vector3 = Vector3(1.2, 3.0, 6.0)
var follow_rotation: Quaternion = Quaternion.from_euler(Vector3(0.0, deg_to_rad(-45.0), 0.0))

var _target_node: Node3D
var _smooth_delta_samples: PackedFloat32Array = []
var _smooth_delta_total: float = 0.0


func _enter_tree() -> void:
	# Unity assigns Instance in Awake, before Start-style initialization.
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

	if not target.is_empty():
		_target_node = get_node_or_null(target) as Node3D


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if not _target_node or not follow:
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return

	# Unity's Transform.position is a world-space position.
	var target_position: Vector3 = follow_rotation * _target_node.global_position
	var self_position: Vector3 = follow_rotation * global_position
	var translation: Vector3 = target_position - self_position
	var smooth_delta: float = _get_smooth_delta(delta)
	var result: Vector3 = Vector3(
		translation.x * smooth_delta * follow_speed.x,
		translation.y * smooth_delta * follow_speed.y,
		translation.z * smooth_delta * follow_speed.z
	)

	if smooth:
		# Equivalent to Transform.Translate(result, origin), where origin is
		# world-aligned at +45 degrees around Y.
		var origin_basis: Basis = Basis.from_euler(Vector3(0.0, deg_to_rad(45.0), 0.0))
		global_position += origin_basis * result
	else:
		# Transform.Translate(result) uses the follower's own local axes.
		global_position += global_basis.orthonormalized() * result


## Starts the four camera transitions in parallel. The completion callback is
## tied to the rotation tween, matching CameraFollower.Trigger in Unity.
func trigger(n_offset: Vector3, n_rotation: Vector3, n_scale: Vector3, n_fov: float,
		duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType,
		rotation_mode: RotateMode = RotateMode.FAST_BEYOND_360,
		callback: Callable = Callable(), use_curve: bool = false,
		curve: Curve = null) -> void:
	_set_offset(n_offset, duration, trans_type, ease_type, use_curve, curve)
	_set_rotation(n_rotation, duration, rotation_mode, trans_type, ease_type, use_curve, curve)
	_set_scale(n_scale, duration, trans_type, ease_type, use_curve, curve)
	_set_fov(n_fov, duration, trans_type, ease_type, use_curve, curve)

	if rotation_tween and callback.is_valid():
		rotation_tween.finished.connect(callback, CONNECT_ONE_SHOT)


func kill_all() -> void:
	offset_tween = _kill_tween(offset_tween)
	rotation_tween = _kill_tween(rotation_tween)
	scale_tween = _kill_tween(scale_tween)
	shake_tween = _kill_tween(shake_tween)
	fov_tween = _kill_tween(fov_tween)


func _set_offset(n_offset: Vector3, duration: float, trans_type: Tween.TransitionType,
		ease_type: Tween.EaseType, use_curve: bool, curve: Curve) -> void:
	offset_tween = _kill_tween(offset_tween)
	if not rotator:
		return

	offset_tween = create_tween()
	if use_curve:
		var initial: Vector3 = rotator.position
		var update_offset: Callable = func(weight: float) -> void:
			rotator.position = initial.lerp(n_offset, _sample_curve(curve, weight))
		offset_tween.tween_method(update_offset, 0.0, 1.0, maxf(duration, 0.0))
	else:
		offset_tween.set_trans(trans_type).set_ease(ease_type)
		offset_tween.tween_property(rotator, "position", n_offset, maxf(duration, 0.0))


func _set_rotation(n_rotation: Vector3, duration: float, mode: RotateMode,
		trans_type: Tween.TransitionType, ease_type: Tween.EaseType,
		use_curve: bool, curve: Curve) -> void:
	rotation_tween = _kill_tween(rotation_tween)
	if not rotator:
		return

	rotation_tween = create_tween()
	var tween_duration: float = maxf(duration, 0.0)
	if mode == RotateMode.FAST or mode == RotateMode.FAST_BEYOND_360:
		var initial: Vector3 = rotator.rotation_degrees
		var destination: Vector3 = n_rotation
		if mode == RotateMode.FAST:
			destination = _short_rotation_target(initial, n_rotation)

		if use_curve:
			var update_rotation: Callable = func(weight: float) -> void:
				rotator.rotation_degrees = initial.lerp(destination, _sample_curve(curve, weight))
			rotation_tween.tween_method(update_rotation, 0.0, 1.0, tween_duration)
		else:
			rotation_tween.set_trans(trans_type).set_ease(ease_type)
			rotation_tween.tween_property(rotator, "rotation_degrees", destination, tween_duration)
		return

	# Axis-add modes are relative rotations. Rebuilding from the captured basis
	# on every update also keeps custom curves and overshoot deterministic.
	var initial_basis: Basis = rotator.basis
	var initial_global_basis: Basis = rotator.global_basis
	var apply_rotation: Callable = func(weight: float) -> void:
		var sampled_weight: float = _sample_curve(curve, weight) if use_curve else weight
		var radians: Vector3 = n_rotation * sampled_weight * (PI / 180.0)
		var added_basis: Basis = Basis.from_euler(radians)
		if mode == RotateMode.WORLD_AXIS_ADD:
			rotator.global_basis = added_basis * initial_global_basis
		else:
			rotator.basis = initial_basis * added_basis

	if not use_curve:
		rotation_tween.set_trans(trans_type).set_ease(ease_type)
	rotation_tween.tween_method(apply_rotation, 0.0, 1.0, tween_duration)


func _set_scale(n_scale: Vector3, duration: float, trans_type: Tween.TransitionType,
		ease_type: Tween.EaseType, use_curve: bool, curve: Curve) -> void:
	scale_tween = _kill_tween(scale_tween)
	if not scale_node:
		return

	scale_tween = create_tween()
	if use_curve:
		var initial: Vector3 = scale_node.scale
		var update_scale: Callable = func(weight: float) -> void:
			scale_node.scale = initial.lerp(n_scale, _sample_curve(curve, weight))
		scale_tween.tween_method(update_scale, 0.0, 1.0, maxf(duration, 0.0))
	else:
		scale_tween.set_trans(trans_type).set_ease(ease_type)
		scale_tween.tween_property(scale_node, "scale", n_scale, maxf(duration, 0.0))


func _set_fov(n_fov: float, duration: float, trans_type: Tween.TransitionType,
		ease_type: Tween.EaseType, use_curve: bool, curve: Curve) -> void:
	fov_tween = _kill_tween(fov_tween)
	if not camera:
		return

	fov_tween = create_tween()
	if use_curve:
		var initial: float = camera.fov
		var update_fov: Callable = func(weight: float) -> void:
			camera.fov = lerpf(initial, n_fov, _sample_curve(curve, weight))
		fov_tween.tween_method(update_fov, 0.0, 1.0, maxf(duration, 0.0))
	else:
		fov_tween.set_trans(trans_type).set_ease(ease_type)
		fov_tween.tween_property(camera, "fov", n_fov, maxf(duration, 0.0))


func do_shake(power: float = 1.0, duration: float = 3.0) -> void:
	# Killing a shake deliberately preserves its instantaneous power, just like
	# DOTween, so the replacement shake starts without a discontinuity.
	shake_tween = _kill_tween(shake_tween)
	shake_tween = create_tween()
	var half_duration: float = maxf(duration * 0.5, 0.0)
	var current_power: float = shake_power

	var update_shake: Callable = func(value: float) -> void:
		shake_power = value
		_shake_update()

	shake_tween.tween_method(update_shake, current_power, power, half_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shake_tween.tween_method(update_shake, power, 0.0, half_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shake_tween.finished.connect(_shake_finished, CONNECT_ONE_SHOT)


func _shake_update() -> void:
	if scale_node:
		# UnityEngine.Random.value is in [0, 1], so the deliberately positive-only
		# displacement is retained for exact source behavior.
		scale_node.position = Vector3(randf(), randf(), randf()) * shake_power


func reset_shake() -> void:
	shake_tween = _kill_tween(shake_tween)
	shake_power = 0.0
	if scale_node:
		scale_node.position = Vector3.ZERO


func _shake_finished() -> void:
	if scale_node:
		scale_node.position = Vector3.ZERO
	shake_power = 0.0
	shake_tween = null


func kill_all_camera_tweens() -> void:
	kill_all()
	shake_power = 0.0
	if scale_node:
		scale_node.position = Vector3.ZERO


func _kill_tween(tween: Tween) -> Tween:
	if tween:
		tween.kill()
	return null


func _sample_curve(curve: Curve, weight: float) -> float:
	if curve:
		return curve.sample_baked(weight)
	return weight


func _short_rotation_target(initial: Vector3, requested: Vector3) -> Vector3:
	return Vector3(
		initial.x + rad_to_deg(angle_difference(deg_to_rad(initial.x), deg_to_rad(requested.x))),
		initial.y + rad_to_deg(angle_difference(deg_to_rad(initial.y), deg_to_rad(requested.y))),
		initial.z + rad_to_deg(angle_difference(deg_to_rad(initial.z), deg_to_rad(requested.z)))
	)


func _get_smooth_delta(delta: float) -> float:
	# Godot has no Time.smoothDeltaTime equivalent. A short moving average
	# provides the same frame-spike filtering role without changing time scale.
	_smooth_delta_samples.append(delta)
	_smooth_delta_total += delta
	if _smooth_delta_samples.size() > 10:
		_smooth_delta_total -= _smooth_delta_samples[0]
		_smooth_delta_samples.remove_at(0)
	return _smooth_delta_total / float(_smooth_delta_samples.size())
