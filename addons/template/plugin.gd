@tool
extends EditorPlugin

const WELCOME_URL := "https://www.cnblogs.com/mmme/p/-/tutorial"
const MARKER_PATH := "user://.first_run_welcome_done"

const TEMPLATE_DEFAULT := "res://[Scenes]/DefaultScene/Default.tscn"
const TEMPLATE_SAMPLE := "res://[Scenes]/Sample/Sample.tscn"
const LEVELS_ROOT := "res://[Scenes]/"

var _menu_button: MenuButton
var _new_level_dialog: ConfirmationDialog


func _enter_tree() -> void:
	_check_first_run()

	_menu_button = MenuButton.new()
	_menu_button.text = "Template"
	_menu_button.tooltip_text = "Template 相关资源"
	_menu_button.switch_on_hover = true

	var popup: PopupMenu = _menu_button.get_popup()
	popup.add_item("Tutorial", 0)
	popup.add_item("新建关卡", 1)
	popup.id_pressed.connect(_on_menu_item_pressed)

	add_control_to_container(CONTAINER_TOOLBAR, _menu_button)


func _exit_tree() -> void:
	if _menu_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _menu_button)
		_menu_button.queue_free()
		_menu_button = null
	if _new_level_dialog and is_instance_valid(_new_level_dialog):
		_new_level_dialog.queue_free()
		_new_level_dialog = null


func _check_first_run() -> void:
	if FileAccess.file_exists(MARKER_PATH):
		return
	var f := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if f:
		f.store_string("done")
		f.close()
	await get_tree().process_frame
	OS.shell_open(WELCOME_URL)
	print("[FirstRunWelcome] 已打开项目主页: %s" % WELCOME_URL)


func _on_menu_item_pressed(id: int) -> void:
	match id:
		0:
			OS.shell_open(WELCOME_URL)
		1:
			_show_new_level_dialog()


# ===================== 新建关卡 =====================

func _show_new_level_dialog() -> void:
	if _new_level_dialog and is_instance_valid(_new_level_dialog):
		_new_level_dialog.queue_free()
		_new_level_dialog = null

	var dialog := ConfirmationDialog.new()
	dialog.title = "新建关卡"
	dialog.min_size = Vector2i(380, 240)
	dialog.ok_button_text = "创建"
	_new_level_dialog = dialog

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)

	# 关卡名称
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "关卡名称："
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_row.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "MyLevel"
	name_edit.custom_minimum_size = Vector2(250, 0)
	name_row.add_child(name_edit)

	# 模板场景
	var tpl_row := HBoxContainer.new()
	vbox.add_child(tpl_row)
	var tpl_lbl := Label.new()
	tpl_lbl.text = "模板场景："
	tpl_lbl.custom_minimum_size = Vector2(100, 0)
	tpl_row.add_child(tpl_lbl)
	var tpl_opts := OptionButton.new()
	tpl_opts.add_item("DefaultScene", 0)
	tpl_opts.add_item("Sample", 1)
	tpl_opts.custom_minimum_size = Vector2(250, 0)
	tpl_row.add_child(tpl_opts)

	# 关卡 ID
	var id_row := HBoxContainer.new()
	vbox.add_child(id_row)
	var id_lbl := Label.new()
	id_lbl.text = "关卡ID："
	id_lbl.custom_minimum_size = Vector2(100, 0)
	id_row.add_child(id_lbl)
	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "1"
	id_edit.custom_minimum_size = Vector2(250, 0)
	id_edit.text = "1"
	id_row.add_child(id_edit)

	# 提示
	var hint := Label.new()
	hint.text = "将在 [Scenes]/<关卡名>/ 下创建场景与唯一的 LevelData 资源"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font", 12)
	vbox.add_child(hint)

	add_child(dialog)

	dialog.confirmed.connect(func():
		var level_name := name_edit.text.strip_edges()
		var template_path: String = TEMPLATE_DEFAULT if tpl_opts.selected == 0 else TEMPLATE_SAMPLE
		var level_id_text := id_edit.text.strip_edges()
		var level_id := 1
		if level_id_text.is_valid_int():
			level_id = level_id_text.to_int()
		if level_name.is_empty():
			_push_error("关卡名称不能为空")
			return
		var err := _create_new_level(level_name, template_path, level_id)
		if err == OK:
			print("[NewLevel] 关卡创建成功：%s (id=%d, 模板=%s)" % [level_name, level_id, template_path])
			dialog.hide()
	)

	dialog.popup_centered()
	await get_tree().process_frame
	name_edit.call_deferred("grab_focus")


