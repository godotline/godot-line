extends Node

## SetActiveTrigger - 激活/禁用触发器
## 触发时激活/禁用指定节点，支持复活时恢复状态

@export_group("激活设置")
@export var activeOnAwake: bool = false
@export var actives: Array[SingleActive] = []

var revives: Array[Dictionary] = []
var index: int = 0

func _ready() -> void:
	add_to_group("checkpoint_actives")
	if activeOnAwake:
		_apply_all_actives()

	LevelManager.add_revive_listener(_on_revive)

func trigger(body: Node3D) -> void:
	if activeOnAwake:
		return
	capture_checkpoint_state()
	_apply_all_actives()

func capture_checkpoint_state() -> void:
	if activeOnAwake:
		return
	index = LevelManager.checkpointCount
	_save_revive_states()

func _apply_all_actives() -> void:
	for activeConfig: SingleActive in actives:
		if activeConfig and activeConfig.target:
			var target: Node = get_node_or_null(activeConfig.target)
			if target:
				if target is Node3D:
					target.visible = activeConfig.active
				elif target is CanvasItem:
					target.visible = activeConfig.active

func _save_revive_states() -> void:
	revives.clear()
	for activeConfig: SingleActive in actives:
		if activeConfig and activeConfig.target:
			var target: Node = get_node_or_null(activeConfig.target)
			if target:
				var originalVisible: bool = false
				if target is Node3D:
					originalVisible = target.visible
				elif target is CanvasItem:
					originalVisible = target.visible
				
				revives.append({
					"target": activeConfig.target,
					"original_visible": originalVisible,
					"dont_revive": activeConfig.dontRevive
				})

func _on_revive() -> void:
	if not is_instance_valid(self):
		return
	LevelManager.CompareCheckpointIndex(index, func():
		if not is_instance_valid(self):
			return
		for state: Dictionary in revives:
			if not state.get("dont_revive", false):
				var targetPath: NodePath = state.get("target", NodePath(""))
				var target: Node = get_node_or_null(targetPath)
				if target:
					var originalVisible: bool = state.get("original_visible", false)
					if target is Node3D:
						target.visible = originalVisible
					elif target is CanvasItem:
						target.visible = originalVisible
	)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)