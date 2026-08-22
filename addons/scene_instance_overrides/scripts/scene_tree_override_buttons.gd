@tool
extends Node

const OVERRIDE_ICON := preload("res://addons/scene_instance_overrides/icons/scene_instance_overrides.svg")
const OVERRIDE_BUTTON_ID := 19427
const VISIBILITY_BUTTON_ID := 1

var _host_plugin: Object
var _scene_dock_tree: Tree
var _decorated_tree_root_id := 0
var _refresh_queued := false
var _scene_dock_buttons_enabled := true
var _context_cache_by_instance_root_id: Dictionary = {}
var _pending_context_by_instance_root_id: Dictionary = {}


func setup(host_plugin: Object, scene_dock_buttons_enabled: bool = true) -> void:
	_host_plugin = host_plugin
	_scene_dock_buttons_enabled = scene_dock_buttons_enabled


func _ready() -> void:
	if _scene_dock_buttons_enabled:
		schedule_refresh()


func shutdown() -> void:
	_refresh_queued = false
	_remove_override_buttons_from_scene_tree()
	_disconnect_scene_dock_tree()
	_context_cache_by_instance_root_id.clear()
	_pending_context_by_instance_root_id.clear()
	_host_plugin = null


func set_scene_dock_buttons_enabled(enabled: bool) -> void:
	if _scene_dock_buttons_enabled == enabled:
		return
	_scene_dock_buttons_enabled = enabled
	_context_cache_by_instance_root_id.clear()
	_pending_context_by_instance_root_id.clear()
	if not is_inside_tree():
		return
	if enabled:
		schedule_refresh()
		return
	_refresh_queued = false
	_remove_override_buttons_from_scene_tree()
	_decorated_tree_root_id = 0


func schedule_refresh() -> void:
	if not _scene_dock_buttons_enabled or _refresh_queued or not is_inside_tree():
		return
	_refresh_queued = true
	call_deferred("_refresh_scene_tree_override_buttons")


func schedule_refresh_with_context(context: Dictionary) -> void:
	if not _scene_dock_buttons_enabled:
		return
	var instance_root := context.get("instance_root") as Node
	if is_instance_valid(instance_root):
		_pending_context_by_instance_root_id[instance_root.get_instance_id()] = context
	schedule_refresh()


func clear_context_cache() -> void:
	_context_cache_by_instance_root_id.clear()
	_pending_context_by_instance_root_id.clear()


func _refresh_scene_tree_override_buttons() -> void:
	_refresh_queued = false
	if not _scene_dock_buttons_enabled or not is_instance_valid(_host_plugin):
		return
	var scene_tree_control := _get_scene_dock_tree()
	if not is_instance_valid(scene_tree_control):
		_decorated_tree_root_id = 0
		return

	var tree_root := scene_tree_control.get_root()
	if tree_root == null:
		_decorated_tree_root_id = 0
		return

	var current_tree_root_id := tree_root.get_instance_id()
	if current_tree_root_id != _decorated_tree_root_id:
		_context_cache_by_instance_root_id.clear()
	for instance_root_id: Variant in _pending_context_by_instance_root_id:
		_context_cache_by_instance_root_id[instance_root_id] = (
			_pending_context_by_instance_root_id[instance_root_id]
		)
	_pending_context_by_instance_root_id.clear()

	_remove_override_buttons_from_item_tree(tree_root)
	var edited_scene_root := EditorInterface.get_edited_scene_root()
	if not is_instance_valid(edited_scene_root):
		_decorated_tree_root_id = tree_root.get_instance_id()
		return

	var row_records: Array[Dictionary] = []
	_collect_scene_row_records(tree_root, edited_scene_root, row_records)
	# One shared scan cache lets every instance root in this refresh batch reuse the serialized
	# snapshot of the edited scene instead of repacking the whole scene per instance root.
	var scan_cache := {}
	for row_record: Dictionary in row_records:
		var instance_root := row_record.get("instance_root") as Node
		if not is_instance_valid(instance_root):
			continue
		var instance_root_id := instance_root.get_instance_id()
		if not _context_cache_by_instance_root_id.has(instance_root_id):
			_context_cache_by_instance_root_id[instance_root_id] = (
				_host_plugin.scan_overrides_for_node(instance_root, scan_cache)
			)
	scan_cache.clear()

	for row_record: Dictionary in row_records:
		var item := row_record.get("item") as TreeItem
		var node := row_record.get("node") as Node
		var instance_root := row_record.get("instance_root") as Node
		if item == null or not is_instance_valid(node) or not is_instance_valid(instance_root):
			continue
		var context: Dictionary = _context_cache_by_instance_root_id.get(
			instance_root.get_instance_id(),
			{}
		)
		if _should_show_override_button_on_scene_row(node, instance_root, context):
			_add_override_button_before_visibility_button(item)

	_decorated_tree_root_id = current_tree_root_id


