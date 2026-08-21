@tool
extends PopupPanel

signal apply_entries_requested(entry_ids: PackedStringArray)
signal revert_entries_requested(entry_ids: PackedStringArray)

const KIND_PROPERTY := "property"
const KIND_ADDED_NODE := "added_node"
const KIND_UNSUPPORTED := "unsupported"
const COMPACT_POPUP_WIDTH := 372.0
const MINIMUM_POPUP_HEIGHT := 180.0
const MAXIMUM_POPUP_HEIGHT := 400.0
const POPUP_CHROME_HEIGHT := 110.0
const TREE_ROW_HEIGHT := 23.0
const TREE_VIEW_PADDING := 2.0
const MINIMUM_VISIBLE_TREE_ROWS := 3
const MAXIMUM_VISIBLE_TREE_ROWS := 12
const VALUE_PREVIEW_LIMIT := 28
const NODE_ICON_SIZE := 16.0
const ADDED_MARKER_SIZE := 10.0
const ADDED_MARKER_GAP := 2.0
const POPUP_CORNER_RADIUS := 6.0

const OVERRIDE_ICON := preload("res://addons/scene_instance_overrides/icons/scene_instance_overrides.svg")

@onready var _header_icon: TextureRect = %HeaderIcon
@onready var _header_title_label: Label = %HeaderTitleLabel
@onready var _context_label: Label = %ContextLabel
@onready var _outer_margin: MarginContainer = %OuterMargin
@onready var _overrides_tree: Tree = %OverridesTree
@onready var _selection_actions: HBoxContainer = %SelectionActions
@onready var _selection_summary: Label = %SelectionSummary
@onready var _selection_revert_button: Button = %SelectionRevertButton
@onready var _selection_apply_button: Button = %SelectionApplyButton
@onready var _revert_all_button: Button = %RevertAllButton
@onready var _apply_all_button: Button = %ApplyAllButton

var _entries: Array[Dictionary] = []
var _supported_entry_ids := PackedStringArray()
var _selected_entry_ids := PackedStringArray()
var _source_path := ""
var _instance_name := "Scene Instance"
var _instance_root: Node
var _node_items: Dictionary = {}
var _collapsed_node_paths: Dictionary = {}
var _estimated_tree_row_count := 1
var _first_actionable_item: TreeItem
var _script_icon_cache: Dictionary = {}
var _added_node_icon_cache: Dictionary = {}
var _popup_resize_queued := false


func _ready() -> void:
	if Engine.is_editor_hint():
		theme = EditorInterface.get_editor_theme()
	_apply_rounded_popup_panel_style()
	_overrides_tree.select_mode = Tree.SELECT_ROW
	_overrides_tree.set_column_expand(0, true)
	_overrides_tree.set_column_clip_content(0, true)
	_refresh_popup_content()
	_queue_popup_resize()


func configure(context: Dictionary) -> void:
	_source_path = str(context.get("source_path", ""))
	_entries = _normalize_entries(context.get("entries", []))
	_supported_entry_ids = _collect_supported_entry_ids(_entries)
	_instance_root = context.get("instance_root") as Node
	_instance_name = str(_instance_root.name) if is_instance_valid(_instance_root) else "Scene Instance"
	_estimated_tree_row_count = _estimate_tree_row_count_from_entries()
	if is_node_ready():
		_refresh_popup_content()


func calculate_compact_popup_size(available_size: Vector2i = Vector2i.ZERO) -> Vector2i:
	var editor_scale := _get_editor_scale()
	var visible_rows := clampi(
		_get_visible_tree_row_count_for_sizing(),
		MINIMUM_VISIBLE_TREE_ROWS,
		MAXIMUM_VISIBLE_TREE_ROWS
	)
	var estimated_height := roundi(clampf(
		(POPUP_CHROME_HEIGHT + visible_rows * TREE_ROW_HEIGHT) * editor_scale,
		MINIMUM_POPUP_HEIGHT * editor_scale,
		MAXIMUM_POPUP_HEIGHT * editor_scale
	))
	var popup_size := Vector2i(
		roundi(COMPACT_POPUP_WIDTH * editor_scale),
		maxi(estimated_height, _get_theme_aware_popup_minimum_height())
	)
	if available_size.x > 0:
		popup_size.x = mini(popup_size.x, available_size.x)
	if available_size.y > 0:
		popup_size.y = mini(popup_size.y, available_size.y)
	return popup_size


func _estimate_tree_row_count_from_entries() -> int:
	var represented_node_paths: Dictionary = {".": true}
	var leaf_count := 0
	var added_descendant_count := 0
	for entry: Dictionary in _entries:
		_record_node_path_and_ancestors(
			represented_node_paths,
			str(entry.get("node_path", "."))
		)
		if str(entry.get("kind", KIND_UNSUPPORTED)) == KIND_ADDED_NODE:
			var added_root := entry.get("current_value") as Node
			if is_instance_valid(added_root):
				added_descendant_count += _count_node_descendants(added_root)
		else:
			leaf_count += 1
	return represented_node_paths.size() + leaf_count + added_descendant_count


