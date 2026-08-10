@tool
extends Area3D
class_name BaseTrigger

## BaseTrigger - 触发器容器
## 负责碰撞检测和分发给子 TriggerBehavior 组件

signal triggered(body: Node3D)
signal exited(body: Node3D)  # 新增：玩家离开区域信号

@export_group("触发器设置")
@export var one_shot: bool = false
@export var require_playing: bool = true
@export var track_exit: bool = false  # 新增：是否追踪离开事件

@export_group("调试设置")
@export var debug_mode: bool = false

@export_group("组件")
@export var component_script: Script
@export_tool_button("Add Component")
var add_component_action: Callable = func() -> void:
	_add_component()

var _used: bool = false
var _behaviors: Array[Node] = []

func _add_component() -> void:
	if not Engine.is_editor_hint():
		return
	if component_script == null or not component_script.can_instantiate():
		push_error("[BaseTrigger] 请先选择一个可实例化的组件脚本")
		return

	var component: Node = component_script.new() as Node
	if component == null:
		push_error("[BaseTrigger] 组件脚本必须继承 Node")
		return

	var script_name: String = component_script.resource_path.get_file().get_basename()
	if script_name.is_empty():
		script_name = component_script.resource_name
	component.name = script_name if not script_name.is_empty() else "TriggerComponent"
	var scene_owner: Node = owner
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("添加触发器组件")
	undo_redo.add_do_method(self, "add_child", component, true)
	if scene_owner:
		undo_redo.add_do_method(component, "set_owner", scene_owner)
	undo_redo.add_do_method(self, "refresh_behaviors")
	undo_redo.add_undo_method(self, "remove_child", component)
	undo_redo.add_undo_method(self, "refresh_behaviors")
	undo_redo.add_do_reference(component)
	undo_redo.commit_action()

	EditorInterface.mark_scene_as_unsaved()
	notify_property_list_changed()
	call_deferred("_edit_component", component)

func _edit_component(component: Node) -> void:
	if is_instance_valid(component):
		EditorInterface.edit_node(component)

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if track_exit:
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
	_collect_behaviors()

func _collect_behaviors() -> void:
	_behaviors.clear()
	for child: Node in get_children():
		if child.has_method("trigger"):
			_behaviors.append(child)

func _on_body_entered(body: Node3D) -> void:
	if one_shot and _used:
		if debug_mode:
			print("[BaseTrigger] ", name, " 已触发过")
		return
	if require_playing and LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	# Unity triggers compare the incoming collider's Tag. Ordinary trigger
	# components are Player-only; FakePlayerTrigger handles its extra tags
	# through the raw body_entered signal.
	if not _has_player_tag(body):
		return

	_used = true
	if debug_mode:
		print("[BaseTrigger] ", name, " 被触发")

	triggered.emit(body)

	for behavior: Node in _behaviors:
		if is_instance_valid(behavior):
			behavior.trigger(body)

func _has_player_tag(body: Node3D) -> bool:
	return body is Player or body.is_in_group("Player")

## 新增：离开区域处理
func _on_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	if debug_mode:
		print("[BaseTrigger] ", name, " 玩家离开")

	exited.emit(body)

	for behavior: Node in _behaviors:
		if is_instance_valid(behavior) and behavior.has_method("on_exit"):
			behavior.on_exit(body)

## 重新收集行为组件
func refresh_behaviors() -> void:
	_collect_behaviors()
