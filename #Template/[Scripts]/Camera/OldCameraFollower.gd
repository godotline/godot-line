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

static var instance: OldCameraFollower

## 兼容旧场景中以标量配置跟随速度，以及新场景中的 Vector3 配置。
@export var followSpeed: Variant = Vector3(1.5, 1.5, 1.5)
@export var follow: bool = true
@export var smooth: bool = true

var rotator: Node3D
var scaleNode: Node3D
var camera: Camera3D

var offsetTween: Tween
var rotationTween: Tween
var scaleTween: Tween
var shakeTween: Tween
var fovTween: Tween
var shakePower: float = 0.0

var targetNode: Node3D
var checkpointApplied: bool = false

## Compatibility state used by the existing checkpoint code.
var _tween: Tween
var currentRotateMode: RotateMode = RotateMode.FAST
var targetRotation: Vector3 = Vector3.ZERO
var startRotation: Vector3 = Vector3.ZERO
var rotationProgress: float = 0.0
var isRotating: bool = false
var baseRotation: Vector3 = Vector3.ZERO
var targetAddPosition: Vector3 = Vector3.ZERO
var targetFollowSpeed: Vector3 = Vector3(1.5, 1.5, 1.5)
var targetDistance: float = 0.0

## Compatibility aliases for the former Godot OldCameraFollower API.
var following: bool:
	get:
		return follow
	set(value):
		follow = value

var line: Node3D:
	get:
		return targetNode

var addPosition: Vector3:
	get:
		return rotator.position if rotator else targetAddPosition
	set(value):
		targetAddPosition = value
		if rotator:
			rotator.position = value

var rotationOffset: Vector3:
	get:
		return rotator.rotation_degrees if rotator else targetRotation
	set(value):
		targetRotation = value
		if rotator:
			rotator.rotation_degrees = value

var distanceFromObject: float:
	get:
		if camera:
			return absf(camera.position.z)
		return targetDistance
	set(value):
		targetDistance = value
		if camera:
			camera.position.z = -value


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	rotator = get_node_or_null("Rotator") as Node3D
	if rotator:
		scaleNode = rotator.get_node_or_null("Scale") as Node3D
	if scaleNode:
		camera = scaleNode.get_node_or_null("Camera3D") as Camera3D
		if not camera:
			camera = scaleNode.get_node_or_null("Camera") as Camera3D
		if not camera:
			for child in scaleNode.get_children():
				if child is Camera3D:
					camera = child
					break

	if not rotator or not scaleNode or not camera:
		push_warning("OldCameraFollower requires Rotator/Scale/Camera3D children")

	_resolve_target()
	targetAddPosition = rotator.position if rotator else Vector3.ZERO
	targetFollowSpeed = _follow_speed_vector()
	targetRotation = rotator.rotation_degrees if rotator else Vector3.ZERO
	targetDistance = absf(camera.position.z) if camera else 0.0
	LevelManager.add_revive_listener(_on_player_revive)

	if LevelManager.cameraCheckpoint.has_checkpoint and LevelManager.cameraCheckpoint.restore_pending:
		call_deferred("_apply_state_checkpoint")


func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_player_revive)
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if LevelManager.cameraCheckpoint.has_checkpoint \
			and LevelManager.cameraCheckpoint.restore_pending \
			and not checkpointApplied:
		_apply_state_checkpoint()
	_set_position(delta)


func _resolve_target() -> void:
	var playerInstance: Player = Player.instance
	targetNode = playerInstance if is_instance_valid(playerInstance) else null


func _on_player_revive() -> void:
	if not is_instance_valid(targetNode):
		_resolve_target()
	if targetNode:
		global_position = targetNode.global_position


func update_follow_position() -> void:
	_set_position(get_process_delta_time())


func _set_position(delta: float) -> void:
	if not is_instance_valid(targetNode):
		_resolve_target()
	if not targetNode or not follow:
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return

	if not smooth:
		global_position = targetNode.global_position
		return

	var translation: Vector3 = targetNode.global_position - global_position
	var speed: Vector3 = _follow_speed_vector()
	var localStep: Vector3 = Vector3(
		translation.x * speed.x * delta,
		translation.y * speed.y * delta,
		translation.z * speed.z * delta
	)
	# Unity Transform.Translate(Vector3) applies the displacement in local space.
	global_position += global_basis.orthonormalized() * localStep


func _follow_speed_vector() -> Vector3:
	if typeof(followSpeed) == TYPE_VECTOR3:
		return followSpeed
	var scalar: float = float(followSpeed)
	return Vector3(scalar, scalar, scalar)