func _record_node_path_and_ancestors(node_paths: Dictionary, node_path: String) -> void:
	var current_path := _normalize_node_path(node_path)
	while current_path != ".":
		node_paths[current_path] = true
		var separator_index := current_path.rfind("/")
		current_path = "." if separator_index < 0 else current_path.left(separator_index)
	node_paths["."] = true


func _count_node_descendants(node: Node) -> int:
	var descendant_count := 0
	for child: Node in node.get_children(false):
		descendant_count += 1 + _count_node_descendants(child)
	return descendant_count


func _get_visible_tree_row_count_for_sizing() -> int:
	if not is_instance_valid(_overrides_tree):
		return _estimated_tree_row_count
	var hidden_root := _overrides_tree.get_root()
	if hidden_root == null:
		return _estimated_tree_row_count
	var visible_row_count := 0
	var child := hidden_root.get_first_child()
	while child != null:
		visible_row_count += _count_visible_item_rows(child)
		child = child.get_next()
	return visible_row_count


func _count_visible_item_rows(item: TreeItem) -> int:
	var visible_row_count := 1
	if item.is_collapsed():
		return visible_row_count
	var child := item.get_first_child()
	while child != null:
		visible_row_count += _count_visible_item_rows(child)
		child = child.get_next()
	return visible_row_count


func get_compact_popup_size(_anchor_control: Control = null) -> Vector2i:
	return calculate_compact_popup_size()


func open_at_anchor(anchor_control: Control) -> void:
	if not is_instance_valid(anchor_control):
		return
	var editor_scale := _get_editor_scale()
	var anchor_screen_position := anchor_control.get_screen_position()
	var anchor_position := Vector2i(
		roundi(anchor_screen_position.x),
		roundi(anchor_screen_position.y)
	)
	var anchor_size := Vector2i(
		roundi(anchor_control.size.x),
		roundi(anchor_control.size.y)
	)
	var anchor_window := anchor_control.get_window()
	var screen_bounds: Rect2i
	if Engine.is_editor_hint() and EditorInterface.is_multi_window_enabled():
		screen_bounds = DisplayServer.screen_get_usable_rect(anchor_window.current_screen)
	else:
		anchor_position -= anchor_window.position
		screen_bounds = Rect2i(Vector2i.ZERO, anchor_window.size)

	var popup_size := calculate_compact_popup_size(screen_bounds.size)
	var popup_position := Vector2i(
		anchor_position.x,
		anchor_position.y + anchor_size.y + roundi(2.0 * editor_scale)
	)
	var bounds_end := screen_bounds.position + screen_bounds.size
	if popup_position.y + popup_size.y > bounds_end.y:
		popup_position.y = anchor_position.y - popup_size.y - roundi(2.0 * editor_scale)
	popup_position.x = clampi(
		popup_position.x,
		screen_bounds.position.x,
		maxi(screen_bounds.position.x, bounds_end.x - popup_size.x)
	)
	popup_position.y = clampi(
		popup_position.y,
		screen_bounds.position.y,
		maxi(screen_bounds.position.y, bounds_end.y - popup_size.y)
	)
	popup_exclusive(anchor_control, Rect2i(popup_position, popup_size))
	_queue_popup_resize()


func open_at_screen_position(anchor_control: Control, screen_position: Vector2i) -> void:
	if not is_instance_valid(anchor_control):
		return
	var anchor_window := anchor_control.get_window()
	var popup_position := screen_position
	var screen_bounds: Rect2i
	if Engine.is_editor_hint() and EditorInterface.is_multi_window_enabled():
		screen_bounds = DisplayServer.screen_get_usable_rect(anchor_window.current_screen)
	else:
		popup_position -= anchor_window.position
		screen_bounds = Rect2i(Vector2i.ZERO, anchor_window.size)

	var editor_scale := _get_editor_scale()
	popup_position += Vector2i(
		roundi(4.0 * editor_scale),
		roundi(4.0 * editor_scale)
	)
	var popup_size := calculate_compact_popup_size(screen_bounds.size)
	var bounds_end := screen_bounds.position + screen_bounds.size
	if popup_position.y + popup_size.y > bounds_end.y:
		popup_position.y -= popup_size.y + roundi(8.0 * editor_scale)
	popup_position.x = clampi(
		popup_position.x,
		screen_bounds.position.x,
		maxi(screen_bounds.position.x, bounds_end.x - popup_size.x)
	)
	popup_position.y = clampi(
		popup_position.y,
		screen_bounds.position.y,
		maxi(screen_bounds.position.y, bounds_end.y - popup_size.y)
	)
	popup_exclusive(anchor_control, Rect2i(popup_position, popup_size))
	_queue_popup_resize()


