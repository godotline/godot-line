@tool
extends EditorPlugin

const OVERRIDE_SCANNER_SCRIPT := preload("res://addons/scene_instance_overrides/scripts/override_scanner.gd")
const OVERRIDE_TRANSACTION_SCRIPT := preload("res://addons/scene_instance_overrides/scripts/override_transaction.gd")
const INSPECTOR_OVERRIDE_POPUP_SCENE_PATH := "res://addons/scene_instance_overrides/inspector_override_popup.tscn"
const PLUGIN_SETTINGS_DIALOG_SCENE := preload("res://addons/scene_instance_overrides/plugin_settings_dialog.tscn")
const SAVE_CONFIRMATION_DIALOG_SCENE := preload("res://addons/scene_instance_overrides/save_confirmation_dialog.tscn")
const INSPECTOR_PLUGIN_SCRIPT := preload("res://addons/scene_instance_overrides/scripts/inspector_plugin.gd")
const PROPERTY_CONTEXT_MENU_SCRIPT := preload("res://addons/scene_instance_overrides/scripts/property_context_menu.gd")
const SCENE_TREE_CONTEXT_MENU_SCRIPT := preload("res://addons/scene_instance_overrides/scripts/scene_tree_context_menu.gd")
const SCENE_TREE_OVERRIDE_BUTTONS_SCRIPT := preload("res://addons/scene_instance_overrides/scripts/scene_tree_override_buttons.gd")
const OVERRIDE_ICON := preload("res://addons/scene_instance_overrides/icons/scene_instance_overrides.svg")
const RECENT_APPLY_UNDO_MENU_NAME := "Undo Last Scene Instance Apply"
const PLUGIN_SETTINGS_MENU_NAME := "Scene Instance Overrides Settings..."
const SHOW_CHILD_NODE_BUTTON_SETTING := "scene_instance_overrides/show_overrides_button_on_child_nodes"
const SHOW_SCENE_DOCK_BUTTON_SETTING := "scene_instance_overrides/show_override_buttons_in_scene_dock"
const DIRTY_PARENT_APPLY_BEHAVIOR_SETTING := "scene_instance_overrides/dirty_parent_apply_behavior"
const OBSOLETE_CONFIRM_BEFORE_APPLY_SETTING := "scene_instance_overrides/confirm_before_applying_overrides"
const INSPECTOR_OVERRIDE_POPUP_LAYOUT_VERSION := 4
const POPUP_REFRESH_MAX_FRAMES := 3
const PROPERTY_EDIT_REFRESH_DELAY := 0.25
const SCENE_TREE_EDITOR_CHANGE_REFRESH_DELAY := 0.25

enum DirtyParentApplyBehavior {
	ASK_EVERY_TIME,
	SAVE_PARENT_AND_APPLY,
	APPLY_TO_BASE_ONLY,
}

var _scanner
var _transaction
var _inspector_override_popup: PopupPanel
var _plugin_settings_dialog: Window
var _save_confirmation_dialog: Window
var _inspector_plugin: EditorInspectorPlugin
var _property_context_menu: EditorContextMenuPlugin
var _scene_tree_context_menu: EditorContextMenuPlugin
var _scene_tree_override_buttons: Node

var _active_context: Dictionary = {}
var _active_node_id: int = 0
var _pending_apply_entries: Array = []
var _pending_apply_context: Dictionary = {}
var _inspector_property_refresh_timer: Timer
var _scene_tree_editor_change_refresh_timer: Timer
var _pending_property_refresh_node_id := 0
var _popup_inspected_node_id := 0
var _popup_expected_instance_root_id := 0
var _popup_expected_source_path := ""
var _popup_host_scene_path := ""
var _popup_inspected_node_path := "."
var _popup_instance_root_path := "."
var _popup_refresh_queued := false
var _popup_target_generation := 0
var _popup_apply_request_generation := -1
var _popup_last_action_position := Vector2i.ZERO
var _popup_reopen_after_action := false


func _enter_tree() -> void:
	_scanner = OVERRIDE_SCANNER_SCRIPT.new()
	_transaction = OVERRIDE_TRANSACTION_SCRIPT.new()
	if _transaction.has_method("setup"):
		_transaction.setup(self)

	_register_editor_settings()
	_create_editor_windows()
	_create_inspector_property_refresh_timer()
	_create_scene_tree_editor_change_refresh_timer()
	_register_inspector_extension()
	_register_editor_undo_redo_refresh_signals()
	_register_context_menu_extensions()
	_create_scene_tree_override_buttons()
	scene_changed.connect(_on_edited_scene_changed)
	scene_saved.connect(_on_edited_scene_saved)
	add_tool_menu_item(PLUGIN_SETTINGS_MENU_NAME, _on_plugin_settings_requested)
	add_tool_menu_item(RECENT_APPLY_UNDO_MENU_NAME, _on_undo_last_apply_requested)


func _exit_tree() -> void:
	remove_tool_menu_item(PLUGIN_SETTINGS_MENU_NAME)
	remove_tool_menu_item(RECENT_APPLY_UNDO_MENU_NAME)
	var editor_undo_redo := EditorInterface.get_editor_undo_redo()
	if (
		is_instance_valid(editor_undo_redo)
		and editor_undo_redo.history_changed.is_connected(
			_on_editor_undo_redo_history_state_changed
		)
	):
		editor_undo_redo.history_changed.disconnect(
			_on_editor_undo_redo_history_state_changed
		)
	if (
		is_instance_valid(editor_undo_redo)
		and editor_undo_redo.version_changed.is_connected(
			_on_editor_undo_redo_history_state_changed
		)
	):
		editor_undo_redo.version_changed.disconnect(
			_on_editor_undo_redo_history_state_changed
		)
	if is_instance_valid(_inspector_plugin):
		remove_inspector_plugin(_inspector_plugin)
	if is_instance_valid(_property_context_menu):
		remove_context_menu_plugin(_property_context_menu)
	if is_instance_valid(_scene_tree_context_menu):
		remove_context_menu_plugin(_scene_tree_context_menu)
	if is_instance_valid(_scene_tree_override_buttons):
		_scene_tree_override_buttons.shutdown()
		_scene_tree_override_buttons.free()
		_scene_tree_override_buttons = null

	if is_instance_valid(_save_confirmation_dialog):
		_save_confirmation_dialog.queue_free()
	if is_instance_valid(_plugin_settings_dialog):
		_plugin_settings_dialog.queue_free()
	if is_instance_valid(_inspector_property_refresh_timer):
		_inspector_property_refresh_timer.stop()
		_inspector_property_refresh_timer.queue_free()
	if is_instance_valid(_scene_tree_editor_change_refresh_timer):
		_scene_tree_editor_change_refresh_timer.stop()
		_scene_tree_editor_change_refresh_timer.queue_free()
	_free_inspector_override_popup()

	_active_context.clear()
	_pending_apply_entries.clear()
	_pending_apply_context.clear()
	_clear_inspector_popup_target()


