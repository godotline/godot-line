@tool
extends BaseTrigger
## @deprecated: 推荐使用 TriggerSignalBehavior 作为 BaseTrigger 的子节点
## Trigger - 通用触发器（向后兼容包装）

signal hit_the_line

func _on_triggered(_body: Node3D) -> void:
	hit_the_line.emit()