func reopen_at_position(preferred_position: Vector2i) -> void:
	var editor_base_control := EditorInterface.get_base_control()
	if not is_instance_valid(editor_base_control):
		return
	var editor_window := editor_base_control.get_window()
	var screen_bounds: Rect2i
	if Engine.is_editor_hint() and EditorInterface.is_multi_window_enabled():
		screen_bounds = DisplayServer.screen_get_usable_rect(editor_window.current_screen)
	else:
		screen_bounds = Rect2i(Vector2i.ZERO, editor_window.size)

	var popup_size := calculate_compact_popup_size(screen_bounds.size)
	var bounds_end := screen_bounds.position + screen_bounds.size
	var popup_position := Vector2i(
		clampi(
			preferred_position.x,
			screen_bounds.position.x,
			maxi(screen_bounds.position.x, bounds_end.x - popup_size.x)
		),
		clampi(
			preferred_position.y,
			screen_bounds.position.y,
			maxi(screen_bounds.position.y, bounds_end.y - popup_size.y)
		)
	)
	popup_exclusive(
		editor_base_control,
		Rect2i(popup_position, popup_size)
	)
	_queue_popup_resize()


func _normalize_entries(raw_entries: Variant) -> Array[Dictionary]:
	var normalized_entries: Array[Dictionary] = []
	if not raw_entries is Array:
		return normalized_entries
	for raw_entry: Variant in raw_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry.duplicate(false)
		entry["id"] = str(entry.get("id", ""))
		entry["kind"] = _normalize_kind(str(entry.get("kind", KIND_UNSUPPORTED)))
		entry["node_path"] = _normalize_node_path(str(entry.get("node_path", ".")))
		entry["property_name"] = str(entry.get("property_name", ""))
		entry["reason"] = str(entry.get("reason", ""))
		entry["supported"] = (
			bool(entry.get("supported", false))
			and entry["kind"] != KIND_UNSUPPORTED
			and not String(entry["id"]).is_empty()
		)
		normalized_entries.append(entry)
	return normalized_entries


func _normalize_kind(kind: String) -> String:
	match kind.strip_edges().to_lower():
		KIND_PROPERTY, "supported_property", "property_override":
			return KIND_PROPERTY
		KIND_ADDED_NODE, "added", "node_added", "added_node_override":
			return KIND_ADDED_NODE
		_:
			return KIND_UNSUPPORTED


func _normalize_node_path(node_path: String) -> String:
	var normalized_path := node_path.strip_edges()
	if normalized_path.is_empty() or normalized_path == ".":
		return "."
	if normalized_path.begins_with("./"):
		return normalized_path.substr(2)
	return normalized_path


func _collect_supported_entry_ids(entries: Array[Dictionary]) -> PackedStringArray:
	var entry_ids := PackedStringArray()
	for entry: Dictionary in entries:
		if bool(entry.get("supported", false)):
			entry_ids.append(str(entry.get("id", "")))
	return entry_ids


func _refresh_popup_content() -> void:
	_header_title_label.text = "Overrides (%d)" % _entries.size()
	var source_name := _source_path.get_file()
	_context_label.text = "%s / %s" % [
		_instance_name,
		source_name if not source_name.is_empty() else "Base scene unavailable",
	]
	_context_label.tooltip_text = _source_path if not _source_path.is_empty() else "The base scene path is unavailable."
	_build_override_tree()

	var has_supported_entries := not _supported_entry_ids.is_empty()
	_revert_all_button.disabled = not has_supported_entries
	_apply_all_button.disabled = not has_supported_entries
	_apply_editor_appearance()
	if _first_actionable_item != null:
		_first_actionable_item.select(0)
		_refresh_selection_actions()
	else:
		_clear_selection_actions()
	_update_tree_minimum_height()
	_queue_popup_resize()


func _update_tree_minimum_height() -> void:
	var visible_rows := clampi(
		_get_visible_tree_row_count_for_sizing(),
		MINIMUM_VISIBLE_TREE_ROWS,
		MAXIMUM_VISIBLE_TREE_ROWS
	)
	_overrides_tree.custom_minimum_size.y = ceili(
		_get_visible_tree_items_height(visible_rows)
		+ _get_tree_panel_vertical_padding()
		+ TREE_VIEW_PADDING * _get_editor_scale()
	)


