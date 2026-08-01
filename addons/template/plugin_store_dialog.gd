@tool
class_name PluginStoreDialog
extends ConfirmationDialog

## 插件商城对话框 - 显示可用插件列表，支持一键下载、启用、卸载

const PluginDownloaderClass := preload("res://addons/template/plugin_downloader.gd")

var _plugin_list: ItemList
var _source_edit: LineEdit
var _refresh_button: Button
var _name_label: Label
var _info_label: RichTextLabel
var _action_button: Button
var _progress_bar: ProgressBar
var _status_label: Label
var _detail_panel: PanelContainer
var _all_plugins: Array[PluginEntry]
var _downloader: PluginDownloader
var _is_busy: bool = false
var _manifest_warning: String = ""
var _is_refreshing: bool = false


## 清理上一次编辑器会话遗留的隔离文件。user:// 不会被 EditorFileSystem 扫描。
static func cleanup_quarantine() -> void:
	var trash_root: String = ProjectSettings.globalize_path("user://plugin_store_trash")
	if not DirAccess.dir_exists_absolute(trash_root):
		return

	var trash_dir: DirAccess = DirAccess.open(trash_root)
	if trash_dir == null:
		return

	trash_dir.list_dir_begin()
	while true:
		var entry_name: String = trash_dir.get_next()
		if entry_name.is_empty():
			break
		if entry_name == "." or entry_name == "..":
			continue
		var entry_path: String = trash_root.path_join(entry_name)
		if trash_dir.current_is_dir():
			_remove_quarantine_tree(entry_path)
		else:
			var remove_err: Error = DirAccess.remove_absolute(entry_path)
			if remove_err != OK:
				push_warning("[PluginStore] 无法清理隔离文件（错误码：%d）：%s" % [remove_err, entry_path])
	trash_dir.list_dir_end()


static func _remove_quarantine_tree(dir_path: String) -> void:
	var directory: DirAccess = DirAccess.open(dir_path)
	if directory == null:
		return

	directory.list_dir_begin()
	while true:
		var child_name: String = directory.get_next()
		if child_name.is_empty():
			break
		if child_name == "." or child_name == "..":
			continue
		var child_path: String = dir_path.path_join(child_name)
		if directory.current_is_dir():
			_remove_quarantine_tree(child_path)
		else:
			var remove_err: Error = DirAccess.remove_absolute(child_path)
			if remove_err != OK:
				push_warning("[PluginStore] 无法清理隔离文件（错误码：%d）：%s" % [remove_err, child_path])
	directory.list_dir_end()

	var remove_dir_err: Error = DirAccess.remove_absolute(dir_path)
	if remove_dir_err != OK:
		push_warning("[PluginStore] 无法清理隔离目录（错误码：%d）：%s" % [remove_dir_err, dir_path])


func _ready() -> void:
	title = "插件商城"
	min_size = Vector2i(720, 520)
	ok_button_text = "关闭"
	get_cancel_button().visible = false
	confirmed.connect(_on_close)
	_build_ui()
	await _refresh_plugin_list()


