@tool
class_name PluginStoreDialog
extends ConfirmationDialog

## 插件商城对话框 - 显示可用插件列表，支持一键下载、启用、卸载

const PluginDownloaderClass := preload("res://addons/template/plugin_downloader.gd")
const PluginInstallerClass := preload("res://addons/template/plugin_installer.gd")

enum SortMode { SORT_BY_NAME, SORT_BY_TIME }

var _plugin_list: ItemList
var _sort_select: OptionButton
var _sort_mode: int = SortMode.SORT_BY_TIME
var _source_edit: LineEdit
var _refresh_button: Button
var _download_source_select: OptionButton
var _name_label: Label
var _info_label: RichTextLabel
var _action_button: Button
var _cancel_button: Button
var _progress_bar: ProgressBar
var _status_label: Label
var _detail_panel: PanelContainer
var _all_plugins: Array[PluginEntry]
var _downloader: PluginDownloader
var _is_busy: bool = false
var _manifest_warning: String = ""
var _is_refreshing: bool = false
var _template_version: String = ""


func _ready() -> void:
	title = "插件商城"
	min_size = Vector2i(720, 520)
	unresizable = false
	ok_button_text = "关闭"
	get_cancel_button().visible = false
	confirmed.connect(_on_close)
	_build_ui()
	await _refresh_plugin_list()


func _build_ui() -> void:
	var mainHBox := HBoxContainer.new()
	mainHBox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mainHBox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(mainHBox)

	# 左侧：排序切换 + 插件列表
	var listVBox := VBoxContainer.new()
	listVBox.custom_minimum_size = Vector2(300, 0)
	listVBox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listVBox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mainHBox.add_child(listVBox)

	_sort_select = OptionButton.new()
	_sort_select.add_item("按首字排序")
	_sort_select.add_item("按时间排序")
	_sort_select.select(SortMode.SORT_BY_TIME)
	_sort_select.item_selected.connect(_on_sort_selected)
	listVBox.add_child(_sort_select)

	_plugin_list = ItemList.new()
	_plugin_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plugin_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plugin_list.item_selected.connect(_on_plugin_selected)
	listVBox.add_child(_plugin_list)

	# 右侧：详情面板
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mainHBox.add_child(_detail_panel)

	var detailVBox := VBoxContainer.new()
	detailVBox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detailVBox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(detailVBox)

	var sourceRow: HBoxContainer = HBoxContainer.new()
	detailVBox.add_child(sourceRow)
	var sourceLabel: Label = Label.new()
	sourceLabel.text = "插件源："
	sourceRow.add_child(sourceLabel)
	_source_edit = LineEdit.new()
	_source_edit.text = PluginRegistry.DEFAULT_MANIFEST_URL
	_source_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_edit.placeholder_text = "远程 plugin_registry.json 地址"
	_source_edit.text_submitted.connect(_on_source_submitted)
	sourceRow.add_child(_source_edit)
	_refresh_button = Button.new()
	_refresh_button.text = "刷新"
	_refresh_button.pressed.connect(_on_refresh_pressed)
	sourceRow.add_child(_refresh_button)
	var contributeButton: Button = Button.new()
	contributeButton.text = "贡献插件"
	contributeButton.tooltip_text = "打开插件注册表的 Pull Requests 页面"
	contributeButton.pressed.connect(_on_contribute_pressed)
	sourceRow.add_child(contributeButton)

	# 下载源
	var downloadRow: HBoxContainer = HBoxContainer.new()
	detailVBox.add_child(downloadRow)
	var downloadLabel: Label = Label.new()
	downloadLabel.text = "下载源："
	downloadRow.add_child(downloadLabel)
	_download_source_select = OptionButton.new()
	_download_source_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	downloadRow.add_child(_download_source_select)

	# 插件名称
	_name_label = Label.new()
	_name_label.name = "PluginNameLabel"
	_name_label.add_theme_font_size_override("font", 18)
	detailVBox.add_child(_name_label)

	# 描述信息
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = false
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label.custom_minimum_size = Vector2(0, 200)
	# RichTextLabel 不会自动打开链接，需监听 meta_clicked 自行处理
	_info_label.meta_clicked.connect(_on_meta_clicked)
	detailVBox.add_child(_info_label)

	# 进度条
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.visible = false
	detailVBox.add_child(_progress_bar)

	# 状态标签
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	detailVBox.add_child(_status_label)

	# 操作按钮（安装/卸载）与下载取消按钮同行放置
	var actionRow := HBoxContainer.new()
	actionRow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actionRow.add_theme_constant_override("separation", 8)
	detailVBox.add_child(actionRow)

	_action_button = Button.new()
	_action_button.text = "一键安装"
	_action_button.custom_minimum_size = Vector2(0, 36)
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.disabled = true
	_action_button.pressed.connect(_on_action_pressed)
	actionRow.add_child(_action_button)

	_cancel_button = Button.new()
	_cancel_button.text = "取消"
	_cancel_button.custom_minimum_size = Vector2(96, 36)
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_on_cancel_pressed)
	actionRow.add_child(_cancel_button)


