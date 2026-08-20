@tool
extends Node
class_name LevelLoader

const MIN_SCALE: float = 0.001

const PLAYER_TEMPLATE: String = "res://#Template/Player.tscn"
const CAMERA_TEMPLATE: String = "res://#Template/CameraRoot.tscn"
const TRIGGER_TEMPLATE: String = "res://#Template/Trigger.tscn"
const GEM_TEMPLATE: String = "res://#Template/Gem.tscn"
const CROWN_TEMPLATE: String = "res://#Template/CrownCheckPoint.tscn"
const LEVEL_UI_TEMPLATE: String = "res://#Template/[Resources]/LevelUI.tscn"
const GROUND_TEMPLATE: String = "res://#Template/Ground.tscn"
const OBSTACLE_TEMPLATE: String = "res://#Template/Obstacle.tscn"

const JumpClass: Script = preload("res://#Template/[Scripts]/Trigger/Jump.gd")
const KillPlayerClass: Script = preload("res://#Template/[Scripts]/Trigger/KillPlayer.gd")
const CameraTriggerClass: Script = preload("res://#Template/[Scripts]/CameraScripts/CameraTrigger.gd")

const MODEL_SEARCH_PATHS: Array[String] = [
	"res://#Template/[Resources]/Models/",
	"res://#Template/[Resources]/",
	"res://Resources/",
	"res://",
]

var loadedMeshes: Dictionary = {}
var extraSearchPaths: Array[String] = []


func buildScene(data: Dictionary, levelDataResource: LevelData = null) -> Node3D:
	loadedMeshes.clear()

	var rootScene: Node3D = Node3D.new()
	rootScene.name = "LevelHolder"

	var info: Dictionary = data.get("info", {})
	var levelName: String = info.get("levelName", "Level")
	if levelName.strip_edges().is_empty():
		levelName = "Level"

	# 1. 创建 BasicOBJ_Group
	var basicObjGroup: Node3D = Node3D.new()
	basicObjGroup.name = "BasicOBJ_Group"
	rootScene.add_child(basicObjGroup)

	var dirLight: DirectionalLight3D = _createLight(basicObjGroup, data)
	var cameraRoot: Node3D = _createCamera(basicObjGroup, data)
	var animPlayer: AnimationPlayer = _createAnimationPlayer(basicObjGroup, data)
	_createPlayer(basicObjGroup, data, levelDataResource, cameraRoot, dirLight, animPlayer)
	_createLevelUI(basicObjGroup)

	# 2. 创建 Scene_Group 与 Scene_001
	var sceneGroup: Node3D = Node3D.new()
	sceneGroup.name = "Scene_Group"
	rootScene.add_child(sceneGroup)

	var scene001: Node3D = Node3D.new()
	scene001.name = "Scene_001"
	sceneGroup.add_child(scene001)

	_createObjects(scene001, data)

	# 如果没有任何网格，添加默认地面
	if not _hasMesh(scene001):
		_addDefaultGround(scene001)

	return rootScene


# ==================== 辅助与变换函数 ====================

func degToRad(deg: float) -> float:
	return deg * PI / 180.0


func toIntSafe(value: Variant) -> int:
	if value is float:
		return int(value)
	elif value is int:
		return value
	elif value is String:
		var strVal: String = value as String
		return strVal.to_int() if strVal.is_valid_int() else -1
	return -1


func getVector3FromDict(dictData: Dictionary, key: String, default: Vector3 = Vector3.ZERO) -> Vector3:
	var data: Variant = dictData.get(key, null)
	if data is Dictionary:
		var d: Dictionary = data as Dictionary
		return Vector3(
			float(d.get("x", default.x)),
			float(d.get("y", default.y)),
			float(d.get("z", default.z))
		)
	return default


func unityToGodotPosition(pos: Vector3) -> Vector3:
	return pos


func unityToGodotScale(scale: Vector3) -> Vector3:
	var s: Vector3 = scale
	if abs(s.x) < MIN_SCALE: s.x = MIN_SCALE
	if abs(s.y) < MIN_SCALE: s.y = MIN_SCALE
	if abs(s.z) < MIN_SCALE: s.z = MIN_SCALE
	return s


