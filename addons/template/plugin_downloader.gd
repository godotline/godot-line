@tool
class_name PluginDownloader extends RefCounted

## 插件下载器 — 下载直链 ZIP、校验 MD5 并解压指定插件目录

signal download_progress(file_index: int, total_files: int, current_file: String)
signal download_complete(success: bool, message: String)

var _node_owner: Node


## 下载插件到指定目标路径。download_url 由商城中的下载源选择器提供。
func download_plugin(entry: PluginEntry, owner_node: Node, download_url: String = "") -> void:
	_node_owner = owner_node
	if not entry:
		emit_signal("download_complete", false, "无效的插件条目")
		return

	var archive_path: String = "user://plugin_store_%s.zip" % entry.id
	var selected_url: String = download_url.strip_edges()
	if selected_url.is_empty():
		var sources: Array[Dictionary] = entry.get_download_sources()
		if not sources.is_empty():
			selected_url = str(sources[0].get("url", ""))
	var download_result: Dictionary = await _download_archive(entry, archive_path, selected_url)
	if not download_result.get("success", false):
		_remove_archive(archive_path)
		emit_signal("download_complete", false, str(download_result.get("message", "下载插件 ZIP 失败")))
		return

	var extract_result: Dictionary = _extract_plugin(entry, archive_path)
	_remove_archive(archive_path)
	if not extract_result.get("success", false):
		emit_signal("download_complete", false, str(extract_result.get("message", "解压插件 ZIP 失败")))
		return

	download_complete.emit(true, "成功导入 %d 个文件" % extract_result.get("file_count", 0))


## 下载直链 ZIP 并在解压前完成 MD5 校验。
func _download_archive(entry: PluginEntry, archive_path: String, download_url: String) -> Dictionary:
	if not entry.can_download():
		return {"success": false, "message": entry.get_download_warning()}
	if not _is_http_url(download_url):
		return {"success": false, "message": "下载源不是有效的 HTTP(S) 直链"}
	var selected_source_exists: bool = false
	for source: Dictionary in entry.get_download_sources():
		if str(source.get("url", "")) == download_url:
			selected_source_exists = true
			break
	if not selected_source_exists:
		return {"success": false, "message": "选定下载源不在插件清单中"}

	_remove_archive(archive_path)
	var http: HTTPRequest = HTTPRequest.new()
	_node_owner.add_child(http)
	http.download_file = archive_path
	download_progress.emit(0, 1, download_url.get_file() if not download_url.get_file().is_empty() else "plugin.zip")
	var err: int = http.request(download_url, ["User-Agent: Godot-PluginStore"])
	if err != OK:
		http.queue_free()
		_remove_archive(archive_path)
		return {"success": false, "message": "无法开始下载（错误码：%d）" % err}

	var result: Array = await http.request_completed
	http.queue_free()

	if result.is_empty() or result[0] != HTTPRequest.RESULT_SUCCESS:
		_remove_archive(archive_path)
		return {"success": false, "message": "下载请求失败"}
	var response_code: int = int(result[1])
	if response_code < 200 or response_code >= 300 or not FileAccess.file_exists(archive_path):
		_remove_archive(archive_path)
		return {"success": false, "message": "下载返回无效（HTTP %d）" % response_code}

	var actual_md5: String = FileAccess.get_md5(archive_path).to_lower()
	var expected_md5: String = entry.md5.strip_edges().to_lower()
	if actual_md5 != expected_md5:
		_remove_archive(archive_path)
		return {"success": false, "message": "ZIP MD5 校验失败（期望 %s，实际 %s）" % [expected_md5, actual_md5]}
	return {"success": true, "message": ""}


func _remove_archive(archive_path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(archive_path)
	if FileAccess.file_exists(archive_path) or FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _is_http_url(url: String) -> bool:
	var normalized: String = url.strip_edges().to_lower()
	return normalized.begins_with("http://") or normalized.begins_with("https://")


## 从直链 ZIP 中提取 entry.sub_dir，支持 ZIP 顶层目录前缀
func _extract_plugin(entry: PluginEntry, archive_path: String) -> Dictionary:
	var zip := ZIPReader.new()
	var open_err: int = zip.open(archive_path)
	if open_err != OK:
		return {"success": false, "message": "无法打开插件 ZIP（错误码：%d）" % open_err}

	var marker: String = entry.sub_dir.trim_suffix("/") + "/"
	var files: PackedStringArray = zip.get_files()
	var matched_files: Array[String] = []
	for archive_file: String in files:
		var marker_index: int = archive_file.find(marker)
		if marker_index < 0 or archive_file.ends_with("/"):
			continue
		var relative_path: String = archive_file.substr(marker_index + marker.length())
		if _is_unsafe_archive_path(relative_path):
			zip.close()
			return {"success": false, "message": "ZIP 中包含不安全路径：%s" % archive_file}
		matched_files.append(archive_file)

	if matched_files.is_empty():
		zip.close()
		return {"success": false, "message": "ZIP 中未找到插件目录：%s" % entry.sub_dir}

	DirAccess.make_dir_recursive_absolute(entry.dest_path)
	var file_count: int = 0
	for archive_file: String in matched_files:
		var relative_path: String = archive_file.substr(archive_file.find(marker) + marker.length())
		var destination: String = entry.dest_path.path_join(relative_path)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var output_file := FileAccess.open(destination, FileAccess.WRITE)
		if not output_file:
			zip.close()
			return {"success": false, "message": "无法写入文件：%s" % destination}
		output_file.store_buffer(zip.read_file(archive_file))
		output_file.close()
		file_count += 1
		download_progress.emit(file_count, matched_files.size(), relative_path)

	zip.close()
	return {"success": true, "file_count": file_count}


func _is_unsafe_archive_path(path: String) -> bool:
	return path.is_empty() or path.begins_with("/") or path.contains("\\") or path == ".." or path.begins_with("../") or path.contains("/../") or path.contains("://")