func Trigger(addOffset: bool, new_offset: Vector3, new_rotation: Vector3,
		new_scale: Vector3, new_fov: float, duration: float,
		transType: Tween.TransitionType = Tween.TRANS_SINE,
		easeType: Tween.EaseType = Tween.EASE_IN_OUT,
		mode: RotateMode = RotateMode.FAST_BEYOND_360,
		callback: Callable = Callable()) -> void:
	_set_offset(addOffset, new_offset, duration, transType, easeType)
	_set_rotation(new_rotation, duration, mode, transType, easeType)
	_set_scale(new_scale, duration, transType, easeType)
	_set_fov(new_fov, duration, transType, easeType)
	if rotationTween and callback.is_valid():
		rotationTween.finished.connect(callback, CONNECT_ONE_SHOT)


func KillAll() -> void:
	offsetTween = _kill_tween(offsetTween)
	rotationTween = _kill_tween(rotationTween)
	scaleTween = _kill_tween(scaleTween)
	shakeTween = _kill_tween(shakeTween)
	fovTween = _kill_tween(fovTween)
	_tween = null


func KillAllCameraTweens() -> void:
	KillAll()


func _set_offset(addOffset: bool, new_offset: Vector3, duration: float,
		transType: Tween.TransitionType, easeType: Tween.EaseType) -> void:
	offsetTween = _kill_tween(offsetTween)
	if not rotator:
		return
	var destination: Vector3 = rotator.position + new_offset if addOffset else new_offset
	targetAddPosition = destination
	offsetTween = create_tween().set_trans(transType).set_ease(easeType)
	offsetTween.tween_property(rotator, "position", destination, maxf(duration, 0.0))


func _set_rotation(new_rotation: Vector3, duration: float, mode: RotateMode,
		transType: Tween.TransitionType, easeType: Tween.EaseType) -> void:
	rotationTween = _kill_tween(rotationTween)
	if not rotator:
		return

	currentRotateMode = mode
	startRotation = rotator.rotation_degrees
	baseRotation = startRotation
	targetRotation = new_rotation
	rotationTween = create_tween().set_trans(transType).set_ease(easeType)
	var tweenDuration: float = maxf(duration, 0.0)

	if mode == RotateMode.FAST or mode == RotateMode.FAST_BEYOND_360:
		var destination: Vector3 = new_rotation
		if mode == RotateMode.FAST:
			destination = _short_rotation_target(startRotation, new_rotation)
		targetRotation = destination
		rotationTween.tween_property(rotator, "rotation_degrees", destination, tweenDuration)
	else:
		var initialBasis: Basis = rotator.basis
		var initialGlobalBasis: Basis = rotator.global_basis
		rotationTween.tween_method(func(weight: float) -> void:
			var addedBasis: Basis = Basis.from_euler(new_rotation * weight * (PI / 180.0))
			if mode == RotateMode.WORLD_AXIS_ADD:
				rotator.global_basis = addedBasis * initialGlobalBasis
			else:
				rotator.basis = initialBasis * addedBasis,
			0.0, 1.0, tweenDuration)
	_tween = rotationTween


func _set_scale(new_scale: Vector3, duration: float,
		transType: Tween.TransitionType, easeType: Tween.EaseType) -> void:
	scaleTween = _kill_tween(scaleTween)
	if not scaleNode:
		return
	scaleTween = create_tween().set_trans(transType).set_ease(easeType)
	scaleTween.tween_property(scaleNode, "scale", new_scale, maxf(duration, 0.0))


func _set_fov(new_fov: float, duration: float,
		transType: Tween.TransitionType, easeType: Tween.EaseType) -> void:
	fovTween = _kill_tween(fovTween)
	if not camera:
		return
	fovTween = create_tween().set_trans(transType).set_ease(easeType)
	fovTween.tween_property(camera, "fov", new_fov, maxf(duration, 0.0))


func DoShake(power: float = 1.0, duration: float = 3.0) -> void:
	shakeTween = _kill_tween(shakeTween)
	shakeTween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	var halfDuration: float = maxf(duration * 0.5, 0.0)
	var initialPower: float = shakePower
	shakeTween.tween_method(_set_shake_power, initialPower, power, halfDuration)
	shakeTween.tween_method(_set_shake_power, power, 0.0, halfDuration)
	shakeTween.finished.connect(_shake_finished, CONNECT_ONE_SHOT)


func _set_shake_power(value: float) -> void:
	shakePower = value
	if scaleNode:
		scaleNode.position = Vector3(randf(), randf(), randf()) * shakePower


func ResetShake() -> void:
	shakeTween = _kill_tween(shakeTween)
	_shake_finished()


func _shake_finished() -> void:
	shakePower = 0.0
	if scaleNode:
		scaleNode.position = Vector3.ZERO
	shakeTween = null


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
	if checkpointApplied:
		return
	var cp: Dictionary = LevelManager.cameraCheckpoint
	if not cp.has_checkpoint or not cp.restore_pending:
		return
	if not is_instance_valid(targetNode):
		_resolve_target()
	if not targetNode:
		push_warning("OldCameraFollower: checkpoint restore failed, target is null")
		return

	LevelManager.load_to_camera_follower(self)
	global_position = targetNode.global_position
	if rotator:
		rotator.rotation_degrees = cp.rotation_degrees
	checkpointApplied = true
	cp.restore_pending = false
