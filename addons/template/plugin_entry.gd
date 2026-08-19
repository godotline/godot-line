@tool
class_name PluginEntry extends RefCounted

## 插件条目 — 描述商城中一个可安装的插件

var id: String
var displayName: String
var description: String
var author: String
var githubOwner: String
var githubRepo: String
var branch: String
## 仓库内插件目录的相对路径（如 "addons/mpm_importer"）
var subDir: String
## 安装后在项目中的目标路径（如 "res://addons/mpm_importer"）
var destPath: String
var version: String
var homepage: String
var iconUrl: String
var downloadUrls: Array[Dictionary] = []
var md5: String = ""
var minTemplateVersion: String = ""

const MD5_HEX_DIGITS: String = "0123456789abcdef"


func _init(pId: String = "", pName: String = "", pDesc: String = "",
		pOwner: String = "", pRepo: String = "", pBranch: String = "main",
		pSub: String = "", pDest: String = "",
		pVersion: String = "1.0", pHomepage: String = "", pIcon: String = "") -> void:
	id = pId
	displayName = pName
	description = pDesc
	author = pOwner
	githubOwner = pOwner
	githubRepo = pRepo
	branch = pBranch
	subDir = pSub
	destPath = pDest
	version = pVersion
	homepage = pHomepage
	iconUrl = pIcon


func get_installed_version() -> String:
	var cfgPath: String = destPath + "/plugin.cfg"
	if not FileAccess.file_exists(cfgPath):
		return ""
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(cfgPath) != OK:
		return ""
	return str(cfg.get_value("plugin", "version", "")).strip_edges()


func get_download_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for raw_source: Dictionary in downloadUrls:
		var url: String = str(raw_source.get("url", "")).strip_edges()
		if not _is_http_url(url):
			continue
		var sourceName: String = str(raw_source.get("name", raw_source.get("label", ""))).strip_edges()
		if sourceName.is_empty():
			sourceName = "下载源 %d" % (sources.size() + 1)
		sources.append({"name": sourceName, "url": url})
	return sources


func get_download_warning() -> String:
	if get_download_sources().is_empty():
		return "清单未提供有效的 ZIP 直链"
	if not is_valid_md5(md5):
		return "清单未提供有效的 ZIP MD5"
	return ""


func can_download() -> bool:
	return get_download_warning().is_empty()


func get_template_version_warning(current_template_version: String) -> String:
	var requiredVersion: String = minTemplateVersion.strip_edges()
	if requiredVersion.is_empty():
		return ""
	var currentVersion: String = current_template_version.strip_edges()
	if currentVersion.is_empty():
		return "无法读取当前 Template 版本，插件要求最低版本 %s" % requiredVersion
	if _compare_versions(currentVersion, requiredVersion) < 0:
		return "当前 Template 版本 %s，插件要求最低版本 %s" % [currentVersion, requiredVersion]
	return ""


func get_version_warning() -> String:
	var installedVersion: String = get_installed_version()
	if installedVersion.is_empty():
		return ""
	var comparison: int = _compare_versions(installedVersion, version)
	if comparison < 0:
		return "已安装版本 %s，可更新到 %s" % [installedVersion, version]
	if comparison > 0:
		return "已安装版本 %s，高于清单版本 %s" % [installedVersion, version]
	return ""


func has_update() -> bool:
	var installedVersion: String = get_installed_version()
	return not installedVersion.is_empty() and _compare_versions(installedVersion, version) < 0


static func _compare_versions(left: String, right: String) -> int:
	var leftParts: Array[int] = _parse_version(left)
	var rightParts: Array[int] = _parse_version(right)
	for i: int in range(3):
		if leftParts[i] < rightParts[i]:
			return -1
		if leftParts[i] > rightParts[i]:
			return 1
	return 0


static func is_valid_md5(value: String) -> bool:
	var normalized: String = value.strip_edges().to_lower()
	if normalized.length() != 32:
		return false
	for i: int in range(normalized.length()):
		if MD5_HEX_DIGITS.find(normalized.substr(i, 1)) < 0:
			return false
	return true


static func _is_http_url(url: String) -> bool:
	var normalized: String = url.strip_edges().to_lower()
	return normalized.begins_with("http://") or normalized.begins_with("https://")


static func _parse_version(version: String) -> Array[int]:
	var parts: Array[int] = [0, 0, 0]
	var versionParts: PackedStringArray = version.split(".")
	for i: int in range(min(versionParts.size(), 3)):
		var part: String = versionParts[i]
		if part.is_valid_int():
			parts[i] = part.to_int()
	return parts
