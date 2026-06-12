@tool
extends TriggerBehavior
class_name TriggerSignalBehavior

## TriggerSignalBehavior - 信号发射行为组件
## 当父 BaseTrigger 被触发时发射 hit_the_line 信号

signal hit_the_line

func _on_triggered(_body: Node3D) -> void:
	hit_the_line.emit()
