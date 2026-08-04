extends Node3D
class_name CameraShake3

## Godot port of the No.4 CameraShake component.

static var instance: CameraShake3

var start_shake: bool = false
var seconds: float = 0.0
var started: bool = false
var quake: float = 0.2

var _delta_position: Vector3 = Vector3.ZERO
var _shake_timer: Timer


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	_shake_timer = Timer.new()
	_shake_timer.one_shot = true
	_shake_timer.timeout.connect(_on_shake_timeout)
	add_child(_shake_timer)
	set_process(false)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(_delta: float) -> void:
	if start_shake:
		position -= _delta_position
		_delta_position = _random_inside_unit_sphere() * (quake / 5.0)
		position += _delta_position

	if started:
		_shake_timer.start(maxf(seconds, 0.0))
		started = false

	set_process(start_shake or started)


func shake_for(duration: float, intensity: float) -> void:
	seconds = duration
	quake = intensity
	started = true
	start_shake = true
	set_process(true)


func reset_shake() -> void:
	if _shake_timer:
		_shake_timer.stop()
	position -= _delta_position
	_delta_position = Vector3.ZERO
	start_shake = false
	started = false
	set_process(false)


func _on_shake_timeout() -> void:
	position -= _delta_position
	_delta_position = Vector3.ZERO
	start_shake = false
	started = false
	set_process(false)


func _random_inside_unit_sphere() -> Vector3:
	for attempt: int in range(32):
		var candidate: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if candidate.length_squared() <= 1.0:
			return candidate
	return Vector3.ZERO
