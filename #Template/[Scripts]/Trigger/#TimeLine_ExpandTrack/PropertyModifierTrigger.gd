@tool
extends BaseTrigger
class_name PropertyModifierTrigger

## PropertyModifierTrigger - 自定义属性修改触发器
## 触发时修改目标节点的指定属性值，复活时恢复原始值。
## 支持即时修改和 Tween 动画过渡。
## 模仿 CameraCurrentTrigger 的 save → apply → revive restore 模式。

@export_group("目标设置")
@export var target_node: NodePath  ## 目标节点路径
@export var property_name: String  ## 属性名称（如 "position"、"scale"、"albedo_color" 等）

@export_group("值设置")
@export var new_value  ## 新值（Variant，支持任意类型）

@export_group("补间动画")
@export var use_tween: bool = false  ## 是否使用 Tween 过渡
@export var tween_duration: float = 1.0  ## 补间持续时间
@export var trans_type: int = 0  ## Tween.TransitionType
@export var ease_type: int = 0  ## Tween.EaseType

@export_group("复活设置")
@export var dont_revive: bool = false  ## 复活时不恢复原始值

var _original_value  ## 触发前的原始属性值
var _checkpoint_index: int = 0
var _applied: bool = false

func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		LevelManager.add_revive_listener(_on_revive)

func _on_triggered(_body: Node3D) -> void:
	if _applied:
		return

	_checkpoint_index = LevelManager.checkpoint_count
	_save_original_value()
	_apply_change()

func _save_original_value() -> void:
	var target = get_node_or_null(target_node)
	if target and not property_name.is_empty():
		_original_value = target.get(property_name)

		if debug_mode:
			print("[PropertyModifierTrigger] ", name, " 保存原始值: ", target_node, ".", property_name, " = ", _original_value)

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

	if debug_mode:
		print("[PropertyModifierTrigger] ", name, " 设置: ", target_node, ".", property_name, " = ", new_value)

func _on_revive() -> void:
	if dont_revive:
		return

	LevelManager.CompareCheckpointIndex(_checkpoint_index, func():
		var target = get_node_or_null(target_node)
		if target and not property_name.is_empty() and _original_value != null:
			target.set(property_name, _original_value)
			_applied = false

			if debug_mode:
				print("[PropertyModifierTrigger] ", name, " 复活恢复: ", target_node, ".", property_name, " = ", _original_value)
	)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)
