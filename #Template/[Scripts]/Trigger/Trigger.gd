@tool
extends BaseTrigger
## Trigger - 通用触发器
## 发射 hit_the_line 信号，供其他节点监听

signal hit_the_line

func _on_triggered(_body: Node3D) -> void:
	hit_the_line.emit()
