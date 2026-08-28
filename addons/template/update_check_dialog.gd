@tool
class_name UpdateCheckDialog
extends ConfirmationDialog

## 检查模板更新：拉取 GitHub 最新 Release 与 main 最新 commit。

const REPO_OWNER: String = "godotline"
const REPO_NAME: String = "godot-line"
const RELEASE_API_URL: String = "https://api.github.com/repos/%s/%s/releases/latest" % [REPO_OWNER, REPO_NAME]
const COMMIT_API_URL: String = "https://api.github.com/repos/%s/%s/commits/main" % [REPO_OWNER, REPO_NAME]
const PLUGIN_CFG_CONTENTS_URL: String = "https://api.github.com/repos/%s/%s/contents/addons/template/plugin.cfg" % [REPO_OWNER, REPO_NAME]
const RELEASES_PAGE_URL: String = "https://github.com/%s/%s/releases" % [REPO_OWNER, REPO_NAME]
const COMMITS_PAGE_URL: String = "https://github.com/%s/%s/commits/main" % [REPO_OWNER, REPO_NAME]
const USER_AGENT: String = "GodotLine-UpdateCheck"
const REQUEST_TIMEOUT_SEC: float = 10.0

var _info_label: RichTextLabel
var _status_label: Label
var _is_checking: bool = false


func _ready() -> void:
	title = "检查更新"
	min_size = Vector2i(520, 360)
	unresizable = false
	ok_button_text = "关闭"
	get_cancel_button().visible = false
	confirmed.connect(_on_close)
	close_requested.connect(_on_close)
	_build_ui()
	await _check_updates()


func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = false
	_info_label.scroll_active = true
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label.custom_minimum_size = Vector2(0, 240)
	_info_label.meta_clicked.connect(_on_meta_clicked)
	vbox.add_child(_info_label)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(_status_label)


func _on_close() -> void:
	hide()
	queue_free()


func _on_meta_clicked(meta: Variant) -> void:
	var url: String = str(meta).strip_edges()
	if url.is_empty():
		return
	OS.shell_open(url)
	_status_label.text = "已在系统浏览器打开：%s" % url


func _check_updates() -> void:
	if _is_checking:
		return
	_is_checking = true
	var currentVersion: String = PluginRegistry.get_template_version()
	_info_label.text = _render_loading(currentVersion)
	_status_label.text = "正在从 GitHub 拉取最新版本…"

	var releaseResult: Dictionary = await _fetch_json(RELEASE_API_URL)
	if not is_instance_valid(self):
		return
	var commitResult: Dictionary = await _fetch_json(COMMIT_API_URL)
	if not is_instance_valid(self):
		return
	var pluginCfgResult: Dictionary = await _fetch_commit_plugin_cfg(commitResult)
	if not is_instance_valid(self):
		return

	_info_label.text = _render_result(currentVersion, releaseResult, commitResult, pluginCfgResult)
	if bool(releaseResult.get("ok", false)) and bool(commitResult.get("ok", false)):
		_status_label.text = "检查完成。"
	else:
		_status_label.text = "部分信息读取失败，请检查网络后重试。"
	_is_checking = false


func _render_loading(currentVersion: String) -> String:
	var text: String = "[b]当前模板版本：[/b] %s\n\n" % _display_version(currentVersion)
	text += "正在检查 GitHub 最新 Release 与 main 最新 commit…"
	return text


func _render_result(currentVersion: String, releaseResult: Dictionary, commitResult: Dictionary, pluginCfgResult: Dictionary) -> String:
	var text: String = "[b]当前模板版本：[/b] %s\n\n" % _display_version(currentVersion)
	text += _render_release(currentVersion, releaseResult)
	text += "\n"
	text += _render_commit(currentVersion, commitResult, pluginCfgResult)
	return text


