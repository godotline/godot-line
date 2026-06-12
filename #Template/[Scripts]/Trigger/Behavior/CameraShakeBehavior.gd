@tool
extends TriggerBehavior
class_name CameraShakeBehavior

## CameraShakeBehavior - 相机震动行为组件
## 当父 BaseTrigger 被触发时触发相机震动

@export var power: float = 1.0
@export var duration: float = 2.0

func _on_triggered(_body: Node3D) -> void:
	var follower = CameraFollower.instance
	if follower:
		follower.do_shake(power, duration)