func _get_visible_tree_items_height(visible_rows: int) -> float:
	var fallback_row_height := _get_tree_row_height_pixels()
	var visible_items: Array[TreeItem] = []
	var hidden_root := _overrides_tree.get_root()
	if hidden_root != null:
		var child := hidden_root.get_first_child()
		while child != null and visible_items.size() < visible_rows:
			_append_visible_tree_items(child, visible_items, visible_rows)
			child = child.get_next()

	var rows_height := 0.0
	for item: TreeItem in visible_items:
		var item_height := float(_overrides_tree.get_item_area_rect(item, -1).size.y)
		rows_height += maxf(item_height, fallback_row_height)
	rows_height += maxf(0.0, float(visible_rows - visible_items.size())) * fallback_row_height
	return rows_height


func _append_visible_tree_items(
		item: TreeItem,
		visible_items: Array[TreeItem],
		maximum_items: int
	) -> void:
	if visible_items.size() >= maximum_items:
		return
	visible_items.append(item)
	if item.is_collapsed():
		return
	var child := item.get_first_child()
	while child != null and visible_items.size() < maximum_items:
		_append_visible_tree_items(child, visible_items, maximum_items)
		child = child.get_next()


func _get_tree_panel_vertical_padding() -> float:
	if _overrides_tree.has_theme_stylebox("panel", "Tree"):
		return _overrides_tree.get_theme_stylebox("panel", "Tree").get_minimum_size().y
	return 0.0


func _get_tree_row_height_pixels() -> float:
	var editor_scale := _get_editor_scale()
	var minimum_row_height := TREE_ROW_HEIGHT * editor_scale
	if not is_instance_valid(_overrides_tree):
		return minimum_row_height
	var font := _overrides_tree.get_theme_font("font", "Tree")
	var font_size := _overrides_tree.get_theme_font_size("font_size", "Tree")
	var themed_content_height := float(font.get_height(font_size))
	themed_content_height = maxf(themed_content_height, NODE_ICON_SIZE * editor_scale)
	themed_content_height += maxf(
		0.0,
		float(_overrides_tree.get_theme_constant("inner_item_margin_top", "Tree"))
	)
	themed_content_height += maxf(
		0.0,
		float(_overrides_tree.get_theme_constant("inner_item_margin_bottom", "Tree"))
	)
	themed_content_height += maxf(
		0.0,
		float(_overrides_tree.get_theme_constant("v_separation", "Tree"))
	)
	return maxf(minimum_row_height, ceilf(themed_content_height))


func _get_theme_aware_popup_minimum_height() -> int:
	if not is_instance_valid(_outer_margin):
		return 0
	var required_height := _outer_margin.get_combined_minimum_size().y
	if has_theme_stylebox("panel", "PopupPanel"):
		required_height += get_theme_stylebox("panel", "PopupPanel").get_minimum_size().y
	required_height = maxf(required_height, get_contents_minimum_size().y)
	return ceili(required_height + 2.0 * _get_editor_scale())


func _queue_popup_resize() -> void:
	if _popup_resize_queued:
		return
	_popup_resize_queued = true
	call_deferred("_resize_visible_popup_to_current_rows")


func _resize_visible_popup_to_current_rows() -> void:
	_popup_resize_queued = false
	if visible:
		_update_tree_minimum_height()
		size = calculate_compact_popup_size()


func _build_override_tree() -> void:
	_overrides_tree.clear()
	_node_items.clear()
	_first_actionable_item = null
	_estimated_tree_row_count = 0
	var hidden_root := _overrides_tree.create_item()
	var instance_item := _overrides_tree.create_item(hidden_root)
	_configure_node_item(instance_item, ".", _instance_root, false)
	_node_items["."] = instance_item

	for entry: Dictionary in _entries:
		_ensure_node_item(str(entry.get("node_path", ".")))

	for entry: Dictionary in _entries:
		var node_path := str(entry.get("node_path", "."))
		var node_item := _node_items.get(node_path) as TreeItem
		if node_item == null:
			continue
		var kind := str(entry.get("kind", KIND_UNSUPPORTED))
		if kind == KIND_ADDED_NODE:
			_configure_added_node_item(node_item, entry)
			_append_entry_id_to_item(node_item, str(entry.get("id", "")))
			_append_added_subtree_items(node_item, entry)
			continue
		if (
			kind == KIND_UNSUPPORTED
			and str(entry.get("property_name", "")) == "@added_node"
			and entry.get("current_value") is Node
		):
			_configure_added_node_item(node_item, entry)
		_configure_entry_leaf(_overrides_tree.create_item(node_item), entry)
		if bool(entry.get("supported", false)):
			_append_entry_id_to_item(node_item, str(entry.get("id", "")))

	_restore_collapsed_items()


func _ensure_node_item(node_path: String) -> TreeItem:
	var normalized_path := _normalize_node_path(node_path)
	if _node_items.has(normalized_path):
		return _node_items[normalized_path] as TreeItem
	var separator_index := normalized_path.rfind("/")
	var parent_path := "." if separator_index < 0 else normalized_path.left(separator_index)
	var parent_item := _ensure_node_item(parent_path)
	var node_item := _overrides_tree.create_item(parent_item)
	_configure_node_item(node_item, normalized_path, _find_instance_node(normalized_path), false)
	_node_items[normalized_path] = node_item
	return node_item


