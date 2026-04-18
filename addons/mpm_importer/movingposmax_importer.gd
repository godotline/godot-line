@tool
extends RefCounted

const MOVING_POS_SCRIPT := preload("res://#Template/[Scripts]/Animator/MovingPosMax.gd")
const POINT_CLASS := preload("res://addons/mpm_importer/MovingPosPoint.gd")

static func apply_entry(root: Node, entry: Dictionary, transform_fix: bool) -> Dictionary:
	var report := {
		"status": "ok",
		"messages": [],
	}

	var hierarchy_path := String(entry.get("hierarchy_path", ""))
	var base := _find_node_by_path(root, hierarchy_path, true, report)
	if base == null:
		var last_part := _get_last_path_part(hierarchy_path)
		base = _find_node_by_name_fallback(root, last_part, report, hierarchy_path)
	if base == null:
		report.status = "missing_node"
		report.messages.append("Missing node: %s" % hierarchy_path)
		return report

	if base is Node3D:
		_apply_local_transform(base, entry, transform_fix)

	var component_index := int(entry.get("component_index", 0))
	var target_area := _resolve_component_area(base, component_index, report)
	if target_area == null:
		report.status = "failed"
		report.messages.append("Failed to resolve Area3D for %s" % hierarchy_path)
		return report

	target_area.set_script(MOVING_POS_SCRIPT)
	_ensure_body_entered_connection(target_area)
	_apply_box_collider(target_area, entry)
	_apply_points(target_area, entry, transform_fix, report, hierarchy_path)
	_apply_animation_object(root, target_area, entry, report)

	return report

static func _find_node_by_path(root: Node, path: String, allow_fuzzy: bool, report: Dictionary) -> Node:
	if path.is_empty() or root == null:
		return null
	var parts := path.split("/", false)
	if parts.is_empty():
		return null

	var node: Node = root
	var start_index := 0
	if parts[0] == root.name:
		start_index = 1
	for i in range(start_index, parts.size()):
		var part := parts[i]
		var parent := node
		var next := parent.get_node_or_null(part)
		if next == null and allow_fuzzy:
			next = _find_child_fuzzy(parent, part, report)
		if next == null:
			return null
		node = next
	return node

static func _get_last_path_part(path: String) -> String:
	if path.is_empty():
		return ""
	var parts := path.split("/", false)
	if parts.is_empty():
		return ""
	return parts[parts.size() - 1]

static func _find_node_by_name_fallback(root: Node, part: String, report: Dictionary, original_path: String) -> Node:
	if root == null or part.is_empty():
		return null

	var normalized_target := _normalize_name(part)
	var matches: Array[Node] = []
	_collect_nodes_by_name(root, normalized_target, matches)

	if matches.size() == 1:
		report.messages.append("Fallback name match: '%s' -> '%s'" % [original_path, matches[0].get_path()])
		return matches[0]
	if matches.size() > 1:
		report.messages.append("Ambiguous fallback name match for '%s' (%d matches)" % [original_path, matches.size()])
	return null

static func _collect_nodes_by_name(node: Node, normalized_target: String, matches: Array) -> void:
	if _normalize_name(node.name) == normalized_target:
		matches.append(node)
	for child in node.get_children():
		_collect_nodes_by_name(child, normalized_target, matches)

static func _find_child_fuzzy(parent: Node, part: String, report: Dictionary) -> Node:
	if parent == null:
		return null

	var candidates: Array[String] = []
	candidates.append(part)

	var no_clone := _remove_clone_tag(part)
	if no_clone != part:
		candidates.append(no_clone)

	var no_index := _remove_trailing_index(part)
	if no_index != part:
		candidates.append(no_index)

	var no_clone_no_index := _remove_trailing_index(no_clone)
	if no_clone_no_index != part and no_clone_no_index != no_clone and no_clone_no_index != no_index:
		candidates.append(no_clone_no_index)

	for name in candidates:
		var direct := parent.get_node_or_null(name)
		if direct != null:
			report.messages.append("Fuzzy match: '%s' -> '%s'" % [part, name])
			return direct

	var normalized_target := _normalize_name(part)
	var matches: Array[Node] = []
	for child in parent.get_children():
		if _normalize_name(child.name) == normalized_target:
			matches.append(child)

	if matches.size() == 1:
		report.messages.append("Fuzzy match: '%s' -> '%s'" % [part, matches[0].name])
		return matches[0]
	if matches.size() > 1:
		report.messages.append("Ambiguous fuzzy match for '%s' (%d matches)" % [part, matches.size()])
		return matches[0]

	return null

