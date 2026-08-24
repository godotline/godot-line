@tool
extends VBoxContainer

const LevelLoaderScript: Script = preload("res://addons/dancing_line_importer/scripts/LevelLoader.gd")
const DEFAULT_LEVEL_DATA_TEMPLATE: String = "res://#Template/[Scenes]/DefaultScene/Default.tres"

@onready var json_path_line: LineEdit = $FileSection/FilePathLine
@onready var browse_button: Button = $FileSection/BrowseButton
@onready var import_button: Button = $Actions/ImportButton
@onready var status_label: Label = $StatusLabel
@onready var log_text: TextEdit = $LogText

var currentJsonData: Dictionary = {}
var currentFolderPath: String = ""
var currentAudioBytes: PackedByteArray = PackedByteArray()
var currentAudioExt: String = "mp3"
var importedModelsDir: String = ""


func _ready() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	import_button.pressed.connect(_on_import_pressed)


func _on_browse_pressed() -> void:
	var dialog: EditorFileDialog = EditorFileDialog.new()
	dialog.title = "选择 dancing_line 关卡文件夹（包含 level.arproj）"
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))
	dialog.dir_selected.connect(_on_folder_selected)


func _on_folder_selected(dir: String) -> void:
	json_path_line.text = dir
	currentFolderPath = dir
	currentAudioBytes.clear()
	currentAudioExt = "mp3"
	importedModelsDir = ""

	var arprojPath: String = ""
	for candidate: String in ["level.arproj", "level.json", "levels.json", "map.json", "data.json"]:
		var p: String = dir.path_join(candidate)
		if FileAccess.file_exists(p):
			arprojPath = p
			break

	# 回退：查找 .arplay 工程包
	var isArplay: bool = false
	if arprojPath.is_empty():
		var dirAccess := DirAccess.open(dir)
		if dirAccess:
			dirAccess.list_dir_begin()
			var entry: String = dirAccess.get_next()
			while not entry.is_empty():
				if not dirAccess.current_is_dir() and entry.get_extension().to_lower() == "arplay":
					arprojPath = dir.path_join(entry)
					isArplay = true
					break
				entry = dirAccess.get_next()
			dirAccess.list_dir_end()

	if arprojPath.is_empty():
		_log("❌ 未在文件夹中找到关卡数据文件 (level.arproj / *.arplay)")
		return

	_log("📂 导入文件夹: " + dir)
	_log("📄 关卡数据文件: " + arprojPath)

	if isArplay:
		_log("📦 检测到 .arplay 工程包，提取资源…")
		currentJsonData = ArplayCrypto.readLevel(arprojPath)
		if currentJsonData.is_empty():
			_log("❌ .arplay 提取失败")
			return
		# 资源直接提取进项目目标目录（产物不落在原始文件夹）
		var info: Dictionary = currentJsonData.get("info", {}) as Dictionary
		var arplaySafeName: String = _sanitizeFilename(str(info.get("levelName", "Level")))
		var arplayResDir: String = "res://[Scenes]/" + arplaySafeName + "/Resources"
		var counts: Dictionary = ArplayCrypto.extract(arprojPath, arplayResDir)["counts"] as Dictionary
		importedModelsDir = arplayResDir + "/"
		EditorInterface.get_resource_filesystem().scan()
		var objCount: int = (currentJsonData.get("objects", []) as Array).size()
		_log("✅ 提取成功！对象 %d 个；提取资源 Meshes=%d Sprites=%d Scripts=%d" % [objCount, int(counts.get("Meshes", 0)), int(counts.get("Sprites", 0)), int(counts.get("Scripts", 0))])
		status_label.text = "✅ 已提取: " + str(info.get("levelName", "未命名"))
	else:
		_parseJsonFile(arprojPath)
		if currentJsonData.is_empty():
			return

	if currentJsonData.is_empty():
		return

	# 读取音频
	for candidate: String in ["song.mp3", "song.ogg", "song.wav", "music.mp3", "music.ogg", "bgm.mp3"]:
		var p: String = dir.path_join(candidate)
		if FileAccess.file_exists(p):
			var f: FileAccess = FileAccess.open(p, FileAccess.READ)
			if f:
				currentAudioBytes = f.get_buffer(f.get_length())
				currentAudioExt = p.get_extension()
				f.close()
				_log("🎵 已读取音频: " + candidate + " (大小: %d 字节)" % currentAudioBytes.size())
			break

	# 复制模型资源（.arplay 路径已在提取时直接写入项目，跳过）
	if not isArplay:
		_copyModels(dir)


