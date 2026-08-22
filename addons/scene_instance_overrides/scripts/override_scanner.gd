@tool
extends RefCounted

const KIND_SUPPORTED_PROPERTY := "supported_property"
const KIND_ADDED_NODE := "added_node"
const KIND_UNSUPPORTED := "unsupported"

const NODE_2D_ROOT_PLACEMENT_PROPERTIES := [
	&"transform",
	&"position",
	&"rotation",
	&"rotation_degrees",
	&"scale",
	&"skew",
	&"top_level",
	&"global_transform",
	&"global_position",
	&"global_rotation",
	&"global_rotation_degrees",
	&"global_scale",
]

const NODE_3D_ROOT_PLACEMENT_PROPERTIES := [
	&"transform",
	&"position",
	&"rotation",
	&"rotation_degrees",
	&"quaternion",
	&"basis",
	&"scale",
	&"top_level",
	&"rotation_edit_mode",
	&"rotation_order",
	&"global_transform",
	&"global_position",
	&"global_rotation",
	&"global_rotation_degrees",
	&"global_basis",
	&"global_scale",
]

const CONTROL_ROOT_LAYOUT_PROPERTIES := [
	&"layout_mode",
	&"anchors_preset",
	&"anchor_left",
	&"anchor_top",
	&"anchor_right",
	&"anchor_bottom",
	&"offset_left",
	&"offset_top",
	&"offset_right",
	&"offset_bottom",
	&"grow_horizontal",
	&"grow_vertical",
	&"custom_minimum_size",
	&"custom_maximum_size",
	&"size",
	&"size_flags_horizontal",
	&"size_flags_vertical",
	&"size_flags_stretch_ratio",
	&"position",
	&"rotation",
	&"rotation_degrees",
	&"scale",
	&"pivot_offset",
	&"pivot_offset_ratio",
	&"offset_transform_enabled",
	&"offset_transform_position",
	&"offset_transform_position_ratio",
	&"offset_transform_rotation",
	&"offset_transform_scale",
	&"offset_transform_pivot",
	&"offset_transform_pivot_ratio",
	&"offset_transform_visual_only",
	&"top_level",
	&"global_position",
	&"global_rotation",
	&"global_scale",
]

# Property lists of script-less built-in classes cannot change while the editor runs, so they
# are cached per class instead of being rebuilt for every node of every scan.
static var _class_property_information_cache: Dictionary = {}


