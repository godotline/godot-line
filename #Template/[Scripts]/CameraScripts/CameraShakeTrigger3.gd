extends Node3D
class_name CameraShakeTrigger3

## Pure component trigger for CameraShake3. Add it below a BaseTrigger node.

@export var camera_shake: CameraShake3
@export var seconds: float = 1.0
@export var quake: float = 2.0


func trigger(body: Node3D) -> void:
	if not body is Player:
		return
	var shake: CameraShake3 = camera_shake if is_instance_valid(camera_shake) else CameraShake3.instance
	if not shake:
		push_warning("CameraShakeTrigger3.gd: CameraShake3 was not found")
		return
	shake.shake_for(seconds, quake)