func _get_scene_dock_tree() -> Tree:
	if is_instance_valid(_scene_dock_tree):
		return _scene_dock_tree
	var editor_base_control := EditorInterface.get_base_control()
	if not is_instance_valid(editor_base_control):
		return null
	var found_tree := _find_main_scene_dock_tree(editor_base_control)
	if is_instance_valid(found_tree):
		_scene_dock_tree = found_tree
		if not _scene_dock_tree.button_clicked.is_connected(_on_scene_tree_button_clicked):
			_scene_dock_tree.button_clicked.connect(_on_scene_tree_button_clicked)
	return _scene_dock_tree


func _find_main_scene_dock_tree(node: Node) -> Tree:
	if node is Tree and _is_main_scene_dock_tree(node):
		return node as Tree
	for child: Node in node.get_children(true):
		var found_tree := _find_main_scene_dock_tree(child)
		if found_tree != null:
			return found_tree
	return null


func _is_main_scene_dock_tree(tree_control: Tree) -> bool:
	var scene_tree_editor := tree_control.get_parent()
	if (
		not is_instance_valid(scene_tree_editor)
		or not str(scene_tree_editor.name).contains("SceneTreeEditor")
	):
		return false
	var ancestor := scene_tree_editor.get_parent()
	while is_instance_valid(ancestor):
		if ancestor is Window:
			return false
		if str(ancestor.name) == "Scene":
			return true
		ancestor = ancestor.get_parent()
	return false


func _collect_scene_row_records(
		item: TreeItem,
		edited_scene_root: Node,
		row_records: Array[Dictionary]
	) -> void:
	var node := _find_node_from_tree_item(item)
	if (
		is_instance_valid(node)
		and node != edited_scene_root
		and edited_scene_root.is_ancestor_of(node)
	):
		var instance_root := _find_nearest_external_instance_root(
			node,
			edited_scene_root
		)
		if is_instance_valid(instance_root):
			row_records.append({
				"item": item,
				"node": node,
				"instance_root": instance_root,
			})

	var child := item.get_first_child()
	while child != null:
		_collect_scene_row_records(child, edited_scene_root, row_records)
		child = child.get_next()


func _find_node_from_tree_item(item: TreeItem) -> Node:
	var metadata: Variant = item.get_metadata(0)
	if not metadata is NodePath:
		return null
	var editor_scene_tree := Engine.get_main_loop() as SceneTree
	if editor_scene_tree == null:
		return null
	return editor_scene_tree.root.get_node_or_null(metadata)


func _find_nearest_external_instance_root(node: Node, edited_scene_root: Node) -> Node:
	var current_node := node
	while is_instance_valid(current_node) and current_node != edited_scene_root:
		if not current_node.scene_file_path.is_empty():
			return current_node
		current_node = current_node.get_parent()
	return null


