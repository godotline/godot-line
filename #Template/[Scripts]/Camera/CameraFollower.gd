extends Node3D
class_name CameraFollower

## Mirrors DOTween's Ease enum values used by the Unity implementation.
enum Ease {
	Linear,
	InSine,
	OutSine,
	InOutSine,
	InQuad,
	OutQuad,
	InOutQuad,
	InCubic,
	OutCubic,
	InOutCubic,
	InQuart,
	OutQuart,
	InOutQuart,
	InQuint,
	OutQuint,
	InOutQuint,
	InExpo,
	OutExpo,
	InOutExpo,
	InCirc,
	OutCirc,
	InOutCirc,
	InElastic,
	OutElastic,
	InOutElastic,
	InBack,
	OutBack,
	InOutBack,
	InBounce,
	OutBounce,
	InOutBounce,
	Flash,
	InFlash,
	OutFlash,
	InOutFlash,
}

## Mirrors DOTween's RotateMode values used by the Unity implementation.
enum RotateMode {
	Fast,
	FastBeyond360,
	WorldAxisAdd,
	LocalAxisAdd,
}

static var instance: CameraFollower

@export_node_path("Node3D") var target: NodePath
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

var followSpeed: Vector3 = Vector3(1.2, 3.0, 6.0)
var followRotation: Quaternion = Quaternion.from_euler(Vector3(0.0, deg_to_rad(-45.0), 0.0))

var targetNode: Node3D
var smoothDeltaSamples: PackedFloat32Array = []
var smoothDeltaTotal: float = 0.0


func _enter_tree() -> void:
	# Unity assigns Instance in Awake, before Start-style initialization.
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

	if not target.is_empty():
		targetNode = get_node_or_null(target) as Node3D


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if not targetNode or not follow:
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return

	# Unity's Transform.position is a world-space position.
	var targetPosition: Vector3 = followRotation * targetNode.global_position
	var selfPosition: Vector3 = followRotation * global_position
	var translation: Vector3 = targetPosition - selfPosition
	var smoothDelta: float = _get_smooth_delta(delta)
	var result: Vector3 = Vector3(
		translation.x * smoothDelta * followSpeed.x,
		translation.y * smoothDelta * followSpeed.y,
		translation.z * smoothDelta * followSpeed.z
	)

	if smooth:
		# Equivalent to Transform.Translate(result, origin), where origin is
		# world-aligned at +45 degrees around Y.
		var originBasis: Basis = Basis.from_euler(Vector3(0.0, deg_to_rad(45.0), 0.0))
		global_position += originBasis * result
	else:
		# Transform.Translate(result) uses the follower's own local axes.
		global_position += global_basis.orthonormalized() * result


## Starts the four camera transitions in parallel. The completion callback is
## tied to the rotation tween, matching CameraFollower.Trigger in Unity.
func Trigger(n_offset: Vector3, n_rotation: Vector3, n_scale: Vector3, n_fov: float,
		duration: float, ease: Ease, mode: RotateMode, callback: Callable,
		use: bool, curve: Curve) -> void:
	_set_offset(n_offset, duration, ease, use, curve)
	_set_rotation(n_rotation, duration, mode, ease, use, curve)
	_set_scale(n_scale, duration, ease, use, curve)
	_set_fov(n_fov, duration, ease, use, curve)

	if rotationTween and callback.is_valid():
		rotationTween.finished.connect(callback, CONNECT_ONE_SHOT)


func KillAll() -> void:
	offsetTween = _kill_tween(offsetTween)
	rotationTween = _kill_tween(rotationTween)
	scaleTween = _kill_tween(scaleTween)
	shakeTween = _kill_tween(shakeTween)
	fovTween = _kill_tween(fovTween)


