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
	result["animation_object_path"] = raw.get("animation_object_path", "")

	var positions: Array = []
	var count := int(raw.get("positions_count", "0"))
	for i in range(count):
		var prefix := "position_%d_" % i
		var entry := {
			"pos": _parse_vec3(raw.get(prefix + "pos", "0,0,0")),
			"ease": int(raw.get(prefix + "ease", "0")),
			"ease_name": raw.get(prefix + "ease_name", ""),
			"postime": float(raw.get(prefix + "postime", "0")),
			"waittime": float(raw.get(prefix + "waittime", "0")),
		}
		positions.append(entry)
	result["positions"] = positions
	result["positions_count"] = count

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
