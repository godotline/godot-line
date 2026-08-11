class_name Setactive
extends Node

## SetActiveTrigger - 激活/禁用触发器
## 触发时激活/禁用指定节点，支持复活时恢复状态

@export_group("激活设置")
@export var activeOnAwake: bool = false
@export var actives: Array[SingleActive] = []

var revives: Array[Dictionary] = []
var index: int = 0

## Godot 没有 GameObject.SetActive；曲线救国地组合处理状态与可见性。
static func setActive(target: Node, active: bool) -> void:
	target.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if target is Node3D:
		target.visible = active
	elif target is CanvasItem:
		target.visible = active

func _ready() -> void:
	add_to_group("checkpoint_actives")
	if activeOnAwake:
		_apply_all_actives()

	LevelManager.add_revive_listener(_on_revive)

func trigger(_body: Node3D) -> void:
	if activeOnAwake:
		return
	index = LevelManager.checkpoint_count
	_apply_all_actives()

func capture_checkpoint_state() -> void:
	if activeOnAwake:
		return
	_add_revives()

func _add_revives() -> void:
	_save_revive_states()

func _apply_all_actives() -> void:
	for active_config: SingleActive in actives:
		if active_config and active_config.target:
			var target: Node = get_node_or_null(active_config.target)
			if target:
				setActive(target, active_config.active)

func _save_revive_states() -> void:
	for active_config: SingleActive in actives:
		if active_config and active_config.target:
			var target: Node = get_node_or_null(active_config.target)
			if target:
				var active: bool = false
				if target is Node3D:
					active = target.visible
				elif target is CanvasItem:
					active = target.visible
				
				revives.append({
					"target": active_config.target,
					"active": active,
					"dontRevive": active_config.dontRevive
				})

func _on_revive() -> void:
	if not is_instance_valid(self):
		return
	LevelManager.CompareCheckpointIndex(index, func():
		if not is_instance_valid(self):
			return
		for revive: Dictionary in revives:
			if not revive.get("dontRevive", false):
				var target_path: NodePath = revive.get("target", NodePath(""))
				var target: Node = get_node_or_null(target_path)
				if target:
					var active: bool = revive.get("active", false)
					setActive(target, active)
	)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)
