class_name SetActive
extends Node

## SetActiveTrigger - 激活/禁用触发器
## 触发时激活/禁用指定节点，支持复活时恢复状态

static var instance: SetActive = null

@export var activeOnAwake: bool = false
@export var actives: Array[SingleActive] = []

var revives: Array[Dictionary] = []
var index: int = 0

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	instance = self
	add_to_group("checkpoint_actives")
	if activeOnAwake:
		SetActiveFunc()

	LevelManager.add_revive_listener(_on_revive)

func trigger(body: Node3D) -> void:
	if activeOnAwake:
		return
	captureCheckpointState()
	SetActiveFunc()

func captureCheckpointState() -> void:
	if activeOnAwake:
		return
	index = LevelManager.checkpointCount
	_saveReviveStates()

func SetActiveFunc() -> void:
	for activeConfig: SingleActive in actives:
		if activeConfig and activeConfig.target:
			var target: Node = get_node_or_null(activeConfig.target)
			if target:
				SetNodeActive(target, activeConfig.active)

func _saveReviveStates() -> void:
	revives.clear()
	for activeConfig: SingleActive in actives:
		if activeConfig and activeConfig.target:
			var target: Node = get_node_or_null(activeConfig.target)
			if target:
				var originalVisible: bool = false
				if target is Node3D or target is CanvasItem:
					originalVisible = target.visible

				revives.append({
					"target": activeConfig.target,
					"originalVisible": originalVisible,
					"dontRevive": activeConfig.dontRevive
				})

func _on_revive() -> void:
	if not is_instance_valid(self):
		return
	LevelManager.CompareCheckpointIndex(index, func() -> void:
		if not is_instance_valid(self):
			return
		for state: Dictionary in revives:
			if not state.get("dontRevive", false):
				var targetPath: NodePath = state.get("target", NodePath(""))
				var target: Node = get_node_or_null(targetPath)
				if target:
					var originalVisible: bool = state.get("originalVisible", false)
					SetNodeActive(target, originalVisible)
	)

static func SetNodeActive(node: Node, active: bool) -> void:
	if not is_instance_valid(node):
		return
	if node is Node3D or node is CanvasItem:
		node.visible = active
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _exit_tree() -> void:
	if instance == self:
		instance = null
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)