func _refresh_plugin_list() -> void:
	if _is_refreshing:
		return
	_is_refreshing = true
	_refresh_button.disabled = true
	_source_edit.editable = false
	_plugin_list.clear()
	_status_label.text = "正在读取远程插件清单..."
	_template_version = PluginRegistry.get_template_version()
	_all_plugins = await PluginRegistry.fetch_plugins(self, _source_edit.text)
	_manifest_warning = PluginRegistry.last_load_warning
	_apply_current_sort()
	for i in range(_all_plugins.size()):
		_append_plugin_item(i)
	if _plugin_list.item_count > 0:
		_plugin_list.select(0)
		_on_plugin_selected(0)
	else:
		_status_label.text = "未获取到可用插件。" if _manifest_warning.is_empty() else _manifest_warning
	_refresh_button.disabled = false
	_source_edit.editable = true
	_is_refreshing = false


func _on_sort_selected(index: int) -> void:
	_sort_mode = index
	_apply_current_sort()
	_rebuild_plugin_items()


## 就地按当前排序模式排列 _all_plugins：首字按名称自然序，时间按更新日期新到旧。
func _apply_current_sort() -> void:
	if _sort_mode == SortMode.SORT_BY_NAME:
		_all_plugins.sort_custom(func(a: PluginEntry, b: PluginEntry) -> bool:
			return a.displayName.naturalnocasecmp_to(b.displayName) < 0
		)
	else:
		# ISO 日期字符串可直接按字典序比较
		_all_plugins.sort_custom(func(a: PluginEntry, b: PluginEntry) -> bool:
			var byDate: int = b.updatedAt.naturalnocasecmp_to(a.updatedAt)
			if byDate != 0:
				return byDate < 0
			return a.displayName.naturalnocasecmp_to(b.displayName) < 0
		)


## 向列表追加第 index 个插件条目（状态后缀与颜色标记）。
func _append_plugin_item(index: int) -> void:
	var entry: PluginEntry = _all_plugins[index]
	var status: String = _get_install_status(entry)
	var versionWarning: String = entry.get_version_warning()
	var recommendation: String = entry.get_template_recommendation(_template_version)
	var downloadWarning: String = entry.get_download_warning()
	if not versionWarning.is_empty():
		status += "，版本更新"
	if not recommendation.is_empty():
		status += "，建议升级模板"
	if not downloadWarning.is_empty() and not _is_installed(entry):
		status += "，不可安装"
	_plugin_list.add_item("%s  [%s]" % [entry.displayName, status])
	if _is_installed(entry):
		_plugin_list.set_item_custom_fg_color(index, Color(0.4, 0.8, 0.4))
	if not versionWarning.is_empty() or not recommendation.is_empty() or (not downloadWarning.is_empty() and not _is_installed(entry)):
		_plugin_list.set_item_custom_fg_color(index, Color(0.95, 0.7, 0.25))