func _create_editor_windows() -> void:
	_create_inspector_override_popup()

	_plugin_settings_dialog = PLUGIN_SETTINGS_DIALOG_SCENE.instantiate()
	_plugin_settings_dialog.theme = EditorInterface.get_editor_theme()
	_plugin_settings_dialog.show_child_node_button_changed.connect(
		_on_show_child_node_button_setting_changed
	)
	_plugin_settings_dialog.show_scene_dock_button_changed.connect(
		_on_show_scene_dock_button_setting_changed
	)
	_plugin_settings_dialog.dirty_parent_apply_behavior_changed.connect(
		_on_dirty_parent_apply_behavior_setting_changed
	)
	EditorInterface.get_base_control().add_child(_plugin_settings_dialog)

	_save_confirmation_dialog = SAVE_CONFIRMATION_DIALOG_SCENE.instantiate()
	_save_confirmation_dialog.theme = EditorInterface.get_editor_theme()
	_save_confirmation_dialog.save_and_apply_requested.connect(
		_on_save_confirmation_accepted
	)
	_save_confirmation_dialog.apply_without_saving_parent_requested.connect(
		_on_apply_without_saving_parent_requested
	)
	_save_confirmation_dialog.cancel_requested.connect(
		_on_save_confirmation_canceled
	)
	_save_confirmation_dialog.dirty_parent_apply_behavior_changed.connect(
		_on_dirty_parent_apply_behavior_setting_changed
	)
	EditorInterface.get_base_control().add_child(_save_confirmation_dialog)


func _register_editor_settings() -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.has_setting(OBSOLETE_CONFIRM_BEFORE_APPLY_SETTING):
		editor_settings.erase(OBSOLETE_CONFIRM_BEFORE_APPLY_SETTING)
	_register_boolean_editor_setting(
		editor_settings,
		SHOW_CHILD_NODE_BUTTON_SETTING,
		true
	)
	_register_boolean_editor_setting(
		editor_settings,
		SHOW_SCENE_DOCK_BUTTON_SETTING,
		true
	)
	_register_integer_enum_editor_setting(
		editor_settings,
		DIRTY_PARENT_APPLY_BEHAVIOR_SETTING,
		DirtyParentApplyBehavior.ASK_EVERY_TIME,
		PackedStringArray([
			"Ask Every Time",
			"Save Parent and Apply",
			"Apply to Base Only",
		])
	)


func _register_boolean_editor_setting(
		editor_settings: EditorSettings,
		setting_name: String,
		default_value: bool
	) -> void:
	if not editor_settings.has_setting(setting_name):
		editor_settings.set_setting(setting_name, default_value)
	editor_settings.set_initial_value(StringName(setting_name), default_value, false)
	editor_settings.add_property_info({
		"name": setting_name,
		"type": TYPE_BOOL,
	})


func _register_integer_enum_editor_setting(
		editor_settings: EditorSettings,
		setting_name: String,
		default_value: int,
		value_labels: PackedStringArray
	) -> void:
	if not editor_settings.has_setting(setting_name):
		editor_settings.set_setting(setting_name, default_value)
	editor_settings.set_initial_value(StringName(setting_name), default_value, false)
	editor_settings.add_property_info({
		"name": setting_name,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(value_labels),
	})


func _get_boolean_editor_setting(setting_name: String, default_value: bool) -> bool:
	var editor_settings := EditorInterface.get_editor_settings()
	if not editor_settings.has_setting(setting_name):
		return default_value
	return bool(editor_settings.get_setting(setting_name))


func _get_integer_editor_setting(setting_name: String, default_value: int) -> int:
	var editor_settings := EditorInterface.get_editor_settings()
	if not editor_settings.has_setting(setting_name):
		return default_value
	return int(editor_settings.get_setting(setting_name))


func _set_boolean_editor_setting(setting_name: String, value: bool) -> void:
	EditorInterface.get_editor_settings().set_setting(setting_name, value)


func _set_integer_editor_setting(setting_name: String, value: int) -> void:
	EditorInterface.get_editor_settings().set_setting(setting_name, value)


func should_show_override_button_for_node(node: Node, context: Dictionary) -> bool:
	if not is_instance_valid(node) or not context.get("valid", false):
		return false
	var instance_root := context.get("instance_root") as Node
	if not is_instance_valid(instance_root):
		return false
	return (
		node == instance_root
		or _get_boolean_editor_setting(SHOW_CHILD_NODE_BUTTON_SETTING, true)
	)


func _create_inspector_property_refresh_timer() -> void:
	_inspector_property_refresh_timer = Timer.new()
	_inspector_property_refresh_timer.one_shot = true
	_inspector_property_refresh_timer.wait_time = PROPERTY_EDIT_REFRESH_DELAY
	_inspector_property_refresh_timer.timeout.connect(
		_on_inspector_property_refresh_timer_timeout
	)
	add_child(_inspector_property_refresh_timer)


func _create_scene_tree_editor_change_refresh_timer() -> void:
	_scene_tree_editor_change_refresh_timer = Timer.new()
	_scene_tree_editor_change_refresh_timer.one_shot = true
	_scene_tree_editor_change_refresh_timer.wait_time = (
		SCENE_TREE_EDITOR_CHANGE_REFRESH_DELAY
	)
	_scene_tree_editor_change_refresh_timer.timeout.connect(
		_on_scene_tree_editor_change_refresh_timer_timeout
	)
	add_child(_scene_tree_editor_change_refresh_timer)


func _create_inspector_override_popup() -> void:
	var popup_scene := ResourceLoader.load(
		INSPECTOR_OVERRIDE_POPUP_SCENE_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE_DEEP
	) as PackedScene
	if popup_scene == null:
		_inspector_override_popup = null
		return
	_inspector_override_popup = popup_scene.instantiate()
	_inspector_override_popup.theme = EditorInterface.get_editor_theme()
	_inspector_override_popup.set_unparent_when_invisible(true)
	_inspector_override_popup.apply_entries_requested.connect(
		_on_inspector_popup_apply_entries_requested
	)
	_inspector_override_popup.revert_entries_requested.connect(
		_on_inspector_popup_revert_entries_requested
	)
	_inspector_override_popup.popup_hide.connect(_on_inspector_override_popup_hidden)


