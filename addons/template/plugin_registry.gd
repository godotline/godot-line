@tool
class_name PluginRegistry extends RefCounted

## 插件注册表 — 定义商城中可用的插件信息

const DEFAULT_MANIFEST_URL: String = "https://raw.githubusercontent.com/godotline/godotline-plugin-registry/refs/heads/main/plugin_registry.json"
const CONTRIBUTION_URL: String = "https://github.com/godotline/godotline-plugin-registry/pulls"
const TEMPLATE_PLUGIN_CFG_PATH: String = "res://addons/template/plugin.cfg"

static var last_load_warning: String = ""


static func get_template_version() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(TEMPLATE_PLUGIN_CFG_PATH) != OK:
		return ""
	return str(config.get_value("plugin", "version", "")).strip_edges()


static func fetch_plugins(owner_node: Node, source_url: String = DEFAULT_MANIFEST_URL) -> Array[PluginEntry]:
	last_load_warning = ""
	var manifest_url: String = source_url.strip_edges()
	if manifest_url.is_empty():
		manifest_url = DEFAULT_MANIFEST_URL
	var http: HTTPRequest = HTTPRequest.new()
	owner_node.add_child(http)
	var request_error: int = http.request(manifest_url, ["Accept: application/json", "User-Agent: GodotLine-PluginStore"])
	if request_error != OK:
		http.queue_free()
		last_load_warning = "无法连接远程插件清单，已使用内置清单"
		return get_all_plugins()

	var result: Array = await http.request_completed
	http.queue_free()
	if result.is_empty() or result[0] != HTTPRequest.RESULT_SUCCESS:
		last_load_warning = "远程插件清单读取失败，已使用内置清单"
		return get_all_plugins()

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse((result[3] as PackedByteArray).get_string_from_utf8())
	if parse_error != OK or not json.data is Dictionary:
		last_load_warning = "远程插件清单格式无效，已使用内置清单"
		return get_all_plugins()

	var manifest: Dictionary = json.data
	var raw_plugins: Variant = manifest.get("plugins", [])
	if not raw_plugins is Array:
		last_load_warning = "远程插件清单缺少 plugins 数组，已使用内置清单"
		return get_all_plugins()

	var plugins: Array[PluginEntry] = []
	for raw_entry: Variant in raw_plugins:
		if raw_entry is Dictionary:
			var entry: PluginEntry = _entry_from_dictionary(raw_entry as Dictionary)
			if entry != null:
				plugins.append(entry)
	if plugins.is_empty():
		last_load_warning = "远程插件清单为空，已使用内置清单"
		return get_all_plugins()
	return plugins


## 获取商城中所有可用插件
static func get_all_plugins() -> Array[PluginEntry]:
	var list: Array[PluginEntry] = []

	# mpm_importer — 从 Unity MPM 文件导入组件
	var mpm: PluginEntry = PluginEntry.new(
		"mpm_importer",
		"MPM Importer",
		"从 Unity 导出的 MPM 文件导入组件到 Godot 项目中。支持 AnimatorPlayer、CameraTrigger、MovingPosMax 等组件导入。",
		"godotline",
		"plugin_mpm_importer",
		"v0.1.0",
		"addons/mpm_importer",
		"res://addons/mpm_importer",
		"1.0.0",
		"https://github.com/godotline/plugin_mpm_importer",
		""
	)
	mpm.download_urls = [{
		"name": "GitHub",
		"url": "https://github.com/godotline/plugin_mpm_importer/archive/refs/tags/v0.1.0.zip"
	}]
	mpm.md5 = "f57cf78f36a7eb001400794c42b45c0c"
	list.append(mpm)

	return list


## 根据 id 查找插件
static func find_plugin(plugin_id: String) -> PluginEntry:
	for entry: PluginEntry in get_all_plugins():
		if entry.id == plugin_id:
			return entry
	return null


static func _entry_from_dictionary(data: Dictionary) -> PluginEntry:
	var plugin_id: String = str(data.get("id", "")).strip_edges()
	var owner: String = str(data.get("github_owner", data.get("author", ""))).strip_edges()
	var repo: String = str(data.get("github_repo", "")).strip_edges()
	if plugin_id.is_empty():
		return null
	var homepage: String = str(data.get("homepage", "")).strip_edges()
	if homepage.is_empty() and not owner.is_empty() and not repo.is_empty():
		homepage = "https://github.com/%s/%s" % [owner, repo]
	var entry: PluginEntry = PluginEntry.new(
		plugin_id,
		str(data.get("display_name", plugin_id)),
		str(data.get("description", "")),
		owner,
		repo,
		str(data.get("branch", "main")),
		str(data.get("sub_dir", "addons/%s" % plugin_id)),
		str(data.get("dest_path", "res://addons/%s" % plugin_id)),
		str(data.get("version", "1.0")),
		homepage,
		str(data.get("icon_url", ""))
	)
	entry.author = str(data.get("author", owner))
	entry.download_urls = _parse_download_urls(data.get("download_urls", []))
	entry.md5 = str(data.get("md5", "")).strip_edges().to_lower()
	entry.min_template_version = str(data.get("min_template_version", "")).strip_edges()
	return entry


static func _parse_download_urls(raw_sources: Variant) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if not raw_sources is Array:
		return sources
	for raw_source: Variant in raw_sources:
		var source_name: String = ""
		var source_url: String = ""
		if raw_source is Dictionary:
			var source_data: Dictionary = raw_source as Dictionary
			source_name = str(source_data.get("name", source_data.get("label", ""))).strip_edges()
			source_url = str(source_data.get("url", "")).strip_edges()
		elif raw_source is String:
			source_url = str(raw_source).strip_edges()
		if source_url.is_empty():
			continue
		if source_name.is_empty():
			source_name = "下载源 %d" % (sources.size() + 1)
		sources.append({"name": source_name, "url": source_url})
	return sources