func _render_release(currentVersion: String, releaseResult: Dictionary) -> String:
	var text: String = "[b]Release 最新版[/b]\n"
	if not bool(releaseResult.get("ok", false)):
		text += "[color=#e05050]%s[/color]\n" % str(releaseResult.get("message", "读取失败"))
		text += "页面：[url]%s[/url]\n" % RELEASES_PAGE_URL
		return text

	var data: Dictionary = releaseResult.get("data", {}) as Dictionary
	var tagName: String = str(data.get("tag_name", "")).strip_edges()
	var releaseName: String = str(data.get("name", "")).strip_edges()
	var htmlUrl: String = str(data.get("html_url", "")).strip_edges()
	var publishedAt: String = _format_iso_time(str(data.get("published_at", "")))
	if htmlUrl.is_empty():
		htmlUrl = RELEASES_PAGE_URL

	text += "版本：%s" % (tagName if not tagName.is_empty() else "未知")
	if not releaseName.is_empty() and releaseName != tagName:
		text += "（%s）" % releaseName
	text += "\n"
	if not publishedAt.is_empty():
		text += "发布时间：%s\n" % publishedAt
	text += "链接：[url]%s[/url]\n" % htmlUrl
	text += "状态：%s\n" % _release_status(currentVersion, tagName)
	return text


func _render_commit(currentVersion: String, commitResult: Dictionary, pluginCfgResult: Dictionary) -> String:
	var text: String = "[b]Git commit 最新版[/b]（远程 main）\n"
	if not bool(commitResult.get("ok", false)):
		text += "[color=#e05050]%s[/color]\n" % str(commitResult.get("message", "读取失败"))
		text += "页面：[url]%s[/url]\n" % COMMITS_PAGE_URL
		return text

	var data: Dictionary = commitResult.get("data", {}) as Dictionary
	var sha: String = str(data.get("sha", "")).strip_edges()
	var htmlUrl: String = str(data.get("html_url", "")).strip_edges()
	var commitInfo: Dictionary = data.get("commit", {}) as Dictionary
	var message: String = str(commitInfo.get("message", "")).strip_edges()
	var subject: String = message.split("\n")[0] if not message.is_empty() else ""
	var committer: Dictionary = commitInfo.get("committer", {}) as Dictionary
	var author: Dictionary = commitInfo.get("author", {}) as Dictionary
	var dateRaw: String = str(committer.get("date", ""))
	if dateRaw.is_empty():
		dateRaw = str(author.get("date", ""))
	var dateText: String = _format_iso_time(dateRaw)
	var authorName: String = str(author.get("name", "")).strip_edges()
	if htmlUrl.is_empty() and not sha.is_empty():
		htmlUrl = "https://github.com/%s/%s/commit/%s" % [REPO_OWNER, REPO_NAME, sha]
	var commitVersion: String = _plugin_version_from_contents(pluginCfgResult)

	text += "版本：%s\n" % _display_version(commitVersion)
	text += "提交：%s\n" % (sha.substr(0, 12) if not sha.is_empty() else "未知")
	if not subject.is_empty():
		text += "说明：%s\n" % _escape_bbcode(subject)
	if not authorName.is_empty():
		text += "作者：%s\n" % _escape_bbcode(authorName)
	if not dateText.is_empty():
		text += "时间：%s\n" % dateText
	if not htmlUrl.is_empty():
		text += "链接：[url]%s[/url]\n" % htmlUrl
	text += "状态：%s\n" % _commit_status(currentVersion, commitVersion, pluginCfgResult)
	return text


func _commit_status(currentVersion: String, commitVersion: String, pluginCfgResult: Dictionary) -> String:
	if not bool(pluginCfgResult.get("ok", false)):
		return "[color=#e05050]%s[/color]" % str(pluginCfgResult.get("message", "无法读取该提交的模板版本"))
	if commitVersion.strip_edges().is_empty():
		return "[color=#e05050]该提交未包含有效的 template 插件版本[/color]"
	var comparison: int = PluginEntry._compare_versions(
		currentVersion.lstrip("vV").strip_edges(),
		commitVersion.lstrip("vV").strip_edges()
	)
	if comparison < 0:
		return "[color=#e0a040]可更新到 %s[/color]" % commitVersion
	if comparison > 0:
		return "当前版本高于远程 main（本地未推送）"
	return "已与远程 main 模板版本一致"