## 清空并按当前排序重建全部列表条目，尽量保持原选中项。
func _rebuild_plugin_items() -> void:
	var selectedId: String = ""
	var selected: PackedInt32Array = _plugin_list.get_selected_items()
	if not selected.is_empty() and selected[0] < _all_plugins.size():
		selectedId = _all_plugins[selected[0]].id
	_plugin_list.clear()
	for i in range(_all_plugins.size()):
		_append_plugin_item(i)
	if selectedId.is_empty():
		return
	for i in range(_all_plugins.size()):
		if _all_plugins[i].id == selectedId:
			_plugin_list.select(i)
			_on_plugin_selected(i)
			return


func _on_refresh_pressed() -> void:
	await _refresh_plugin_list()


func _on_source_submitted(_source_url: String) -> void:
	await _refresh_plugin_list()


func _on_contribute_pressed() -> void:
	OS.shell_open(PluginRegistry.CONTRIBUTION_URL)
	_status_label.text = "已打开插件注册表 Pull Requests 页面。"


## 打开详情中点击的主页链接（RichTextLabel 需手动处理 meta_clicked）。
func _on_meta_clicked(meta: Variant) -> void:
	var url: String = str(meta).strip_edges()
	if not url.is_empty():
		OS.shell_open(url)
		_status_label.text = "已在系统浏览器打开：%s" % url


func _on_plugin_selected(index: int) -> void:
	if index < 0 or index >= _all_plugins.size():
		return
	var entry: PluginEntry = _all_plugins[index]

	if is_instance_valid(_name_label):
		_name_label.text = entry.displayName
	_populate_download_sources(entry)

	var status: String = _get_install_status(entry)
	var desc: String = "[b]版本：[/b] %s\n" % entry.version
	if not entry.updatedAt.is_empty():
		desc += "[b]更新时间：[/b] %s\n" % entry.updatedAt
	desc += "[b]当前 Template 版本：[/b] %s\n" % (_template_version if not _template_version.is_empty() else "未知")
	if not entry.recommendedTemplateVersion.is_empty():
		desc += "[b]推荐 Template 版本：[/b] %s\n" % entry.recommendedTemplateVersion
	var installedVersion: String = entry.get_installed_version()
	if not installedVersion.is_empty():
		desc += "[b]已安装版本：[/b] %s\n" % installedVersion
	desc += "[b]作者：[/b] %s\n\n" % entry.author
	desc += "[b]状态：[/b] %s\n\n" % status
	desc += "[b]描述：[/b]\n%s\n\n" % entry.description
	var changelogText: String = _render_changelog(entry)
	if not changelogText.is_empty():
		desc += "%s\n" % changelogText
	desc += "[b]主页：[/b] [url]%s[/url]" % entry.homepage
	var versionWarning: String = entry.get_version_warning()
	if not versionWarning.is_empty():
		desc += "\n\n[color=#e0a040][b]版本状态：[/b] %s[/color]" % versionWarning
	var recommendation: String = entry.get_template_recommendation(_template_version)
	if not recommendation.is_empty():
		desc += "\n\n[color=#e0a040][b]模板建议：[/b] %s[/color]" % recommendation
	var downloadWarning: String = entry.get_download_warning()
	if not downloadWarning.is_empty() and not _is_installed(entry):
		desc += "\n\n[color=#e05050][b]安装不可用：[/b] %s[/color]" % downloadWarning
	if not _manifest_warning.is_empty():
		desc += "\n\n[color=#e0a040][b]清单警告：[/b] %s[/color]" % _manifest_warning
	_info_label.text = desc
	_status_label.text = _manifest_warning

	_update_action_button(entry)


