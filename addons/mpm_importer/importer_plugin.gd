@tool
extends EditorPlugin

const PLUGIN_NAME = "MPM Importer"

const AnimatorParser := preload("res://addons/mpm_importer/animatorplayer_mpm_parser.gd")
const AnimatorImporter := preload("res://addons/mpm_importer/animatorplayer_importer.gd")
const CameraParser := preload("res://addons/mpm_importer/cameratrigger_mpm_parser.gd")
const CameraImporter := preload("res://addons/mpm_importer/cameratrigger_importer.gd")
const MovingPosParser := preload("res://addons/mpm_importer/movingposmax_mpm_parser.gd")
const MovingPosImporter := preload("res://addons/mpm_importer/movingposmax_importer.gd")

var menu_button: MenuButton
var import_menu: PopupMenu
var animations_root_path: NodePath = NodePath("")
var default_camera_path: NodePath = NodePath("")
var transform_fix: bool = true

func _enter_tree():
	_add_toolbar_menu()
	print(PLUGIN_NAME + " plugin loaded")

func _exit_tree():
	_remove_toolbar_menu()
	print(PLUGIN_NAME + " plugin unloaded")

func _add_toolbar_menu():
	# 创建菜单按钮
	menu_button = MenuButton.new()
	menu_button.text = "MPM导入"
	menu_button.flat = false
	
	import_menu = menu_button.get_popup()
	import_menu.add_item("导入 AnimatorPlayer...", 0)
	import_menu.add_item("导入 CameraTrigger...", 1)
	import_menu.add_item("导入 MovingPosMax...", 2)
	import_menu.add_separator()
	import_menu.add_item("设置 animations_root", 3)
	import_menu.add_item("设置 default_camera", 4)
	import_menu.add_check_item("坐标转换修复", 5)
	import_menu.set_item_checked(5, transform_fix)
	
	import_menu.id_pressed.connect(_on_menu_item_pressed)
	
	# 添加到工具栏
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, menu_button)

func _remove_toolbar_menu():
	if menu_button != null:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, menu_button)
		menu_button.queue_free()
		menu_button = null

func _on_menu_item_pressed(id: int):
	match id:
		0:
			_import_animatorplayer()
		1:
			_import_cameratrigger()
		2:
			_import_movingposmax()
		3:
			_set_animations_root()
		4:
			_set_default_camera()
		5:
			_toggle_transform_fix()

func _import_animatorplayer():
	if animations_root_path == NodePath(""):
		push_warning("请先设置 animations_root 路径 (MPM导入 > 设置 animations_root)")
		return
	_show_folder_dialog("导入 AnimatorPlayer", func(dir: String):
		_import_folder(dir, "animatorplayer")
	)

func _import_cameratrigger():
	_show_folder_dialog("导入 CameraTrigger", func(dir: String):
		_import_folder(dir, "cameratrigger")
	)

func _import_movingposmax():
	_show_folder_dialog("导入 MovingPosMax", func(dir: String):
		_import_folder(dir, "movingposmax")
	)

func _set_animations_root():
	_show_node_path_dialog("设置 Animations Root", animations_root_path, func(path: NodePath):
		animations_root_path = path
		print("animations_root 已设置为: %s" % path)
	)

func _set_default_camera():
	_show_node_path_dialog("设置 Default Camera", default_camera_path, func(path: NodePath):
		default_camera_path = path
		print("default_camera 已设置为: %s" % path)
	)

func _toggle_transform_fix():
	transform_fix = !transform_fix
	import_menu.set_item_checked(5, transform_fix)
	print("坐标转换修复: %s" % ("开启" if transform_fix else "关闭"))

func _show_folder_dialog(title: String, callback: Callable):
	var file_dialog := EditorFileDialog.new()
	file_dialog.title = title
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	file_dialog.set_initial_position(Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS)
	file_dialog.set_size(Vector2i(1000, 600))
	
	file_dialog.dir_selected.connect(func(dir: String) -> void:
		file_dialog.queue_free()
		callback.call(dir)
	, CONNECT_ONE_SHOT)
	file_dialog.close_requested.connect(func() -> void:
		file_dialog.queue_free()
	, CONNECT_ONE_SHOT)
	
	get_editor_interface().get_base_control().add_child(file_dialog)
	file_dialog.popup.call_deferred()

func _show_node_path_dialog(title: String, current_path: NodePath, callback: Callable):
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.set_initial_position(Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS)
	
	var vbox := VBoxContainer.new()
	vbox.set_custom_minimum_size(Vector2(400, 0))
	
	var label := Label.new()
	label.text = "输入节点路径 (NodePath):"
	vbox.add_child(label)
	
	var line_edit := LineEdit.new()
	line_edit.text = String(current_path)
	line_edit.expand_to_text_length = true
	vbox.add_child(line_edit)
	
	dialog.add_child(vbox)
	
	dialog.confirmed.connect(func():
		callback.call(NodePath(line_edit.text))
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup.call_deferred()

func _import_folder(dir: String, importer_type: String):
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		push_warning("没有打开的场景")
		return
	
	var da := DirAccess.open(dir)
	if da == null:
		push_warning("无法打开文件夹: %s" % dir)
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
			messages.append("空文件或无法读取: %s" % path)
			continue
		
		var report: Dictionary
		match importer_type:
			"animatorplayer":
				var animations_node = root.get_node_or_null(animations_root_path)
				if animations_node == null:
					push_warning("找不到 animations_root 节点: %s" % animations_root_path)
					return
				var entry: Dictionary = AnimatorParser.parse_text(text)
				report = AnimatorImporter.apply_entry(root, entry, animations_node)
			"cameratrigger":
				var entry: Dictionary = CameraParser.parse_text(text)
				report = CameraImporter.apply_entry(root, entry, default_camera_path, transform_fix)
			"movingposmax":
				var entry: Dictionary = MovingPosParser.parse_text(text)
				report = MovingPosImporter.apply_entry(root, entry, transform_fix)
		
		match String(report.get("status", "")):
			"ok":
				ok += 1
			"missing_node":
				missing += 1
				messages.append_array(report.get("messages", []))
			_:
				failed += 1
				messages.append_array(report.get("messages", []))
	
	print("%s 导入结果" % importer_type.capitalize())
	print("总计: %d, 成功: %d, 缺失节点: %d, 失败: %d" % [total, ok, missing, failed])
	for msg in messages:
		print(msg)

func _enable_plugin():
	print(PLUGIN_NAME + " enabled")

func _disable_plugin():
	print(PLUGIN_NAME + " disabled")