func _register_inspector_extension() -> void:
	_inspector_plugin = INSPECTOR_PLUGIN_SCRIPT.new()
	_inspector_plugin.setup(self)
	add_inspector_plugin(_inspector_plugin)


func _register_editor_undo_redo_refresh_signals() -> void:
	var editor_undo_redo := EditorInterface.get_editor_undo_redo()
	if (
		is_instance_valid(editor_undo_redo)
		and not editor_undo_redo.history_changed.is_connected(
			_on_editor_undo_redo_history_state_changed
		)
	):
		editor_undo_redo.history_changed.connect(
			_on_editor_undo_redo_history_state_changed
		)
	if (
		is_instance_valid(editor_undo_redo)
		and not editor_undo_redo.version_changed.is_connected(
			_on_editor_undo_redo_history_state_changed
		)
	):
		editor_undo_redo.version_changed.connect(
			_on_editor_undo_redo_history_state_changed
		)


func _register_context_menu_extensions() -> void:
	_property_context_menu = PROPERTY_CONTEXT_MENU_SCRIPT.new()
	_property_context_menu.setup(self)
	add_context_menu_plugin(
		EditorContextMenuPlugin.CONTEXT_SLOT_INSPECTOR_PROPERTY,
		_property_context_menu
	)

	_scene_tree_context_menu = SCENE_TREE_CONTEXT_MENU_SCRIPT.new()
	_scene_tree_context_menu.setup(self)
	add_context_menu_plugin(
		EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE,
		_scene_tree_context_menu
	)


func _create_scene_tree_override_buttons() -> void:
	_scene_tree_override_buttons = SCENE_TREE_OVERRIDE_BUTTONS_SCRIPT.new()
	_scene_tree_override_buttons.setup(
		self,
		_get_boolean_editor_setting(SHOW_SCENE_DOCK_BUTTON_SETTING, true)
	)
	add_child(_scene_tree_override_buttons)


func _schedule_scene_tree_override_button_refresh(context: Dictionary = {}) -> void:
	if not is_instance_valid(_scene_tree_override_buttons):
		return
	if context.is_empty():
		_scene_tree_override_buttons.schedule_refresh()
	else:
		_scene_tree_override_buttons.schedule_refresh_with_context(context)


func _on_edited_scene_changed(_scene_root: Node) -> void:
	if is_instance_valid(_scene_tree_override_buttons):
		_scene_tree_override_buttons.clear_context_cache()
	_schedule_scene_tree_override_button_refresh()


func _on_edited_scene_saved(_scene_path: String) -> void:
	_schedule_scene_tree_override_button_refresh()


func _on_plugin_settings_requested() -> void:
	if not is_instance_valid(_plugin_settings_dialog):
		return
	_plugin_settings_dialog.configure(
		_get_boolean_editor_setting(SHOW_CHILD_NODE_BUTTON_SETTING, true),
		_get_boolean_editor_setting(SHOW_SCENE_DOCK_BUTTON_SETTING, true),
		_get_integer_editor_setting(
			DIRTY_PARENT_APPLY_BEHAVIOR_SETTING,
			DirtyParentApplyBehavior.ASK_EVERY_TIME
		)
	)
	_plugin_settings_dialog.popup_centered(_plugin_settings_dialog.size)


func _on_show_child_node_button_setting_changed(enabled: bool) -> void:
	_set_boolean_editor_setting(SHOW_CHILD_NODE_BUTTON_SETTING, enabled)
	_refresh_current_inspector_after_button_visibility_setting_change()
	_schedule_scene_tree_override_button_refresh()


func _on_show_scene_dock_button_setting_changed(enabled: bool) -> void:
	_set_boolean_editor_setting(SHOW_SCENE_DOCK_BUTTON_SETTING, enabled)
	if is_instance_valid(_scene_tree_override_buttons):
		_scene_tree_override_buttons.set_scene_dock_buttons_enabled(enabled)


func _on_dirty_parent_apply_behavior_setting_changed(behavior: int) -> void:
	_set_integer_editor_setting(
		DIRTY_PARENT_APPLY_BEHAVIOR_SETTING,
		clampi(
			behavior,
			DirtyParentApplyBehavior.ASK_EVERY_TIME,
			DirtyParentApplyBehavior.APPLY_TO_BASE_ONLY
		)
	)


func _refresh_current_inspector_after_button_visibility_setting_change() -> void:
	var inspected_object := EditorInterface.get_inspector().get_edited_object()
	if not inspected_object is Node or not is_instance_valid(inspected_object):
		return
	var context := scan_overrides_for_node(inspected_object)
	call_deferred("_rebuild_inspector_for_node", inspected_object, context)


func _on_editor_undo_redo_history_state_changed() -> void:
	_schedule_inspector_refresh_for_current_edited_node()
	schedule_scene_tree_refresh_after_editor_change()


func schedule_scene_tree_refresh_after_editor_change() -> void:
	if (
		not _get_boolean_editor_setting(SHOW_SCENE_DOCK_BUTTON_SETTING, true)
		or not is_instance_valid(_scene_tree_editor_change_refresh_timer)
	):
		return
	_scene_tree_editor_change_refresh_timer.start()


func _on_scene_tree_editor_change_refresh_timer_timeout() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_scene_tree_editor_change_refresh_timer.start()
		return
	if is_instance_valid(_scene_tree_override_buttons):
		_scene_tree_override_buttons.clear_context_cache()
	_schedule_scene_tree_override_button_refresh()


func _schedule_inspector_refresh_for_current_edited_node() -> void:
	var inspected_object := EditorInterface.get_inspector().get_edited_object()
	if (
		not inspected_object is Node
		or not is_instance_valid(_inspector_property_refresh_timer)
	):
		return
	_pending_property_refresh_node_id = inspected_object.get_instance_id()
	_inspector_property_refresh_timer.start()


