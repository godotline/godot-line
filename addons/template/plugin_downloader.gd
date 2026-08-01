@tool
class_name PluginDownloader extends RefCounted

## 插件下载器 — 下载 GitHub 仓库 ZIP 并解压指定插件目录

signal download_progress(file_index: int, total_files: int, current_file: String)
signal download_complete(success: bool, message: String)

const GITHUB_ARCHIVE_URL := "https://github.com/%s/%s/archive/refs/heads/%s.zip"

var _node_owner: Node


## 下载插件到指定目标路径
func download_plugin(entry: PluginEntry, owner_node: Node) -> void:
	_node_owner = owner_node
	if not entry:
		emit_signal("download_complete", false, "无效的插件条目")
		return

	var archive_path: String = "user://plugin_store_%s.zip" % entry.id
	download_progress.emit(0, 1, "main.zip")
	var download_ok: bool = await _download_archive(entry, archive_path)
	if not download_ok:
		emit_signal("download_complete", false, "下载插件 ZIP 失败")
		return

	var extract_result: Dictionary = _extract_plugin(entry, archive_path)
	DirAccess.remove_absolute(archive_path)
	if not extract_result.get("success", false):
		emit_signal("download_complete", false, extract_result.get("message", "解压插件 ZIP 失败"))
		return

	download_complete.emit(true, "成功导入 %d 个文件" % extract_result.get("file_count", 0))


## 下载 GitHub 仓库 ZIP
func _download_archive(entry: PluginEntry, archive_path: String) -> bool:
	var http := HTTPRequest.new()
	_node_owner.add_child(http)
	http.download_file = archive_path
	var url: String = GITHUB_ARCHIVE_URL % [entry.github_owner, entry.github_repo, entry.branch]
	var err: int = http.request(url, ["User-Agent: Godot-PluginStore"])
	if err != OK:
		http.queue_free()
		return false

	var result: Array = await http.request_completed
	http.queue_free()

	if result.is_empty() or result[0] != HTTPRequest.RESULT_SUCCESS or not FileAccess.file_exists(archive_path):
		DirAccess.remove_absolute(archive_path)
		return false
	return true


## 从 GitHub ZIP 中提取 entry.sub_dir，支持 ZIP 顶层目录前缀
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
