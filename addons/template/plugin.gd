@tool
extends EditorPlugin

const WELCOME_URL := "https://github.com/meny2333/GodotLineCollection"
const MARKER_PATH := "user://.first_run_welcome_done"

var _menu_button: MenuButton


func _enter_tree() -> void:
	# --- 首次运行：打开项目主页 ---
	_check_first_run()

	# --- 右上角工具栏 Template 菜单 ---
	_menu_button = MenuButton.new()
	_menu_button.text = "Template"
	_menu_button.tooltip_text = "Template 相关资源"
	_menu_button.switch_on_hover = true

	var popup: PopupMenu = _menu_button.get_popup()
	popup.add_item("Tutorial", 0)
	popup.id_pressed.connect(_on_menu_item_pressed)

	add_control_to_container(CONTAINER_TOOLBAR, _menu_button)


func _exit_tree() -> void:
	if _menu_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _menu_button)
		_menu_button.queue_free()
		_menu_button = null


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