## 新建关卡：基于模板场景实例化、替换 LevelData 为唯一副本、重新打包保存
func _create_new_level(level_name: String, template_path: String, level_id: int) -> int:
	var safe_name := _sanitize_name(level_name)
	if safe_name.is_empty():
		_push_error("无效的关卡名称：%s" % level_name)
		return ERR_INVALID_PARAMETER

	var level_dir := LEVELS_ROOT + safe_name + "/"
	var scene_path := level_dir + safe_name + ".tscn"
	var tres_path := level_dir + safe_name + ".tres"

	if FileAccess.file_exists(scene_path) or FileAccess.file_exists(tres_path):
		_push_error("关卡已存在：%s" % level_dir)
		return ERR_ALREADY_EXISTS

	var template_scene := load(template_path) as PackedScene
	if not template_scene:
		_push_error("无法加载模板场景：%s" % template_path)
		return ERR_CANT_OPEN

	# 使用 GEN_EDIT_STATE_MAIN 实例化，保留节点所有权（owner=root），保证 pack() 能正确打包
	var root := template_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if not root:
		_push_error("实例化模板场景失败：%s" % template_path)
		return ERR_CANT_CREATE

	# 查找 Player 节点
	var player := root.get_node_or_null("BasicOBJ_Group/Player") as Player
	if not player:
		_push_error("模板场景 %s 未找到 BasicOBJ_Group/Player 节点" % template_path)
		root.queue_free()
		return ERR_INVALID_DATA

	if not player.level_data:
		_push_error("模板场景 %s 的 Player 节点未设置 level_data" % template_path)
		root.queue_free()
		return ERR_INVALID_DATA

	# 创建目录
	DirAccess.make_dir_recursive_absolute(level_dir)

	# 深拷贝 LevelData 资源，设新字段（唯一化）
	var new_data := (player.level_data as Resource).duplicate(true) as LevelData
	if not new_data:
		_push_error("复制 LevelData 资源失败")
		root.queue_free()
		return ERR_CANT_CREATE
	new_data.saveID = level_id
	new_data.levelTitle = level_name
	# levelTitleKey 保持模板原值，仅当为空时用 safe_name
	if new_data.levelTitleKey.is_empty():
		new_data.levelTitleKey = safe_name

	# 保存 LevelData 资源（ResourceSaver 会自动分配 UID）
	var save_err := ResourceSaver.save(new_data, tres_path)
	if save_err != OK:
		_push_error("LevelData 资源保存失败：%s (err=%d)" % [tres_path, save_err])
		root.queue_free()
		return save_err
	print("[NewLevel] 已生成 LevelData 资源：%s" % tres_path)

	# 重新加载刚保存的资源，拿到带 UID 的引用
	var saved_data := load(tres_path) as LevelData
	if not saved_data:
		_push_error("无法重新加载刚保存的 LevelData：%s" % tres_path)
		root.queue_free()
		return ERR_CANT_OPEN

	# 将 Player 的 level_data 指向唯一副本
	player.level_data = saved_data

	# 打包并保存场景
	var new_scene := PackedScene.new()
	var pack_err := new_scene.pack(root)
	root.queue_free()
	if pack_err != OK:
		_push_error("打包场景失败 (err=%d)" % pack_err)
		return pack_err

	var scene_save_err := ResourceSaver.save(new_scene, scene_path)
	if scene_save_err != OK:
		_push_error("场景保存失败：%s (err=%d)" % [scene_path, scene_save_err])
		return scene_save_err
	print("[NewLevel] 已生成场景文件：%s" % scene_path)

	# 刷新文件系统
	EditorInterface.get_resource_filesystem().scan()

	# 在编辑器中打开新场景
	EditorInterface.open_scene_from_path(scene_path)

	return OK


func _sanitize_name(name: String) -> String:
	var out := ""
	for ch in name:
		var code := ch.unicode_at(0)
		# 允许：字母 (A-Z,a-z)、数字 (0-9)、下划线、连字符
		if (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or (code >= 48 and code <= 57) \
			or code == 95 or code == 45:
			out += ch
	return out


func _push_error(msg: String) -> void:
	push_error("[Template 插件] " + msg)
	printerr("[Template 插件] " + msg)