func _copyModels(sourceDir: String) -> void:
	var resourcesDir: String = sourceDir.path_join("Resources")
	if not DirAccess.dir_exists_absolute(resourcesDir):
		_log("⚠️ 未找到 Resources 子文件夹，跳过模型导入")
		return

	var info: Dictionary = currentJsonData.get("info", {})
	var levelName: String = str(info.get("levelName", "Level"))
	var safeName: String = _sanitizeFilename(levelName)
	var targetDir: String = "res://[Scenes]/" + safeName + "/Resources/"
	DirAccess.make_dir_recursive_absolute(targetDir)

	var count: int = _copyModelsRecursive(resourcesDir, targetDir)

	_log("📦 已复制 %d 个模型/纹理文件到: " % count + targetDir)
	if count > 0:
		importedModelsDir = targetDir
		EditorInterface.get_resource_filesystem().scan()


## 递归遍历 Resources 子树（含 Meshes/Sprites 等子目录），文件按原名平铺复制
func _copyModelsRecursive(dirPath: String, targetDir: String) -> int:
	var da: DirAccess = DirAccess.open(dirPath)
	if not da:
		_log("❌ 无法读取资源文件夹: " + dirPath)
		return 0

	var count: int = 0
	da.list_dir_begin()
	while true:
		var fileName: String = da.get_next()
		if fileName.is_empty():
			break
		if fileName.begins_with("."):
			continue
		var fullPath: String = dirPath.path_join(fileName)
		if da.current_is_dir():
			count += _copyModelsRecursive(fullPath, targetDir)
			continue
		var ext: String = fileName.get_extension().to_lower()
		if ext in ["meta", "lua", "txt", "json", "cs", "unity", "prefab", "mat"]:
			continue
		var validExts: Array[String] = ["obj", "png", "jpg", "jpeg", "mtl", "glb", "gltf", "fbx", "tga", "bmp", "dds", "hdr", "exr", "ktx", "pvr", "pkm", "svg", "webp"]
		if ext not in validExts:
			continue
		var err: Error = DirAccess.copy_absolute(fullPath, targetDir + fileName)
		if err == OK:
			count += 1

	da.list_dir_end()
	return count


