@tool
extends Node3D
class_name TriggerBehavior

## TriggerBehavior - 触发器行为组件基类
## 作为 BaseTrigger 的子节点使用，实现单一职责的行为组件
## 支持 revive 统一恢复和 checkpoint 索引比较

## 是否已触发过（用于 one_shot 等逻辑）
var _triggered: bool = false

## 触发时记录的检查点索引，用于 revive 恢复判断
var _checkpoint_index: int = 0

## 是否注册过 revive 监听器
var _revive_registered: bool = false

func _ready() -> void:
	## 验证父节点必须是 BaseTrigger
	if not get_parent() is BaseTrigger:
		push_warning("[TriggerBehavior] %s 的父节点不是 BaseTrigger，行为组件必须作为 BaseTrigger 的子节点" % name)

## 由父 BaseTrigger 调用，执行触发逻辑
func trigger(body: Node3D) -> void:
	_triggered = true
	_checkpoint_index = LevelManager.checkpoint_count
	_on_triggered(body)

## 子类重写此方法实现具体触发逻辑
func _on_triggered(_body: Node3D) -> void:
	pass

## 注册 revive 监听器（带 checkpoint 索引自动比较）
func _register_revive() -> void:
	if not _revive_registered:
		LevelManager.add_revive_listener(_on_revive_internal)
		_revive_registered = true

## 内部 revive 回调，自动比较 checkpoint 索引
func _on_revive_internal() -> void:
	LevelManager.CompareCheckpointIndex(_checkpoint_index, func():
		_on_revive()
	)

## 子类重写此方法实现 revive 恢复逻辑
func _on_revive() -> void:
	pass

func _exit_tree() -> void:
	if _revive_registered:
		LevelManager.remove_revive_listener(_on_revive_internal)