func scan_for_node(node: Node, shared_cache: Dictionary = {}) -> Dictionary:
	var context := _make_empty_context()
	if node == null or not is_instance_valid(node):
		context["error"] = "The selected node is invalid."
		return context

	var edited_scene_root := _find_edited_scene_root(node)
	if edited_scene_root == null:
		context["error"] = "The root of the currently edited scene could not be found."
		return context

	var instance_root := _find_nearest_external_scene_root(node, edited_scene_root)
	if instance_root == null:
		context["error"] = "The selected node does not belong to an external scene instance."
		return context

	var source_path := String(instance_root.scene_file_path)
	context["instance_root"] = instance_root
	context["source_path"] = source_path
	var source_error := _get_source_path_error(source_path)
	if not source_error.is_empty():
		context["error"] = source_error
		return context

	var base_scene_resource := ResourceLoader.load(source_path, "PackedScene")
	if not base_scene_resource is PackedScene:
		context["error"] = "Failed to load a PackedScene from the base path: %s" % source_path
		return context

	var base_scene := base_scene_resource as PackedScene
	var base_scene_state := base_scene.get_state()
	if base_scene_state != null and base_scene_state.get_base_scene_state() != null:
		context["error"] = "Instances whose base is an inherited scene are not supported."
		return context

	# Serializing the whole edited scene dominates the scan cost, so the snapshot and the node
	# data derived from it are memoized per edited scene root and shared between all scans of
	# one refresh batch (see plugin.gd / scene_tree_override_buttons.gd).
	var caches := {"batch": shared_cache, "local": {}}
	var edited_root_cache_key := "edited_root:%d" % edited_scene_root.get_instance_id()

	var edited_scene_snapshot: PackedScene = shared_cache.get("snapshot:" + edited_root_cache_key)
	if edited_scene_snapshot == null:
		edited_scene_snapshot = PackedScene.new()
		var pack_error := edited_scene_snapshot.pack(edited_scene_root)
		if pack_error != OK:
			context["error"] = "Failed to serialize the edited scene in memory. Error code: %d" % pack_error
			return context
		shared_cache["snapshot:" + edited_root_cache_key] = edited_scene_snapshot

	var base_root := _instantiate_base_scene_for_comparison(base_scene)
	if base_root == null:
		context["error"] = "Failed to instantiate the base PackedScene for comparison."
		return context

	var serialized_nodes: Dictionary
	var serialized_nodes_cache_key := "serialized_nodes:" + edited_root_cache_key
	if shared_cache.has(serialized_nodes_cache_key):
		serialized_nodes = shared_cache[serialized_nodes_cache_key]
	else:
		serialized_nodes = _collect_serialized_scene_nodes(edited_scene_snapshot.get_state())
		shared_cache[serialized_nodes_cache_key] = serialized_nodes

	var current_nodes := _collect_relative_nodes(instance_root)
	var base_nodes := _collect_relative_nodes(base_root)
	var entries: Array[Dictionary] = []

	entries.append_array(_collect_property_override_entries(
		instance_root,
		edited_scene_root,
		current_nodes,
		base_nodes,
		serialized_nodes,
		caches
	))
	entries.append_array(_collect_added_and_changed_structure_entries(
		instance_root,
		edited_scene_root,
		current_nodes,
		base_nodes,
		serialized_nodes,
		caches
	))
	entries.append_array(_collect_missing_original_node_entries(current_nodes, base_nodes))
	entries.append_array(_collect_reordered_original_node_entries(current_nodes, base_nodes))
	entries.append_array(_collect_changed_original_node_type_entries(current_nodes, base_nodes))
	entries.append_array(_collect_changed_original_group_entries(
		edited_scene_root,
		current_nodes,
		base_nodes,
		serialized_nodes
	))
	entries.append_array(_collect_changed_signal_connection_entries(
		current_nodes,
		base_nodes,
		caches
	))

	base_root.free()
	entries.sort_custom(_entry_comes_before)
	var supported_count := 0
	for entry: Dictionary in entries:
		if bool(entry["supported"]):
			supported_count += 1

	context["valid"] = true
	context["entries"] = entries
	context["supported_count"] = supported_count
	return context


func _make_empty_context() -> Dictionary:
	var entries: Array[Dictionary] = []
	return {
		"valid": false,
		"instance_root": null,
		"source_path": "",
		"entries": entries,
		"supported_count": 0,
		"error": "",
	}


func _find_edited_scene_root(node: Node) -> Node:
	if node.is_inside_tree():
		var scene_tree := node.get_tree()
		var edited_scene_root := scene_tree.get_edited_scene_root()
		if (
			is_instance_valid(edited_scene_root)
			and (edited_scene_root == node or edited_scene_root.is_ancestor_of(node))
		):
			return edited_scene_root

	# Treat the topmost parent as the edited root for test nodes that are not attached to a SceneTree.
	var current := node
	while current.get_parent() != null:
		current = current.get_parent()
	return current


func _find_nearest_external_scene_root(node: Node, edited_scene_root: Node) -> Node:
	var current := node
	while current != null and current != edited_scene_root:
		if not String(current.scene_file_path).is_empty():
			return current
		current = current.get_parent()
	return null


func _get_source_path_error(source_path: String) -> String:
	if not source_path.begins_with("res://"):
		return "Only scenes inside the project can be used as a base: %s" % source_path
	if source_path.begins_with("res://addons/"):
		return "Third-party scenes under res://addons/ cannot be modified as a base scene."
	var extension := source_path.get_extension().to_lower()
	if extension != "tscn" and extension != "scn":
		return "Only directly writable .tscn or .scn scenes are supported."
	if FileAccess.file_exists(source_path + ".import"):
		return "Scenes managed by an importer cannot be modified."
	if not ResourceLoader.exists(source_path, "PackedScene"):
		return "The base scene file could not be found: %s" % source_path
	return ""


