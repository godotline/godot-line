@tool
extends TriggerBehavior
class_name PropertyModifierBehavior

## PropertyModifierBehavior - 通用属性修改行为组件
## 当父 BaseTrigger 被触发时修改目标节点的指定属性，revive 时恢复原始值

@export_group("目标设置")
@export var target_node: NodePath  ## 目标节点路径
@export var property_name: String  ## 属性名称

@export_group("值设置")
@export var new_value  ## 新值（Variant）

@export_group("补间动画")
@export var use_tween: bool = false
@export var tween_duration: float = 1.0
@export var trans_type: int = 0
@export var ease_type: int = 0

@export_group("复活设置")
@export var dont_revive: bool = false

var _original_value
var _applied: bool = false

func _on_triggered(_body: Node3D) -> void:
	if _applied:
		return

	_save_original_value()
	_apply_change()
	_register_revive()

func _save_original_value() -> void:
	var target = get_node_or_null(target_node)
	if target and not property_name.is_empty():
		_original_value = target.get(property_name)

func _apply_change() -> void:
	var target = get_node_or_null(target_node)
	if not target or property_name.is_empty():
		return

	_applied = true

	if use_tween and tween_duration > 0.0:
		var tween := create_tween()
		tween.set_ease(ease_type)
		tween.set_trans(trans_type)
		tween.tween_property(target, property_name, new_value, tween_duration)
	else:
		target.set(property_name, new_value)

func _on_revive() -> void:
	if dont_revive:
		return

	var target = get_node_or_null(target_node)
	if target and not property_name.is_empty() and _original_value != null:
		target.set(property_name, _original_value)
		_applied = false
