extends Node3D
class_name CameraProjectionDynamicChanging3

## Pure component trigger for the No.4 projection transition.
## Godot Camera3D does not expose a custom projection matrix, so the transition
## interpolates the equivalent FOV/orthographic size before switching modes.

@export var camera: Camera3D
@export_node_path("Camera3D") var camera_path: NodePath = NodePath("")
@export var projection_change_time: float = 1.0

var change_projection: bool = false

var _changing: bool = false
var _current_t: float = 0.0
var _start_projection: int = Camera3D.PROJECTION_PERSPECTIVE
var _start_fov: float = 75.0
var _start_size: float = 1.0
var _target_fov: float = 75.0
var _target_size: float = 1.0


func _ready() -> void:
	_resolve_camera()
	set_process(true)


func _process(delta: float) -> void:
	if _changing:
		change_projection = false
		_advance_transition(delta)
	elif change_projection:
		_begin_transition()
		change_projection = false
		if _changing:
			_advance_transition(delta)


## Called by BaseTrigger after it has filtered the entering body.
func trigger(body: Node3D) -> void:
	if body is Player:
		change_projection = true
		set_process(true)


func _resolve_camera() -> void:
	if is_instance_valid(camera):
		return
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if camera:
		return
	var follower: CameraFollower3 = CameraFollower3.instance
	if follower:
		camera = follower.camera
	if not camera and is_inside_tree():
		camera = get_viewport().get_camera_3d()


func _begin_transition() -> void:
	_resolve_camera()
	if not camera:
		return

	_start_projection = camera.projection
	_start_fov = camera.fov
	_start_size = camera.size
	_current_t = 0.0
	if _start_projection == Camera3D.PROJECTION_ORTHOGONAL:
		_target_size = _start_size
		_target_fov = _fov_for_orthographic_size(_start_size)
	else:
		_target_fov = _start_fov
		_target_size = _orthographic_size_for_fov(_start_fov)
	_changing = true


func _advance_transition(delta: float) -> void:
	_resolve_camera()
	if not camera:
		_changing = false
		return

	var transition_duration: float = maxf(projection_change_time * 10.0, 0.0001)
	_current_t += delta / transition_duration
	if _current_t < 1.0:
		var weight: float = pow(_current_t, 2.0) if _start_projection == Camera3D.PROJECTION_ORTHOGONAL else sqrt(_current_t)
		if _start_projection == Camera3D.PROJECTION_ORTHOGONAL:
			camera.size = lerpf(_start_size, _target_size, weight)
		else:
			camera.fov = lerpf(_start_fov, _target_fov, weight)
		return

	_changing = false
	if _start_projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = _target_fov
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = _target_size


func _reference_distance() -> float:
	if camera:
		var local_distance: float = absf(camera.position.z)
		if local_distance > 0.001:
			return local_distance
	var follower: CameraFollower3 = CameraFollower3.instance
	if follower:
		return maxf(absf(follower.distance_from_object), 0.001)
	return 1.0


func _orthographic_size_for_fov(fov: float) -> float:
	var radians: float = deg_to_rad(clampf(fov, 0.1, 179.0))
	return maxf(2.0 * _reference_distance() * tan(radians / 2.0), 0.001)


func _fov_for_orthographic_size(size: float) -> float:
	var radians: float = 2.0 * atan(maxf(size, 0.001) / (2.0 * _reference_distance()))
	return clampf(rad_to_deg(radians), 0.1, 179.0)