static func _remove_clone_tag(value: String) -> String:
	var result := value.replace("(Clone)", "")
	return result.strip_edges()

static func _remove_trailing_index(value: String) -> String:
	if !value.ends_with(")"):
		return value
	var open_idx := value.rfind(" (")
	if open_idx == -1:
		return value
	var inside := value.substr(open_idx + 2, value.length() - open_idx - 3)
	if inside.is_valid_int():
		return value.substr(0, open_idx).strip_edges()
	return value

static func _normalize_name(value: String) -> String:
	var result := _remove_clone_tag(value)
	result = _remove_trailing_index(result)
	result = _remove_trailing_digits(result)
	return result.strip_edges()

static func _remove_trailing_digits(value: String) -> String:
	var idx := value.length() - 1
	if idx < 0:
		return value
	if !value[idx].is_valid_int():
		return value

	while idx >= 0 and value[idx].is_valid_int():
		idx -= 1

	if idx < 0:
		return value
	if value[idx] == " ":
		return value
	return value.substr(0, idx + 1).strip_edges()

static func _resolve_component_area(base: Node, component_index: int, report: Dictionary) -> Area3D:
	if component_index == 0 and base is Area3D:
		return base

	var parent := base
	if parent == null:
		return null

	var name := "MovingPosMax_%d" % component_index
	var existing := parent.get_node_or_null(name)
	if existing != null:
		if existing is Area3D:
			return existing
		report.messages.append("Name conflict for %s" % name)

	var area := Area3D.new()
	area.name = name
	area.position = Vector3.ZERO
	area.rotation = Vector3.ZERO
	area.scale = Vector3.ONE
	parent.add_child(area)
	if parent.get_owner() != null:
		area.owner = parent.get_owner()
	return area

static func _apply_local_transform(node: Node3D, entry: Dictionary, transform_fix: bool) -> void:
	var pos: Vector3 = entry.get("local_pos", Vector3.ZERO)
	var rot: Vector3 = entry.get("local_rot", Vector3.ZERO)
	var scl: Vector3 = entry.get("local_scale", Vector3.ONE)
	if transform_fix:
		pos.x = -pos.x
		rot.y = -rot.y
	node.position = pos
	node.rotation_degrees = rot
	node.scale = scl

static func _ensure_body_entered_connection(area: Area3D) -> void:
	var callable := Callable(area, "_on_body_entered")
	var connections := area.get_signal_connection_list("body_entered")
	var has_persistent := false
	for conn in connections:
		if conn.get("callable") == callable:
			var flags := int(conn.get("flags", 0))
			if (flags & Object.CONNECT_PERSIST) != 0:
				has_persistent = true
				break
	if has_persistent:
		return

	while area.is_connected("body_entered", callable):
		area.disconnect("body_entered", callable)
	area.connect("body_entered", callable, Object.CONNECT_PERSIST)

static func _apply_box_collider(area: Area3D, entry: Dictionary) -> void:
	var box_center: Vector3 = entry.get("box_center", Vector3.ZERO)
	var box_size: Vector3 = entry.get("box_size", Vector3.ZERO)

	var collision: CollisionShape3D = null
	for child in area.get_children():
		if child is CollisionShape3D:
			collision = child
			break
	if collision == null:
		collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		area.add_child(collision)
		if area.get_owner() != null:
			collision.owner = area.get_owner()

	var shape: BoxShape3D = null
	if collision.shape is BoxShape3D:
		shape = collision.shape
	else:
		shape = BoxShape3D.new()
		collision.shape = shape

	shape.size = box_size
	collision.position = box_center