func _instantiate_base_scene_for_comparison(base_scene: PackedScene) -> Node:
	var base_root := base_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if base_root == null:
		base_root = base_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	return base_root


func _collect_serialized_scene_nodes(scene_state: SceneState) -> Dictionary:
	var serialized_nodes := {}
	if scene_state == null:
		return serialized_nodes
	for node_index in scene_state.get_node_count():
		var node_path := _normalize_path(String(scene_state.get_node_path(node_index)))
		var properties := {}
		for property_index in scene_state.get_node_property_count(node_index):
			var property_name := scene_state.get_node_property_name(node_index, property_index)
			properties[property_name] = scene_state.get_node_property_value(node_index, property_index)
		serialized_nodes[node_path] = {
			"properties": properties,
			"groups": scene_state.get_node_groups(node_index),
		}
	return serialized_nodes


func _collect_relative_nodes(root: Node) -> Dictionary:
	var nodes := {}
	_collect_relative_nodes_recursive(root, root, nodes)
	return nodes


func _collect_relative_nodes_recursive(root: Node, current: Node, nodes: Dictionary) -> void:
	var relative_path := _relative_path(root, current)
	nodes[relative_path] = current
	for child: Node in current.get_children(false):
		_collect_relative_nodes_recursive(root, child, nodes)


func _collect_property_override_entries(
		instance_root: Node,
		edited_scene_root: Node,
		current_nodes: Dictionary,
		base_nodes: Dictionary,
		serialized_nodes: Dictionary,
		caches: Dictionary
	) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var relative_paths: Array = current_nodes.keys()
	relative_paths.sort()
	for relative_path_value: Variant in relative_paths:
		var relative_path := String(relative_path_value)
		if not base_nodes.has(relative_path):
			continue
		var current_node := current_nodes[relative_path] as Node
		var base_node := base_nodes[relative_path] as Node
		if current_node.get_class() != base_node.get_class():
			continue
		var serialized_path := _path_from_edited_root(edited_scene_root, current_node)
		if not serialized_nodes.has(serialized_path):
			continue
		var serialized_properties: Dictionary = serialized_nodes[serialized_path]["properties"]
		var property_information := _index_property_information(current_node, caches)
		var property_names: Array = serialized_properties.keys()
		property_names.sort()
		for property_name_value: Variant in property_names:
			var property_name := StringName(property_name_value)
			if not property_information.has(property_name):
				continue
			var property_info: Dictionary = property_information[property_name]
			var usage := int(property_info.get("usage", PROPERTY_USAGE_NONE))
			if not _property_can_be_an_instance_override(usage):
				continue
			if current_node == instance_root and _is_excluded_root_placement_property(current_node, property_name):
				continue
			if not _object_has_property(base_node, property_name, caches):
				entries.append(_make_entry(
					KIND_UNSUPPORTED,
					relative_path,
					property_name,
					current_node.get(property_name),
					null,
					"The base node has no matching property, so this change cannot be applied safely.",
					false
				))
				continue
			var current_value: Variant = current_node.get(property_name)
			var base_value: Variant = base_node.get(property_name)
			if _values_are_equivalent(current_value, base_value):
				continue
			var unsafe_reason := _get_unsafe_value_reason(
				current_value,
				current_node,
				instance_root,
				edited_scene_root,
				usage
			)
			if not unsafe_reason.is_empty():
				entries.append(_make_entry(
					KIND_UNSUPPORTED,
					relative_path,
					property_name,
					current_value,
					base_value,
					unsafe_reason,
					false
				))
				continue
			entries.append(_make_entry(
				KIND_SUPPORTED_PROPERTY,
				relative_path,
				property_name,
				current_value,
				base_value,
				"",
				true
			))
	return entries


