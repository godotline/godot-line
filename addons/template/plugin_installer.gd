@tool
class_name PluginInstaller
extends RefCounted

## 插件生命周期管理 — 启用/停用插件、维护 project.godot 启用记录、
## 卸载时把插件目录移入隔离区、清理遗留隔离文件。

const TRASH_ROOT := "user://plugin_store_trash"


## 清理上一次编辑器会话遗留的隔离文件。user:// 不会被 EditorFileSystem 扫描。
static func cleanupQuarantine() -> void:
	var trashRoot: String = ProjectSettings.globalize_path(TRASH_ROOT)
	if not DirAccess.dir_exists_absolute(trashRoot):
		return

	var trashDir: DirAccess = DirAccess.open(trashRoot)
	if trashDir == null:
		return

	trashDir.list_dir_begin()
	while true:
		var entryName: String = trashDir.get_next()
		if entryName.is_empty():
			break
		if entryName == "." or entryName == "..":
			continue
		var entryPath: String = trashRoot.path_join(entryName)
		if trashDir.current_is_dir():
			_removeQuarantineTree(entryPath)
		else:
			var removeErr: Error = DirAccess.remove_absolute(entryPath)
			if removeErr != OK:
				push_warning("[PluginStore] 无法清理隔离文件（错误码：%d）：%s" % [removeErr, entryPath])
	trashDir.list_dir_end()


static func _removeQuarantineTree(dirPath: String) -> void:
	var directory: DirAccess = DirAccess.open(dirPath)
	if directory == null:
		return

	directory.list_dir_begin()
	while true:
		var childName: String = directory.get_next()
		if childName.is_empty():
			break
		if childName == "." or childName == "..":
			continue
		var childPath: String = dirPath.path_join(childName)
		if directory.current_is_dir():
			_removeQuarantineTree(childPath)
		else:
			var removeErr: Error = DirAccess.remove_absolute(childPath)
			if removeErr != OK:
				push_warning("[PluginStore] 无法清理隔离文件（错误码：%d）：%s" % [removeErr, childPath])
	directory.list_dir_end()

	var removeDirErr: Error = DirAccess.remove_absolute(dirPath)
	if removeDirErr != OK:
		push_warning("[PluginStore] 无法清理隔离目录（错误码：%d）：%s" % [removeDirErr, dirPath])


## 在 project.godot 中记录并在当前编辑器中启用插件。
static func enablePlugin(entry: PluginEntry, ownerNode: Node) -> bool:
	var pluginCfgPath: String = entry.destPath + "/plugin.cfg"
	if not FileAccess.file_exists(pluginCfgPath):
		push_warning("[PluginStore] 插件配置文件不存在：%s" % pluginCfgPath)
		return false

	var cfg: ConfigFile = ConfigFile.new()
	var cfgErr: int = cfg.load(pluginCfgPath)
	if cfgErr != OK:
		push_warning("[PluginStore] 无法读取插件配置：%s" % pluginCfgPath)
		return false

	var pluginName: String = str(cfg.get_value("plugin", "name", ""))
	if pluginName.is_empty():
		push_warning("[PluginStore] 插件配置中未找到 name 字段")
		return false

	var projPath: String = "res://project.godot"
	var projCfg: ConfigFile = ConfigFile.new()
	var projErr: int = projCfg.load(projPath)
	if projErr != OK:
		push_warning("[PluginStore] 无法读取 project.godot")
		return false

	var enabled: PackedStringArray = projCfg.get_value("editor_plugins", "enabled", PackedStringArray())

	var fullPath: String = pluginCfgPath
	var alreadyEnabled: bool = false
	for p: String in enabled:
		if p == fullPath:
			alreadyEnabled = true
			break

	if not alreadyEnabled:
		enabled.append(fullPath)
		projCfg.set_value("editor_plugins", "enabled", enabled)
		var saveErr: Error = projCfg.save(projPath)
		if saveErr != OK:
			push_warning("[PluginStore] 无法保存 project.godot（错误码：%d）" % saveErr)
			return false
		print("[PluginStore] 已写入插件启用记录：%s" % pluginName)
	else:
		print("[PluginStore] 插件已存在启用记录：%s" % pluginName)
	ProjectSettings.set_setting("editor_plugins/enabled", enabled)

	var scanOk: bool = await scanAndWait(ownerNode)
	if not scanOk:
		push_warning("[PluginStore] 文件系统扫描未完成，暂不启用插件：%s" % pluginName)
		return false

	if not EditorInterface.is_plugin_enabled(fullPath):
		EditorInterface.set_plugin_enabled(fullPath, true)
		for _i: int in range(2):
			if not _treeAlive(ownerNode):
				return false
			await ownerNode.get_tree().process_frame

	var runtimeEnabled: bool = EditorInterface.is_plugin_enabled(fullPath)
	if not runtimeEnabled:
		push_warning("[PluginStore] 无法在当前编辑器启用插件：%s" % pluginName)
		return false

	print("[PluginStore] 已在当前编辑器启用插件：%s" % pluginName)
	return true


