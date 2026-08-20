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
const SpeedClass: Script = preload("res://#Template/[Scripts]/Trigger/Speed.gd")
const GravityTriggerClass: Script = preload("res://#Template/[Scripts]/Trigger/GravityTrigger.gd")
const SetFogClass: Script = preload("res://#Template/[Scripts]/Trigger/SetFog.gd")
const CameraShakeClass: Script = preload("res://#Template/[Scripts]/CameraScripts/CameraShakeTrigger.gd")

const MODEL_SEARCH_PATHS: Array[String] = [
	"res://#Template/[Resources]/Models/",
	"res://#Template/[Resources]/",
	"res://Resources/",
	"res://",
]

var loadedMeshes: Dictionary = {}
var loadedTextures: Dictionary = {}
var extraSearchPaths: Array[String] = []


func buildScene(data: Dictionary, levelDataResource: LevelData = null) -> Node3D:
	loadedMeshes.clear()
	loadedTextures.clear()

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
	var sprites: Array = data.get("sprites", [])
	var objects: Array = data.get("objects", [])

	var nodeMap: Dictionary = {}
	var rootNodes: Array[Node] = []

	# 1. 实例化所有对象
	for rawObj: Variant in objects:
		if not rawObj is Dictionary:
			continue
		var objData: Dictionary = rawObj as Dictionary
		var objId: int = toIntSafe(objData.get("id", -1))
		var node: Node = _createSingleObject(objData, meshes, materials, sprites)
		if node:
			nodeMap[objId] = node

	# 2. 建立父子关系
	for rawObj: Variant in objects:
		if not rawObj is Dictionary:
			continue
		var objData: Dictionary = rawObj as Dictionary
		var objId: int = toIntSafe(objData.get("id", -1))
		var parentId: int = toIntSafe(objData.get("parentId", -1))

		if nodeMap.has(objId):
			var node: Node = nodeMap[objId]
			if parentId != -1 and parentId != 0 and nodeMap.has(parentId):
				var parentNode: Node = nodeMap[parentId]
				parentNode.add_child(node)
			else:
				# parentId 为 -1, 0 或找不到父节点的，作为根节点挂在 Scene_001 下
				rootNodes.append(node)

	for rootNode: Node in rootNodes:
		parent.add_child(rootNode)


func _createSingleObject(objData: Dictionary, meshes: Array, materials: Array, sprites: Array = []) -> Node:
	var rawType: Variant = objData.get("type", 1)
	var type: int = toIntSafe(rawType)
	var objName: String = str(objData.get("name", "unnamed")).to_lower()

	var node: Node = null
	match type:
		0:
			node = _createGroupObject(objData)
		1, 6, 7, 8:
			if objName.contains("cube") or objName.contains("box"):
				node = _createObstacleBox(objData, materials, sprites)
			elif objName.contains("gem") or objName.contains("diamond"):
				node = _createGemInstance(objData)
			elif objName.contains("crown"):
				node = _createCrownInstance(objData)
			else:
				node = _createMeshObject(objData, meshes, materials, sprites)
		2:
			node = _createGroupObject(objData)
		3:
			node = _createDirectionalLightObject(objData)
		4:
			node = _createTriggerObject(objData)
		5, 9, 11:
			node = _createRoadObject(objData, materials, sprites)
		_:
			node = _createGroupObject(objData)

	# 处理 visibility 属性：
	# ARPhros 导出端的 visibility 定义（反人类设计）：
	# 0: 正常物体 / 初始激活可见
	# 1: 真正可见的关卡主场景容器（如 场景（总）、场景 1）
	# 2: 初始隐藏的后续关卡场景（如 路线、场景 2、场景 7 等，由 VisibilityTrigger 动态激活）
	# 之前把 1 当成了隐藏，导致 场景（总）/场景 1 顶级容器直接 visible=false，全场景变黑！
	# 正确逻辑：只有当 visibility == 2 时才是初始隐藏（待触发器激活）
	if node is Node3D:
		var vis: int = toIntSafe(objData.get("visibility", 0))
		if vis == 2:
			(node as Node3D).visible = false
		else:
			(node as Node3D).visible = true

	return node


# ==================== 具体物体类型 ====================

