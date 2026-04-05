@tool
extends EditorScript

const META_PATH := "res://#Template/level_patch_meta.tres"
const META_DIR := "res://#Template/level_patches"
const OUTPUT_DIR := "res://patches/levels"

func _run() -> void:
	var metas := _collect_metas()
	if metas.is_empty():
		push_warning("No LevelPatchMeta found. Put one at %s or in %s" % [META_PATH, META_DIR])
		return

	var out_abs := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)

	for meta in metas:
		if meta == null:
			continue
		_write_level(meta)

	print("Patch level generation done.")

func _collect_metas() -> Array:
	var results: Array = []
	if FileAccess.file_exists(META_PATH):
		var meta = load(META_PATH)
		if meta != null:
			results.append(meta)

	var dir := DirAccess.open(META_DIR)
	if dir == null:
		return results
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.to_lower().ends_with(".tres"):
			var res = load(META_DIR.path_join(name))
			if res != null:
				results.append(res)
		name = dir.get_next()
	dir.list_dir_end()
	return results

func _write_level(meta) -> void:
	if not meta is LevelPatchMeta:
		push_warning("Unsupported meta type: %s" % [meta])
		return
	if meta.name.strip_edges() == "":
		push_warning("Level name is empty, skip.")
		return
	if meta.tiny_levels.is_empty():
		push_warning("Tiny levels empty for: %s" % meta.name)
		return

	var safe_file: String = meta.file_name.strip_edges()
	if safe_file == "":
		safe_file = _slugify(meta.name)
	var out_path := OUTPUT_DIR.path_join(safe_file + ".tres")

	var lines: Array[String] = []
	lines.append('[gd_resource type="Resource" script_class="LevelData" format=3]')
	lines.append("")
	lines.append('[ext_resource type="Script" path="res://Scripts/ui/leveldata.gd" id="1"]')
	lines.append('[ext_resource type="Script" path="res://Scripts/ui/tinylevel.gd" id="2"]')
	var has_card: bool = meta.card_path.strip_edges() != ""
	if has_card:
		lines.append('[ext_resource type="Resource" path="%s" id="3"]' % _tres_string(meta.card_path))

	var sub_ids: Array[String] = []
	for i in range(meta.tiny_levels.size()):
		var tiny: TinyLevelMeta = meta.tiny_levels[i]
		var sub_id := "Resource_%d" % (i + 1)
		sub_ids.append(sub_id)
		lines.append("")
		lines.append('[sub_resource type="Resource" id="%s"]' % sub_id)
		lines.append('script = ExtResource("2")')
		lines.append('name = "%s"' % _tres_string(tiny.name))
		lines.append('path = "%s"' % _tres_string(tiny.path))

	lines.append("")
	lines.append("[resource]")
	lines.append('script = ExtResource("1")')
	lines.append('name = "%s"' % _tres_string(meta.name))
	lines.append('chinese_name = "%s"' % _tres_string(meta.chinese_name))
	lines.append("star = %d" % int(meta.star))
	lines.append('level_maker = "%s"' % _tres_string(meta.level_maker))
	lines.append('music_maker = "%s"' % _tres_string(meta.music_maker))
	lines.append('introduction = "%s"' % _tres_string(meta.introduction))
	lines.append('tinylevel = Array[ExtResource("2")]([%s])' % _join_subresources(sub_ids))
	lines.append('background_path = "%s"' % _tres_string(meta.background_path))
	lines.append('roundphoto_path = "%s"' % _tres_string(meta.roundphoto_path))
	lines.append("color = Color(%s, %s, %s, %s)" % [
		_float(meta.color.r),
		_float(meta.color.g),
		_float(meta.color.b),
		_float(meta.color.a),
	])
	lines.append("unlock = %s" % ("true" if meta.unlock else "false"))
	if has_card:
		lines.append('card = ExtResource("3")')

	var content := "\n".join(lines) + "\n"
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to write: %s" % out_path)
		return
	file.store_string(content)
	file.flush()
	print("Generated level data:", out_path)

func _join_subresources(ids: Array[String]) -> String:
	var parts: Array[String] = []
	for id in ids:
		parts.append('SubResource("%s")' % id)
	return ", ".join(parts)

func _slugify(src: String) -> String:
	var out := ""
	for ch in src:
		var code := ch.unicode_at(0)
		var is_alpha := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		out += ch if is_alpha else "_"
	out = out.strip_edges()
	if out == "":
		out = "level"
	return out

func _tres_string(src: String) -> String:
	var s := src
	s = s.replace("\\", "\\\\")
	s = s.replace("\"", "\\\"")
	s = s.replace("\r\n", "\n")
	s = s.replace("\n", "\\n")
	return s

func _float(v: float) -> String:
	return String.num(v, 6)