func _collect_added_and_changed_structure_entries(
		instance_root: Node,
		edited_scene_root: Node,
		current_nodes: Dictionary,
		base_nodes: Dictionary,
		serialized_nodes: Dictionary,
		caches: Dictionary
	) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var missing_paths: Array[String] = []
	for relative_path_value: Variant in current_nodes.keys():
		var relative_path := String(relative_path_value)
		if relative_path == "." or base_nodes.has(relative_path):
			continue
		var current_node := current_nodes[relative_path] as Node
		var serialized_path := _path_from_edited_root(edited_scene_root, current_node)
		if serialized_nodes.has(serialized_path):
			missing_paths.append(relative_path)
	missing_paths.sort_custom(_shorter_path_comes_first)

	var recorded_subtree_roots: Array[String] = []
	for relative_path: String in missing_paths:
		if _path_is_inside_any_subtree(relative_path, recorded_subtree_roots):
			continue
		var current_node := current_nodes[relative_path] as Node
		recorded_subtree_roots.append(relative_path)
		if current_node.owner != edited_scene_root:
			entries.append(_make_entry(
				KIND_UNSUPPORTED,
				relative_path,
				&"@structure",
				current_node.get_class(),
				null,
				"Renaming or reparenting an existing base-scene child is not supported.",
				false
			))
			continue
		var subtree_reason := _get_added_subtree_unsafe_reason(
			current_node,
			instance_root,
			edited_scene_root,
			serialized_nodes,
			caches
		)
		if not subtree_reason.is_empty():
			entries.append(_make_entry(
				KIND_UNSUPPORTED,
				relative_path,
				&"@added_node",
				current_node,
				null,
				subtree_reason,
				false
			))
			continue
		entries.append(_make_entry(
			KIND_ADDED_NODE,
			relative_path,
			&"",
			current_node,
			null,
			"",
			true
		))
	return entries


func _collect_missing_original_node_entries(
		current_nodes: Dictionary,
		base_nodes: Dictionary
	) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var missing_paths: Array[String] = []
	for relative_path_value: Variant in base_nodes.keys():
		var relative_path := String(relative_path_value)
		if relative_path != "." and not current_nodes.has(relative_path):
			missing_paths.append(relative_path)
	missing_paths.sort_custom(_shorter_path_comes_first)
	var recorded_subtree_roots: Array[String] = []
	for relative_path: String in missing_paths:
		if _path_is_inside_any_subtree(relative_path, recorded_subtree_roots):
			continue
		recorded_subtree_roots.append(relative_path)
		var base_node := base_nodes[relative_path] as Node
		entries.append(_make_entry(
			KIND_UNSUPPORTED,
			relative_path,
			&"@structure",
			null,
			base_node.get_class(),
			"Deleting, renaming, or reparenting an existing base-scene child is not supported.",
			false
		))
	return entries


func _collect_reordered_original_node_entries(
		current_nodes: Dictionary,
		base_nodes: Dictionary
	) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var parent_paths: Array = base_nodes.keys()
	parent_paths.sort()
	for parent_path_value: Variant in parent_paths:
		var parent_path := String(parent_path_value)
		if not current_nodes.has(parent_path):
			continue
		var current_parent := current_nodes[parent_path] as Node
		var base_parent := base_nodes[parent_path] as Node
		var current_order := _collect_shared_child_names(current_parent, parent_path, base_nodes)
		var base_order := _collect_shared_child_names(base_parent, parent_path, current_nodes)
		if current_order == base_order:
			continue
		entries.append(_make_entry(
			KIND_UNSUPPORTED,
			parent_path,
			&"@child_order",
			current_order,
			base_order,
			"Reordering existing base-scene children is not supported.",
			false
		))
	return entries


func _collect_changed_original_node_type_entries(
		current_nodes: Dictionary,
		base_nodes: Dictionary
	) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var relative_paths: Array = current_nodes.keys()
	relative_paths.sort()
	for relative_path_value: Variant in relative_paths:
		var relative_path := String(relative_path_value)
		if not base_nodes.has(relative_path):
			continue
		var current_node := current_nodes[relative_path] as Node
		var base_node := base_nodes[relative_path] as Node
		if current_node.get_class() == base_node.get_class():
			continue
		entries.append(_make_entry(
			KIND_UNSUPPORTED,
			relative_path,
			&"@node_type",
			current_node.get_class(),
			base_node.get_class(),
			"Changing the type of an existing base-scene node is not supported.",
			false
		))
	return entries