func _set_offset(n_offset: Vector3, duration: float, ease: Ease, use: bool, curve: Curve) -> void:
	offsetTween = _kill_tween(offsetTween)
	if not rotator:
		return

	offsetTween = create_tween()
	if use:
		var initial: Vector3 = rotator.position
		var updateOffset: Callable = func(weight: float) -> void:
			rotator.position = initial.lerp(n_offset, _sample_curve(curve, weight))
		offsetTween.tween_method(updateOffset, 0.0, 1.0, maxf(duration, 0.0))
	else:
		offsetTween.set_trans(_ease_to_transition(ease)).set_ease(_ease_to_ease_type(ease))
		offsetTween.tween_property(rotator, "position", n_offset, maxf(duration, 0.0))


func _set_rotation(n_rotation: Vector3, duration: float, mode: RotateMode,
		ease: Ease, use: bool, curve: Curve) -> void:
	rotationTween = _kill_tween(rotationTween)
	if not rotator:
		return

	rotationTween = create_tween()
	var tweenDuration: float = maxf(duration, 0.0)
	if mode == RotateMode.Fast or mode == RotateMode.FastBeyond360:
		var initial: Vector3 = rotator.rotation_degrees
		var destination: Vector3 = n_rotation
		if mode == RotateMode.Fast:
			destination = _short_rotation_target(initial, n_rotation)

		if use:
			var updateRotation: Callable = func(weight: float) -> void:
				rotator.rotation_degrees = initial.lerp(destination, _sample_curve(curve, weight))
			rotationTween.tween_method(updateRotation, 0.0, 1.0, tweenDuration)
		else:
			rotationTween.set_trans(_ease_to_transition(ease)).set_ease(_ease_to_ease_type(ease))
			rotationTween.tween_property(rotator, "rotation_degrees", destination, tweenDuration)
		return

	# Axis-add modes are relative rotations. Rebuilding from the captured basis
	# on every update also keeps custom curves and overshoot deterministic.
	var initialBasis: Basis = rotator.basis
	var initialGlobalBasis: Basis = rotator.global_basis
	var applyRotation: Callable = func(weight: float) -> void:
		var sampledWeight: float = _sample_curve(curve, weight) if use else weight
		var radians: Vector3 = n_rotation * sampledWeight * (PI / 180.0)
		var addedBasis: Basis = Basis.from_euler(radians)
		if mode == RotateMode.WorldAxisAdd:
			rotator.global_basis = addedBasis * initialGlobalBasis
		else:
			rotator.basis = initialBasis * addedBasis

	if not use:
		rotationTween.set_trans(_ease_to_transition(ease)).set_ease(_ease_to_ease_type(ease))
	rotationTween.tween_method(applyRotation, 0.0, 1.0, tweenDuration)


func _set_scale(n_scale: Vector3, duration: float, ease: Ease, use: bool, curve: Curve) -> void:
	scaleTween = _kill_tween(scaleTween)
	if not scaleNode:
		return

	scaleTween = create_tween()
	if use:
		var initial: Vector3 = scaleNode.scale
		var updateScale: Callable = func(weight: float) -> void:
			scaleNode.scale = initial.lerp(n_scale, _sample_curve(curve, weight))
		scaleTween.tween_method(updateScale, 0.0, 1.0, maxf(duration, 0.0))
	else:
		scaleTween.set_trans(_ease_to_transition(ease)).set_ease(_ease_to_ease_type(ease))
		scaleTween.tween_property(scaleNode, "scale", n_scale, maxf(duration, 0.0))


func _set_fov(n_fov: float, duration: float, ease: Ease, use: bool, curve: Curve) -> void:
	fovTween = _kill_tween(fovTween)
	if not camera:
		return

	fovTween = create_tween()
	if use:
		var initial: float = camera.fov
		var updateFov: Callable = func(weight: float) -> void:
			camera.fov = lerpf(initial, n_fov, _sample_curve(curve, weight))
		fovTween.tween_method(updateFov, 0.0, 1.0, maxf(duration, 0.0))
	else:
		fovTween.set_trans(_ease_to_transition(ease)).set_ease(_ease_to_ease_type(ease))
		fovTween.tween_property(camera, "fov", n_fov, maxf(duration, 0.0))


