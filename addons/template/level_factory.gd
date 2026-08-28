@tool
class_name LevelFactory
extends RefCounted

## 新建关卡：基于模板场景实例化、替换 LevelData 为唯一副本、重新打包保存。

const TEMPLATE_DEFAULT := "res://#Template/[Scenes]/DefaultScene/Default.tscn"
const TEMPLATE_SAMPLE := "res://#Template/[Scenes]/Sample/Sample.tscn"
const LEVELS_ROOT := "res://[Scenes]/"


static func createLevel(levelName: String, templatePath: String, levelId: int) -> int:
	var safeName := _sanitizeName(levelName)
	if safeName.is_empty():
		_pushError("无效的关卡名称：%s" % levelName)
		return ERR_INVALID_PARAMETER

	var levelDir := LEVELS_ROOT + safeName + "/"
	var scenePath := levelDir + safeName + ".tscn"
	var tresPath := levelDir + safeName + ".tres"

	if FileAccess.file_exists(scenePath) or FileAccess.file_exists(tresPath):
		_pushError("关卡已存在：%s" % levelDir)
		return ERR_ALREADY_EXISTS

	var templateScene := load(templatePath) as PackedScene
	if not templateScene:
		_pushError("无法加载模板场景：%s" % templatePath)
		return ERR_CANT_OPEN

	# 使用 GEN_EDIT_STATE_MAIN 实例化，保留节点所有权（owner=root），保证 pack() 能正确打包
	var root := templateScene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if not root:
		_pushError("实例化模板场景失败：%s" % templatePath)
		return ERR_CANT_CREATE

	# 查找 Player 节点
	var player := root.get_node_or_null("BasicOBJ_Group/Player") as Player
	if not player:
		_pushError("模板场景 %s 未找到 BasicOBJ_Group/Player 节点" % templatePath)
		root.queue_free()
		return ERR_INVALID_DATA

	if not player.levelData:
		_pushError("模板场景 %s 的 Player 节点未设置 levelData" % templatePath)
		root.queue_free()
		return ERR_INVALID_DATA

	# 创建目录
	DirAccess.make_dir_recursive_absolute(levelDir)

	# 深拷贝 LevelData 资源，设新字段（唯一化）
	var newData := (player.levelData as Resource).duplicate(true) as LevelData
	if not newData:
		_pushError("复制 LevelData 资源失败")
		root.queue_free()
		return ERR_CANT_CREATE
	newData.saveID = levelId
	newData.levelTitle = levelName
	# levelTitleKey 保持模板原值，仅当为空时用 safeName
	if newData.levelTitleKey.is_empty():
		newData.levelTitleKey = safeName

	# 保存 LevelData 资源（ResourceSaver 会自动分配 UID）
	var saveErr := ResourceSaver.save(newData, tresPath)
	if saveErr != OK:
		_pushError("LevelData 资源保存失败：%s (err=%d)" % [tresPath, saveErr])
		root.queue_free()
		return saveErr
	print("[NewLevel] 已生成 LevelData 资源：%s" % tresPath)

	# 重新加载刚保存的资源，拿到带 UID 的引用
	var savedData := load(tresPath) as LevelData
	if not savedData:
		_pushError("无法重新加载刚保存的 LevelData：%s" % tresPath)
		root.queue_free()
		return ERR_CANT_OPEN

	# 将 Player 的 levelData 指向唯一副本
	player.levelData = savedData

	# 打包并保存场景
	var newScene := PackedScene.new()
	var packErr := newScene.pack(root)
	root.queue_free()
	if packErr != OK:
		_pushError("打包场景失败 (err=%d)" % packErr)
		return packErr

	var sceneSaveErr := ResourceSaver.save(newScene, scenePath)
	if sceneSaveErr != OK:
		_pushError("场景保存失败：%s (err=%d)" % [scenePath, sceneSaveErr])
		return sceneSaveErr
	print("[NewLevel] 已生成场景文件：%s" % scenePath)

	# 刷新文件系统
	EditorInterface.get_resource_filesystem().scan()

	# 在编辑器中打开新场景
	EditorInterface.open_scene_from_path(scenePath)

	return OK


static func _sanitizeName(name: String) -> String:
	var out := ""
	for ch in name:
		var code := ch.unicode_at(0)
		# 允许：字母 (A-Z,a-z)、数字 (0-9)、下划线、连字符
		if (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or (code >= 48 and code <= 57) \
			or code == 95 or code == 45:
			out += ch
	return out


static func _pushError(msg: String) -> void:
	push_error("[Template 插件] " + msg)
	printerr("[Template 插件] " + msg)