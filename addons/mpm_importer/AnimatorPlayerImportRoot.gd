@tool
extends Node

const Parser := preload("res://addons/mpm_importer/animatorplayer_mpm_parser.gd")
const Importer := preload("res://addons/mpm_importer/animatorplayer_importer.gd")

@export var animations_root: NodePath

@export_tool_button("Import AnimatorPlayer Folder") var import_action = func():
	if !Engine.is_editor_hint():
		return
	_show_folder_dialog()

func _show_folder_dialog() -> void:
	var file_dialog := EditorFileDialog.new()
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	file_dialog.set_initial_position(Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS)
	file_dialog.set_size(Vector2i(1200, 800))

	file_dialog.dir_selected.connect(func(dir: String) -> void:
		file_dialog.queue_free()
		_import_from_folder(dir), CONNECT_ONE_SHOT)
	file_dialog.close_requested.connect(func() -> void:
		file_dialog.queue_free(), CONNECT_ONE_SHOT)

	EditorInterface.get_base_control().add_child(file_dialog)
	file_dialog.popup.call_deferred()

func _import_from_folder(dir: String) -> void:
	var root := get_tree().edited_scene_root
	if root == null:
		push_warning("No edited scene root found.")
		return

	if animations_root == NodePath(""):
		push_warning("animations_root not set.")
		return
	var animations_node := get_node_or_null(animations_root)
	if animations_node == null:
		push_warning("Missing animations_root: %s" % animations_root)
		return

	var da := DirAccess.open(dir)
	if da == null:
		push_warning("Failed to open folder: %s" % dir)
		return

	var files := da.get_files()
	var total := 0
	var ok := 0
	var missing := 0
	var failed := 0
	var messages: Array = []

	for file_name in files:
		if !file_name.to_lower().ends_with(".mpm"):
			continue
		total += 1
		var path := dir.path_join(file_name)
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			failed += 1
			messages.append("Empty or unreadable file: %s" % path)
			continue

		var entry: Dictionary = Parser.parse_text(text)
		var report: Dictionary = Importer.apply_entry(root, entry, animations_node)
		match String(report.get("status", "")):
			"ok":
				ok += 1
			"missing_node":
				missing += 1
				messages.append_array(report.get("messages", []))
			_:
				failed += 1
				messages.append_array(report.get("messages", []))

	print("AnimatorPlayer Import Summary")
	print("Total: %d, OK: %d, Missing: %d, Failed: %d" % [total, ok, missing, failed])
	for msg in messages:
		print(msg)