func DoShake(power: float = 1.0, duration: float = 3.0) -> void:
	# Killing a shake deliberately preserves its instantaneous power, just like
	# DOTween, so the replacement shake starts without a discontinuity.
	shakeTween = _kill_tween(shakeTween)
	shakeTween = create_tween()
	var halfDuration: float = maxf(duration * 0.5, 0.0)
	var currentPower: float = shakePower

	var updateShake: Callable = func(value: float) -> void:
		shakePower = value
		_shake_update()

	shakeTween.tween_method(updateShake, currentPower, power, halfDuration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shakeTween.tween_method(updateShake, power, 0.0, halfDuration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shakeTween.finished.connect(_shake_finished, CONNECT_ONE_SHOT)


func _shake_update() -> void:
	if scaleNode:
		# UnityEngine.Random.value is in [0, 1], so the deliberately positive-only
		# displacement is retained for exact source behavior.
		scaleNode.position = Vector3(randf(), randf(), randf()) * shakePower


func ResetShake() -> void:
	shakeTween = _kill_tween(shakeTween)
	shakePower = 0.0
	if scaleNode:
		scaleNode.position = Vector3.ZERO


func _shake_finished() -> void:
	if scaleNode:
		scaleNode.position = Vector3.ZERO
	shakePower = 0.0
	shakeTween = null


func KillAllCameraTweens() -> void:
	KillAll()
	shakePower = 0.0
	if scaleNode:
		scaleNode.position = Vector3.ZERO


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
	smoothDeltaSamples.append(delta)
	smoothDeltaTotal += delta
	if smoothDeltaSamples.size() > 10:
		smoothDeltaTotal -= smoothDeltaSamples[0]
		smoothDeltaSamples.remove_at(0)
	return smoothDeltaTotal / float(smoothDeltaSamples.size())


## Maps a DOTween-style Ease value onto Godot's TransitionType.
func _ease_to_transition(ease: Ease) -> Tween.TransitionType:
	match ease:
		Ease.InSine, Ease.OutSine, Ease.InOutSine:
			return Tween.TRANS_SINE
		Ease.InQuad, Ease.OutQuad, Ease.InOutQuad:
			return Tween.TRANS_QUAD
		Ease.InCubic, Ease.OutCubic, Ease.InOutCubic:
			return Tween.TRANS_CUBIC
		Ease.InQuart, Ease.OutQuart, Ease.InOutQuart:
			return Tween.TRANS_QUART
		Ease.InQuint, Ease.OutQuint, Ease.InOutQuint:
			return Tween.TRANS_QUINT
		Ease.InExpo, Ease.OutExpo, Ease.InOutExpo:
			return Tween.TRANS_EXPO
		Ease.InCirc, Ease.OutCirc, Ease.InOutCirc:
			return Tween.TRANS_CIRC
		Ease.InElastic, Ease.OutElastic, Ease.InOutElastic:
			return Tween.TRANS_ELASTIC
		Ease.InBack, Ease.OutBack, Ease.InOutBack:
			return Tween.TRANS_BACK
		Ease.InBounce, Ease.OutBounce, Ease.InOutBounce:
			return Tween.TRANS_BOUNCE
		Ease.Flash, Ease.InFlash, Ease.OutFlash, Ease.InOutFlash:
			return Tween.TRANS_LINEAR
		_:
			return Tween.TRANS_LINEAR


## Maps a DOTween-style Ease value onto Godot's EaseType.
func _ease_to_ease_type(ease: Ease) -> Tween.EaseType:
	match ease:
		Ease.InSine, Ease.InQuad, Ease.InCubic, Ease.InQuart, Ease.InQuint, Ease.InExpo, Ease.InCirc, Ease.InElastic, Ease.InBack, Ease.InBounce, Ease.InFlash:
			return Tween.EASE_IN
		Ease.OutSine, Ease.OutQuad, Ease.OutCubic, Ease.OutQuart, Ease.OutQuint, Ease.OutExpo, Ease.OutCirc, Ease.OutElastic, Ease.OutBack, Ease.OutBounce, Ease.OutFlash:
			return Tween.EASE_OUT
		_:
			return Tween.EASE_IN_OUT
