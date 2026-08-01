@tool
class_name PluginEntry extends RefCounted

## 插件条目 — 描述商城中一个可安装的插件

var id: String
var display_name: String
var description: String
var author: String
var github_owner: String
var github_repo: String
var branch: String
## 仓库内插件目录的相对路径（如 "addons/mpm_importer"）
var sub_dir: String
## 安装后在项目中的目标路径（如 "res://addons/mpm_importer"）
var dest_path: String
var version: String
var homepage: String
var icon_url: String


func _init(p_id: String = "", p_name: String = "", p_desc: String = "",
		p_owner: String = "", p_repo: String = "", p_branch: String = "main",
		p_sub: String = "", p_dest: String = "",
		p_version: String = "1.0", p_homepage: String = "", p_icon: String = "") -> void:
	id = p_id
	display_name = p_name
	description = p_desc
	author = p_owner
	github_owner = p_owner
	github_repo = p_repo
	branch = p_branch
	sub_dir = p_sub
	dest_path = p_dest
	version = p_version
	homepage = p_homepage
	icon_url = p_icon


func get_installed_version() -> String:
	var cfg_path: String = dest_path + "/plugin.cfg"
	if not FileAccess.file_exists(cfg_path):
		return ""
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return ""
	return str(cfg.get_value("plugin", "version", "")).strip_edges()


func get_version_warning() -> String:
	var installed_version: String = get_installed_version()
	if installed_version.is_empty():
		return ""
	var comparison: int = _compare_versions(installed_version, version)
	if comparison < 0:
		return "已安装版本 %s，可更新到 %s" % [installed_version, version]
	if comparison > 0:
		return "已安装版本 %s，高于清单版本 %s" % [installed_version, version]
	return ""


func has_update() -> bool:
	var installed_version: String = get_installed_version()
	return not installed_version.is_empty() and _compare_versions(installed_version, version) < 0


static func _compare_versions(left: String, right: String) -> int:
	var left_parts: Array[int] = _parse_version(left)
	var right_parts: Array[int] = _parse_version(right)
	for i: int in range(3):
		if left_parts[i] < right_parts[i]:
			return -1
		if left_parts[i] > right_parts[i]:
			return 1
	return 0


static func _parse_version(version: String) -> Array[int]:
	var parts: Array[int] = [0, 0, 0]
	var version_parts: PackedStringArray = version.split(".")
	for i: int in range(min(version_parts.size(), 3)):
		var part: String = version_parts[i]
		if part.is_valid_int():
			parts[i] = part.to_int()
	return parts
