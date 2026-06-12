extends Node3D
class_name TriggerBehavior

## TriggerBehavior - 触发器行为组件基类
## 作为 BaseTrigger 的子节点使用，实现单一职责的行为组件

## 是否已触发过
var _triggered: bool = false

## 触发时记录的检查点索引
var _checkpoint_index: int = 0

func _ready() -> void:
	## 验证父节点必须是 BaseTrigger
	if not get_parent() is BaseTrigger:
		push_warning("[TriggerBehavior] %s 的父节点不是 BaseTrigger" % name)

## 由父 BaseTrigger 调用
func trigger(body: Node3D) -> void:
	_triggered = true
	_checkpoint_index = LevelManager.checkpoint_count
	_on_triggered(body)

## 子类重写此方法实现具体触发逻辑
func _on_triggered(_body: Node3D) -> void:
	pass

## 子类重写此方法实现 revive 恢复逻辑
func _on_revive() -> void:
	pass