static func _apply_points(area: Area3D, entry: Dictionary, transform_fix: bool, report: Dictionary, hierarchy_path: String) -> void:
	var positions_data: Array = entry.get("positions", [])
	var target_positions: Array[Vector3] = []
	var move_durations: Array[float] = []
	var wait_times: Array[float] = []
	var transition_type: Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR
	
	for i in range(positions_data.size()):
		var data = positions_data[i]
		var pos: Vector3 = data.get("pos", Vector3.ZERO)
		if transform_fix:
			pos.x = -pos.x
		target_positions.append(pos)
		move_durations.append(float(data.get("postime", 1.0)))
		wait_times.append(float(data.get("waittime", 0.0)))
		if i == 0:
			transition_type = _map_ease(int(data.get("ease", 0)), String(data.get("ease_name", "")))

	area.set("target_positions", target_positions)
	area.set("move_durations", move_durations)
	area.set("wait_times", wait_times)
	area.set("transition_type", transition_type)
	area.notify_property_list_changed()
	
	if target_positions.is_empty():
		report.messages.append("No points set: %s" % hierarchy_path)

static func _apply_animation_object(root: Node, area: Area3D, entry: Dictionary, report: Dictionary) -> void:
	var path := String(entry.get("animation_object_path", ""))
	if path.is_empty():
		return
	var target := _find_node_by_path(root, path, true, report)
	if target == null:
		report.messages.append("Missing animated_object: %s" % path)
		return
	area.set("animated_object", target)

static func _map_ease(unity_ease: int, ease_name: String) -> Tween.TransitionType:
	var name := ease_name.strip_edges()
	if !name.is_empty():
		return _map_ease_name(name)
	return _map_ease_int(unity_ease)

static func _map_ease_name(name: String) -> Tween.TransitionType:
	var key := name.to_lower()
	if key.ends_with("sine"):
		return Tween.TransitionType.TRANS_SINE
	if key.ends_with("quad"):
		return Tween.TransitionType.TRANS_QUAD
	if key.ends_with("cubic"):
		return Tween.TransitionType.TRANS_CUBIC
	if key.ends_with("quart"):
		return Tween.TransitionType.TRANS_QUART
	if key.ends_with("quint"):
		return Tween.TransitionType.TRANS_QUINT
	if key.ends_with("expo"):
		return Tween.TransitionType.TRANS_EXPO
	if key.ends_with("circ"):
		return Tween.TransitionType.TRANS_CIRC
	if key.ends_with("back"):
		return Tween.TransitionType.TRANS_BACK
	if key.ends_with("bounce"):
		return Tween.TransitionType.TRANS_BOUNCE
	if key.ends_with("elastic"):
		return Tween.TransitionType.TRANS_ELASTIC
	if key.ends_with("flash"):
		return Tween.TransitionType.TRANS_LINEAR
	if key == "linear":
		return Tween.TransitionType.TRANS_LINEAR
	return Tween.TransitionType.TRANS_SINE

static func _map_ease_int(unity_ease: int) -> Tween.TransitionType:
	match unity_ease:
		1:
			return Tween.TransitionType.TRANS_LINEAR # Linear
		2, 3, 4:
			return Tween.TransitionType.TRANS_SINE # In/Out/InOutSine
		5, 6, 7:
			return Tween.TransitionType.TRANS_QUAD # In/Out/InOutQuad
		8, 9, 10:
			return Tween.TransitionType.TRANS_CUBIC # In/Out/InOutCubic
		11, 12, 13:
			return Tween.TransitionType.TRANS_QUART # In/Out/InOutQuart
		14, 15, 16:
			return Tween.TransitionType.TRANS_QUINT # In/Out/InOutQuint
		17, 18, 19:
			return Tween.TransitionType.TRANS_EXPO # In/Out/InOutExpo
		20, 21, 22:
			return Tween.TransitionType.TRANS_CIRC # In/Out/InOutCirc
		23, 24, 25:
			return Tween.TransitionType.TRANS_ELASTIC # In/Out/InOutElastic
		26, 27, 28:
			return Tween.TransitionType.TRANS_BACK # In/Out/InOutBack
		29, 30, 31:
			return Tween.TransitionType.TRANS_BOUNCE # In/Out/InOutBounce
		32, 33, 34, 35:
			return Tween.TransitionType.TRANS_LINEAR # Flash variants
		0:
			return Tween.TransitionType.TRANS_SINE # Unset
		_:
			return Tween.TransitionType.TRANS_SINE