func _should_show_override_button_on_scene_row(
		node: Node,
		instance_root: Node,
		context: Dictionary
	) -> bool:
	if not context.get("valid", false):
		return false
	var entries: Variant = context.get("entries", [])
	if not entries is Array or entries.is_empty():
		return false
	if node == instance_root:
		return true
	if not _host_plugin.should_show_override_button_for_node(node, context):
		return false

	var relative_node_path := str(instance_root.get_path_to(node))
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var entry_node_path := _normalize_instance_node_path(
			str(entry.get("node_path", "."))
		)
		if relative_node_path == entry_node_path:
			return true
		if (
			str(entry.get("kind", "")) == "added_node"
			and relative_node_path.begins_with(entry_node_path + "/")
		):
			return true
	return false


func _normalize_instance_node_path(node_path: String) -> String:
	var normalized_path := node_path.strip_edges()
	if normalized_path.is_empty() or normalized_path == ".":
		return "."
	if normalized_path.begins_with("./"):
		return normalized_path.substr(2)
	return normalized_path


func _add_override_button_before_visibility_button(item: TreeItem) -> void:
	if item.get_button_by_id(0, OVERRIDE_BUTTON_ID) >= 0:
		return

	var visibility_button_index := item.get_button_by_id(0, VISIBILITY_BUTTON_ID)
	var visibility_icon: Texture2D
	var visibility_disabled := false
	var visibility_tooltip := ""
	var has_visibility_button := visibility_button_index >= 0
	if has_visibility_button:
		visibility_icon = item.get_button(0, visibility_button_index)
		visibility_disabled = item.is_button_disabled(0, visibility_button_index)
		visibility_tooltip = item.get_button_tooltip_text(0, visibility_button_index)
		item.erase_button(0, visibility_button_index)

	item.add_button(
		0,
		OVERRIDE_ICON,
		OVERRIDE_BUTTON_ID,
		false,
		"Review scene instance overrides",
		"Review scene instance overrides"
	)
	if has_visibility_button:
		item.add_button(
			0,
			visibility_icon,
			VISIBILITY_BUTTON_ID,
			visibility_disabled,
			visibility_tooltip,
			"Toggle node visibility"
		)


func _remove_override_buttons_from_scene_tree() -> void:
	if not is_instance_valid(_scene_dock_tree):
		return
	var tree_root := _scene_dock_tree.get_root()
	if tree_root != null:
		_remove_override_buttons_from_item_tree(tree_root)


func _remove_override_buttons_from_item_tree(item: TreeItem) -> void:
	var override_button_index := item.get_button_by_id(0, OVERRIDE_BUTTON_ID)
	if override_button_index >= 0:
		item.erase_button(0, override_button_index)
	var child := item.get_first_child()
	while child != null:
		_remove_override_buttons_from_item_tree(child)
		child = child.get_next()


func _disconnect_scene_dock_tree() -> void:
	if (
		is_instance_valid(_scene_dock_tree)
		and _scene_dock_tree.button_clicked.is_connected(_on_scene_tree_button_clicked)
	):
		_scene_dock_tree.button_clicked.disconnect(_on_scene_tree_button_clicked)
	_scene_dock_tree = null
	_decorated_tree_root_id = 0


func _on_scene_tree_button_clicked(
		item: TreeItem,
		column: int,
		button_id: int,
		mouse_button_index: int
	) -> void:
	if (
		button_id != OVERRIDE_BUTTON_ID
		or column != 0
		or mouse_button_index != MOUSE_BUTTON_LEFT
		or not is_instance_valid(_host_plugin)
		or not is_instance_valid(_scene_dock_tree)
	):
		return
	var node := _find_node_from_tree_item(item)
	if not is_instance_valid(node):
		schedule_refresh()
		return
	var click_position := Vector2i(
		_scene_dock_tree.get_screen_position()
		+ _scene_dock_tree.get_local_mouse_position()
	)
	_host_plugin.show_override_popup_from_scene_tree(
		_scene_dock_tree,
		node,
		click_position
	)