func _parseJsonFile(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		_log("❌ 无法打开文件: " + path)
		return

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		_log("❌ JSON 解析失败: " + json.get_error_message())
		return

	if not json.data is Dictionary:
		_log("❌ JSON 根节点不是 Dictionary")
		return

	currentJsonData = json.data as Dictionary
	var info: Dictionary = currentJsonData.get("info", {})
	var levelName: String = str(info.get("levelName", "未命名"))
	var objectCount: int = (currentJsonData.get("objects", []) as Array).size()

	_log("✅ 解析成功!")
	_log("📋 关卡名称: " + levelName)
	_log("📦 对象数量: " + str(objectCount))
	status_label.text = "✅ 已解析: " + levelName


func _on_import_pressed() -> void:
	if currentJsonData.is_empty():
		_log("❌ 请先选择关卡文件夹")
		return

	_log("🔄 生成关卡资源与场景...")

	# 仅在后台仍在扫描时等待，若已扫描完成则直接跳过，避免重复触发 scan
	if not importedModelsDir.is_empty() and EditorInterface.get_resource_filesystem().is_scanning():
		_log("⏳ 等待模型资源导入...")
		await EditorInterface.get_resource_filesystem().filesystem_changed
		_log("✅ 模型资源导入完成")

	var info: Dictionary = currentJsonData.get("info", {})
	var levelName: String = str(info.get("levelName", "Level"))
	var safeName: String = _sanitizeFilename(levelName)
	var levelDir: String = "res://[Scenes]/" + safeName + "/"
	var scenePath: String = levelDir + safeName + ".tscn"
	var dataPath: String = levelDir + safeName + ".tres"

	DirAccess.make_dir_recursive_absolute(levelDir)

	var audioStreamPath: String = ""
	if not currentAudioBytes.is_empty():
		audioStreamPath = levelDir + "song." + currentAudioExt
		var audioFile: FileAccess = FileAccess.open(audioStreamPath, FileAccess.WRITE)
		if audioFile:
			audioFile.store_buffer(currentAudioBytes)
			audioFile.close()
			_log("🎵 音频文件已保存至: " + audioStreamPath)
			# 关键：刚写入的音频尚未进入资源系统，直接 load 会失败导致
			# LevelData.levelAudioClip 为空。必须先注册并同步重导入该文件。
			var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
			fs.update_file(audioStreamPath)
			fs.reimport_files(PackedStringArray([audioStreamPath]))
			_log("✅ 音频已导入资源系统")

	var levelData: LevelData = _createLevelDataResource(currentJsonData, safeName, dataPath, audioStreamPath)
	if not levelData:
		_log("❌ LevelData 资源创建失败")
		return

	var scene: Node = _buildScene(currentJsonData, levelData)
	if scene == null:
		_log("❌ 场景生成失败")
		return

	var packedScene: PackedScene = PackedScene.new()
	var packErr: Error = packedScene.pack(scene)
	if packErr != OK:
		_log("❌ 打包场景失败: " + str(packErr))
		scene.queue_free()
		return

	var saveErr: Error = ResourceSaver.save(packedScene, scenePath)
	scene.queue_free()

	if saveErr == OK:
		_log("✅ 关卡场景已保存: " + scenePath)
		_log("✅ 关卡数据已保存: " + dataPath)
		_log("💡 导入完成！请在文件系统中双击打开该场景。")
		status_label.text = "✅ 已生成: " + safeName
		# 延迟一帧触发 scan_sources，避免在保存资源的回调中发生递归 reimport_files
		EditorInterface.get_resource_filesystem().call_deferred("scan_sources")
	else:
		_log("❌ 场景保存失败: " + str(saveErr))


func _createLevelDataResource(data: Dictionary, safeName: String, dataPath: String, audioStreamPath: String = "") -> LevelData:
	var info: Dictionary = data.get("info", {})
	var levelTitle: String = str(info.get("levelName", safeName))
	var playerData: Dictionary = data.get("player", {})
	var customData: Variant = JSON.parse_string(str(playerData.get("customData", "{}")))
	var speedVal: float = 12.0
	if customData is Dictionary:
		speedVal = float((customData as Dictionary).get("speed", 12.0))

	var defaultTemplateRes: LevelData = load(DEFAULT_LEVEL_DATA_TEMPLATE) as LevelData
	var newLevelData: LevelData
	if defaultTemplateRes:
		newLevelData = defaultTemplateRes.duplicate(true) as LevelData
	else:
		newLevelData = LevelData.new()

	newLevelData.levelTitle = levelTitle
	newLevelData.levelTitleKey = safeName
	newLevelData.speed = speedVal
	newLevelData.saveID = int(Time.get_unix_time_from_system()) % 100000

	if not audioStreamPath.is_empty() and ResourceLoader.exists(audioStreamPath):
		var audioRes: AudioStream = load(audioStreamPath) as AudioStream
		if audioRes:
			newLevelData.levelAudioClip = audioRes

	var saveErr: Error = ResourceSaver.save(newLevelData, dataPath)
	if saveErr != OK:
		_log("❌ 保存 LevelData 失败: " + str(saveErr))
		return null

	return load(dataPath) as LevelData


func _setOwnerRecursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	# 如果该节点本身是子场景实例（如 Player.tscn, CameraRoot.tscn, LevelUI.tscn,
	# 导入生成的 Ground/Trigger 实例等），它的根节点 owner 设为主场景，
	# 其模板内部子节点保留原本预制体的内部所有权（owner=实例根），不下钻；
	# 但导入器追加在实例根下的无主节点（EventTrigger/动画器/颜色组件等）
	# 属于本场景内容，需要一并设置 owner 才能保存。
	if node != owner and not node.scene_file_path.is_empty():
		for child: Node in node.get_children():
			if child.owner == null:
				_setOwnerRecursive(child, owner)
		return
	for child: Node in node.get_children():
		_setOwnerRecursive(child, owner)


func _buildScene(data: Dictionary, levelDataResource: LevelData) -> Node:
	var loader: LevelLoader = LevelLoaderScript.new() as LevelLoader
	add_child(loader)
	if not importedModelsDir.is_empty():
		loader.extraSearchPaths = [importedModelsDir]
	var scene: Node = loader.buildScene(data, levelDataResource)
	# owner 先设置；实例的 editable 标记必须在 owner 之后调用才生效
	_setOwnerRecursive(scene, scene)
	loader.markEditableInstances(scene)
	loader.queue_free()
	return scene


func _sanitizeFilename(name: String) -> String:
	if name.strip_edges().is_empty():
		return "level_" + str(Time.get_unix_time_from_system())

	var result: String = ""
	for ch: String in name:
		var code: int = ch.unicode_at(0)
		var isLetter: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var isDigit: bool = (code >= 48 and code <= 57)
		var isUnderscore: bool = code == 95 or code == 45
		var isChinese: bool = (code >= 0x4E00 and code <= 0x9FFF)
		var isUnicode: bool = code > 127
		var isValid: bool = isLetter or isDigit or isUnderscore or isChinese or isUnicode
		result += ch if isValid else "_"

	result = result.trim_prefix("_")
	result = result.trim_suffix("_")

	if result.is_empty():
		result = "level_" + str(Time.get_unix_time_from_system())

	return result


func _log(msg: String) -> void:
	log_text.text += msg + "\n"
	log_text.scroll_vertical = log_text.get_line_count()