func _plugin_version_from_contents(pluginCfgResult: Dictionary) -> String:
	if not bool(pluginCfgResult.get("ok", false)):
		return ""
	var data: Dictionary = pluginCfgResult.get("data", {}) as Dictionary
	var encoding: String = str(data.get("encoding", "")).strip_edges()
	var contentB64: String = str(data.get("content", "")).replace("\n", "").strip_edges()
	var cfgText: String = ""
	if encoding == "base64" and not contentB64.is_empty():
		cfgText = Marshalls.base64_to_utf8(contentB64)
	if cfgText.strip_edges().is_empty():
		return ""
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.parse(cfgText) != OK:
		return ""
	return str(cfg.get_value("plugin", "version", "")).strip_edges()


func _fetch_commit_plugin_cfg(commitResult: Dictionary) -> Dictionary:
	if not bool(commitResult.get("ok", false)):
		return {"ok": false, "message": "无法读取该提交的模板版本"}
	var sha: String = str((commitResult.get("data", {}) as Dictionary).get("sha", "")).strip_edges()
	if sha.is_empty():
		return {"ok": false, "message": "远程 commit 缺少 SHA"}
	return await _fetch_json("%s?ref=%s" % [PLUGIN_CFG_CONTENTS_URL, sha])


func _release_status(currentVersion: String, tagName: String) -> String:
	var latestVersion: String = tagName.lstrip("vV").strip_edges()
	var localVersion: String = currentVersion.lstrip("vV").strip_edges()
	if localVersion.is_empty():
		return "无法读取本地版本"
	if latestVersion.is_empty():
		return "无法读取远程版本"
	var comparison: int = PluginEntry._compare_versions(localVersion, latestVersion)
	if comparison < 0:
		return "[color=#e0a040]可更新到 %s[/color]" % tagName
	if comparison > 0:
		return "当前版本高于最新 Release（开发中）"
	return "已是最新 Release"


func _display_version(version: String) -> String:
	if version.strip_edges().is_empty():
		return "未知"
	return version.strip_edges()


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


func _format_iso_time(isoText: String) -> String:
	var raw: String = isoText.strip_edges()
	if raw.is_empty():
		return ""
	var normalized: String = raw.replace("T", " ")
	if normalized.ends_with("Z"):
		normalized = normalized.substr(0, normalized.length() - 1) + " UTC"
	return normalized


func _fetch_json(url: String) -> Dictionary:
	if not is_inside_tree():
		return {"ok": false, "message": "对话框已关闭"}
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SEC
	var headers: PackedStringArray = PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: %s" % USER_AGENT,
	])
	var requestError: int = http.request(url, headers)
	if requestError != OK:
		http.queue_free()
		return {"ok": false, "message": "无法发起请求（错误码：%d）" % requestError}

	var result: Array = await http.request_completed
	if is_instance_valid(http):
		http.queue_free()
	if not is_instance_valid(self):
		return {"ok": false, "message": "对话框已关闭"}
	if result.is_empty() or result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "message": "网络请求失败"}
	var responseCode: int = int(result[1])
	var bodyText: String = (result[3] as PackedByteArray).get_string_from_utf8()
	var json: JSON = JSON.new()
	var parseError: Error = json.parse(bodyText)
	if parseError != OK:
		return {"ok": false, "message": "响应不是有效 JSON（HTTP %d）" % responseCode}
	if responseCode == 404:
		return {"ok": false, "message": "未找到对应资源（HTTP 404）"}
	if responseCode < 200 or responseCode >= 300:
		var errorMessage: String = "GitHub 返回 HTTP %d" % responseCode
		if json.data is Dictionary:
			var apiMessage: String = str((json.data as Dictionary).get("message", "")).strip_edges()
			if not apiMessage.is_empty():
				errorMessage += "：%s" % apiMessage
		return {"ok": false, "message": errorMessage}
	if not json.data is Dictionary:
		return {"ok": false, "message": "响应格式无效"}
	return {"ok": true, "data": json.data as Dictionary}