func _collect_changed_original_group_entries(
		edited_scene_root: Node,
		current_nodes: Dictionary,
		base_nodes: Dictionary,
		serialized_nodes: Dictionary
	) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var relative_paths: Array = current_nodes.keys()
	relative_paths.sort()
	for relative_path_value: Variant in relative_paths:
		var relative_path := String(relative_path_value)
		if not base_nodes.has(relative_path):
			continue
		var current_node := current_nodes[relative_path] as Node
		var serialized_path := _path_from_edited_root(edited_scene_root, current_node)
		if not serialized_nodes.has(serialized_path):
			continue
		var base_node := base_nodes[relative_path] as Node
		var current_groups := _collect_user_group_names(current_node)
		var base_groups := _collect_user_group_names(base_node)
		if current_groups == base_groups:
			continue
		entries.append(_make_entry(
			KIND_UNSUPPORTED,
			relative_path,
			&"@groups",
			current_groups,
			base_groups,
			"Changing groups on an existing base-scene node is not supported.",
			false
		))
	return entries


func _collect_changed_signal_connection_entries(
		current_nodes: Dictionary,
		base_nodes: Dictionary,
		caches: Dictionary
	) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var current_connections := _collect_persistent_connection_descriptions(current_nodes, caches, true)
	var base_connections := _collect_persistent_connection_descriptions(base_nodes, caches, false)
	if current_connections == base_connections:
		return entries
	entries.append(_make_entry(
		KIND_UNSUPPORTED,
		".",
		&"@signal_connections",
		current_connections,
		base_connections,
		"Changing persistent signal connections on an existing base-scene node is not supported.",
		false
	))
	return entries


func _collect_user_group_names(node: Node) -> Array[String]:
	var groups: Array[String] = []
	for group_value: StringName in node.get_groups():
		var group_name := String(group_value)
		if not group_name.begins_with("_"):
			groups.append(group_name)
	groups.sort()
	return groups


func _collect_persistent_connection_descriptions(
		nodes: Dictionary,
		caches: Dictionary,
		use_batch_cache: bool
	) -> Array[String]:
	var descriptions: Array[String] = []
	var relative_paths: Array = nodes.keys()
	relative_paths.sort()
	for source_path_value: Variant in relative_paths:
		var source_path := String(source_path_value)
		var source_node := nodes[source_path] as Node
		for connection: Dictionary in _get_node_persistent_connections(source_node, caches, use_batch_cache):
			var callable: Callable = connection["callable"]
			var flags := int(connection["flags"])
			var target_object := callable.get_object()
			var target_path := "@external_object"
			if target_object is Node:
				target_path = _find_relative_path_for_node(nodes, target_object as Node)
			descriptions.append("%s|%s|%s|%s|%d" % [
				source_path,
				connection["signal"],
				target_path,
				callable.get_method(),
				flags,
			])
	descriptions.sort()
	return descriptions


func _get_node_persistent_connections(
		node: Node,
		caches: Dictionary,
		use_batch_cache: bool
	) -> Array:
	var cache_key := "node_persistent_connections:%d" % node.get_instance_id()
	var batch_cache: Dictionary = caches["batch"]
	if use_batch_cache and batch_cache.has(cache_key):
		return batch_cache[cache_key]
	var connections: Array = []
	for signal_info: Dictionary in node.get_signal_list():
		var signal_name := StringName(signal_info["name"])
		for connection: Dictionary in node.get_signal_connection_list(signal_name):
			if (int(connection.get("flags", 0)) & CONNECT_PERSIST) == 0:
				continue
			connections.append({
				"signal": signal_name,
				"callable": connection.get("callable", Callable()),
				"flags": int(connection.get("flags", 0)),
			})
	if use_batch_cache:
		batch_cache[cache_key] = connections
	return connections