func unityToGodotRotation(unityDeg: Vector3) -> Vector3:
	var godotDeg: Vector3 = Vector3(unityDeg.x, -unityDeg.y, unityDeg.z)
	return Vector3(degToRad(godotDeg.x), degToRad(godotDeg.y), degToRad(godotDeg.z))


func unityToGodotRotationNoFlip(unityDeg: Vector3) -> Vector3:
	return Vector3(degToRad(unityDeg.x), degToRad(unityDeg.y), degToRad(unityDeg.z))


# ==================== 基础物体创建 ====================

func _createLight(parent: Node, data: Dictionary) -> DirectionalLight3D:
	var lightData: Dictionary = data.get("directionalLight", {})
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	var pos: Vector3 = getVector3FromDict(lightData, "position", Vector3(0, 10, 0))
	light.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(lightData, "eulerAngles", Vector3(50, 135, 0))
	light.rotation = unityToGodotRotation(rot)
	light.shadow_enabled = true

	var customData: Variant = JSON.parse_string(str(lightData.get("customData", "{}")))
	if customData is Dictionary:
		var custom: Dictionary = customData as Dictionary
		var colorData: Variant = custom.get("color", null)
		if colorData is Dictionary:
			var c: Dictionary = colorData as Dictionary
			light.light_color = Color(float(c.get("r", 1.0)), float(c.get("g", 1.0)), float(c.get("b", 1.0)), float(c.get("a", 1.0)))
		light.light_energy = float(custom.get("intensity", 1.0))

	parent.add_child(light)
	return light


func _createCamera(parent: Node, data: Dictionary) -> Node3D:
	var cameraScene: PackedScene = load(CAMERA_TEMPLATE) as PackedScene
	var cameraRoot: Node3D
	if cameraScene:
		cameraRoot = cameraScene.instantiate() as Node3D
	else:
		cameraRoot = Node3D.new()
		var cam: Camera3D = Camera3D.new()
		cam.name = "Camera3D"
		cameraRoot.add_child(cam)

	cameraRoot.name = "CameraRoot"

	var envData: Dictionary = data.get("environment", {})
	var camNode: Camera3D = cameraRoot.get_node_or_null("Rotator/Scale/Camera3D") as Camera3D
	if not camNode:
		camNode = cameraRoot.get_node_or_null("Camera3D") as Camera3D

	if camNode:
		var env: Environment = Environment.new()
		var bgColorData: Variant = envData.get("backgroundColor", null)
		if bgColorData is Dictionary:
			var bg: Dictionary = bgColorData as Dictionary
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(float(bg.get("r", 0.1)), float(bg.get("g", 0.1)), float(bg.get("b", 0.15)), 1.0)

		var ambColorData: Variant = envData.get("ambientColor", null)
		if ambColorData is Dictionary:
			var amb: Dictionary = ambColorData as Dictionary
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(float(amb.get("r", 0.3)), float(amb.get("g", 0.3)), float(amb.get("b", 0.4)), 1.0)
			env.ambient_light_energy = 0.5

		if envData.get("enableFog", false):
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
			var fogDensity: Variant = envData.get("fogDensity", 0.01)
			env.fog_density = float(fogDensity)
			var fogColorData: Variant = envData.get("fogColor", null)
			if fogColorData is Dictionary:
				var fc: Dictionary = fogColorData as Dictionary
				env.fog_light_color = Color(float(fc.get("r", 0.0)), float(fc.get("g", 0.0)), float(fc.get("b", 0.0)), 1.0)
			elif bgColorData is Dictionary:
				var bg: Dictionary = bgColorData as Dictionary
				env.fog_light_color = Color(float(bg.get("r", 0.1)), float(bg.get("g", 0.1)), float(bg.get("b", 0.15)), 1.0)

		camNode.environment = env

	var camData: Dictionary = data.get("mainCamera", {})
	var customData: Variant = JSON.parse_string(str(camData.get("customData", "{}")))
	if customData is Dictionary:
		var custom: Dictionary = customData as Dictionary
		var pivot: Dictionary = custom.get("pivotOffset", {})
		cameraRoot.position = Vector3(float(pivot.get("x", 0.0)), float(pivot.get("y", 0.0)), float(pivot.get("z", 0.0)))
		var rot: Dictionary = custom.get("targetRotation", {})
		cameraRoot.rotation = unityToGodotRotation(Vector3(float(rot.get("x", 45.0)), float(rot.get("y", 60.0)), float(rot.get("z", 0.0))))
		var fovVal: Variant = custom.get("fov", 60.0)
		if camNode:
			camNode.fov = float(fovVal)

	parent.add_child(cameraRoot)
	return cameraRoot


