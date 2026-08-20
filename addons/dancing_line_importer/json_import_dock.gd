@tool
extends VBoxContainer

const LevelLoaderScript: Script = preload("res://addons/dancing_line_importer/scripts/LevelLoader.gd")
const DEFAULT_LEVEL_DATA_TEMPLATE: String = "res://#Template/[Scenes]/DefaultScene/Default.tres"

@onready var json_path_line: LineEdit = $FileSection/FilePathLine
@onready var browse_button: Button = $FileSection/BrowseButton
@onready var import_button: Button = $Actions/ImportButton
@onready var preview_button: Button = $Actions/PreviewButton
@onready var status_label: Label = $StatusLabel
@onready var log_text: TextEdit = $LogText

var currentJsonData: Dictionary = {}
var tempScene: Node = null
var currentFolderPath: String = ""
var currentAudioBytes: PackedByteArray = PackedByteArray()
var currentAudioExt: String = "mp3"
var importedModelsDir: String = ""


func _ready() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	import_button.pressed.connect(_on_import_pressed)
	preview_button.pressed.connect(_on_preview_pressed)


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

	if arprojPath.is_empty():
		_log("❌ 未在文件夹中找到关卡数据文件 (level.arproj)")
		return

	_log("📂 导入文件夹: " + dir)
	_log("📄 关卡数据文件: " + arprojPath)
	_parseJsonFile(arprojPath)

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

	# 复制模型资源
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

	var da: DirAccess = DirAccess.open(resourcesDir)
	if not da:
		_log("❌ 无法读取 Resources 文件夹: " + resourcesDir)
		return

	da.list_dir_begin()
	var count: int = 0
	while true:
		var fileName: String = da.get_next()
		if fileName.is_empty():
			break
		if fileName.begins_with(".") or da.current_is_dir():
			continue
		var ext: String = fileName.get_extension().to_lower()
		if ext in ["meta", "lua", "txt", "json", "cs", "unity", "prefab", "mat"]:
			continue
		var validExts: Array[String] = ["obj", "png", "jpg", "jpeg", "mtl", "glb", "gltf", "fbx", "tga", "bmp", "dds", "hdr", "exr", "ktx", "pvr", "pkm", "svg", "webp"]
		if ext not in validExts:
			continue
		var src: String = resourcesDir.path_join(fileName)
		var dst: String = targetDir + fileName
		var err: Error = DirAccess.copy_absolute(src, dst)
		if err == OK:
			count += 1

	da.list_dir_end()

	_log("📦 已复制 %d 个模型/纹理文件到: " % count + targetDir)
	if count > 0:
		importedModelsDir = targetDir
		EditorInterface.get_resource_filesystem().scan()


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


func _on_preview_pressed() -> void:
	if currentJsonData.is_empty():
		_log("❌ 请先选择关卡文件夹")
		return

	_log("🔄 预览场景...")
	_clearPreview()

	tempScene = _buildScene(currentJsonData, null)
	if tempScene and tempScene.get_child_count() > 0:
		var viewport: Node = EditorInterface.get_editor_viewport_3d().get_parent()
		viewport.add_child(tempScene)
		_log("✅ 预览已加载")
		status_label.text = "👁️ 预览中"
	else:
		_log("❌ 场景为空，无法预览")
		tempScene = null


func _on_import_pressed() -> void:
	if currentJsonData.is_empty():
		_log("❌ 请先选择关卡文件夹")
		return

	_log("🔄 生成关卡资源与场景...")

	# 如果有模型需要等待导入完成
	if not importedModelsDir.is_empty():
		_log("⏳ 等待模型资源导入...")
		if EditorInterface.get_resource_filesystem().is_scanning():
			await EditorInterface.get_resource_filesystem().filesystem_changed
		else:
			# 触发扫描并等待
			EditorInterface.get_resource_filesystem().scan()
			await EditorInterface.get_resource_filesystem().filesystem_changed
		_log("✅ 模型资源导入完成")

	var info: Dictionary = currentJsonData.get("info", {})
	var levelName: String = str(info.get("levelName", "Level"))
	var safeName: String = _sanitizeFilename(levelName)
	var levelDir: String = "res://[Scenes]/" + safeName + "/"
	var scenePath: String = levelDir + safeName + ".scn"
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
			EditorInterface.get_resource_filesystem().scan()

	var levelData: LevelData = _createLevelDataResource(currentJsonData, safeName, dataPath, audioStreamPath)
	if not levelData:
		_log("❌ LevelData 资源创建失败")
		return

	var scene: Node = _buildScene(currentJsonData, levelData)
	if scene == null:
		_log("❌ 场景生成失败")
		return

	_setOwnerRecursive(scene, scene)

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
		status_label.text = "✅ 已生成: " + safeName
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.open_scene_from_path(scenePath)
	else:
		_log("❌ 场景保存失败: " + str(saveErr))

	_clearPreview()


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
	for child: Node in node.get_children():
		_setOwnerRecursive(child, owner)


func _buildScene(data: Dictionary, levelDataResource: LevelData) -> Node:
	var loader: LevelLoader = LevelLoaderScript.new() as LevelLoader
	add_child(loader)
	if not importedModelsDir.is_empty():
		loader.extraSearchPaths = [importedModelsDir]
	var scene: Node = loader.buildScene(data, levelDataResource)
	loader.queue_free()
	return scene


func _clearPreview() -> void:
	if tempScene:
		if tempScene.get_parent():
			tempScene.get_parent().remove_child(tempScene)
		tempScene.queue_free()
		tempScene = null


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