func _find_relative_path_for_node(nodes: Dictionary, target: Node) -> String:
	for relative_path_value: Variant in nodes.keys():
		var relative_path := String(relative_path_value)
		if nodes[relative_path] == target:
			return relative_path
	return "@outside_instance"


func _collect_shared_child_names(parent: Node, parent_path: String, other_nodes: Dictionary) -> Array[String]:
	var child_names: Array[String] = []
	for child: Node in parent.get_children(false):
		var child_path := String(child.name) if parent_path == "." else parent_path.path_join(String(child.name))
		if other_nodes.has(child_path):
			child_names.append(String(child.name))
	return child_names


func _get_added_subtree_unsafe_reason(
		added_root: Node,
		instance_root: Node,
		edited_scene_root: Node,
		serialized_nodes: Dictionary,
		caches: Dictionary
	) -> String:
	# The persistent-connection data of the edited scene is precomputed once per batch instead
	# of re-walking the whole scene for every added subtree.
	var connection_data := _get_scene_persistent_connection_data(edited_scene_root, caches)
	if _has_persistent_signal_connection_targeting_subtree_from_outside(
		connection_data,
		added_root
	):
		return "The added subtree is targeted by a persistent signal connection from outside the subtree."
	var subtree_nodes: Array[Node] = []
	_collect_subtree_nodes(added_root, subtree_nodes)
	for subtree_node: Node in subtree_nodes:
		var nested_scene_path := String(subtree_node.scene_file_path)
		if not nested_scene_path.is_empty():
			if nested_scene_path.begins_with("res://addons/"):
				return "The added subtree contains a scene instance from res://addons/."
			if FileAccess.file_exists(nested_scene_path + ".import") or nested_scene_path.get_extension().to_lower() not in ["tscn", "scn"]:
				return "The added subtree contains an imported scene instance."
			return "The added subtree contains a nested PackedScene instance."
		if _node_has_persistent_signal_connection(connection_data, subtree_node):
			return "Persistent signal connections in an added subtree are not supported."

		var serialized_path := _path_from_edited_root(edited_scene_root, subtree_node)
		if not serialized_nodes.has(serialized_path):
			continue
		var property_information := _index_property_information(subtree_node, caches)
		var serialized_properties: Dictionary = serialized_nodes[serialized_path]["properties"]
		for property_name_value: Variant in serialized_properties.keys():
			var property_name := StringName(property_name_value)
			if not property_information.has(property_name):
				continue
			var property_info: Dictionary = property_information[property_name]
			var usage := int(property_info.get("usage", PROPERTY_USAGE_NONE))
			if not _property_can_be_an_instance_override(usage):
				continue
			var unsafe_reason := _get_unsafe_value_reason(
				subtree_node.get(property_name),
				subtree_node,
				instance_root,
				edited_scene_root,
				usage
			)
			if not unsafe_reason.is_empty():
				return "%s.%s: %s" % [_relative_path(instance_root, subtree_node), property_name, unsafe_reason]
	return ""


func _get_scene_persistent_connection_data(edited_scene_root: Node, caches: Dictionary) -> Dictionary:
	var batch_cache: Dictionary = caches["batch"]
	var cache_key := "scene_persistent_connections:%d" % edited_scene_root.get_instance_id()
	if batch_cache.has(cache_key):
		return batch_cache[cache_key]
	var records: Array[Dictionary] = []
	var scene_nodes: Array[Node] = []
	_collect_subtree_nodes(edited_scene_root, scene_nodes)
	for source_node: Node in scene_nodes:
		for connection: Dictionary in _get_node_persistent_connections(source_node, caches, false):
			var callable: Callable = connection["callable"]
			var target_object := callable.get_object()
			if not target_object is Node:
				continue
			records.append({
				"source": source_node,
				"target": target_object as Node,
			})
	var source_ids: Dictionary = {}
	for record: Dictionary in records:
		source_ids[(record["source"] as Node).get_instance_id()] = true
	var connection_data := {"records": records, "source_ids": source_ids}
	batch_cache[cache_key] = connection_data
	return connection_data


