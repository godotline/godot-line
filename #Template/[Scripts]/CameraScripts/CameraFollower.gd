extends Node3D
class_name CameraFollower

static var instance: CameraFollower

@export var target: NodePath
@export var follow: bool = true
@export var smooth: bool = true

var rotator: Node3D
var scale_node: Node3D
var camera: Camera3D

## Tween references
var offset_tween: Tween
var rotation_tween: Tween
var scale_tween: Tween
var shake_tween: Tween
var fov_tween: Tween
var shake_power: float = 0.0

## Follow speed (x, y, z components)
var follow_speed := Vector3(1.2, 3.0, 6.0)

## Rotation quaternion for follow calculation
var follow_rotation := Quaternion.from_euler(Vector3(0, deg_to_rad(-45), 0))

var _target_node: Node3D = null

func _ready() -> void:
	instance = self
	
	# Find child nodes
	for child in get_children():
		if child.name == "Rotator":
			rotator = child
			for sub_child in rotator.get_children():
				if sub_child.name == "Scale":
					scale_node = sub_child
					for camera_child in scale_node.get_children():
						if camera_child is Camera3D:
							camera = camera_child
							break
	
	# Get target node
	if target:
		_target_node = get_node_or_null(target) as Node3D

func _process(delta: float) -> void:
	if not _target_node or not follow:
		return
	
	# Only follow when playing
	if LevelManager.game_state != LevelManager.GameStatus.Playing:
		return
	
	# Calculate translation based on rotated positions
	var target_pos = follow_rotation * _target_node.position
	var self_pos = follow_rotation * position
	var translation = target_pos - self_pos
	
	var result = Vector3(
		translation.x * delta * follow_speed.x,
		translation.y * delta * follow_speed.y,
		translation.z * delta * follow_speed.z
	)
	
	if smooth:
		# Apply translation relative to a rotated origin
		var origin_transform = Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(45), 0)), Vector3.ZERO)
		position += origin_transform.basis * result
	else:
		position += result

## Trigger camera transition with offset, rotation, scale, and FOV
func trigger(n_offset: Vector3, n_rotation: Vector3, n_scale: Vector3, n_fov: float,
		duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType,
		callback: Callable = Callable()) -> void:
	
	_set_offset(n_offset, duration, trans_type, ease_type)
	_set_rotation(n_rotation, duration, trans_type, ease_type)
	_set_scale(n_scale, duration, trans_type, ease_type)
	_set_fov(n_fov, duration, trans_type, ease_type)
	
	if callback.is_valid() and rotation_tween:
		rotation_tween.finished.connect(callback)

## Kill all active tweens
func kill_all() -> void:
	if offset_tween:
		offset_tween.kill()
		offset_tween = null
	if rotation_tween:
		rotation_tween.kill()
		rotation_tween = null
	if scale_tween:
		scale_tween.kill()
		scale_tween = null
	if shake_tween:
		shake_tween.kill()
		shake_tween = null
	if fov_tween:
		fov_tween.kill()
		fov_tween = null

## Set offset with tween
func _set_offset(n_offset: Vector3, duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if offset_tween:
		offset_tween.kill()
		offset_tween = null
	
	if not rotator:
		return
	
	offset_tween = create_tween().set_trans(trans_type).set_ease(ease_type)
	offset_tween.tween_property(rotator, "position", n_offset, duration)

## Set rotation with tween
func _set_rotation(n_rotation: Vector3, duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if rotation_tween:
		rotation_tween.kill()
		rotation_tween = null
	
	if not rotator:
		return
	
	rotation_tween = create_tween().set_trans(trans_type).set_ease(ease_type)
	rotation_tween.tween_property(rotator, "rotation_degrees", n_rotation, duration)

## Set scale with tween
func _set_scale(n_scale: Vector3, duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if scale_tween:
		scale_tween.kill()
		scale_tween = null
	
	if not scale_node:
		return
	
	scale_tween = create_tween().set_trans(trans_type).set_ease(ease_type)
	scale_tween.tween_property(scale_node, "scale", n_scale, duration)

## Set FOV with tween
func _set_fov(n_fov: float, duration: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if fov_tween:
		fov_tween.kill()
		fov_tween = null
	
	if not camera:
		return
	
	fov_tween = create_tween().set_trans(trans_type).set_ease(ease_type)
	fov_tween.tween_property(camera, "fov", n_fov, duration)

## Shake camera with power and duration
func do_shake(power: float = 1.0, duration: float = 3.0) -> void:
	# Kill previous shake
	if shake_tween:
		shake_tween.kill()
	
	# Create sequence: ramp up then ramp down
	var seq = create_tween()
	
	# Phase 1: ramp up from current to target power
	var current_power = shake_power
	seq.tween_method(func(val: float) -> void:
		shake_power = val
	, current_power, power, duration * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Phase 2: ramp down to 0
	seq.tween_method(func(val: float) -> void:
		shake_power = val
	, power, 0.0, duration * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	# Update shake each step
	seq.step_finished.connect(func(_step: int) -> void:
		_shake_update()
	)
	
	# On complete
	seq.finished.connect(func() -> void:
		_shake_finished()
	)
	
	shake_tween = seq

func _shake_update() -> void:
	if scale_node:
		scale_node.position = Vector3(
			randf() * shake_power,
			randf() * shake_power,
			randf() * shake_power
		)

func reset_shake() -> void:
	if shake_tween:
		shake_tween.kill()
	shake_power = 0.0
	if scale_node:
		scale_node.position = Vector3.ZERO

func _shake_finished() -> void:
	if scale_node:
		scale_node.position = Vector3.ZERO
	shake_power = 0.0

## Kill all camera tweens and reset shake
func kill_all_camera_tweens() -> void:
	kill_all()
	shake_power = 0.0
	if scale_node:
		scale_node.position = Vector3.ZERO