func _configure_node_item(item: TreeItem, node_path: String, node: Node, is_added: bool) -> void:
	_estimated_tree_row_count += 1
	item.set_custom_minimum_height(roundi(TREE_ROW_HEIGHT * _get_editor_scale()))
	var display_name := _get_node_display_name(node_path, node)
	item.set_text(0, display_name)
	item.set_tooltip_text(0, _get_node_tooltip(node_path, node, is_added))
	item.set_icon(0, _get_node_icon(node))
	item.set_metadata(0, {
		"row_kind": "node",
		"node_path": node_path,
		"property_name": "",
		"entry_ids": PackedStringArray(),
		"is_added": is_added,
	})
	if is_added:
		_apply_added_node_appearance(item)
	else:
		_apply_base_node_appearance(item)


func _configure_added_node_item(item: TreeItem, entry: Dictionary) -> void:
	var node_path := str(entry.get("node_path", "."))
	var added_node := _find_entry_node(entry)
	item.set_text(0, _get_node_display_name(node_path, added_node))
	item.set_tooltip_text(0, _get_node_tooltip(node_path, added_node, true))
	item.set_icon(0, _get_node_icon(added_node))
	var metadata := _get_item_metadata(item)
	metadata["is_added"] = true
	item.set_metadata(0, metadata)
	_apply_added_node_appearance(item)


func _configure_entry_leaf(item: TreeItem, entry: Dictionary) -> void:
	_estimated_tree_row_count += 1
	item.set_custom_minimum_height(roundi(TREE_ROW_HEIGHT * _get_editor_scale()))
	var supported := bool(entry.get("supported", false))
	var property_name := str(entry.get("property_name", ""))
	var display_name := _format_property_name(property_name)
	if supported:
		display_name += "   %s → %s" % [
			_format_value_preview(entry.get("base_value", null), true),
			_format_value_preview(entry.get("current_value", null), false),
		]
	item.set_text(0, display_name)
	item.set_icon(0, _get_property_editor_icon() if supported else null)
	item.set_tooltip_text(0, _build_entry_tooltip(entry))
	var entry_ids := PackedStringArray()
	if supported:
		entry_ids.append(str(entry.get("id", "")))
	item.set_metadata(0, {
		"row_kind": "property" if supported else "unsupported",
		"node_path": str(entry.get("node_path", ".")),
		"property_name": property_name,
		"entry_ids": entry_ids,
		"is_added": false,
		"reason": str(entry.get("reason", "")),
	})
	if supported:
		if has_theme_color("accent_color", "Editor"):
			item.set_custom_color(0, get_theme_color("accent_color", "Editor"))
		_register_first_actionable_item(item)
	else:
		item.set_custom_color(0, _get_warning_color())


func _append_added_subtree_items(parent_item: TreeItem, entry: Dictionary) -> void:
	var added_root := _find_entry_node(entry)
	if not is_instance_valid(added_root):
		return
	var root_path := str(entry.get("node_path", "."))
	var entry_id := str(entry.get("id", ""))
	_append_added_node_children(parent_item, added_root, root_path, entry_id)


func _append_added_node_children(
		parent_item: TreeItem,
		parent_node: Node,
		parent_path: String,
		entry_id: String
	) -> void:
	for child: Node in parent_node.get_children(false):
		var child_path := str(child.name) if parent_path == "." else parent_path.path_join(str(child.name))
		if _node_items.has(child_path):
			continue
		var child_item := _overrides_tree.create_item(parent_item)
		_configure_node_item(child_item, child_path, child, true)
		_append_entry_id_to_item(child_item, entry_id)
		_node_items[child_path] = child_item
		_append_added_node_children(child_item, child, child_path, entry_id)


func _append_entry_id_to_item(item: TreeItem, entry_id: String) -> void:
	if entry_id.is_empty():
		return
	var metadata := _get_item_metadata(item)
	var entry_ids: PackedStringArray = metadata.get("entry_ids", PackedStringArray())
	if not entry_ids.has(entry_id):
		entry_ids.append(entry_id)
	metadata["entry_ids"] = entry_ids
	item.set_metadata(0, metadata)
	_register_first_actionable_item(item)


func _register_first_actionable_item(item: TreeItem) -> void:
	if _first_actionable_item == null:
		_first_actionable_item = item


func _get_item_metadata(item: TreeItem) -> Dictionary:
	var metadata: Variant = item.get_metadata(0)
	return metadata.duplicate(true) if metadata is Dictionary else {}