func _has_persistent_signal_connection_targeting_subtree_from_outside(
		connection_data: Dictionary,
		added_root: Node
	) -> bool:
	for record_value: Variant in connection_data["records"]:
		var record: Dictionary = record_value
		var source_node := record["source"] as Node
		if source_node == added_root or added_root.is_ancestor_of(source_node):
			continue
		var target_node := record["target"] as Node
		if target_node == added_root or added_root.is_ancestor_of(target_node):
			return true
	return false


func _node_has_persistent_signal_connection(connection_data: Dictionary, node: Node) -> bool:
	return (connection_data["source_ids"] as Dictionary).has(node.get_instance_id())


func _collect_subtree_nodes(root: Node, output: Array[Node]) -> void:
	output.append(root)
	for child: Node in root.get_children(false):
		_collect_subtree_nodes(child, output)


func _get_unsafe_value_reason(
		value: Variant,
		owning_node: Node,
		instance_root: Node,
		edited_scene_root: Node,
		usage: int,
		depth: int = 0
	) -> String:
	if depth > 8:
		return "The safety of a nested value could not be verified."
	match typeof(value):
		TYPE_NODE_PATH:
			if (usage & PROPERTY_USAGE_NODE_PATH_FROM_SCENE_ROOT) != 0 and not (value as NodePath).is_empty():
				return "A NodePath relative to the edited scene root cannot be safely rebased to the base scene."
			if not _node_path_stays_inside_instance(value as NodePath, owning_node, instance_root, edited_scene_root, usage):
				return "The NodePath points outside the instance boundary or cannot be verified."
		TYPE_OBJECT:
			if value == null:
				return ""
			if value is Resource:
				var resource := value as Resource
				if resource.is_built_in() or resource.resource_path.is_empty() or "::" in resource.resource_path:
					return "Creating or internally editing a built-in subresource is not supported."
				return ""
			return "An Object reference that is not a Resource cannot be serialized safely."
		TYPE_ARRAY:
			for element: Variant in value:
				var element_reason := _get_unsafe_value_reason(
					element,
					owning_node,
					instance_root,
					edited_scene_root,
					usage,
					depth + 1
				)
				if not element_reason.is_empty():
					return element_reason
		TYPE_DICTIONARY:
			for key: Variant in value:
				var key_reason := _get_unsafe_value_reason(
					key,
					owning_node,
					instance_root,
					edited_scene_root,
					usage,
					depth + 1
				)
				if not key_reason.is_empty():
					return key_reason
				var dictionary_value_reason := _get_unsafe_value_reason(
					value[key],
					owning_node,
					instance_root,
					edited_scene_root,
					usage,
					depth + 1
				)
				if not dictionary_value_reason.is_empty():
					return dictionary_value_reason
	return ""


func _node_path_stays_inside_instance(
		node_path: NodePath,
		owning_node: Node,
		instance_root: Node,
		edited_scene_root: Node,
		usage: int
	) -> bool:
	if node_path.is_empty():
		return true
	if node_path.is_absolute():
		return false
	var names_only := NodePath(String(node_path.get_concatenated_names()))
	if names_only.is_empty():
		return true
	var lookup_root := edited_scene_root if (usage & PROPERTY_USAGE_NODE_PATH_FROM_SCENE_ROOT) != 0 else owning_node
	var target := lookup_root.get_node_or_null(names_only)
	if target == null:
		return false
	return target == instance_root or instance_root.is_ancestor_of(target)


func _property_can_be_an_instance_override(usage: int) -> bool:
	return (usage & PROPERTY_USAGE_STORAGE) != 0 and (usage & PROPERTY_USAGE_NO_INSTANCE_STATE) == 0


func _is_excluded_root_placement_property(node: Node, property_name: StringName) -> bool:
	if node is Control:
		return property_name in CONTROL_ROOT_LAYOUT_PROPERTIES
	if node is Node2D:
		return property_name in NODE_2D_ROOT_PLACEMENT_PROPERTIES
	if node is Node3D:
		return property_name in NODE_3D_ROOT_PLACEMENT_PROPERTIES
	return false


