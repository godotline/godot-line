@tool
extends EditorPlugin

## Template 插件入口：只负责插件注册、工具栏菜单与子功能派发。
## 各子功能均为独立脚本 — 新建关卡（new_level_dialog.gd / level_factory.gd）、
## GuidanceBox 排序（guidance_box_sorter.gd）、检查点参数回填（checkpoint_capture_applier.gd）、
## 插件商城（plugin_store_dialog.gd / plugin_installer.gd）、更新检查（update_check_dialog.gd）。

const WELCOME_URL := "https://www.cnblogs.com/mmme/p/-/tutorial"
const MARKER_PATH := "user://.first_run_welcome_done"

const DirectionGizmoPlugin := preload("res://addons/template/direction_gizmo_plugin.gd")
const NoteReaderClass := preload("res://addons/template/NoteReader.gd")
const JoltNegativeScaleFixerClass := preload("res://addons/template/jolt_negative_scale_fixer.gd")
const MaterialMergerClass := preload("res://addons/template/material_merger.gd")
const NewLevelDialogClass := preload("res://addons/template/new_level_dialog.gd")
const GuidanceBoxSorterClass := preload("res://addons/template/guidance_box_sorter.gd")
const CheckpointCaptureApplierClass := preload("res://addons/template/checkpoint_capture_applier.gd")
const PluginStoreDialogClass := preload("res://addons/template/plugin_store_dialog.gd")
const PluginInstallerClass := preload("res://addons/template/plugin_installer.gd")
const UpdateCheckDialogClass := preload("res://addons/template/update_check_dialog.gd")
const EventTriggerInspectorPluginClass := preload("res://addons/template/event_trigger_inspector_plugin.gd")
const ComponentInspectorPluginClass := preload("res://addons/template/component_inspector_plugin.gd")
const CheckpointCaptureDebuggerPluginClass := preload("res://addons/template/checkpoint_capture_debugger.gd")

var _menu_button: MenuButton
var _new_level_dialog: ConfirmationDialog
var _store_dialog: ConfirmationDialog
var _update_dialog: ConfirmationDialog
var _direction_gizmo_plugin: EditorNode3DGizmoPlugin
var _event_trigger_inspector_plugin: Object
var _component_inspector_plugin: Object
var _checkpoint_capture_debugger_plugin: EditorDebuggerPlugin


func _enter_tree() -> void:
	PluginInstallerClass.cleanupQuarantine()
	_check_first_run()
	_direction_gizmo_plugin = DirectionGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_direction_gizmo_plugin)
	_event_trigger_inspector_plugin = EventTriggerInspectorPluginClass.new()
	add_inspector_plugin(_event_trigger_inspector_plugin)
	_component_inspector_plugin = ComponentInspectorPluginClass.new()
	add_inspector_plugin(_component_inspector_plugin)
	_checkpoint_capture_debugger_plugin = CheckpointCaptureDebuggerPluginClass.new()
	_checkpoint_capture_debugger_plugin.call("setup", Callable(self, "_apply_checkpoint_snapshot"))
	add_debugger_plugin(_checkpoint_capture_debugger_plugin)

	_menu_button = MenuButton.new()
	var templateVersion: String = PluginRegistry.get_template_version()
	_menu_button.text = "模板 %s" % (templateVersion if not templateVersion.is_empty() else "未知版本")
	_menu_button.tooltip_text = "Template 相关资源"
	_menu_button.switch_on_hover = true

	var popup: PopupMenu = _menu_button.get_popup()
	popup.add_item("模板手册", 0)
	popup.add_item("新建关卡", 1)
	popup.add_item("排序 GuidanceBox", 3)
	popup.add_item("NoteReader", 4)
	popup.add_separator()
	popup.add_item("修复 Jolt 缩放", 5)
	popup.add_item("合并相同材质", 6)
	popup.add_separator()
	popup.add_item("插件商城", 2)
	popup.add_item("检查更新", 7)
	popup.id_pressed.connect(_on_menu_item_pressed)

	add_control_to_container(CONTAINER_TOOLBAR, _menu_button)


func _exit_tree() -> void:
	if _checkpoint_capture_debugger_plugin:
		remove_debugger_plugin(_checkpoint_capture_debugger_plugin)
		_checkpoint_capture_debugger_plugin = null
	if _direction_gizmo_plugin:
		remove_node_3d_gizmo_plugin(_direction_gizmo_plugin)
		_direction_gizmo_plugin = null
	if _event_trigger_inspector_plugin:
		remove_inspector_plugin(_event_trigger_inspector_plugin)
		_event_trigger_inspector_plugin = null
	if _component_inspector_plugin:
		remove_inspector_plugin(_component_inspector_plugin)
		_component_inspector_plugin = null
	if _menu_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _menu_button)
		_menu_button.queue_free()
		_menu_button = null
	if _new_level_dialog and is_instance_valid(_new_level_dialog):
		_new_level_dialog.queue_free()
		_new_level_dialog = null
	if _store_dialog and is_instance_valid(_store_dialog):
		_store_dialog.queue_free()
		_store_dialog = null
	if _update_dialog and is_instance_valid(_update_dialog):
		_update_dialog.queue_free()
		_update_dialog = null


