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


func _ready() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	import_button.pressed.connect(_on_import_pressed)
	preview_button.pressed.connect(_on_preview_pressed)


var currentAudioBytes: PackedByteArray = PackedByteArray()
var currentAudioExt: String = "mp3"


func _on_browse_pressed() -> void:
	var dialog: EditorFileDialog = EditorFileDialog.new()
	dialog.title = "选择 ARPhros 关卡文件 (.arphos, .arphros, .json)"
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.arphos, *.arphros, *.json", "Arphros Level Files")
	dialog.add_filter("*.arphos", "Arphros Package (*.arphos)")
	dialog.add_filter("*.arphros", "Arphros Package (*.arphros)")
	dialog.add_filter("*.json", "JSON Level Files (*.json)")
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))
	dialog.file_selected.connect(_on_file_selected)


func _on_file_selected(path: String) -> void:
	json_path_line.text = path
	_parseFile(path)


func _parseFile(path: String) -> void:
	currentAudioBytes.clear()
	if not FileAccess.file_exists(path):
		_log("❌ 文件不存在: " + path)
		return

	var ext: String = path.get_extension().to_lower()
	if ext == "json":
		_parseJsonFile(path)
	else:
		_parseArphosPackage(path)


func _parseArphosPackage(path: String) -> void:
	var reader: ZIPReader = ZIPReader.new()
	var err: Error = reader.open(path)
	if err != OK:
		_log("⚠️ ZIPReader 打开失败 (code %d)，尝试直接按文本 JSON 解析..." % err)
		_parseJsonFile(path)
		return

	var files: PackedStringArray = reader.get_files()
	_log("📦 包内包含文件: " + ", ".join(files))

	var jsonBytes: PackedByteArray = PackedByteArray()
	for f: String in files:
		var low: String = f.to_lower()
		if low.ends_with(".arplay") or low.ends_with(".json") or low.contains("level"):
			jsonBytes = reader.read_file(f)
			_log("📄 读取关卡数据文件: " + f)
		elif low.ends_with(".mp3") or low.ends_with(".ogg") or low.ends_with(".wav"):
			currentAudioBytes = reader.read_file(f)
			currentAudioExt = low.get_extension()
			_log("🎵 读取关卡音频文件: " + f + " (大小: %d 字节)" % currentAudioBytes.size())

	if jsonBytes.is_empty() and files.size() > 0:
		jsonBytes = reader.read_file(files[0])

	reader.close()

	if jsonBytes.is_empty():
		_log("❌ 未在包中找到关卡数据文件")
		return

	var text: String = jsonBytes.get_string_from_utf8()
	_parseJsonText(text)


func _parseJsonFile(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		_log("❌ 无法打开文件: " + path)
		return

	var text: String = file.get_as_text()
	file.close()
	_parseJsonText(text)


func _parseJsonText(text: String) -> void:
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
		_log("❌ 请先选择 JSON 文件")
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
		_log("❌ 请先选择 JSON 文件")
		return

	_log("🔄 生成关卡资源与场景...")

	var info: Dictionary = currentJsonData.get("info", {})
	var levelName: String = str(info.get("levelName", "Level"))
	var safeName: String = _sanitizeFilename(levelName)
	var levelDir: String = "res://[Scenes]/" + safeName + "/"
	var scenePath: String = levelDir + safeName + ".tscn"
	var dataPath: String = levelDir + safeName + ".tres"

	# 创建关卡专属目录
	DirAccess.make_dir_recursive_absolute(levelDir)

	# 提取并保存音频文件（如果有）
	var audioStreamPath: String = ""
	if not currentAudioBytes.is_empty():
		audioStreamPath = levelDir + "song." + currentAudioExt
		var audioFile: FileAccess = FileAccess.open(audioStreamPath, FileAccess.WRITE)
		if audioFile:
			audioFile.store_buffer(currentAudioBytes)
			audioFile.close()
			_log("🎵 音频文件已解压保存至: " + audioStreamPath)
			EditorInterface.get_resource_filesystem().scan()

	# 生成 LevelData 资源
	var levelData: LevelData = _createLevelDataResource(currentJsonData, safeName, dataPath, audioStreamPath)
	if not levelData:
		_log("❌ LevelData 资源创建失败")
		return

	var scene: Node = _buildScene(currentJsonData, levelData)
	if scene == null:
		_log("❌ 场景生成失败")
		return

	# 设置 owner 确保所有节点包含在打包场景内
	_setOwnerRecursive(scene, scene)

	# 打包场景并保存
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