func _createAnimationPlayer(parent: Node, _data: Dictionary) -> AnimationPlayer:
	var animPlayer: AnimationPlayer = AnimationPlayer.new()
	animPlayer.name = "AnimationPlayer"
	animPlayer.root_node = NodePath("../..")

	var animLib: AnimationLibrary = AnimationLibrary.new()
	var resetAnim: Animation = Animation.new()
	resetAnim.length = 0.001
	animLib.add_animation(&"RESET", resetAnim)

	var levelAnim: Animation = Animation.new()
	levelAnim.length = 130.0
	animLib.add_animation(&"level", levelAnim)

	animPlayer.add_animation_library(&"", animLib)

	var audioPlayer: AudioStreamPlayer = AudioStreamPlayer.new()
	audioPlayer.name = "AudioStreamPlayer"
	animPlayer.add_child(audioPlayer)

	parent.add_child(animPlayer)
	return animPlayer


func _createPlayer(
	parent: Node,
	data: Dictionary,
	levelDataResource: LevelData,
	cameraRoot: Node3D,
	dirLight: DirectionalLight3D,
	animPlayer: AnimationPlayer
) -> Player:
	var playerScene: PackedScene = load(PLAYER_TEMPLATE) as PackedScene
	var player: Player
	if playerScene:
		player = playerScene.instantiate() as Player
	else:
		player = Player.new()

	player.name = "Player"
	player.add_to_group("Player")
	player.add_to_group("player")

	var playerData: Dictionary = data.get("player", {})
	var pos: Vector3 = getVector3FromDict(playerData, "position", Vector3.ZERO)
	player.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(playerData, "eulerAngles", Vector3(0, 90, 0))
	player.rotation = unityToGodotRotation(rot)

	if levelDataResource:
		player.levelData = levelDataResource

	if cameraRoot:
		var camNode: Camera3D = cameraRoot.get_node_or_null("Rotator/Scale/Camera3D") as Camera3D
		if camNode:
			player.sceneCamera = camNode
	if dirLight:
		player.sceneLight = dirLight
	if animPlayer:
		player.animation = NodePath("../AnimationPlayer")

	var customData: Variant = JSON.parse_string(str(playerData.get("customData", "{}")))
	if customData is Dictionary:
		var custom: Dictionary = customData as Dictionary
		var speedVal: Variant = custom.get("speed", 12.0)
		player.Speed = float(speedVal)

	parent.add_child(player)
	return player


func _createLevelUI(parent: Node) -> void:
	var uiScene: PackedScene = load(LEVEL_UI_TEMPLATE) as PackedScene
	if uiScene:
		var uiInstance: Node = uiScene.instantiate()
		uiInstance.name = "LevelUI"
		parent.add_child(uiInstance)


# ==================== 关卡物体与树构建 ====================

func _createObjects(parent: Node, data: Dictionary) -> void:
	var meshes: Array = data.get("meshes", [])
	var materials: Array = data.get("materials", [])
	var objects: Array = data.get("objects", [])

	var nodeMap: Dictionary = {}
	var rootNodes: Array[Node] = []

	for rawObj: Variant in objects:
		if not rawObj is Dictionary:
			continue
		var objData: Dictionary = rawObj as Dictionary
		var objId: int = toIntSafe(objData.get("id", -1))
		var node: Node = _createSingleObject(objData, meshes, materials)
		if node:
			nodeMap[objId] = node
			var parentId: int = toIntSafe(objData.get("parentId", -1))
			if parentId == -1 or parentId == 0:
				rootNodes.append(node)

	for rawObj: Variant in objects:
		if not rawObj is Dictionary:
			continue
		var objData: Dictionary = rawObj as Dictionary
		var objId: int = toIntSafe(objData.get("id", -1))
		var parentId: int = toIntSafe(objData.get("parentId", -1))
		if parentId != -1 and parentId != 0 and nodeMap.has(objId) and nodeMap.has(parentId):
			var child: Node = nodeMap[objId]
			var parentNode: Node = nodeMap[parentId]
			if child.get_parent():
				child.get_parent().remove_child(child)
			parentNode.add_child(child)

	for rootNode: Node in rootNodes:
		parent.add_child(rootNode)