func _restore_collapsed_items() -> void:
	for node_path_value: Variant in _node_items:
		var node_path := str(node_path_value)
		var item := _node_items[node_path] as TreeItem
		if item != null:
			item.set_collapsed(bool(_collapsed_node_paths.get(node_path, false)))


func _find_instance_node(node_path: String) -> Node:
	if not is_instance_valid(_instance_root):
		return null
	if node_path == ".":
		return _instance_root
	return _instance_root.get_node_or_null(NodePath(node_path))


func _find_entry_node(entry: Dictionary) -> Node:
	var instance_node := _find_instance_node(str(entry.get("node_path", ".")))
	if is_instance_valid(instance_node):
		return instance_node
	return entry.get("current_value") as Node


func _get_node_display_name(node_path: String, node: Node) -> String:
	if is_instance_valid(node):
		return str(node.name)
	if node_path == ".":
		return _instance_name
	return node_path.get_file()


func _get_node_tooltip(node_path: String, node: Node, is_added: bool) -> String:
	var type_name := _get_node_type_name(node)
	var status := "Added node" if is_added else "Existing base-scene node"
	return "%s\nPath: %s\nType: %s" % [status, node_path, type_name]


func _get_node_type_name(node: Node) -> String:
	if not is_instance_valid(node):
		return "Node"
	var node_script := node.get_script() as Script
	if node_script != null:
		var global_name := str(node_script.get_global_name())
		if not global_name.is_empty():
			return global_name
	return node.get_class()


func _get_node_icon(node: Node) -> Texture2D:
	if is_instance_valid(node):
		var node_script := node.get_script() as Script
		if node_script != null:
			var script_icon := _get_custom_script_icon(node_script)
			if script_icon != null:
				return script_icon
		var node_class_name := StringName(node.get_class())
		while not node_class_name.is_empty():
			if has_theme_icon(node_class_name, "EditorIcons"):
				return get_theme_icon(node_class_name, "EditorIcons")
			if not ClassDB.class_exists(node_class_name):
				break
			node_class_name = ClassDB.get_parent_class(node_class_name)
	return _find_first_editor_icon(PackedStringArray([
		"Node",
		"PackedScene",
	]))


func _get_custom_script_icon(node_script: Script) -> Texture2D:
	var current_script := node_script
	while current_script != null:
		var script_icon := _get_direct_custom_script_icon(current_script)
		if script_icon != null:
			return script_icon
		current_script = current_script.get_base_script()
	return null


func _get_direct_custom_script_icon(node_script: Script) -> Texture2D:
	var script_path := node_script.resource_path
	var global_name := str(node_script.get_global_name())
	var cache_key := script_path if not script_path.is_empty() else global_name
	if not cache_key.is_empty() and _script_icon_cache.has(cache_key):
		return _script_icon_cache[cache_key] as Texture2D

	var script_icon: Texture2D
	if not global_name.is_empty() and has_theme_icon(global_name, "EditorIcons"):
		script_icon = get_theme_icon(global_name, "EditorIcons")
	if script_icon == null:
		var icon_path := _find_global_class_icon_path(script_path, global_name)
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path, "Texture2D"):
			script_icon = ResourceLoader.load(
				icon_path,
				"Texture2D",
				ResourceLoader.CACHE_MODE_REUSE
			) as Texture2D

	if script_icon != null and not cache_key.is_empty():
		_script_icon_cache[cache_key] = script_icon
	return script_icon


func _find_global_class_icon_path(script_path: String, global_name: String) -> String:
	for class_data_value: Variant in ProjectSettings.get_global_class_list():
		if not class_data_value is Dictionary:
			continue
		var class_data: Dictionary = class_data_value
		var registered_path := str(class_data.get("path", ""))
		var registered_name := str(class_data.get("class", ""))
		if (
			(not script_path.is_empty() and registered_path == script_path)
			or (not global_name.is_empty() and registered_name == global_name)
		):
			var icon_path := str(class_data.get("icon", ""))
			if not icon_path.is_empty() and not icon_path.contains("://"):
				icon_path = registered_path.get_base_dir().path_join(icon_path)
			return icon_path
	return ""


func _apply_base_node_appearance(item: TreeItem) -> void:
	item.set_custom_color(0, _get_disabled_color())
	item.set_icon_modulate(0, Color(1.0, 1.0, 1.0, 0.48))


func _apply_added_node_appearance(item: TreeItem) -> void:
	item.clear_custom_color(0)
	item.set_icon_modulate(0, Color.WHITE)
	item.set_icon(0, _create_added_node_prefixed_icon(item.get_icon(0)))


