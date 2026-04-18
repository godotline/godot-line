@tool
extends RefCounted

static func parse_text(text: String) -> Dictionary:
	var raw: Dictionary = {}
	for line in text.split("\n", false):
		var trimmed := line.strip_edges()
		if trimmed.is_empty():
			continue
		if !trimmed.contains("="):
			continue
		var parts := trimmed.split("=", false, 2)
		if parts.size() < 2:
			continue
		var key := parts[0].strip_edges()
		var value := parts[1].strip_edges()
		raw[key] = value

	var result: Dictionary = {}
	result["hierarchy_path"] = raw.get("hierarchy_path", "")
	result["component_index"] = int(raw.get("component_index", "0"))
	result["local_pos"] = _parse_vec3(raw.get("local_pos", "0,0,0"))
	result["local_rot"] = _parse_vec3(raw.get("local_rot", "0,0,0"))
	result["local_scale"] = _parse_vec3(raw.get("local_scale", "1,1,1"))
	result["box_center"] = _parse_vec3(raw.get("box_center", "0,0,0"))
	result["box_size"] = _parse_vec3(raw.get("box_size", "0,0,0"))
	result["set_camera_path"] = raw.get("set_camera_path", "")

	result["active_position"] = _parse_bool(raw.get("active_position", "true"))
	result["new_add_position"] = _parse_vec3(raw.get("new_add_position", "0,0,0"))
	result["active_rotate"] = _parse_bool(raw.get("active_rotate", "true"))
	result["new_rotation"] = _parse_vec3(raw.get("new_rotation", "0,0,0"))
	result["active_distance"] = _parse_bool(raw.get("active_distance", "true"))
	result["new_distance"] = float(raw.get("new_distance", "0"))
	result["active_speed"] = _parse_bool(raw.get("active_speed", "true"))
	result["new_follow_speed"] = float(raw.get("new_follow_speed", "0"))
	result["ease_type"] = _parse_ease_type(raw.get("ease_type", ""))
	result["need_time"] = float(raw.get("need_time", "0"))
	result["use_time"] = _parse_bool(raw.get("use_time", "false"))
	result["trigger_time"] = float(raw.get("trigger_time", "0"))

	return result

static func _parse_vec3(value: String) -> Vector3:
	var parts := value.split(",", false)
	if parts.size() < 3:
		return Vector3.ZERO
	return Vector3(
		float(parts[0].strip_edges()),
		float(parts[1].strip_edges()),
		float(parts[2].strip_edges())
	)

static func _parse_bool(value: String) -> bool:
	var key := value.strip_edges().to_lower()
	return key == "true" or key == "1" or key == "yes" or key == "on"

static func _parse_ease_type(value: String) -> Tween.EaseType:
	var key := value.strip_edges().to_lower()
	if key.begins_with("inout"):
		return Tween.EaseType.EASE_IN_OUT
	if key.begins_with("in"):
		return Tween.EaseType.EASE_IN
	if key.begins_with("out"):
		return Tween.EaseType.EASE_OUT
	if key.findn("inout") != -1:
		return Tween.EaseType.EASE_IN_OUT
	if key.findn("in") != -1:
		return Tween.EaseType.EASE_IN
	if key.findn("out") != -1:
		return Tween.EaseType.EASE_OUT
	return Tween.EaseType.EASE_IN_OUT
