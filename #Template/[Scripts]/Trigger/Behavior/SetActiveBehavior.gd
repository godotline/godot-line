@tool
extends TriggerBehavior
class_name SetActiveBehavior

## SetActiveBehavior - 激活/禁用行为组件
## 触发时激活/禁用指定节点，支持复活时恢复状态

@export_group("激活设置")
@export var active_on_awake: bool = false
@export var actives: Array[SingleActive] = []

var _revive_states: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	
	if active_on_awake:
		_apply_all_actives()

func _on_triggered(_body: Node3D) -> void:
	if active_on_awake:
		return
	
	_save_revive_states()
	_apply_all_actives()
	_register_revive()

func _apply_all_actives() -> void:
	for active_config in actives:
		if active_config and active_config.target:
			var target = get_node_or_null(active_config.target)
			if target:
				if target is Node3D:
					target.visible = active_config.active
				elif target is CanvasItem:
					target.visible = active_config.active

func _save_revive_states() -> void:
	_revive_states.clear()
	for active_config in actives:
		if active_config and active_config.target:
			var target = get_node_or_null(active_config.target)
			if target:
				var original_visible = false
				if target is Node3D:
					original_visible = target.visible
				elif target is CanvasItem:
					original_visible = target.visible
				
				_revive_states.append({
					"target": active_config.target,
					"original_visible": original_visible,
					"dont_revive": active_config.dont_revive
				})

func _on_revive() -> void:
	for state in _revive_states:
		if not state.get("dont_revive", false):
			var target_path = state.get("target", "")
			var target = get_node_or_null(target_path)
			if target:
				var original_visible = state.get("original_visible", false)
				if target is Node3D:
					target.visible = original_visible
				elif target is CanvasItem:
					target.visible = original_visible