func _create_added_node_prefixed_icon(node_icon: Texture2D) -> Texture2D:
	var effective_node_icon := node_icon
	if effective_node_icon == null:
		return null
	var added_marker_icon := _find_first_editor_icon(PackedStringArray(["Add"]))
	if added_marker_icon == null:
		return effective_node_icon
	var editor_scale := _get_editor_scale()
	var cache_key := "%d:%d" % [
		effective_node_icon.get_instance_id(),
		roundi(editor_scale * 100.0),
	]
	if _added_node_icon_cache.has(cache_key):
		return _added_node_icon_cache[cache_key] as Texture2D

	var marker_image := added_marker_icon.get_image()
	var node_image := effective_node_icon.get_image()
	if marker_image == null or marker_image.is_empty() or node_image == null or node_image.is_empty():
		return effective_node_icon

	var marker_height := maxi(1, roundi(ADDED_MARKER_SIZE * editor_scale))
	var node_height := maxi(1, roundi(NODE_ICON_SIZE * editor_scale))
	var marker_width := maxi(
		1,
		roundi(float(marker_image.get_width()) * marker_height / marker_image.get_height())
	)
	var node_width := maxi(
		1,
		roundi(float(node_image.get_width()) * node_height / node_image.get_height())
	)
	marker_image.resize(marker_width, marker_height, Image.INTERPOLATE_LANCZOS)
	node_image.resize(node_width, node_height, Image.INTERPOLATE_LANCZOS)

	var gap_width := maxi(1, roundi(ADDED_MARKER_GAP * editor_scale))
	var combined_height := maxi(marker_height, node_height)
	var combined_image := Image.create(
		marker_width + gap_width + node_width,
		combined_height,
		false,
		Image.FORMAT_RGBA8
	)
	combined_image.fill(Color.TRANSPARENT)
	combined_image.blit_rect(
		marker_image,
		Rect2i(Vector2i.ZERO, marker_image.get_size()),
		Vector2i(0, (combined_height - marker_height) / 2)
	)
	combined_image.blit_rect(
		node_image,
		Rect2i(Vector2i.ZERO, node_image.get_size()),
		Vector2i(marker_width + gap_width, (combined_height - node_height) / 2)
	)
	var combined_texture := ImageTexture.create_from_image(combined_image)
	_added_node_icon_cache[cache_key] = combined_texture
	return combined_texture


func _format_property_name(property_name: String) -> String:
	if property_name.begins_with("@"):
		var structural_name := property_name.trim_prefix("@").replace("_", " ")
		return structural_name.capitalize() if not structural_name.is_empty() else "Structural change"
	return property_name if not property_name.is_empty() else "Changed value"


func _format_value_preview(value: Variant, is_base_value: bool) -> String:
	var value_text: String
	if value == null:
		value_text = "None" if is_base_value else "Null"
	elif value is Node:
		value_text = str((value as Node).name)
	elif value is Resource:
		var resource := value as Resource
		value_text = resource.resource_path.get_file() if not resource.resource_path.is_empty() else resource.get_class()
	else:
		value_text = str(value)
	value_text = value_text.replace("\n", " ").replace("\r", " ")
	if value_text.length() > VALUE_PREVIEW_LIMIT:
		return value_text.left(VALUE_PREVIEW_LIMIT - 1) + "…"
	return value_text


func _build_entry_tooltip(entry: Dictionary) -> String:
	var reason := str(entry.get("reason", ""))
	if not bool(entry.get("supported", false)):
		return reason if not reason.is_empty() else "This override is not supported."
	return "%s.%s\nBase: %s\nCurrent: %s" % [
		str(entry.get("node_path", ".")),
		str(entry.get("property_name", "")),
		_format_full_value(entry.get("base_value", null), true),
		_format_full_value(entry.get("current_value", null), false),
	]


func _format_full_value(value: Variant, is_base_value: bool) -> String:
	if value == null:
		return "None" if is_base_value else "Null"
	if value is Node:
		var node := value as Node
		return "%s (%s)" % [node.name, node.get_class()]
	if value is Resource:
		var resource := value as Resource
		return resource.resource_path if not resource.resource_path.is_empty() else resource.get_class()
	return str(value).replace("\n", " ").replace("\r", " ")


func _apply_editor_appearance() -> void:
	_header_icon.texture = OVERRIDE_ICON
	_context_label.add_theme_color_override("font_color", _get_disabled_color())
	_set_button_editor_icon(_selection_revert_button, PackedStringArray(["Reload", "Undo", "History"]))
	_set_button_editor_icon(_selection_apply_button, PackedStringArray(["Save", "ImportCheck", "Success"]))
	_set_button_editor_icon(_revert_all_button, PackedStringArray(["Reload", "Undo", "History"]))
	_set_button_editor_icon(_apply_all_button, PackedStringArray(["Save", "ImportCheck", "Success"]))