func _createSingleObject(objData: Dictionary, meshes: Array, materials: Array) -> Node:
	var rawType: Variant = objData.get("type", 1)
	var type: int = toIntSafe(rawType)
	var objName: String = str(objData.get("name", "unnamed")).to_lower()

	match type:
		0, 1, 6, 7, 8:
			if objName.contains("cube") or objName.contains("box"):
				return _createObstacleBox(objData, materials)
			elif objName.contains("gem") or objName.contains("diamond"):
				return _createGemInstance(objData)
			elif objName.contains("crown"):
				return _createCrownInstance(objData)
			else:
				return _createMeshObject(objData, meshes, materials)
		2:
			return _createPointLightObject(objData)
		3:
			return _createDirectionalLightObject(objData)
		4:
			return _createTriggerObject(objData)
		5, 9, 10, 11:
			return _createRoadObject(objData, materials)
		_:
			return _createMeshObject(objData, meshes, materials)


# ==================== 具体物体类型 ====================

func _createRoadObject(objData: Dictionary, materials: Array) -> Node:
	var groundScene: PackedScene = load(GROUND_TEMPLATE) as PackedScene
	var roadNode: Node3D
	if groundScene:
		roadNode = groundScene.instantiate() as Node3D
	else:
		var sb: StaticBody3D = StaticBody3D.new()
		sb.collision_layer = 2
		sb.collision_mask = 0
		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		col.shape = shape
		sb.add_child(col)
		var meshInst: MeshInstance3D = MeshInstance3D.new()
		meshInst.mesh = BoxMesh.new()
		sb.add_child(meshInst)
		roadNode = sb

	roadNode.name = str(objData.get("name", "Road"))
	var pos: Vector3 = getVector3FromDict(objData, "position")
	roadNode.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	roadNode.rotation = unityToGodotRotation(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	roadNode.scale = unityToGodotScale(scale)

	var mat: Material = _createStandardMaterial(objData, materials)
	var meshNode: MeshInstance3D = roadNode.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if meshNode and mat:
		meshNode.material_override = mat

	return roadNode


func _createObstacleBox(objData: Dictionary, materials: Array) -> Node:
	var obsScene: PackedScene = load(OBSTACLE_TEMPLATE) as PackedScene
	var obsNode: Node3D
	if obsScene:
		obsNode = obsScene.instantiate() as Node3D
	else:
		var sb: StaticBody3D = StaticBody3D.new()
		sb.collision_layer = 4
		sb.collision_mask = 0
		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		col.shape = shape
		sb.add_child(col)
		var meshInst: MeshInstance3D = MeshInstance3D.new()
		meshInst.mesh = BoxMesh.new()
		sb.add_child(meshInst)
		obsNode = sb

	obsNode.name = str(objData.get("name", "Box"))
	var pos: Vector3 = getVector3FromDict(objData, "position")
	obsNode.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	obsNode.rotation = unityToGodotRotation(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	obsNode.scale = unityToGodotScale(scale)

	var mat: Material = _createStandardMaterial(objData, materials)
	var meshNode: MeshInstance3D = obsNode.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if meshNode and mat:
		meshNode.material_override = mat

	return obsNode


func _createGemInstance(objData: Dictionary) -> Node:
	var gemScene: PackedScene = load(GEM_TEMPLATE) as PackedScene
	var gemNode: Node3D
	if gemScene:
		gemNode = gemScene.instantiate() as Node3D
	else:
		gemNode = Node3D.new()

	gemNode.name = str(objData.get("name", "Gem"))
	var pos: Vector3 = getVector3FromDict(objData, "position")
	gemNode.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	gemNode.rotation = unityToGodotRotation(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	gemNode.scale = unityToGodotScale(scale)

	return gemNode


func _createCrownInstance(objData: Dictionary) -> Node:
	var crownScene: PackedScene = load(CROWN_TEMPLATE) as PackedScene
	var crownNode: Node3D
	if crownScene:
		crownNode = crownScene.instantiate() as Node3D
	else:
		crownNode = Node3D.new()

	crownNode.name = str(objData.get("name", "CrownCheckpoint"))
	var pos: Vector3 = getVector3FromDict(objData, "position")
	crownNode.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	crownNode.rotation = unityToGodotRotation(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	crownNode.scale = unityToGodotScale(scale)

	return crownNode


func _createMeshObject(objData: Dictionary, meshes: Array, materials: Array) -> Node:
	var meshNode: MeshInstance3D = MeshInstance3D.new()
	meshNode.name = str(objData.get("name", "Mesh"))
	var pos: Vector3 = getVector3FromDict(objData, "position")
	meshNode.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	meshNode.rotation = unityToGodotRotation(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	meshNode.scale = unityToGodotScale(scale)

	var mesh: Mesh = _loadMeshFromJson(objData, meshes)
	if mesh == null:
		mesh = _createBuiltinMesh(objData)
	meshNode.mesh = mesh

	var material: Material = _createStandardMaterial(objData, materials)
	if material:
		meshNode.material_override = material

	return meshNode


func _createTriggerObject(objData: Dictionary) -> Node:
	var triggerScene: PackedScene = load(TRIGGER_TEMPLATE) as PackedScene
	var triggerRoot: Area3D
	if triggerScene:
		triggerRoot = triggerScene.instantiate() as Area3D
	else:
		triggerRoot = Area3D.new()
		triggerRoot.set_script(preload("res://#Template/[Scripts]/Trigger/BaseTrigger.gd"))
		var col: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		col.shape = box
		triggerRoot.add_child(col)

	var pos: Vector3 = getVector3FromDict(objData, "position")
	triggerRoot.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	triggerRoot.rotation = unityToGodotRotationNoFlip(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	triggerRoot.scale = unityToGodotScale(scale)

	var customData: Variant = JSON.parse_string(str(objData.get("customData", "{}")))
	var custom: Dictionary = customData as Dictionary if customData is Dictionary else {}
	var triggerType: int = toIntSafe(custom.get("type", 0))

	match triggerType:
		0: # CameraTrigger
			triggerRoot.name = "CameraTrigger"
			var camComp: Node = CameraTriggerClass.new()
			camComp.name = "CameraTrigger"
			if custom.has("duration"):
				camComp.set("duration", float(custom.get("duration", 2.0)))
			if custom.has("fov"):
				camComp.set("fieldOfView", float(custom.get("fov", 80.0)))
			triggerRoot.add_child(camComp)
		1: # JumpTrigger
			triggerRoot.name = "JumpTrigger"
			var jumpComp: Node = JumpClass.new()
			jumpComp.name = "Jump"
			if custom.has("power"):
				jumpComp.set("power", float(custom.get("power", 500.0)))
			if custom.has("changeDirection"):
				jumpComp.set("changeDirection", bool(custom.get("changeDirection", false)))
			triggerRoot.add_child(jumpComp)
		2: # CrownTrigger -> 建议替换为 CrownCheckPoint
			return _createCrownInstance(objData)
		3: # DeathTrigger
			triggerRoot.name = "DeathTrigger"
			var killComp: Node = KillPlayerClass.new()
			killComp.name = "KillPlayer"
			killComp.set("reason", 1) # Drowned or Hit
			triggerRoot.add_child(killComp)
		_:
			triggerRoot.name = str(objData.get("name", "Trigger"))

	return triggerRoot


func _createPointLightObject(objData: Dictionary) -> Node:
	var customData: Variant = JSON.parse_string(str(objData.get("customData", "{}")))
	var custom: Dictionary = customData as Dictionary if customData is Dictionary else {}
	var light: OmniLight3D = OmniLight3D.new()
	light.name = str(objData.get("name", "PointLight"))
	var pos: Vector3 = getVector3FromDict(objData, "position")
	light.position = unityToGodotPosition(pos)
	light.omni_range = float(custom.get("range", 10.0))
	var colorData: Variant = custom.get("color", null)
	if colorData is Dictionary:
		var c: Dictionary = colorData as Dictionary
		light.light_color = Color(float(c.get("r", 1.0)), float(c.get("g", 1.0)), float(c.get("b", 1.0)), float(c.get("a", 1.0)))
	light.light_energy = float(custom.get("intensity", 1.0))
	return light


func _createDirectionalLightObject(objData: Dictionary) -> Node:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = str(objData.get("name", "DirectionalLight"))
	var pos: Vector3 = getVector3FromDict(objData, "position", Vector3(0, 10, 0))
	light.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles", Vector3(50, 135, 0))
	light.rotation = unityToGodotRotation(rot)
	var customData: Variant = JSON.parse_string(str(objData.get("customData", "{}")))
	if customData is Dictionary:
		var custom: Dictionary = customData as Dictionary
		var colorData: Variant = custom.get("color", null)
		if colorData is Dictionary:
			var c: Dictionary = colorData as Dictionary
			light.light_color = Color(float(c.get("r", 1.0)), float(c.get("g", 1.0)), float(c.get("b", 1.0)), float(c.get("a", 1.0)))
		light.light_energy = float(custom.get("intensity", 1.0))
	return light


# ==================== 网格与材质加载 ====================

func _parseCustom(objData: Dictionary) -> Dictionary:
	var customDataStr: Variant = objData.get("customData", "{}")
	if customDataStr is Dictionary:
		return customDataStr as Dictionary
	if customDataStr is String and customDataStr != "":
		var parsed: Variant = JSON.parse_string(customDataStr as String)
		if parsed is Dictionary:
			return parsed as Dictionary
	return {}


func _getMeshDataDict(custom: Dictionary) -> Dictionary:
	var data: Variant = custom.get("data", {})
	if data is Dictionary:
		return data as Dictionary
	var meshData: Variant = custom.get("meshData", {})
	if meshData is Dictionary:
		return meshData as Dictionary
	return custom


func _getMaterialIds(custom: Dictionary) -> Array:
	var meshDataDict: Dictionary = _getMeshDataDict(custom)
	if meshDataDict.has("materialIds") and meshDataDict.get("materialIds") is Array:
		return meshDataDict.get("materialIds") as Array
	if custom.has("materialIds") and custom.get("materialIds") is Array:
		return custom.get("materialIds") as Array
	return []


func _loadMeshFromJson(objData: Dictionary, meshes: Array) -> Mesh:
	var custom: Dictionary = _parseCustom(objData)
	var meshDataDict: Dictionary = _getMeshDataDict(custom)
	var objName: String = str(objData.get("name", "unnamed"))

	var meshId: int = -1
	if meshDataDict.has("meshId"):
		meshId = toIntSafe(meshDataDict.get("meshId", -1))
	elif custom.has("meshId"):
		meshId = toIntSafe(custom.get("meshId", -1))

	if meshId != -1 and meshId >= 0 and meshId < meshes.size():
		var rawInfo: Variant = meshes[meshId]
		if rawInfo is Dictionary:
			var meshInfo: Dictionary = rawInfo as Dictionary
			var fileName: String = str(meshInfo.get("fileName", ""))
			if fileName != "":
				var mesh: Mesh = _loadMeshByFilename(fileName)
				if mesh != null:
					return mesh

	var namedMesh: Mesh = _loadMeshByName(objName)
	if namedMesh != null:
		return namedMesh

	for rawInfo: Variant in meshes:
		if rawInfo is Dictionary:
			var meshInfo: Dictionary = rawInfo as Dictionary
			var fileName: String = str(meshInfo.get("fileName", ""))
			var baseName: String = fileName.get_basename()
			if baseName != "" and objName.to_lower().contains(baseName.to_lower()):
				var m: Mesh = _loadMeshByFilename(fileName)
				if m != null:
					return m

	return null


func _loadMeshByFilename(fileName: String) -> Mesh:
	if loadedMeshes.has(fileName):
		return loadedMeshes[fileName] as Mesh

	for basePath: String in MODEL_SEARCH_PATHS + extraSearchPaths:
		var fullPath: String = basePath + fileName
		if ResourceLoader.exists(fullPath):
			var resource: Resource = load(fullPath)
			if resource is Mesh:
				loadedMeshes[fileName] = resource
				return resource as Mesh

	var extensions: Array[String] = [".obj", ".glb", ".gltf", ".fbx"]
	for ext: String in extensions:
		if not fileName.ends_with(ext):
			for basePath: String in MODEL_SEARCH_PATHS + extraSearchPaths:
				var fullPath: String = basePath + fileName + ext
				if ResourceLoader.exists(fullPath):
					var resource: Resource = load(fullPath)
					if resource is Mesh:
						loadedMeshes[fileName] = resource
						return resource as Mesh

	return null


func _loadMeshByName(name: String) -> Mesh:
	for basePath: String in MODEL_SEARCH_PATHS + extraSearchPaths:
		var fullPath: String = basePath + name
		if ResourceLoader.exists(fullPath):
			var resource: Resource = load(fullPath)
			if resource is Mesh:
				return resource as Mesh

	var extensions: Array[String] = [".obj", ".glb", ".gltf"]
	for ext: String in extensions:
		for basePath: String in MODEL_SEARCH_PATHS + extraSearchPaths:
			var fullPath: String = basePath + name + ext
			if ResourceLoader.exists(fullPath):
				var resource: Resource = load(fullPath)
				if resource is Mesh:
					return resource as Mesh

	return null


func _createBuiltinMesh(objData: Dictionary) -> Mesh:
	var name: String = str(objData.get("name", "")).to_lower()
	if name.contains("plane") or name.contains("ground") or name.contains("floor"):
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(1, 1)
		return plane
	elif name.contains("sphere") or name.contains("ball"):
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.5
		return sphere
	elif name.contains("cylinder") or name.contains("pillar"):
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.5
		cylinder.height = 1.0
		return cylinder
	else:
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(1, 1, 1)
		return box


func _createStandardMaterial(objData: Dictionary, materials: Array) -> StandardMaterial3D:
	var name: String = str(objData.get("name", "")).to_lower()
	var custom: Dictionary = _parseCustom(objData)

	var materialIds: Array = _getMaterialIds(custom)
	var baseColor: Color = _getDefaultColor(name)

	if not materialIds.is_empty():
		var matId: int = toIntSafe(materialIds[0])
		if matId >= 0 and matId < materials.size():
			var rawMat: Variant = materials[matId]
			if rawMat is Dictionary:
				var matData: Dictionary = rawMat as Dictionary
				var colorData: Variant = matData.get("color", null)
				if colorData is Dictionary:
					var c: Dictionary = colorData as Dictionary
					baseColor = Color(float(c.get("r", baseColor.r)), float(c.get("g", baseColor.g)), float(c.get("b", baseColor.b)), float(c.get("a", baseColor.a)))

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = baseColor
	material.roughness = 0.5
	material.metallic = 0.0
	return material


func _getDefaultColor(name: String) -> Color:
	var lower: String = name.to_lower()
	if lower.contains("ground") or lower.contains("floor"):
		return Color(0.2, 0.25, 0.3)
	elif lower.contains("wall"):
		return Color(0.3, 0.3, 0.35)
	elif lower.contains("tree") or lower.contains("leaf") or lower.contains("树叶"):
		return Color(0.1, 0.5, 0.1)
	elif lower.contains("water") or lower.contains("水面"):
		return Color(0.0, 0.3, 0.5)
	elif lower.contains("light"):
		return Color(1.0, 0.9, 0.5)
	elif lower.contains("cube") or lower.contains("box"):
		return Color(0.5, 0.6, 0.7)
	elif lower.contains("road"):
		return Color(0.4, 0.4, 0.45)
	else:
		return Color(0.5, 0.5, 0.5)


func _hasMesh(node: Node) -> bool:
	if node is MeshInstance3D:
		return true
	for child: Node in node.get_children():
		if _hasMesh(child):
			return true
	return false


func _addDefaultGround(parent: Node) -> void:
	var groundScene: PackedScene = load(GROUND_TEMPLATE) as PackedScene
	if groundScene:
		var ground: Node3D = groundScene.instantiate() as Node3D
		ground.name = "Ground"
		ground.transform = Transform3D(Basis.from_scale(Vector3(100.0, 1.0, 100.0)), Vector3(0.0, -1.0, 0.0))
		parent.add_child(ground)
