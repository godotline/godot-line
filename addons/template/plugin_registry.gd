@tool
class_name PluginRegistry extends RefCounted

## 插件注册表 — 定义商城中可用的插件信息

const DEFAULT_MANIFEST_URL: String = "https://raw.githubusercontent.com/godotline/godotline-plugin-registry/refs/heads/main/plugin_registry.json"

static var last_load_warning: String = ""


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
	var mpm := PluginEntry.new(
		"mpm_importer",
		"MPM Importer",
		"从 Unity 导出的 MPM 文件导入组件到 Godot 项目中。支持 AnimatorPlayer、CameraTrigger、MovingPosMax 等组件导入。",
		"godotline",
		"mpm_importer",
		"main",
		"addons/mpm_importer",
		"res://addons/mpm_importer",
		"1.0",
		"https://github.com/godotline/mpm_importer",
		""
	)
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
	if plugin_id.is_empty() or owner.is_empty() or repo.is_empty():
		return null
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
		str(data.get("homepage", "https://github.com/%s/%s" % [owner, repo])),
		str(data.get("icon_url", ""))
	)
	entry.author = str(data.get("author", owner))
	return entry