func _apply_rounded_popup_panel_style() -> void:
	transparent = true
	transparent_bg = true
	if not has_theme_stylebox("panel", "PopupPanel"):
		return
	var editor_panel_style := get_theme_stylebox("panel", "PopupPanel")
	if not editor_panel_style is StyleBoxFlat:
		return
	var rounded_style := editor_panel_style.duplicate() as StyleBoxFlat
	if rounded_style == null:
		return

	var corner_radius := maxi(1, roundi(POPUP_CORNER_RADIUS * _get_editor_scale()))
	rounded_style.corner_radius_top_left = corner_radius
	rounded_style.corner_radius_top_right = corner_radius
	rounded_style.corner_radius_bottom_right = corner_radius
	rounded_style.corner_radius_bottom_left = corner_radius
	add_theme_stylebox_override("panel", rounded_style)


func _set_button_editor_icon(button: Button, icon_names: PackedStringArray) -> void:
	button.icon = _find_first_editor_icon(icon_names)


func _get_property_editor_icon() -> Texture2D:
	return _find_first_editor_icon(PackedStringArray([
		"MemberProperty",
		"Edit",
	]))


func _find_first_editor_icon(icon_names: PackedStringArray) -> Texture2D:
	for icon_name: String in icon_names:
		if has_theme_icon(icon_name, "EditorIcons"):
			return get_theme_icon(icon_name, "EditorIcons")
	return null


func _get_disabled_color() -> Color:
	if has_theme_color("font_disabled_color", "Editor"):
		return get_theme_color("font_disabled_color", "Editor")
	if has_theme_color("font_disabled_color", "Tree"):
		return get_theme_color("font_disabled_color", "Tree")
	return Color(0.58, 0.58, 0.58, 1.0)


func _get_warning_color() -> Color:
	if has_theme_color("warning_color", "Editor"):
		return get_theme_color("warning_color", "Editor")
	return Color(1.0, 0.65, 0.25, 1.0)


func _get_editor_scale() -> float:
	return EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0


func _refresh_selection_actions() -> void:
	var selected_item := _overrides_tree.get_selected()
	if selected_item == null:
		_clear_selection_actions()
		return
	var metadata := _get_item_metadata(selected_item)
	var entry_ids: PackedStringArray = metadata.get("entry_ids", PackedStringArray())
	if entry_ids.is_empty():
		if str(metadata.get("row_kind", "")) == "unsupported":
			var reason := str(metadata.get("reason", ""))
			_selection_summary.text = reason if not reason.is_empty() else "This override is not supported."
			_selection_actions.visible = true
			_selection_revert_button.disabled = true
			_selection_apply_button.disabled = true
			_queue_popup_resize()
		else:
			_clear_selection_actions()
		return
	_selected_entry_ids = entry_ids.duplicate()
	_selection_summary.text = _build_selection_summary(selected_item, metadata, entry_ids.size())
	_selection_actions.visible = true
	_selection_revert_button.disabled = false
	_selection_apply_button.disabled = false
	_queue_popup_resize()


func _clear_selection_actions() -> void:
	_selected_entry_ids = PackedStringArray()
	_selection_summary.text = ""
	_selection_actions.visible = false
	_selection_revert_button.disabled = true
	_selection_apply_button.disabled = true
	_queue_popup_resize()


func _build_selection_summary(item: TreeItem, metadata: Dictionary, entry_count: int) -> String:
	var row_kind := str(metadata.get("row_kind", ""))
	if row_kind == "property":
		return item.get_text(0)
	if bool(metadata.get("is_added", false)):
		return "%s  ·  Added" % item.get_text(0)
	return "%s  ·  %d %s" % [
		item.get_text(0),
		entry_count,
		"override" if entry_count == 1 else "overrides",
	]


func _on_overrides_tree_item_selected() -> void:
	_refresh_selection_actions()


func _on_overrides_tree_item_collapsed(item: TreeItem) -> void:
	var metadata := _get_item_metadata(item)
	if str(metadata.get("row_kind", "")) == "node":
		_collapsed_node_paths[str(metadata.get("node_path", "."))] = item.is_collapsed()
		_update_tree_minimum_height()
		_queue_popup_resize()


func _on_selection_apply_button_pressed() -> void:
	_emit_apply_request(_selected_entry_ids)


func _on_selection_revert_button_pressed() -> void:
	_emit_revert_request(_selected_entry_ids)


func _on_apply_all_button_pressed() -> void:
	_emit_apply_request(_supported_entry_ids)


func _on_revert_all_button_pressed() -> void:
	_emit_revert_request(_supported_entry_ids)


func _emit_apply_request(entry_ids: PackedStringArray) -> void:
	if entry_ids.is_empty():
		return
	var requested_entry_ids := entry_ids.duplicate()
	apply_entries_requested.emit(requested_entry_ids)


func _emit_revert_request(entry_ids: PackedStringArray) -> void:
	if entry_ids.is_empty():
		return
	var requested_entry_ids := entry_ids.duplicate()
	revert_entries_requested.emit(requested_entry_ids)


func _on_close_requested() -> void:
	hide()