func _on_inspector_property_refresh_timer_timeout() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_inspector_property_refresh_timer.start()
		return
	var inspected_object := instance_from_id(_pending_property_refresh_node_id) as Node
	_pending_property_refresh_node_id = 0
	if not is_instance_valid(inspected_object) or not inspected_object.is_inside_tree():
		return
	if EditorInterface.get_inspector().get_edited_object() != inspected_object:
		return
	if (
		is_instance_valid(_inspector_override_popup)
		and _inspector_override_popup.visible
		and _popup_inspected_node_id != 0
	):
		_queue_inspector_popup_refresh(
			_popup_target_generation
		)
		return
	var context := scan_overrides_for_node(inspected_object)
	if context.get("valid", false):
		_rebuild_inspector_for_node(inspected_object, context)
	_schedule_scene_tree_override_button_refresh(context)


func scan_overrides_for_node(node: Node, shared_cache: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(node) or _scanner == null:
		return {
			"valid": false,
			"entries": [],
			"supported_count": 0,
			"error": "The selected node cannot be inspected.",
		}

	var context: Dictionary = _scanner.scan_for_node(node, shared_cache)
	var edited_scene_root := EditorInterface.get_edited_scene_root()
	context["edited_scene_root"] = edited_scene_root
	context["host_path"] = edited_scene_root.scene_file_path if is_instance_valid(edited_scene_root) else ""
	context["entries"] = _normalize_override_entries(context.get("entries", []))
	context["supported_count"] = _count_supported_entries(context["entries"])
	return context


func show_override_popup_from_inspector(
		anchor_control: Control,
		inspected_node: Node,
		expected_instance_root_id: int,
		expected_source_path: String
	) -> void:
	_show_override_popup_for_node(
		anchor_control,
		inspected_node,
		expected_instance_root_id,
		expected_source_path,
		Vector2i(-1, -1)
	)


func show_override_popup_from_scene_tree(
		anchor_control: Control,
		inspected_node: Node,
		popup_screen_position: Vector2i
	) -> void:
	if not is_instance_valid(inspected_node):
		return
	var context := scan_overrides_for_node(inspected_node)
	var instance_root := context.get("instance_root") as Node
	if (
		not context.get("valid", false)
		or not is_instance_valid(instance_root)
		or context.get("entries", []).is_empty()
	):
		_schedule_scene_tree_override_button_refresh()
		return
	_show_override_popup_for_node(
		anchor_control,
		inspected_node,
		instance_root.get_instance_id(),
		str(context.get("source_path", "")),
		popup_screen_position
	)


func _show_override_popup_for_node(
		anchor_control: Control,
		inspected_node: Node,
		expected_instance_root_id: int,
		expected_source_path: String,
		popup_screen_position: Vector2i
	) -> void:
	if not is_instance_valid(anchor_control) or not is_instance_valid(inspected_node):
		_show_error("The override button or target node no longer exists.")
		return
	_recreate_inspector_override_popup_if_layout_is_stale()
	if not is_instance_valid(_inspector_override_popup):
		_show_error("The override popup cannot be opened. Disable and re-enable the plugin, then try again.")
		return

	var context := scan_overrides_for_node(inspected_node)
	var instance_root := context.get("instance_root") as Node
	if (
		not context.get("valid", false)
		or not is_instance_valid(instance_root)
		or instance_root.get_instance_id() != expected_instance_root_id
		or str(context.get("source_path", "")) != expected_source_path
	):
		_show_error("The scene instance target shown in the Inspector has changed. Refresh the Inspector and try again.")
		call_deferred("_rebuild_inspector_for_node", inspected_node)
		return
	if context.get("entries", []).is_empty():
		call_deferred("_rebuild_inspector_for_node", inspected_node)
		return

	_detach_inspector_override_popup_from_previous_window()
	_popup_target_generation += 1
	_popup_reopen_after_action = false
	_remember_inspector_popup_target(context, inspected_node)
	_inspector_override_popup.configure(context)
	if popup_screen_position.x >= 0 and popup_screen_position.y >= 0:
		_inspector_override_popup.open_at_screen_position(
			anchor_control,
			popup_screen_position
		)
	else:
		_inspector_override_popup.open_at_anchor(anchor_control)


func _recreate_inspector_override_popup_if_layout_is_stale() -> void:
	if (
		is_instance_valid(_inspector_override_popup)
		and _inspector_override_popup.has_node("%OverridesTree")
		and _inspector_override_popup.has_node("%SelectionActions")
		and int(_inspector_override_popup.get_meta("layout_version", 0))
			== INSPECTOR_OVERRIDE_POPUP_LAYOUT_VERSION
	):
		return
	_free_inspector_override_popup()
	_create_inspector_override_popup()


func _on_inspector_popup_apply_entries_requested(entry_ids: PackedStringArray) -> void:
	var inspected_node := _get_inspector_popup_target_node()
	if not is_instance_valid(inspected_node):
		_show_error("The Inspector override target node no longer exists.")
		_close_inspector_override_popup()
		return
	_remember_visible_popup_window_for_action()
	_popup_apply_request_generation = _popup_target_generation
	apply_override_entry_ids_from_inspector(
		inspected_node,
		entry_ids,
		_popup_expected_instance_root_id,
		_popup_expected_source_path
	)
	if _pending_apply_entries.is_empty() and not _popup_refresh_queued:
		_popup_reopen_after_action = false
	_popup_apply_request_generation = -1


func _on_inspector_popup_revert_entries_requested(entry_ids: PackedStringArray) -> void:
	var inspected_node := _get_inspector_popup_target_node()
	if not is_instance_valid(inspected_node):
		_show_error("The Inspector override target node no longer exists.")
		_close_inspector_override_popup()
		return
	_remember_visible_popup_window_for_action()
	revert_override_entry_ids_from_inspector(
		inspected_node,
		entry_ids,
		_popup_expected_instance_root_id,
		_popup_expected_source_path
	)


func _get_inspector_popup_target_node() -> Node:
	if _popup_inspected_node_id == 0:
		return null
	return instance_from_id(_popup_inspected_node_id) as Node


func _clear_inspector_popup_target() -> void:
	_popup_inspected_node_id = 0
	_popup_expected_instance_root_id = 0
	_popup_expected_source_path = ""
	_popup_host_scene_path = ""
	_popup_inspected_node_path = "."
	_popup_instance_root_path = "."


func _close_inspector_override_popup() -> void:
	_popup_target_generation += 1
	_popup_reopen_after_action = false
	if is_instance_valid(_inspector_override_popup):
		_inspector_override_popup.hide()
	_clear_inspector_popup_target()


func _on_inspector_override_popup_hidden() -> void:
	if _popup_reopen_after_action:
		return
	_clear_inspector_popup_target()


func _remember_visible_popup_window_for_action() -> void:
	if not is_instance_valid(_inspector_override_popup):
		return
	_popup_last_action_position = _inspector_override_popup.position
	_popup_reopen_after_action = true


func _remember_inspector_popup_target(context: Dictionary, inspected_node: Node) -> void:
	var edited_scene_root := context.get("edited_scene_root") as Node
	var instance_root := context.get("instance_root") as Node
	_popup_inspected_node_id = inspected_node.get_instance_id() if is_instance_valid(inspected_node) else 0
	_popup_expected_instance_root_id = (
		instance_root.get_instance_id() if is_instance_valid(instance_root) else 0
	)
	_popup_expected_source_path = str(context.get("source_path", ""))
	_popup_host_scene_path = str(context.get("host_path", ""))
	_popup_inspected_node_path = _get_scene_relative_node_path(edited_scene_root, inspected_node)
	_popup_instance_root_path = _get_scene_relative_node_path(edited_scene_root, instance_root)


func _get_scene_relative_node_path(scene_root: Node, node: Node) -> String:
	if not is_instance_valid(scene_root) or not is_instance_valid(node):
		return "."
	if scene_root == node:
		return "."
	if not scene_root.is_ancestor_of(node):
		return "."
	return str(scene_root.get_path_to(node))


func _queue_inspector_popup_refresh(
		expected_target_generation: int
	) -> void:
	if (
		expected_target_generation < 0
		or expected_target_generation != _popup_target_generation
		or _popup_refresh_queued
		or not is_instance_valid(_inspector_override_popup)
		or (
			not _inspector_override_popup.visible
			and not _popup_reopen_after_action
		)
	):
		return
	_popup_refresh_queued = true
	call_deferred(
		"_refresh_inspector_popup_from_current_scene",
		expected_target_generation
	)


func _refresh_inspector_popup_from_current_scene(
		expected_target_generation: int
	) -> void:
	var inspected_node: Node
	for _refresh_frame: int in range(POPUP_REFRESH_MAX_FRAMES):
		await get_tree().process_frame
		if (
			expected_target_generation != _popup_target_generation
			or not is_instance_valid(_inspector_override_popup)
		):
			_popup_refresh_queued = false
			return
		inspected_node = _find_reloaded_popup_target_node(_popup_inspected_node_path)
		if not is_instance_valid(inspected_node):
			inspected_node = _find_reloaded_popup_target_node(_popup_instance_root_path)
		if is_instance_valid(inspected_node):
			break
	_popup_refresh_queued = false
	if not is_instance_valid(inspected_node):
		_close_inspector_override_popup()
		if is_instance_valid(_scene_tree_override_buttons):
			_scene_tree_override_buttons.clear_context_cache()
		_schedule_scene_tree_override_button_refresh()
		return

	var refreshed_context := scan_overrides_for_node(inspected_node)
	if (
		not refreshed_context.get("valid", false)
		or str(refreshed_context.get("source_path", "")) != _popup_expected_source_path
	):
		var refreshed_instance_root := _find_reloaded_popup_target_node(
			_popup_instance_root_path
		)
		if is_instance_valid(refreshed_instance_root):
			inspected_node = refreshed_instance_root
			refreshed_context = scan_overrides_for_node(inspected_node)

	if not refreshed_context.get("valid", false):
		_close_inspector_override_popup()
		_rebuild_inspector_for_node(inspected_node, refreshed_context)
		if is_instance_valid(_scene_tree_override_buttons):
			_scene_tree_override_buttons.clear_context_cache()
		_schedule_scene_tree_override_button_refresh()
		return

	if refreshed_context.get("entries", []).is_empty():
		_close_inspector_override_popup()
		_rebuild_inspector_for_node(inspected_node, refreshed_context)
		_schedule_scene_tree_override_button_refresh(refreshed_context)
		return

	_remember_inspector_popup_target(refreshed_context, inspected_node)
	_inspector_override_popup.configure(refreshed_context)
	if not _inspector_override_popup.visible and _popup_reopen_after_action:
		_inspector_override_popup.reopen_at_position(_popup_last_action_position)
	_popup_reopen_after_action = false
	_rebuild_inspector_for_node(inspected_node, refreshed_context)
	_schedule_scene_tree_override_button_refresh(refreshed_context)


func _find_reloaded_popup_target_node(relative_path: String) -> Node:
	var existing_node := _get_inspector_popup_target_node()
	if (
		is_instance_valid(existing_node)
		and existing_node.is_inside_tree()
		and relative_path == _popup_inspected_node_path
	):
		return existing_node

	var host_scene_root := _find_open_popup_host_scene_root()
	if not is_instance_valid(host_scene_root):
		return null
	if relative_path.is_empty() or relative_path == ".":
		return host_scene_root
	return host_scene_root.get_node_or_null(NodePath(relative_path))


func _find_open_popup_host_scene_root() -> Node:
	var edited_scene_root := EditorInterface.get_edited_scene_root()
	if (
		is_instance_valid(edited_scene_root)
		and (
			_popup_host_scene_path.is_empty()
			or edited_scene_root.scene_file_path == _popup_host_scene_path
		)
	):
		return edited_scene_root
	for open_scene_root_value: Variant in EditorInterface.get_open_scene_roots():
		var open_scene_root := open_scene_root_value as Node
		if (
			is_instance_valid(open_scene_root)
			and open_scene_root.scene_file_path == _popup_host_scene_path
		):
			return open_scene_root
	return null


func _detach_inspector_override_popup_from_previous_window() -> void:
	if not is_instance_valid(_inspector_override_popup):
		return
	if _inspector_override_popup.visible:
		_inspector_override_popup.hide()
	var popup_parent := _inspector_override_popup.get_parent()
	if is_instance_valid(popup_parent):
		popup_parent.remove_child(_inspector_override_popup)


func _free_inspector_override_popup() -> void:
	if not is_instance_valid(_inspector_override_popup):
		return
	_detach_inspector_override_popup_from_previous_window()
	_inspector_override_popup.free()
	_inspector_override_popup = null


func apply_override_entry_ids_from_inspector(
		node: Node,
		entry_ids: PackedStringArray,
		expected_instance_root_id: int,
		expected_source_path: String
	) -> void:
	var current_entries := _activate_context_and_collect_current_entries(
		node,
		entry_ids,
		expected_instance_root_id,
		expected_source_path
	)
	if current_entries.is_empty():
		return
	_request_apply_entries(current_entries)


func revert_override_entry_ids_from_inspector(
		node: Node,
		entry_ids: PackedStringArray,
		expected_instance_root_id: int,
		expected_source_path: String
	) -> void:
	var current_entries := _activate_context_and_collect_current_entries(
		node,
		entry_ids,
		expected_instance_root_id,
		expected_source_path
	)
	if current_entries.is_empty():
		return
	_execute_revert_entries(current_entries)


func has_supported_property_override(node: Node, property_name: StringName) -> bool:
	return not _find_property_override(node, property_name).is_empty()


func has_added_node_override(node: Node) -> bool:
	return not _find_added_node_override(node).is_empty()


func apply_property_from_editor(editor_property: EditorProperty) -> void:
	if not is_instance_valid(editor_property):
		return
	var edited_object := editor_property.get_edited_object()
	if not edited_object is Node:
		return
	var context := scan_overrides_for_node(edited_object)
	var entry := _find_property_override_in_context(
		context,
		edited_object,
		editor_property.get_edited_property()
	)
	if entry.is_empty():
		_show_error("This property is not an override that can be applied to the base scene.")
		return
	_active_context = context
	_active_node_id = edited_object.get_instance_id()
	_request_apply_entries([entry])


func revert_property_from_editor(editor_property: EditorProperty) -> void:
	if not is_instance_valid(editor_property):
		return
	var edited_object := editor_property.get_edited_object()
	if not edited_object is Node:
		return
	var context := scan_overrides_for_node(edited_object)
	var entry := _find_property_override_in_context(
		context,
		edited_object,
		editor_property.get_edited_property()
	)
	if entry.is_empty():
		_show_error("This property has no override to revert.")
		return
	_active_context = context
	_active_node_id = edited_object.get_instance_id()
	_execute_revert_entries([entry])


func apply_added_node_from_scene_tree(node: Node) -> void:
	var context := scan_overrides_for_node(node)
	var entry := _find_added_node_override_in_context(context, node)
	if entry.is_empty():
		_show_error("The selected node is not a locally added child that can be applied.")
		return
	_active_context = context
	_active_node_id = node.get_instance_id()
	_request_apply_entries([entry])


func revert_added_node_from_scene_tree(node: Node) -> void:
	var context := scan_overrides_for_node(node)
	var entry := _find_added_node_override_in_context(context, node)
	if entry.is_empty():
		_show_error("The selected node is not a locally added child that can be reverted.")
		return
	_active_context = context
	_active_node_id = node.get_instance_id()
	_execute_revert_entries([entry])


func find_node_from_editor_context_path(path_text: String) -> Node:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree != null:
		var absolute_node := scene_tree.root.get_node_or_null(NodePath(path_text))
		if is_instance_valid(absolute_node):
			return absolute_node

	var edited_scene_root := EditorInterface.get_edited_scene_root()
	if not is_instance_valid(edited_scene_root):
		return null
	if path_text == str(edited_scene_root.get_path()) or path_text == "/" + str(edited_scene_root.name):
		return edited_scene_root

	var pending: Array[Node] = [edited_scene_root]
	while not pending.is_empty():
		var candidate := pending.pop_front()
		if str(candidate.get_path()) == path_text:
			return candidate
		for child in candidate.get_children():
			if child is Node:
				pending.append(child)
	return null


func _find_property_override(node: Node, property_name: StringName) -> Dictionary:
	var context := scan_overrides_for_node(node)
	return _find_property_override_in_context(context, node, property_name)


func _find_property_override_in_context(
		context: Dictionary,
		node: Node,
		property_name: StringName
	) -> Dictionary:
	if not context.get("valid", false):
		return {}
	var instance_root: Node = context.get("instance_root")
	if (
		not is_instance_valid(instance_root)
		or (not instance_root.is_ancestor_of(node) and instance_root != node)
	):
		return {}
	var relative_path := str(instance_root.get_path_to(node))
	for raw_entry in context.get("entries", []):
		var entry: Dictionary = raw_entry
		if entry.get("kind") != "property" or not entry.get("supported", false):
			continue
		if str(entry.get("node_path", ".")) == relative_path and StringName(entry.get("property_name", "")) == property_name:
			return entry
	return {}


func _find_added_node_override(node: Node) -> Dictionary:
	var context := scan_overrides_for_node(node)
	return _find_added_node_override_in_context(context, node)


func _find_added_node_override_in_context(context: Dictionary, node: Node) -> Dictionary:
	if not context.get("valid", false):
		return {}
	var instance_root: Node = context.get("instance_root")
	if not is_instance_valid(instance_root) or not instance_root.is_ancestor_of(node):
		return {}
	var relative_path := str(instance_root.get_path_to(node))
	for raw_entry in context.get("entries", []):
		var entry: Dictionary = raw_entry
		if entry.get("kind") == "added_node" and entry.get("supported", false) and str(entry.get("node_path", "")) == relative_path:
			return entry
	return {}


func _request_apply_entries(entries: Array) -> void:
	if not _pending_apply_entries.is_empty():
		if _is_pending_apply_interaction_active():
			_show_error("Another Apply is waiting for a parent-scene save choice. Complete it first.")
			return
		_clear_pending_apply_request()
	var supported_entries := _filter_supported_entries(entries)
	if supported_entries.is_empty():
		_show_error("No applicable overrides were selected.")
		return
	if _active_context.is_empty():
		_show_error("The target scene information could not be determined.")
		return

	var dirty_blockers := _collect_dirty_dependency_blockers(_active_context)
	if not dirty_blockers.is_empty():
		_show_error(
			"Apply was blocked because the following base or dependent scenes have unsaved changes:\n- "
			+ "\n- ".join(dirty_blockers)
		)
		return

	_pending_apply_entries = supported_entries
	_pending_apply_context = _active_context.duplicate(true)
	_pending_apply_context["popup_target_generation"] = _popup_apply_request_generation
	_hide_inspector_override_popup_while_apply_is_pending()
	_show_parent_save_choice_or_apply()


func _hide_inspector_override_popup_while_apply_is_pending() -> void:
	if (
		_popup_reopen_after_action
		and is_instance_valid(_inspector_override_popup)
		and _inspector_override_popup.visible
	):
		_inspector_override_popup.hide()


func _show_parent_save_choice_or_apply() -> void:
	if _pending_apply_entries.is_empty() or _pending_apply_context.is_empty():
		return
	var host_path := str(_pending_apply_context.get("host_path", ""))
	if EditorInterface.get_unsaved_scenes().has(host_path):
		var dirty_parent_behavior := _get_integer_editor_setting(
			DIRTY_PARENT_APPLY_BEHAVIOR_SETTING,
			DirtyParentApplyBehavior.ASK_EVERY_TIME
		)
		if dirty_parent_behavior == DirtyParentApplyBehavior.SAVE_PARENT_AND_APPLY:
			_save_parent_scene_and_execute_pending_apply()
			return
		if (
			dirty_parent_behavior == DirtyParentApplyBehavior.APPLY_TO_BASE_ONLY
			and _pending_apply_entries_are_property_overrides_only()
		):
			_execute_pending_apply_entries_without_saving_parent()
			return
		_configure_parent_save_confirmation_dialog()
		_save_confirmation_dialog.popup_centered(_save_confirmation_dialog.size)
		return
	_execute_pending_apply_entries()


func _on_save_confirmation_accepted() -> void:
	_save_parent_scene_and_execute_pending_apply()


func _save_parent_scene_and_execute_pending_apply() -> void:
	var save_error := EditorInterface.save_scene()
	if save_error != OK:
		var popup_target_generation := int(
			_pending_apply_context.get("popup_target_generation", -1)
		)
		_pending_apply_entries.clear()
		_pending_apply_context.clear()
		if popup_target_generation == _popup_target_generation:
			_popup_reopen_after_action = false
		_show_error("Failed to save the current parent scene. Error code: %s" % save_error)
		return
	_execute_pending_apply_entries()


func _on_apply_without_saving_parent_requested() -> void:
	call_deferred("_execute_pending_apply_entries_without_saving_parent")


func _configure_parent_save_confirmation_dialog() -> void:
	if not is_instance_valid(_save_confirmation_dialog):
		return
	_save_confirmation_dialog.configure(
		_pending_apply_entries_are_property_overrides_only(),
		_get_integer_editor_setting(
			DIRTY_PARENT_APPLY_BEHAVIOR_SETTING,
			DirtyParentApplyBehavior.ASK_EVERY_TIME
		)
	)


func _pending_apply_entries_are_property_overrides_only() -> bool:
	if _pending_apply_entries.is_empty():
		return false
	for entry_value: Variant in _pending_apply_entries:
		if not entry_value is Dictionary:
			return false
		var entry: Dictionary = entry_value
		if str(entry.get("kind", "")) != "property":
			return false
	return true


func _on_save_confirmation_canceled() -> void:
	_clear_pending_apply_request()


func _clear_pending_apply_request() -> void:
	var popup_target_generation := int(
		_pending_apply_context.get("popup_target_generation", -1)
	)
	_pending_apply_entries.clear()
	_pending_apply_context.clear()
	if popup_target_generation == _popup_target_generation:
		_popup_reopen_after_action = false


func _is_pending_apply_interaction_active() -> bool:
	return (
		is_instance_valid(_save_confirmation_dialog)
		and _save_confirmation_dialog.visible
	)


func _execute_pending_apply_entries() -> void:
	if _pending_apply_entries.is_empty():
		return
	var entries := _pending_apply_entries.duplicate(true)
	var context := _pending_apply_context.duplicate(true)
	var popup_target_generation := int(context.get("popup_target_generation", -1))
	_pending_apply_entries.clear()
	_pending_apply_context.clear()

	var result: Dictionary = _transaction.apply_entries(context, entries)
	if not result.get("success", false):
		_show_error(str(result.get("message", "Failed to apply the overrides to the base scene.")))
		if result.has("rolled_back"):
			if bool(result.get("rolled_back", false)):
				_queue_inspector_popup_refresh(
					popup_target_generation
				)
			elif popup_target_generation == _popup_target_generation:
				_close_inspector_override_popup()
		elif popup_target_generation == _popup_target_generation:
			_popup_reopen_after_action = false
		return

	_show_info(str(result.get("message", "Applied the overrides to the base scene.")))
	_active_context.clear()
	_active_node_id = 0
	_queue_inspector_popup_refresh(popup_target_generation)


func _execute_pending_apply_entries_without_saving_parent() -> void:
	if _pending_apply_entries.is_empty() or _pending_apply_context.is_empty():
		return
	if not _pending_apply_entries_are_property_overrides_only():
		var unsupported_popup_generation := int(
			_pending_apply_context.get("popup_target_generation", -1)
		)
		_show_error(
			"Apply Without Saving Parent currently supports property overrides only."
		)
		_pending_apply_entries.clear()
		_pending_apply_context.clear()
		_queue_inspector_popup_refresh(unsupported_popup_generation)
		return
	var entries := _pending_apply_entries.duplicate(true)
	var context := _pending_apply_context.duplicate(true)
	var popup_target_generation := int(context.get("popup_target_generation", -1))
	_pending_apply_entries.clear()
	_pending_apply_context.clear()

	var result: Dictionary = _transaction.apply_property_entries_without_saving_host(
		context,
		entries
	)
	if not result.get("success", false):
		_show_error(
			str(result.get("message", "Failed to apply without saving the parent scene."))
		)
		_queue_inspector_popup_refresh(popup_target_generation)
		return

	_show_info(
		str(
			result.get(
				"message",
				"Applied the property overrides without saving the parent scene."
			)
		)
	)
	_active_context.clear()
	_active_node_id = 0
	_queue_inspector_popup_refresh(popup_target_generation)


func _execute_revert_entries(entries: Array) -> void:
	var supported_entries := _filter_supported_entries(entries)
	if supported_entries.is_empty():
		_show_error("No revertible overrides were selected.")
		return
	var result: Dictionary = _transaction.revert_entries(_active_context, supported_entries)
	if not result.get("success", false):
		_popup_reopen_after_action = false
		_show_error(str(result.get("message", "Failed to revert the overrides.")))
		return

	_show_info(str(result.get("message", "Reverted the overrides.")))
	_refresh_inspector_after_local_change()


func _on_undo_last_apply_requested() -> void:
	var result: Dictionary = _transaction.undo_last_apply()
	if not result.get("success", false):
		_show_error(str(result.get("message", "Failed to undo the latest Apply operation.")))
		return
	_show_info(str(result.get("message", "Undid the latest Apply operation.")))
	_active_context.clear()
	_active_node_id = 0


func _refresh_inspector_after_local_change() -> void:
	var node := instance_from_id(_active_node_id) as Node
	if not is_instance_valid(node) or not node.is_inside_tree():
		node = _active_context.get("instance_root") as Node
	if not is_instance_valid(node):
		_active_context.clear()
		_active_node_id = 0
		return
	var refreshed_context := scan_overrides_for_node(node)
	if not refreshed_context.get("valid", false):
		_active_context.clear()
		_active_node_id = 0
	else:
		_active_context = refreshed_context
		_active_node_id = node.get_instance_id()
	if (
		is_instance_valid(_inspector_override_popup)
		and _inspector_override_popup.visible
		and _popup_inspected_node_id != 0
	):
		_queue_inspector_popup_refresh(
			_popup_target_generation
		)
	else:
		call_deferred("_rebuild_inspector_for_node", node)
	_schedule_scene_tree_override_button_refresh(refreshed_context)


func _rebuild_inspector_for_node(node: Node, scanned_context: Dictionary = {}) -> void:
	_cancel_pending_property_edit_inspector_refresh()
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var context := scanned_context
	if context.is_empty():
		context = scan_overrides_for_node(node)
	if is_instance_valid(_inspector_plugin):
		var displayed_context := context
		if (
			context.get("valid", false)
			and not should_show_override_button_for_node(node, context)
		):
			displayed_context = context.duplicate(false)
			displayed_context["entries"] = []
		_inspector_plugin.refresh_visible_override_control(node, displayed_context)
	EditorInterface.inspect_object(node)
	var editor_inspector := EditorInterface.get_inspector()
	if is_instance_valid(editor_inspector):
		editor_inspector.edit(null)
		editor_inspector.edit(node)


func _cancel_pending_property_edit_inspector_refresh() -> void:
	_pending_property_refresh_node_id = 0
	if is_instance_valid(_inspector_property_refresh_timer):
		_inspector_property_refresh_timer.stop()


func _collect_dirty_dependency_blockers(context: Dictionary) -> PackedStringArray:
	var source_path := str(context.get("source_path", ""))
	var host_path := str(context.get("host_path", ""))
	var unsaved_scenes := EditorInterface.get_unsaved_scenes()
	var blockers := PackedStringArray()
	if _transaction != null and _transaction.has_method("find_open_dirty_dependency_paths"):
		for dirty_path: String in _transaction.find_open_dirty_dependency_paths(context):
			if dirty_path != host_path and not blockers.has(dirty_path):
				blockers.append(dirty_path)
	for unsaved_path in unsaved_scenes:
		if unsaved_path == host_path:
			continue
		if unsaved_path == source_path or _open_scene_references_source(unsaved_path, source_path):
			var blocker_label := unsaved_path if not unsaved_path.is_empty() else "Unsaved new scene"
			if not blockers.has(blocker_label):
				blockers.append(blocker_label)
	return blockers


func _open_scene_references_source(scene_path: String, source_path: String) -> bool:
	for root in EditorInterface.get_open_scene_roots():
		if not root is Node or root.scene_file_path != scene_path:
			continue
		var pending: Array[Node] = [root]
		while not pending.is_empty():
			var node := pending.pop_front()
			if node != root and node.scene_file_path == source_path:
				return true
			for child in node.get_children():
				if child is Node:
					pending.append(child)
	return false


func _normalize_override_entries(raw_entries: Array) -> Array:
	var normalized_entries: Array = []
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		match str(entry.get("kind", "unsupported")):
			"supported_property", "property_override":
				entry["kind"] = "property"
			"added", "added_child", "added_node_override":
				entry["kind"] = "added_node"
			"property", "added_node", "unsupported":
				pass
			_:
				entry["kind"] = "unsupported"
		entry["supported"] = bool(entry.get("supported", entry["kind"] != "unsupported"))
		entry["selected"] = bool(entry.get("selected", entry["supported"]))
		normalized_entries.append(entry)
	return normalized_entries


func _filter_supported_entries(entries: Array) -> Array:
	var supported_entries: Array = []
	for raw_entry in entries:
		if raw_entry is Dictionary and raw_entry.get("supported", false):
			supported_entries.append(raw_entry.duplicate(true))
	return supported_entries


func _activate_context_and_collect_current_entries(
		node: Node,
		entry_ids: PackedStringArray,
		expected_instance_root_id: int,
		expected_source_path: String
	) -> Array:
	if not is_instance_valid(node):
		_show_error("The Inspector override target node no longer exists.")
		return []

	var requested_ids: Dictionary = {}
	for entry_id: String in entry_ids:
		if entry_id.is_empty() or requested_ids.has(entry_id):
			_show_error("An override entry ID is empty or duplicated.")
			return []
		requested_ids[entry_id] = true
	if requested_ids.is_empty():
		_show_error("No override entries were found to process.")
		return []

	var context := scan_overrides_for_node(node)
	if not context.get("valid", false):
		_show_error(str(context.get("error", "Failed to rescan the scene instance overrides.")))
		return []

	var instance_root := context.get("instance_root") as Node
	if (
		not is_instance_valid(instance_root)
		or instance_root.get_instance_id() != expected_instance_root_id
		or str(context.get("source_path", "")) != expected_source_path
	):
		_show_error("The scene instance target shown in the Inspector has changed. Refresh the Inspector and try again.")
		call_deferred("_rebuild_inspector_for_node", node)
		return []

	var current_entries: Array = []
	for raw_entry in context.get("entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry_id := str(raw_entry.get("id", ""))
		if requested_ids.has(entry_id) and bool(raw_entry.get("supported", false)):
			current_entries.append(raw_entry)

	if current_entries.size() != requested_ids.size():
		_show_error("The override list has changed. Refresh the Inspector and try again.")
		call_deferred("_rebuild_inspector_for_node", node)
		return []
	_active_context = context
	_active_node_id = node.get_instance_id()
	return current_entries


func _count_supported_entries(entries: Array) -> int:
	var count := 0
	for entry in entries:
		if entry is Dictionary and entry.get("supported", false):
			count += 1
	return count


func _show_info(message: String) -> void:
	print("[Scene Instance Overrides] %s" % message)
	EditorInterface.get_editor_toaster().push_toast(message, EditorToaster.SEVERITY_INFO)


func _show_error(message: String) -> void:
	push_error("[Scene Instance Overrides] %s" % message)
	EditorInterface.get_editor_toaster().push_toast(message, EditorToaster.SEVERITY_ERROR)