## 等待新插件文件完成导入，避免在扫描期间调用插件管理器。
static func scanAndWait(ownerNode: Node) -> bool:
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	filesystem.scan()
	for _i: int in range(121):
		if not filesystem.is_scanning():
			return true
		if not _treeAlive(ownerNode):
			return false
		await ownerNode.get_tree().process_frame
	return false


## 通过 Godot 的插件管理器卸载已启用的插件，并等待其退出树。
static func disablePluginBeforeRemoval(entry: PluginEntry, ownerNode: Node) -> bool:
	var pluginCfgPath: String = entry.destPath + "/plugin.cfg"
	if not FileAccess.file_exists(pluginCfgPath):
		return true

	if not EditorInterface.is_plugin_enabled(pluginCfgPath):
		return true

	EditorInterface.set_plugin_enabled(pluginCfgPath, false)
	for _i: int in range(120):
		if not _treeAlive(ownerNode):
			return false
		await ownerNode.get_tree().process_frame
		if not EditorInterface.is_plugin_enabled(pluginCfgPath):
			if not _treeAlive(ownerNode):
				return false
			await ownerNode.get_tree().process_frame
			if not EditorInterface.is_plugin_enabled(pluginCfgPath):
				return true
	push_warning("[PluginStore] 插件仍处于启用状态，取消删除：%s" % pluginCfgPath)
	return false


## 从 project.godot 中移除插件的启用记录。
static func disablePluginInProject(entry: PluginEntry) -> bool:
	var projPath: String = "res://project.godot"
	var projCfg: ConfigFile = ConfigFile.new()
	var projErr: int = projCfg.load(projPath)
	if projErr != OK:
		push_warning("[PluginStore] 无法读取 project.godot")
		return false

	var enabled: PackedStringArray = projCfg.get_value("editor_plugins", "enabled", PackedStringArray())
	var newEnabled: PackedStringArray = PackedStringArray()

	for p: String in enabled:
		# 保留不匹配的插件路径
		# 匹配条件：路径等于 destPath，或路径以 destPath + "/" 开头
		if p != entry.destPath and not p.begins_with(entry.destPath + "/"):
			newEnabled.append(p)

	if newEnabled.size() != enabled.size():
		projCfg.set_value("editor_plugins", "enabled", newEnabled)
		var saveErr: Error = projCfg.save(projPath)
		if saveErr != OK:
			push_warning("[PluginStore] 无法保存 project.godot（错误码：%d）" % saveErr)
			return false
		print("[PluginStore] 已从 project.godot 移除插件启用记录：%s" % entry.id)
	ProjectSettings.set_setting("editor_plugins/enabled", newEnabled)
	return true


## 将插件目录移出 res://，把真正的清理延后到编辑器重启后。
static func quarantinePluginDir(entry: PluginEntry) -> bool:
	var sourcePath: String = ProjectSettings.globalize_path(entry.destPath)
	if not DirAccess.dir_exists_absolute(sourcePath):
		return true

	var trashRoot: String = ProjectSettings.globalize_path(TRASH_ROOT)
	var makeDirErr: Error = DirAccess.make_dir_recursive_absolute(trashRoot)
	if makeDirErr != OK and not DirAccess.dir_exists_absolute(trashRoot):
		push_warning("[PluginStore] 无法创建插件隔离目录（错误码：%d）" % makeDirErr)
		return false

	var trashName: String = "%s_%d" % [entry.id.replace("/", "_"), Time.get_ticks_msec()]
	var targetPath: String = trashRoot.path_join(trashName)
	var renameErr: Error = DirAccess.rename_absolute(sourcePath, targetPath)
	if renameErr != OK:
		push_warning("[PluginStore] 无法将插件移出项目（错误码：%d）" % renameErr)
		return false

	print("[PluginStore] 插件文件已移入隔离目录：%s" % targetPath)
	return true


static func _treeAlive(ownerNode: Node) -> bool:
	return is_instance_valid(ownerNode) and ownerNode.get_tree() != null