func _check_first_run() -> void:
	if FileAccess.file_exists(MARKER_PATH):
		return
	var f := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if f:
		f.store_string("done")
		f.close()
	await get_tree().process_frame
	OS.shell_open(WELCOME_URL)
	print("[FirstRunWelcome] 已打开项目主页: %s" % WELCOME_URL)


func _on_menu_item_pressed(id: int) -> void:
	match id:
		0:
			OS.shell_open(WELCOME_URL)
		1:
			_show_new_level_dialog()
		3:
			GuidanceBoxSorterClass.sortCurrentScene()
		4:
			_spawn_note_reader()
		5:
			_fix_jolt_negative_scales()
		6:
			_merge_same_materials()
		2:
			_show_store_dialog()
		7:
			_show_update_dialog()


# ===================== NoteReader 谱面生成 =====================

func _spawn_note_reader() -> void:
	var sceneRoot: Node = get_editor_interface().get_edited_scene_root()
	if not sceneRoot:
		_push_error("当前没有打开的场景")
		return

	var existing: Node = sceneRoot.get_node_or_null("NoteReader")
	if existing:
		get_editor_interface().edit_node(existing)
		return

	var reader: Node = NoteReaderClass.new()
	reader.name = "NoteReader"
	sceneRoot.add_child(reader)
	reader.owner = sceneRoot

	get_editor_interface().edit_node(reader)
	get_editor_interface().mark_scene_as_unsaved()
	print("[NoteReader] 已在场景中添加 NoteReader 节点，请在 Inspector 中配置参数（场景字段可直接拖拽 .tscn）并勾选「执行生成」")


# ===================== Jolt 缩放修复 =====================

## Jolt 只看每个碰撞体自身的全局变换。负缩放、剪切、以及挂在
## 「非均匀缩放且带旋转」的父节点下，都会报 "Failed to correctly scale body"。
## 正交的非均匀（Trigger / Ground 拉长盒子）是合法的，不会被平均。
## 算法见 jolt_negative_scale_fixer.gd。
func _fix_jolt_negative_scales() -> void:
	var sceneRoot: Node = get_editor_interface().get_edited_scene_root()
	if not sceneRoot:
		_push_error("当前没有打开的场景")
		return

	var report: Dictionary = JoltNegativeScaleFixerClass.repair(sceneRoot, get_undo_redo())
	if report["fixed"] == 0:
		print("[JoltScale] 未发现需要修复的物理节点")
		return
	get_editor_interface().mark_scene_as_unsaved()
	print("[JoltScale] 已修复 %d 个物理节点（重挂 %d）" % [report["fixed"], report["reparented"]])
	for warning: String in report["warnings"]:
		push_warning("[JoltScale] " + warning)


# ===================== 合并相同材质 =====================

func _merge_same_materials() -> void:
	var sceneRoot: Node = get_editor_interface().get_edited_scene_root()
	if not sceneRoot:
		_push_error("当前没有打开的场景")
		return

	var stats: Dictionary = MaterialMergerClass.merge(sceneRoot, get_undo_redo())
	var refs: int = stats.get("refs", 0)
	if stats.get("replaced", 0) == 0:
		print("[MergeMaterial] 未发现可合并的重复材质（材质引用 %d 个，唯一 %d 个）" % [refs, stats.get("unique", 0)])
		return
	get_editor_interface().mark_scene_as_unsaved()
	print("[MergeMaterial] 已将 %d 处重复材质引用统一到 %d 份唯一材质（总引用 %d）；保存场景后重复的内联子资源会自动移除" % [
		stats.get("replaced", 0), stats.get("unique", 0), refs,
	])


# ===================== 插件商城 / 检查更新 =====================

func _show_store_dialog() -> void:
	if _store_dialog and is_instance_valid(_store_dialog):
		_store_dialog.queue_free()
		_store_dialog = null

	_store_dialog = PluginStoreDialogClass.new()
	_store_dialog.unresizable = false
	add_child(_store_dialog)
	_store_dialog.popup_centered(Vector2i(720, 520))


func _show_update_dialog() -> void:
	if _update_dialog and is_instance_valid(_update_dialog):
		_update_dialog.queue_free()
		_update_dialog = null

	_update_dialog = UpdateCheckDialogClass.new()
	add_child(_update_dialog)
	_update_dialog.popup_centered(Vector2i(520, 360))


# ===================== 新建关卡 =====================

func _show_new_level_dialog() -> void:
	if _new_level_dialog and is_instance_valid(_new_level_dialog):
		_new_level_dialog.queue_free()
		_new_level_dialog = null

	_new_level_dialog = NewLevelDialogClass.new()
	_new_level_dialog.unresizable = false
	add_child(_new_level_dialog)
	_new_level_dialog.popup_centered()
	await get_tree().process_frame
	_new_level_dialog.call("focusNameEdit")


func _push_error(msg: String) -> void:
	push_error("[Template 插件] " + msg)
	printerr("[Template 插件] " + msg)


func _apply_checkpoint_snapshot(snapshot: Dictionary) -> void:
	CheckpointCaptureApplierClass.applySnapshot(snapshot)