func _index_property_information(object: Object, caches: Dictionary) -> Dictionary:
	var instance_cache_key := "prop_info:%d" % object.get_instance_id()
	var local_cache: Dictionary = caches["local"]
	if local_cache.has(instance_cache_key):
		return local_cache[instance_cache_key]
	var property_information: Dictionary
	if object.get_script() == null:
		var class_cache_key := StringName("prop_info_class:" + object.get_class())
		if not _class_property_information_cache.has(class_cache_key):
			_class_property_information_cache[class_cache_key] = _build_property_information(object)
		property_information = _class_property_information_cache[class_cache_key]
	else:
		property_information = _build_property_information(object)
	local_cache[instance_cache_key] = property_information
	return property_information


func _build_property_information(object: Object) -> Dictionary:
	var property_information := {}
	for property_info: Dictionary in object.get_property_list():
		property_information[StringName(property_info["name"])] = property_info
	return property_information


func _object_has_property(object: Object, property_name: StringName, caches: Dictionary) -> bool:
	return _index_property_information(object, caches).has(property_name)


func _values_are_equivalent(current_value: Variant, base_value: Variant) -> bool:
	if typeof(current_value) != typeof(base_value):
		return false
	if current_value is Resource and base_value is Resource:
		var current_resource := current_value as Resource
		var base_resource := base_value as Resource
		if current_resource.is_built_in() or base_resource.is_built_in():
			# A built-in resource selected for serialization may contain internal edits even when its path is unchanged.
			return false
		if not current_resource.resource_path.is_empty() and not base_resource.resource_path.is_empty():
			return current_resource.resource_path == base_resource.resource_path
	return current_value == base_value


func _make_entry(
		kind: String,
		node_path: String,
		property_name: StringName,
		current_value: Variant,
		base_value: Variant,
		reason: String,
		supported: bool
	) -> Dictionary:
	var identifier_suffix := String(property_name)
	if identifier_suffix.is_empty():
		identifier_suffix = "@node"
	return {
		"id": "%s:%s:%s" % [kind, node_path, identifier_suffix],
		"kind": kind,
		"node_path": node_path,
		"property_name": String(property_name),
		"current_value": current_value,
		"base_value": base_value,
		"reason": reason,
		"selected": true,
		"supported": supported,
	}


func _relative_path(root: Node, node: Node) -> String:
	return _normalize_path(String(root.get_path_to(node)))


func _path_from_edited_root(edited_scene_root: Node, node: Node) -> String:
	return _normalize_path(String(edited_scene_root.get_path_to(node)))


func _normalize_path(path: String) -> String:
	if path.is_empty() or path == ".":
		return "."
	if path.begins_with("./"):
		return path.substr(2)
	return path


func _path_is_inside_any_subtree(path: String, subtree_roots: Array[String]) -> bool:
	for subtree_root: String in subtree_roots:
		if path.begins_with(subtree_root + "/"):
			return true
	return false


func _shorter_path_comes_first(left: String, right: String) -> bool:
	var left_depth := left.count("/")
	var right_depth := right.count("/")
	if left_depth == right_depth:
		return left < right
	return left_depth < right_depth


func _entry_comes_before(left: Dictionary, right: Dictionary) -> bool:
	var kind_order := {
		KIND_SUPPORTED_PROPERTY: 0,
		KIND_ADDED_NODE: 1,
		KIND_UNSUPPORTED: 2,
	}
	var left_kind_order := int(kind_order.get(String(left["kind"]), 99))
	var right_kind_order := int(kind_order.get(String(right["kind"]), 99))
	if left_kind_order != right_kind_order:
		return left_kind_order < right_kind_order
	var left_path := String(left["node_path"])
	var right_path := String(right["node_path"])
	if left_path != right_path:
		return left_path < right_path
	return String(left["property_name"]) < String(right["property_name"])