## 渲染更新日志为 BBCode；清单未提供时返回空串。
func _render_changelog(entry: PluginEntry) -> String:
	if entry.changelog.is_empty():
		return ""
	var text: String = "[b]更新日志：[/b]\n"
	for i in range(entry.changelog.size()):
		var release: Dictionary = entry.changelog[i]
		var heading: String = str(release.get("version", ""))
		var date: String = str(release.get("date", ""))
		if not heading.is_empty():
			heading = "v" + heading.lstrip("vV")
		if not date.is_empty():
			if heading.is_empty():
				heading = date
			else:
				heading += "（%s）" % date
		text += "[b]%s[/b]\n" % heading
		var notes: PackedStringArray = release.get("notes", PackedStringArray())
		for note: String in notes:
			text += "- %s\n" % note
		if i < entry.changelog.size() - 1:
			text += "\n"
	return text


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
		var downloadWarning: String = entry.get_download_warning()
		if not downloadWarning.is_empty():
			_action_button.text = "无法安装"
			_action_button.disabled = true
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
		var downloadWarning: String = entry.get_download_warning()
		if not downloadWarning.is_empty():
			_status_label.text = "安装不可用：" + downloadWarning
			return
		var downloadUrl: String = _get_selected_download_url(entry)
		if downloadUrl.is_empty():
			_status_label.text = "安装不可用：请选择有效的下载源"
			return
		# 推荐版本仅提示，不拦截安装
		var recommendation: String = entry.get_template_recommendation(_template_version)
		if not recommendation.is_empty():
			_status_label.text = "注意：" + recommendation
		_start_install(entry, downloadUrl)


func _populate_download_sources(entry: PluginEntry) -> void:
	_download_source_select.clear()
	var sources: Array[Dictionary] = entry.get_download_sources()
	for i: int in range(sources.size()):
		var source: Dictionary = sources[i]
		_download_source_select.add_item(str(source.get("name", "下载源 %d" % (i + 1))), i)
	if sources.is_empty():
		_download_source_select.add_item("无可用下载源", 0)
		_download_source_select.set_item_disabled(0, true)
		_download_source_select.disabled = true
	else:
		_download_source_select.select(0)
		_download_source_select.disabled = false


func _get_selected_download_url(entry: PluginEntry) -> String:
	var sources: Array[Dictionary] = entry.get_download_sources()
	var sourceId: int = _download_source_select.get_selected_id()
	if sourceId < 0 or sourceId >= sources.size():
		return ""
	return str(sources[sourceId].get("url", "")).strip_edges()


func _confirm_uninstall(entry: PluginEntry) -> void:
	# 使用确认对话框，避免误删
	var dialog := ConfirmationDialog.new()
	dialog.unresizable = false
	dialog.title = "确认卸载"
	dialog.dialog_text = "确定要卸载插件 %s 吗？\n\n插件会先停用并移出 %s/，再从 project.godot 中移除启用记录。重启编辑器后会清理隔离文件。" % [entry.displayName, entry.destPath]
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

func _start_install(entry: PluginEntry, downloadUrl: String) -> void:
	_is_busy = true
	_action_button.disabled = true
	_action_button.text = "正在安装..."
	_progress_bar.visible = true
	_progress_bar.value = 0
	_status_label.text = "正在下载选定的 ZIP..."

	_downloader = PluginDownloaderClass.new()
	_downloader.download_progress.connect(_on_download_progress)
	_downloader.download_complete.connect(_on_download_complete)
	_downloader.download_cancelled.connect(_on_download_cancelled)

	_cancel_button.visible = true
	_cancel_button.disabled = false
	await _downloader.download_plugin(entry, self, downloadUrl)


func _on_download_progress(file_index: int, total_files: int, current_file: String) -> void:
	var progress: float = float(file_index) / float(total_files) * 100.0
	_progress_bar.value = progress
	_status_label.text = "正在下载 %d/%d: %s" % [file_index + 1, total_files, current_file]


func _on_download_complete(success: bool, message: String) -> void:
	_is_busy = false
	_progress_bar.visible = false
	_cancel_button.visible = false
	# 安装文件已落盘，先立即恢复操作按钮，避免后续启用/刷新阶段卡在"正在安装..."。
	_restore_action_button()
	if success:
		_status_label.text = "安装成功！正在启用插件并刷新..."
		var selected: PackedInt32Array = _plugin_list.get_selected_items()
		if not selected.is_empty():
			var entry: PluginEntry = _all_plugins[selected[0]]
			var enableOk: bool = await PluginInstallerClass.enablePlugin(entry, self)
			if enableOk:
				_status_label.text = "插件已安装并在当前编辑器中启用。"
			else:
				_status_label.text = "插件已安装，但当前编辑器启用失败，请重启编辑器重试。"
			await _refresh_plugin_list()
	else:
		_status_label.text = "安装失败：" + message


