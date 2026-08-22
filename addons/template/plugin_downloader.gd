@tool
class_name PluginDownloader extends RefCounted

## 插件下载器 — 下载直链 ZIP、校验 MD5 并解压指定插件目录

signal download_progress(file_index: int, total_files: int, current_file: String)
signal download_complete(success: bool, message: String)
signal download_cancelled

var nodeOwner: Node
var httpRequest: HTTPRequest
var isCancelled: bool = false


## 请求中止当前下载，中止完成后通过 download_cancelled 通知。
func cancel_download() -> void:
	isCancelled = true
	if is_instance_valid(httpRequest):
		httpRequest.cancel_request()
		# Godot 的 HTTPRequest.cancel_request() 只会停止请求并重置状态，不会触发 request_completed 信号。
		# 因此必须手动唤醒正在 await 该信号的下载协程，否则取消后会永远卡在等待中。
		# 注意：4.7 的 Result 枚举没有 RESULT_CANCELLED，这里用任意非成功整型值即可（后续由 isCancelled 判定）。
		httpRequest.emit_signal("request_completed", 1, 0, PackedStringArray(), PackedByteArray())


## 下载插件到指定目标路径。download_url 由商城中的下载源选择器提供。
func download_plugin(entry: PluginEntry, owner_node: Node, download_url: String = "") -> void:
	nodeOwner = owner_node
	if not entry:
		emit_signal("download_complete", false, "无效的插件条目")
		return

	var archivePath: String = "user://plugin_store_%s.zip" % entry.id
	var selectedUrl: String = download_url.strip_edges()
	if selectedUrl.is_empty():
		var sources: Array[Dictionary] = entry.get_download_sources()
		if not sources.is_empty():
			selectedUrl = str(sources[0].get("url", ""))
	var downloadResult: Dictionary = await _download_archive(entry, archivePath, selectedUrl)
	if isCancelled or not downloadResult.get("success", false):
		_remove_archive(archivePath)
		if isCancelled:
			download_cancelled.emit()
			return
		emit_signal("download_complete", false, str(downloadResult.get("message", "下载插件 ZIP 失败")))
		return

	var extractResult: Dictionary = _extract_plugin(entry, archivePath)
	_remove_archive(archivePath)
	if not extractResult.get("success", false):
		if isCancelled:
			download_cancelled.emit()
			return
		emit_signal("download_complete", false, str(extractResult.get("message", "解压插件 ZIP 失败")))
		return

	if isCancelled:
		download_cancelled.emit()
		return
	download_complete.emit(true, "成功导入 %d 个文件" % extractResult.get("file_count", 0))


## 下载直链 ZIP 并在解压前完成 MD5 校验。
func _download_archive(entry: PluginEntry, archivePath: String, download_url: String) -> Dictionary:
	if not entry.can_download():
		return {"success": false, "message": entry.get_download_warning()}
	if not _is_http_url(download_url):
		return {"success": false, "message": "下载源不是有效的 HTTP(S) 直链"}
	var selectedSourceExists: bool = false
	for source: Dictionary in entry.get_download_sources():
		if str(source.get("url", "")) == download_url:
			selectedSourceExists = true
			break
	if not selectedSourceExists:
		return {"success": false, "message": "选定下载源不在插件清单中"}

	_remove_archive(archivePath)
	httpRequest = HTTPRequest.new()
	nodeOwner.add_child(httpRequest)
	httpRequest.download_file = archivePath
	download_progress.emit(0, 1, download_url.get_file() if not download_url.get_file().is_empty() else "plugin.zip")
	var err: int = httpRequest.request(download_url, ["User-Agent: Godot-PluginStore"])
	if err != OK:
		httpRequest.queue_free()
		httpRequest = null
		_remove_archive(archivePath)
		return {"success": false, "message": "无法开始下载（错误码：%d）" % err}

	var result: Array = await httpRequest.request_completed
	httpRequest.queue_free()
	httpRequest = null

	if isCancelled:
		_remove_archive(archivePath)
		return {"success": false, "cancelled": true, "message": "已取消下载"}
	if result.is_empty() or result[0] != HTTPRequest.RESULT_SUCCESS:
		_remove_archive(archivePath)
		return {"success": false, "message": "下载请求失败"}
	var responseCode: int = int(result[1])
	if responseCode < 200 or responseCode >= 300 or not FileAccess.file_exists(archivePath):
		_remove_archive(archivePath)
		return {"success": false, "message": "下载返回无效（HTTP %d）" % responseCode}

	var actualMd5: String = FileAccess.get_md5(archivePath).to_lower()
	var expectedMd5: String = entry.md5.strip_edges().to_lower()
	if actualMd5 != expectedMd5:
		_remove_archive(archivePath)
		return {"success": false, "message": "ZIP MD5 校验失败（期望 %s，实际 %s）" % [expectedMd5, actualMd5]}
	return {"success": true, "message": ""}


func _remove_archive(archivePath: String) -> void:
	var absolutePath: String = ProjectSettings.globalize_path(archivePath)
	if FileAccess.file_exists(archivePath) or FileAccess.file_exists(absolutePath):
		DirAccess.remove_absolute(absolutePath)


func _is_http_url(url: String) -> bool:
	var normalized: String = url.strip_edges().to_lower()
	return normalized.begins_with("http://") or normalized.begins_with("https://")


## 从直链 ZIP 中提取 entry.subDir，支持 ZIP 顶层目录前缀
func _extract_plugin(entry: PluginEntry, archivePath: String) -> Dictionary:
	var zip := ZIPReader.new()
	var openErr: int = zip.open(archivePath)
	if openErr != OK:
		return {"success": false, "message": "无法打开插件 ZIP（错误码：%d）" % openErr}

	var marker: String = entry.subDir.trim_suffix("/") + "/"
	var files: PackedStringArray = zip.get_files()
	var matchedFiles: Array[String] = []
	for archive_file: String in files:
		var markerIndex: int = archive_file.find(marker)
		if markerIndex < 0 or archive_file.ends_with("/"):
			continue
		var relativePath: String = archive_file.substr(markerIndex + marker.length())
		if _is_unsafe_archive_path(relativePath):
			zip.close()
			return {"success": false, "message": "ZIP 中包含不安全路径：%s" % archive_file}
		matchedFiles.append(archive_file)

	if matchedFiles.is_empty():
		zip.close()
		return {"success": false, "message": "ZIP 中未找到插件目录：%s" % entry.subDir}

	DirAccess.make_dir_recursive_absolute(entry.destPath)
	var fileCount: int = 0
	for archive_file: String in matchedFiles:
		if isCancelled:
			zip.close()
			return {"success": false, "cancelled": true, "message": "已取消下载"}
		var relativePath: String = archive_file.substr(archive_file.find(marker) + marker.length())
		var destination: String = entry.destPath.path_join(relativePath)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var outputFile := FileAccess.open(destination, FileAccess.WRITE)
		if not outputFile:
			zip.close()
			return {"success": false, "message": "无法写入文件：%s" % destination}
		outputFile.store_buffer(zip.read_file(archive_file))
		outputFile.close()
		fileCount += 1
		download_progress.emit(fileCount, matchedFiles.size(), relativePath)

	zip.close()
	return {"success": true, "file_count": fileCount}


func _is_unsafe_archive_path(path: String) -> bool:
	return path.is_empty() or path.begins_with("/") or path.contains("\\") or path == ".." or path.begins_with("../") or path.contains("/../") or path.contains("://")