func _createGroupObject(objData: Dictionary) -> Node3D:
	var groupNode: Node3D = Node3D.new()
	var objId: int = toIntSafe(objData.get("id", 0))
	groupNode.name = "%s_%d" % [str(objData.get("name", "Group")), objId]
	var pos: Vector3 = getVector3FromDict(objData, "position")
	groupNode.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	groupNode.rotation = unityToGodotRotation(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	groupNode.scale = unityToGodotScale(scale)
	return groupNode

func _createRoadObject(objData: Dictionary, materials: Array, sprites: Array = []) -> Node:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.collision_layer = 2
	sb.collision_mask = 0

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.margin = 0.001
	col.shape = shape
	sb.add_child(col)

	var meshInst: MeshInstance3D = MeshInstance3D.new()
	meshInst.mesh = BoxMesh.new()
	sb.add_child(meshInst)

	var roadNode: Node3D = sb

	var objId: int = toIntSafe(objData.get("id", 0))
	roadNode.name = "%s_%d" % [str(objData.get("name", "Road")), objId]
	var pos: Vector3 = getVector3FromDict(objData, "position")
	roadNode.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	roadNode.rotation = unityToGodotRotation(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	roadNode.scale = unityToGodotScale(scale)

	var mat: Material = _createStandardMaterial(objData, materials, sprites)
	if mat:
		meshInst.material_override = mat

	return roadNode


func _createObstacleBox(objData: Dictionary, materials: Array, sprites: Array = []) -> Node:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.collision_layer = 4
	sb.collision_mask = 0

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.margin = 0.001
	col.shape = shape
	sb.add_child(col)

	var meshInst: MeshInstance3D = MeshInstance3D.new()
	meshInst.mesh = BoxMesh.new()
	sb.add_child(meshInst)

	var obsNode: Node3D = sb

	var objId: int = toIntSafe(objData.get("id", 0))
	obsNode.name = "%s_%d" % [str(objData.get("name", "Box")), objId]
	var pos: Vector3 = getVector3FromDict(objData, "position")
	obsNode.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	obsNode.rotation = unityToGodotRotation(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	obsNode.scale = unityToGodotScale(scale)

	var mat: Material = _createStandardMaterial(objData, materials, sprites)
	if mat:
		meshInst.material_override = mat

	return obsNode


func _createGemInstance(objData: Dictionary) -> Node:
	var gemScene: PackedScene = load(GEM_TEMPLATE) as PackedScene
	var gemNode: Node3D
	if gemScene:
		gemNode = gemScene.instantiate() as Node3D
	else:
		gemNode = Node3D.new()

	var objId: int = toIntSafe(objData.get("id", 0))
	gemNode.name = "%s_%d" % [str(objData.get("name", "Gem")), objId]
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

	var objId: int = toIntSafe(objData.get("id", 0))
	crownNode.name = "%s_%d" % [str(objData.get("name", "CrownCheckpoint")), objId]
	var pos: Vector3 = getVector3FromDict(objData, "position")
	crownNode.position = unityToGodotPosition(pos)
	# 忽略 arproj 中的 scale 和 rotation，仅复制 position
	return crownNode


func _createMeshObject(objData: Dictionary, meshes: Array, materials: Array, sprites: Array = []) -> Node:
	var meshNode: MeshInstance3D = MeshInstance3D.new()
	var objId: int = toIntSafe(objData.get("id", 0))
	meshNode.name = "%s_%d" % [str(objData.get("name", "Mesh")), objId]
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

	var material: Material = _createStandardMaterial(objData, materials, sprites)
	if material:
		meshNode.material_override = material

	return meshNode


func _createTriggerObject(objData: Dictionary) -> Node:
	var triggerRoot: Area3D = Area3D.new()
	triggerRoot.set_script(preload("res://#Template/[Scripts]/Trigger/BaseTrigger.gd"))

	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	col.shape = box
	triggerRoot.add_child(col)

	var objId: int = toIntSafe(objData.get("id", 0))
	var pos: Vector3 = getVector3FromDict(objData, "position")
	triggerRoot.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	triggerRoot.rotation = unityToGodotRotationNoFlip(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	triggerRoot.scale = unityToGodotScale(scale)

	var customData: Variant = JSON.parse_string(str(objData.get("customData", "{}")))
	var custom: Dictionary = customData as Dictionary if customData is Dictionary else {}
	var triggerType: int = toIntSafe(custom.get("type", 0))

	var dataStr: String = str(custom.get("data", ""))

	match triggerType:
		0: # CameraTrigger (ARPhros CameraTrigger)
			triggerRoot.name = "%s_%d" % ["CameraTrigger", objId]
			var camComp: Node = CameraTriggerClass.new()
			camComp.name = "CameraTrigger"
			# 数据格式示例: "True|15, 45, 0|True|0, 3, 0|True|25|True|5000|linear|0|True|True|0"
			var parts: PackedStringArray = dataStr.split("|")
			if parts.size() >= 7:
				var fovVal: float = float(parts[5]) if parts[5].is_valid_float() else 80.0
				camComp.set("fieldOfView", fovVal)
				if parts.size() >= 8:
					var smoothFactor: float = float(parts[7]) if parts[7].is_valid_float() else 5000.0
					camComp.set("duration", 2.0 if smoothFactor <= 0 else clamp(5000.0 / smoothFactor, 0.1, 5.0))
			triggerRoot.add_child(camComp)

		1: # JumpTrigger
			triggerRoot.name = "%s_%d" % ["JumpTrigger", objId]
			var jumpComp: Node = JumpClass.new()
			jumpComp.name = "Jump"
			# 数据格式: "0, 660, 0|False|True|True"
			var parts: PackedStringArray = dataStr.split("|")
			if parts.size() > 0:
				var powerCoords: PackedStringArray = parts[0].split(",")
				if powerCoords.size() >= 2:
					var py: float = float(powerCoords[1].strip_edges())
					jumpComp.set("power", py if py > 0 else 500.0)
				else:
					jumpComp.set("power", float(parts[0]) if parts[0].is_valid_float() else 500.0)
			triggerRoot.add_child(jumpComp)

		2: # SpeedTrigger (ARPhros type 2)
			triggerRoot.name = "%s_%d" % ["SpeedTrigger", objId]
			var speedComp: Node = SpeedClass.new()
			speedComp.name = "Speed"
			var spd: float = float(dataStr.strip_edges()) if dataStr.strip_edges().is_valid_float() else 12.0
			if spd > 0.0:
				speedComp.set("speed", spd)
			triggerRoot.add_child(speedComp)

		3: # DeathTrigger
			triggerRoot.name = "%s_%d" % ["DeathTrigger", objId]
			var killComp: Node = KillPlayerClass.new()
			killComp.name = "KillPlayer"
			killComp.set("reason", 1) # Drowned / Hit
			triggerRoot.add_child(killComp)

		4: # ShakeCameraTrigger
			triggerRoot.name = "%s_%d" % ["CameraShakeTrigger", objId]
			var shakeComp: Node = CameraShakeClass.new()
			shakeComp.name = "CameraShakeTrigger"
			triggerRoot.add_child(shakeComp)

		13: # FovTrigger
			triggerRoot.name = "%s_%d" % ["FovTrigger", objId]
			var camComp: Node = CameraTriggerClass.new()
			camComp.name = "CameraTrigger"
			var parts: PackedStringArray = dataStr.split("|")
			if parts.size() >= 1:
				camComp.set("fieldOfView", float(parts[0]) if parts[0].is_valid_float() else 80.0)
			if parts.size() >= 2:
				camComp.set("duration", float(parts[1]) if parts[1].is_valid_float() else 1.0)
			triggerRoot.add_child(camComp)

		22: # FogTrigger
			triggerRoot.name = "%s_%d" % ["FogTrigger", objId]
			var fogComp: Node = SetFogClass.new()
			fogComp.name = "SetFog"
			triggerRoot.add_child(fogComp)

		24: # GravityTrigger
			triggerRoot.name = "%s_%d" % ["GravityTrigger", objId]
			var gravComp: Node = GravityTriggerClass.new()
			gravComp.name = "GravityTrigger"
			# 数据格式: "0, -50, 0"
			var gravCoords: PackedStringArray = dataStr.split(",")
			if gravCoords.size() >= 3:
				var gx: float = float(gravCoords[0].strip_edges())
				var gy: float = float(gravCoords[1].strip_edges())
				var gz: float = float(gravCoords[2].strip_edges())
				gravComp.set("gravity", Vector3(gx, gy, gz))
			triggerRoot.add_child(gravComp)

		_:
			triggerRoot.name = "%s_%d" % [str(objData.get("name", "Trigger")), objId]

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

	# 1. 优先按 meshes 数组中元素自身的 id 字段匹配
	if meshId != -1:
		for rawInfo: Variant in meshes:
			if rawInfo is Dictionary:
				var meshInfo: Dictionary = rawInfo as Dictionary
				if toIntSafe(meshInfo.get("id", -1)) == meshId:
					var fileName: String = str(meshInfo.get("fileName", ""))
					if fileName != "":
						var mesh: Mesh = _loadMeshByFilename(fileName)
						if mesh != null:
							return mesh

		# 兼容兜底：按下标索引匹配
		if meshId >= 0 and meshId < meshes.size():
			var rawInfo: Variant = meshes[meshId]
			if rawInfo is Dictionary:
				var meshInfo: Dictionary = rawInfo as Dictionary
				var fileName: String = str(meshInfo.get("fileName", ""))
				if fileName != "":
					var mesh: Mesh = _loadMeshByFilename(fileName)
					if mesh != null:
						return mesh

	# 2. 按物体名称匹配
	var namedMesh: Mesh = _loadMeshByName(objName)
	if namedMesh != null:
		return namedMesh

	# 3. 按 meshes 中的文件名模糊匹配物体名称
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


func _createStandardMaterial(objData: Dictionary, materials: Array, sprites: Array = []) -> StandardMaterial3D:
	var name: String = str(objData.get("name", "")).to_lower()
	var custom: Dictionary = _parseCustom(objData)

	var materialIds: Array = _getMaterialIds(custom)
	var baseColor: Color = _getDefaultColor(name)
	var spriteId: int = -1

	if not materialIds.is_empty():
		var matId: int = toIntSafe(materialIds[0])
		# 优先按 materials 数组中元素自身的 id 字段匹配
		var foundMat: Dictionary = {}
		for rawMat: Variant in materials:
			if rawMat is Dictionary:
				var m: Dictionary = rawMat as Dictionary
				if toIntSafe(m.get("id", -1)) == matId:
					foundMat = m
					break
		# 兼容兜底：按下标匹配
		if foundMat.is_empty() and matId >= 0 and matId < materials.size():
			var rawMat: Variant = materials[matId]
			if rawMat is Dictionary:
				foundMat = rawMat as Dictionary

		if not foundMat.is_empty():
			var colorData: Variant = foundMat.get("color", null)
			if colorData is Dictionary:
				var c: Dictionary = colorData as Dictionary
				baseColor = Color(float(c.get("r", baseColor.r)), float(c.get("g", baseColor.g)), float(c.get("b", baseColor.b)), float(c.get("a", baseColor.a)))
			spriteId = toIntSafe(foundMat.get("spriteId", -1))

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = baseColor
	material.roughness = 0.5
	material.metallic = 0.0

	# 如果材质绑定了纹理 (spriteId)
	if spriteId != -1 and not sprites.is_empty():
		var tex: Texture2D = _loadTextureBySpriteId(spriteId, sprites)
		if tex:
			material.albedo_texture = tex

	return material


func _loadTextureBySpriteId(spriteId: int, sprites: Array) -> Texture2D:
	var fileName: String = ""
	for rawSprite: Variant in sprites:
		if rawSprite is Dictionary:
			var s: Dictionary = rawSprite as Dictionary
			if toIntSafe(s.get("id", -1)) == spriteId:
				fileName = str(s.get("fileName", ""))
				break
	if fileName.is_empty() and spriteId >= 0 and spriteId < sprites.size():
		var rawSprite: Variant = sprites[spriteId]
		if rawSprite is Dictionary:
			fileName = str((rawSprite as Dictionary).get("fileName", ""))

	if fileName.is_empty():
		return null

	if loadedTextures.has(fileName):
		return loadedTextures[fileName] as Texture2D

	for basePath: String in MODEL_SEARCH_PATHS + extraSearchPaths:
		var fullPath: String = basePath + fileName
		if ResourceLoader.exists(fullPath):
			var res: Resource = load(fullPath)
			if res is Texture2D:
				loadedTextures[fileName] = res
				return res as Texture2D

	return null


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
