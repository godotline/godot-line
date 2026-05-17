extends BaseTrigger
class_name SetActiveTrigger

## SetActiveTrigger - 激活/禁用触发器
## 触发时激活/禁用指定节点，支持复活时恢复状态

@export_group("激活设置")
@export var active_on_awake: bool = false
@export var actives: Array[Dictionary] = []

var _revive_states: Array[Dictionary] = []
var _checkpoint_index: int = 0

func _ready() -> void:
	super._ready()
	
	if active_on_awake:
		_apply_all_actives()
	
	LevelManager.add_revive_listener(_on_revive)

func _on_triggered(_body: Node3D) -> void:
	if active_on_awake:
		return
	
	_checkpoint_index = LevelManager.checkpoint_count
	_save_revive_states()
	_apply_all_actives()

func _apply_all_actives() -> void:
	for active_config in actives:
		var target_path = active_config.get("target", "")
		var target = get_node_or_null(target_path)
		if target:
			var active_state = active_config.get("active", true)
			if target is Node3D:
				target.visible = active_state
			elif target is CanvasItem:
				target.visible = active_state

func _save_revive_states() -> void:
	_revive_states.clear()
	for active_config in actives:
		var target_path = active_config.get("target", "")
		var target = get_node_or_null(target_path)
		if target:
			var original_visible = false
			if target is Node3D:
				original_visible = target.visible
			elif target is CanvasItem:
				original_visible = target.visible
			
			_revive_states.append({
				"target": target_path,
				"original_visible": original_visible,
				"dont_revive": active_config.get("dont_revive", false)
			})

func _on_revive() -> void:
	LevelManager.CompareCheckpointIndex(_checkpoint_index, func():
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
	)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	LevelManager.remove_revive_listener(_on_revive)