func _build_ui() -> void:
	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_hbox)

	# 左侧：插件列表
	_plugin_list = ItemList.new()
	_plugin_list.custom_minimum_size = Vector2(300, 0)
	_plugin_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plugin_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plugin_list.item_selected.connect(_on_plugin_selected)
	main_hbox.add_child(_plugin_list)

	# 右侧：详情面板
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(_detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(detail_vbox)

	var source_row: HBoxContainer = HBoxContainer.new()
	detail_vbox.add_child(source_row)
	var source_label: Label = Label.new()
	source_label.text = "插件源："
	source_row.add_child(source_label)
	_source_edit = LineEdit.new()
	_source_edit.text = PluginRegistry.DEFAULT_MANIFEST_URL
	_source_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_edit.placeholder_text = "远程 plugin_registry.json 地址"
	_source_edit.text_submitted.connect(_on_source_submitted)
	source_row.add_child(_source_edit)
	_refresh_button = Button.new()
	_refresh_button.text = "刷新"
	_refresh_button.pressed.connect(_on_refresh_pressed)
	source_row.add_child(_refresh_button)

	# 插件名称
	_name_label = Label.new()
	_name_label.name = "PluginNameLabel"
	_name_label.add_theme_font_size_override("font", 18)
	detail_vbox.add_child(_name_label)

	# 描述信息
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = false
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label.custom_minimum_size = Vector2(0, 200)
	detail_vbox.add_child(_info_label)

	# 进度条
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.visible = false
	detail_vbox.add_child(_progress_bar)

	# 状态标签
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	detail_vbox.add_child(_status_label)

	# 操作按钮（安装/卸载/重试）
	_action_button = Button.new()
	_action_button.text = "一键安装"
	_action_button.custom_minimum_size = Vector2(0, 36)
	_action_button.disabled = true
	_action_button.pressed.connect(_on_action_pressed)
	detail_vbox.add_child(_action_button)


func _refresh_plugin_list() -> void:
	if _is_refreshing:
		return
	_is_refreshing = true
	_refresh_button.disabled = true
	_source_edit.editable = false
	_plugin_list.clear()
	_status_label.text = "正在读取远程插件清单..."
	_all_plugins = await PluginRegistry.fetch_plugins(self, _source_edit.text)
	_manifest_warning = PluginRegistry.last_load_warning
	for i in range(_all_plugins.size()):
		var entry: PluginEntry = _all_plugins[i]
		var status: String = _get_install_status(entry)
		var version_warning: String = entry.get_version_warning()
		if not version_warning.is_empty():
			status += "，版本更新"
		var display_text: String = "%s  [%s]" % [entry.display_name, status]
		_plugin_list.add_item(display_text)
		if _is_installed(entry):
			_plugin_list.set_item_custom_fg_color(i, Color(0.4, 0.8, 0.4))
		if not version_warning.is_empty():
			_plugin_list.set_item_custom_fg_color(i, Color(0.95, 0.7, 0.25))
	if _plugin_list.item_count > 0:
		_plugin_list.select(0)
		_on_plugin_selected(0)
	_refresh_button.disabled = false
	_source_edit.editable = true
	_is_refreshing = false


func _on_refresh_pressed() -> void:
	await _refresh_plugin_list()


func _on_source_submitted(_source_url: String) -> void:
	await _refresh_plugin_list()


func _on_plugin_selected(index: int) -> void:
	if index < 0 or index >= _all_plugins.size():
		return
	var entry: PluginEntry = _all_plugins[index]

	if is_instance_valid(_name_label):
		_name_label.text = entry.display_name

	var status: String = _get_install_status(entry)
	var desc: String = "[b]版本：[/b] %s\n" % entry.version
	var installed_version: String = entry.get_installed_version()
	if not installed_version.is_empty():
		desc += "[b]已安装版本：[/b] %s\n" % installed_version
	desc += "[b]作者：[/b] %s\n\n" % entry.author
	desc += "[b]状态：[/b] %s\n\n" % status
	desc += "[b]描述：[/b]\n%s\n\n" % entry.description
	desc += "[b]主页：[/b] [url]%s[/url]" % entry.homepage
	var version_warning: String = entry.get_version_warning()
	if not version_warning.is_empty():
		desc += "\n\n[color=#e0a040][b]版本状态：[/b] %s[/color]" % version_warning
	if not _manifest_warning.is_empty():
		desc += "\n\n[color=#e0a040][b]清单警告：[/b] %s[/color]" % _manifest_warning
	_info_label.text = desc
	_status_label.text = _manifest_warning

	_update_action_button(entry)


func _update_action_button(entry: PluginEntry) -> void:
	if _is_busy:
		_action_button.text = "正在处理..."
		_action_button.disabled = true
		return

	var installed: bool = _is_installed(entry)
	if installed:
		_action_button.text = "一键卸载"
		_action_button.disabled = false
	else:
		_action_button.text = "一键安装"
		_action_button.disabled = false


func _on_action_pressed() -> void:
	if _is_busy:
		return
	var selected: PackedInt32Array = _plugin_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if index < 0 or index >= _all_plugins.size():
		return

	var entry: PluginEntry = _all_plugins[index]
	var installed: bool = _is_installed(entry)
	if installed:
		_confirm_uninstall(entry)
	else:
		_start_install(entry)


func _confirm_uninstall(entry: PluginEntry) -> void:
	# 使用确认对话框，避免误删
	var dialog := ConfirmationDialog.new()
	dialog.title = "确认卸载"
	dialog.dialog_text = "确定要卸载插件 %s 吗？\n\n插件会先停用并移出 %s/，再从 project.godot 中移除启用记录。重启编辑器后会清理隔离文件。" % [entry.display_name, entry.dest_path]
	dialog.ok_button_text = "卸载"
	dialog.cancel_button_text = "取消"
	add_child(dialog)
	dialog.confirmed.connect(func():
		_start_uninstall(entry)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(420, 200))


# ===================== 安装 =====================

func _start_install(entry: PluginEntry) -> void:
	_is_busy = true
	_action_button.disabled = true
	_action_button.text = "正在安装..."
	_progress_bar.visible = true
	_progress_bar.value = 0
	_status_label.text = "正在获取仓库信息..."

	_downloader = PluginDownloaderClass.new()
	_downloader.download_progress.connect(_on_download_progress)
	_downloader.download_complete.connect(_on_download_complete)

	await _downloader.download_plugin(entry, self)


func _on_download_progress(file_index: int, total_files: int, current_file: String) -> void:
	var progress: float = float(file_index) / float(total_files) * 100.0
	_progress_bar.value = progress
	_status_label.text = "正在下载 %d/%d: %s" % [file_index + 1, total_files, current_file]


func _on_download_complete(success: bool, message: String) -> void:
	_is_busy = false
	_progress_bar.visible = false
	if success:
		_status_label.text = "安装成功！正在启用插件并刷新..."
		var selected: PackedInt32Array = _plugin_list.get_selected_items()
		if not selected.is_empty():
			var entry: PluginEntry = _all_plugins[selected[0]]
			var enable_ok: bool = await _enable_plugin(entry)
			if enable_ok:
				_status_label.text = "插件已安装并在当前编辑器中启用。"
			else:
				_status_label.text = "插件已安装，但当前编辑器启用失败，请重启编辑器重试。"
			await _refresh_plugin_list()
	else:
		_status_label.text = "安装失败：" + message
		var sel: PackedInt32Array = _plugin_list.get_selected_items()
		if not sel.is_empty():
			var entry: PluginEntry = _all_plugins[sel[0]]
			_update_action_button(entry)


## 在 project.godot 中记录并在当前编辑器中启用插件。
func _enable_plugin(entry: PluginEntry) -> bool:
	var plugin_cfg_path: String = entry.dest_path + "/plugin.cfg"
	if not FileAccess.file_exists(plugin_cfg_path):
		push_warning("[PluginStore] 插件配置文件不存在：%s" % plugin_cfg_path)
		return false

	var cfg: ConfigFile = ConfigFile.new()
	var cfg_err: int = cfg.load(plugin_cfg_path)
	if cfg_err != OK:
		push_warning("[PluginStore] 无法读取插件配置：%s" % plugin_cfg_path)
		return false

	var plugin_name: String = str(cfg.get_value("plugin", "name", ""))
	if plugin_name.is_empty():
		push_warning("[PluginStore] 插件配置中未找到 name 字段")
		return false

	var proj_path: String = "res://project.godot"
	var proj_cfg: ConfigFile = ConfigFile.new()
	var proj_err: int = proj_cfg.load(proj_path)
	if proj_err != OK:
		push_warning("[PluginStore] 无法读取 project.godot")
		return false

	var enabled: PackedStringArray = proj_cfg.get_value("editor_plugins", "enabled", PackedStringArray())

	var full_path: String = plugin_cfg_path
	var already_enabled: bool = false
	for p: String in enabled:
		if p == full_path:
			already_enabled = true
			break

	if not already_enabled:
		enabled.append(full_path)
		proj_cfg.set_value("editor_plugins", "enabled", enabled)
		var save_err: Error = proj_cfg.save(proj_path)
		if save_err != OK:
			push_warning("[PluginStore] 无法保存 project.godot（错误码：%d）" % save_err)
			return false
		print("[PluginStore] 已写入插件启用记录：%s" % plugin_name)
	else:
		print("[PluginStore] 插件已存在启用记录：%s" % plugin_name)
	ProjectSettings.set_setting("editor_plugins/enabled", enabled)

	var scan_ok: bool = await _scan_filesystem_and_wait()
	if not scan_ok:
		push_warning("[PluginStore] 文件系统扫描未完成，暂不启用插件：%s" % plugin_name)
		return false

	if not EditorInterface.is_plugin_enabled(full_path):
		EditorInterface.set_plugin_enabled(full_path, true)
		await get_tree().process_frame
		await get_tree().process_frame

	var runtime_enabled: bool = EditorInterface.is_plugin_enabled(full_path)
	if not runtime_enabled:
		push_warning("[PluginStore] 无法在当前编辑器启用插件：%s" % plugin_name)
		return false

	print("[PluginStore] 已在当前编辑器启用插件：%s" % plugin_name)
	return true


## 等待新插件文件完成导入，避免在扫描期间调用插件管理器。
func _scan_filesystem_and_wait() -> bool:
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	filesystem.scan()
	await get_tree().process_frame
	for _i: int in range(120):
		if not filesystem.is_scanning():
			return true
		await get_tree().process_frame
	return false


# ===================== 卸载 =====================

func _start_uninstall(entry: PluginEntry) -> void:
	_is_busy = true
	_action_button.disabled = true
	_action_button.text = "正在卸载..."
	_progress_bar.visible = true
	_progress_bar.value = 0
	_status_label.text = "正在停用插件..."

	# 1. 先让 Godot 卸载插件实例，不能在插件仍运行时删除它的脚本。
	var disable_ok: bool = await _disable_plugin_before_removal(entry)
	if not disable_ok:
		_is_busy = false
		_progress_bar.visible = false
		_status_label.text = "无法安全停用插件，已取消卸载。"
		_update_action_button(entry)
		return

	# 2. 清理 project.godot 中可能残留的启用记录。
	var project_ok: bool = _disable_plugin_in_project(entry)
	if not project_ok:
		_is_busy = false
		_progress_bar.visible = false
		_status_label.text = "无法保存插件停用状态，已取消卸载。"
		_update_action_button(entry)
		return

	# 3. 将目录原子移出项目，避免编辑器扫描到逐个消失的脚本文件。
	_progress_bar.value = 30
	_status_label.text = "正在移出插件文件..."
	var quarantine_ok: bool = _quarantine_plugin_dir(entry)

	_progress_bar.value = 100
	_is_busy = false
	_progress_bar.visible = false

	if quarantine_ok:
		_refresh_plugin_item(entry)
		_status_label.text = "插件 %s 已卸载！已移出项目，重启编辑器后清理隔离文件。" % entry.display_name
		print("[PluginStore] 已卸载插件：%s" % entry.display_name)
	else:
		_status_label.text = "卸载失败：插件文件仍在项目中，请手动处理 %s" % entry.dest_path
		push_warning("[PluginStore] 无法移出插件目录：%s" % entry.dest_path)


## 通过 Godot 的插件管理器卸载已启用的插件，并等待其退出树。
func _disable_plugin_before_removal(entry: PluginEntry) -> bool:
	var plugin_cfg_path: String = entry.dest_path + "/plugin.cfg"
	if not FileAccess.file_exists(plugin_cfg_path):
		return true

	if not EditorInterface.is_plugin_enabled(plugin_cfg_path):
		return true

	EditorInterface.set_plugin_enabled(plugin_cfg_path, false)
	for _i: int in range(120):
		await get_tree().process_frame
		if not EditorInterface.is_plugin_enabled(plugin_cfg_path):
			await get_tree().process_frame
			if not EditorInterface.is_plugin_enabled(plugin_cfg_path):
				return true
	push_warning("[PluginStore] 插件仍处于启用状态，取消删除：%s" % plugin_cfg_path)
	return false


## 从 project.godot 中移除插件的启用记录。
func _disable_plugin_in_project(entry: PluginEntry) -> bool:
	var proj_path: String = "res://project.godot"
	var proj_cfg: ConfigFile = ConfigFile.new()
	var proj_err: int = proj_cfg.load(proj_path)
	if proj_err != OK:
		push_warning("[PluginStore] 无法读取 project.godot")
		return false

	var enabled: PackedStringArray = proj_cfg.get_value("editor_plugins", "enabled", PackedStringArray())
	var new_enabled: PackedStringArray = PackedStringArray()

	for p: String in enabled:
		# 保留不匹配的插件路径
		# 匹配条件：路径等于 dest_path，或路径以 dest_path + "/" 开头
		if p != entry.dest_path and not p.begins_with(entry.dest_path + "/"):
			new_enabled.append(p)

	if new_enabled.size() != enabled.size():
		proj_cfg.set_value("editor_plugins", "enabled", new_enabled)
		var save_err: Error = proj_cfg.save(proj_path)
		if save_err != OK:
			push_warning("[PluginStore] 无法保存 project.godot（错误码：%d）" % save_err)
			return false
		print("[PluginStore] 已从 project.godot 移除插件启用记录：%s" % entry.id)
	ProjectSettings.set_setting("editor_plugins/enabled", new_enabled)
	return true


## 将插件目录移出 res://，把真正的清理延后到编辑器重启后。
func _quarantine_plugin_dir(entry: PluginEntry) -> bool:
	var source_path: String = ProjectSettings.globalize_path(entry.dest_path)
	if not DirAccess.dir_exists_absolute(source_path):
		return true

	var trash_root: String = ProjectSettings.globalize_path("user://plugin_store_trash")
	var make_dir_err: Error = DirAccess.make_dir_recursive_absolute(trash_root)
	if make_dir_err != OK and not DirAccess.dir_exists_absolute(trash_root):
		push_warning("[PluginStore] 无法创建插件隔离目录（错误码：%d）" % make_dir_err)
		return false

	var trash_name: String = "%s_%d" % [entry.id.replace("/", "_"), Time.get_ticks_msec()]
	var target_path: String = trash_root.path_join(trash_name)
	var rename_err: Error = DirAccess.rename_absolute(source_path, target_path)
	if rename_err != OK:
		push_warning("[PluginStore] 无法将插件移出项目（错误码：%d）" % rename_err)
		return false

	print("[PluginStore] 插件文件已移入隔离目录：%s" % target_path)
	return true


## 只更新当前条目，避免卸载完成后再次扫描项目或请求远程清单。
func _refresh_plugin_item(entry: PluginEntry) -> void:
	var item_index: int = -1
	for i: int in range(_all_plugins.size()):
		if _all_plugins[i].id == entry.id:
			item_index = i
			break
	if item_index < 0:
		return

	var status: String = _get_install_status(entry)
	var version_warning: String = entry.get_version_warning()
	if not version_warning.is_empty():
		status += "，版本更新"
	var display_text: String = "%s  [%s]" % [entry.display_name, status]
	_plugin_list.set_item_text(item_index, display_text)
	_plugin_list.set_item_custom_fg_color(item_index, Color(1, 1, 1))
	if _is_installed(entry):
		_plugin_list.set_item_custom_fg_color(item_index, Color(0.4, 0.8, 0.4))
	if not version_warning.is_empty():
		_plugin_list.set_item_custom_fg_color(item_index, Color(0.95, 0.7, 0.25))
	_plugin_list.select(item_index)
	_on_plugin_selected(item_index)


func _is_installed(entry: PluginEntry) -> bool:
	return DirAccess.dir_exists_absolute(entry.dest_path)


func _get_install_status(entry: PluginEntry) -> String:
	if not _is_installed(entry):
		return "未安装"

	var plugin_cfg_path: String = entry.dest_path + "/plugin.cfg"
	if FileAccess.file_exists(plugin_cfg_path) and EditorInterface.is_plugin_enabled(plugin_cfg_path):
		return "已启用"
	return "已安装"


func _on_close() -> void:
	hide()