## 按当前选中项立即恢复操作按钮；无选中时回退为不可用的"一键安装"。
func _restore_action_button() -> void:
	var selected: PackedInt32Array = _plugin_list.get_selected_items()
	if not selected.is_empty():
		_update_action_button(_all_plugins[selected[0]])
		return
	_action_button.text = "一键安装"
	_action_button.disabled = true


## 用户请求中止当前下载；真正结束后由 _on_download_cancelled 恢复界面状态。
func _on_cancel_pressed() -> void:
	if _downloader == null:
		return
	_cancel_button.disabled = true
	_status_label.text = "正在取消下载..."
	_downloader.cancel_download()


func _on_download_cancelled() -> void:
	_is_busy = false
	_progress_bar.visible = false
	_progress_bar.value = 0
	_cancel_button.visible = false
	_status_label.text = "已取消下载。"
	var selected: PackedInt32Array = _plugin_list.get_selected_items()
	if not selected.is_empty():
		_update_action_button(_all_plugins[selected[0]])


# ===================== 卸载 =====================

func _start_uninstall(entry: PluginEntry) -> void:
	_is_busy = true
	_action_button.disabled = true
	_action_button.text = "正在卸载..."
	_progress_bar.visible = true
	_progress_bar.value = 0
	_status_label.text = "正在停用插件..."

	# 1. 先让 Godot 卸载插件实例，不能在插件仍运行时删除它的脚本。
	var disableOk: bool = await PluginInstallerClass.disablePluginBeforeRemoval(entry, self)
	if not disableOk:
		_is_busy = false
		_progress_bar.visible = false
		_status_label.text = "无法安全停用插件，已取消卸载。"
		_update_action_button(entry)
		return

	# 2. 清理 project.godot 中可能残留的启用记录。
	var projectOk: bool = PluginInstallerClass.disablePluginInProject(entry)
	if not projectOk:
		_is_busy = false
		_progress_bar.visible = false
		_status_label.text = "无法保存插件停用状态，已取消卸载。"
		_update_action_button(entry)
		return

	# 3. 将目录原子移出项目，避免编辑器扫描到逐个消失的脚本文件。
	_progress_bar.value = 30
	_status_label.text = "正在移出插件文件..."
	var quarantineOk: bool = PluginInstallerClass.quarantinePluginDir(entry)

	_progress_bar.value = 100
	_is_busy = false
	_progress_bar.visible = false

	if quarantineOk:
		_refresh_plugin_item(entry)
		_status_label.text = "插件 %s 已卸载！已移出项目，重启编辑器后清理隔离文件。" % entry.displayName
		print("[PluginStore] 已卸载插件：%s" % entry.displayName)
	else:
		_status_label.text = "卸载失败：插件文件仍在项目中，请手动处理 %s" % entry.destPath
		push_warning("[PluginStore] 无法移出插件目录：%s" % entry.destPath)


## 只重绘列表条目，避免卸载完成后再次扫描项目或请求远程清单。
func _refresh_plugin_item(_entry: PluginEntry) -> void:
	_apply_current_sort()
	_rebuild_plugin_items()


func _is_installed(entry: PluginEntry) -> bool:
	return DirAccess.dir_exists_absolute(entry.destPath)


func _get_install_status(entry: PluginEntry) -> String:
	if not _is_installed(entry):
		return "未安装"

	var pluginCfgPath: String = entry.destPath + "/plugin.cfg"
	if FileAccess.file_exists(pluginCfgPath) and EditorInterface.is_plugin_enabled(pluginCfgPath):
		return "已启用"
	return "已安装"


func _on_close() -> void:
	# 关闭对话框时若下载仍在进行，一并中止，避免后台残留下载任务。
	if _is_busy and _downloader != null:
		_downloader.cancel_download()
	hide()
