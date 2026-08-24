@tool
extends Node
class_name LevelLoader

const MIN_SCALE: float = 0.001

## 对象分片构建的单帧时间预算（毫秒）：超时即让出主线程一帧，避免大关卡导入阻塞编辑器
const FRAME_BUDGET_MS: int = 20

## 左右镜像总开关：导入关卡整体沿 X 轴镜像（与原版游戏画面方向对齐）。
## 方案：Scene_001 作为唯一反射载体（负 x 缩放），内部物体本地变换保持原值；
## 载体外的实体（玩家/相机/平行光）单独做位置取反与旋转共轭。
const MIRROR_X: bool = true

const PLAYER_TEMPLATE: String = "res://#Template/Player.tscn"
const CAMERA_TEMPLATE: String = "res://#Template/CameraRoot.tscn"
const TRIGGER_TEMPLATE: String = "res://#Template/Trigger.tscn"
const GEM_TEMPLATE: String = "res://#Template/Gem.tscn"
const CROWN_TEMPLATE: String = "res://#Template/CrownCheckPoint.tscn"
const LEVEL_UI_TEMPLATE: String = "res://#Template/[Resources]/LevelUI.tscn"
const GROUND_TEMPLATE: String = "res://#Template/Ground.tscn"
const OBSTACLE_TEMPLATE: String = "res://#Template/Obstacle.tscn"

const SingleActiveClass: Script = preload("res://#Template/[Scripts]/Settings/SingleActive.gd")
const FogSettingsClass: Script = preload("res://#Template/[Scripts]/Settings/FogSettings.gd")
const AnimatableClass: Script = preload("res://addons/dancing_line_importer/scripts/animatable.gd")

## 触发器映射表：组件脚本、构造描述、解析规格与动画 ease 映射集中于此
## （其余触发器组件的 preload 已迁入该表，见 trigger_type_map.gd）
const TriggerTypeMapClass: Script = preload("res://addons/dancing_line_importer/scripts/trigger_type_map.gd")

const MODEL_SEARCH_PATHS: Array[String] = [
	"res://#Template/[Resources]/Models/",
	"res://#Template/[Resources]/",
	"res://Resources/",
	"res://",
]

var loadedMeshes: Dictionary = {}
var loadedTextures: Dictionary = {}
var extraSearchPaths: Array[String] = []

## type 5/6/7 待链接动画触发器：键=触发器根节点，值结构见 _buildAnimatorTrigger
var pendingAnimatorTriggers: Dictionary = {}

## 发生内部覆写的子场景实例（CameraRoot），保存前由 dock 调用
## markEditableInstances 统一标记 editable
var _overrideInstances: Array[Node] = []

## 从 Ground.tscn 复制的单位盒网格缓存（已剥离模板材质引用）
var _groundTemplateMeshCache: Mesh = null
var _groundPartsLoaded: bool = false


## progressCallback：可选进度回调，签名 (builtCount: int, totalCount: int)，在对象分片构建时回调。
## 本函数为协程：内部按帧时间预算分片并 await 让出主线程（保持编辑器可交互），调用方必须 await。
func buildScene(data: Dictionary, levelDataResource: LevelData = null, progressCallback: Callable = Callable()) -> Node3D:
	loadedMeshes.clear()
	loadedTextures.clear()
	pendingAnimatorTriggers.clear()
	_overrideInstances.clear()

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

	if MIRROR_X:
		# 左右镜像唯一载体：全部关卡内容经此负 x 缩放，合成世界变换时自动取反。
		# 子节点本地 TRS 保持 arproj 原值——动画器烘焙（读实际本地值）与
		# meta "arprojScale" 语义均不受影响；网格子节点的常量翻转因子 (-1,1,1)
		# 叠乘载体后恰为整体镜像。载体必须是纯容器：物理体不支持负缩放祖先，
		# 故不可上移到 LevelHolder（其下含 Player/Camera 等实体）。
		scene001.scale = Vector3(-1, 1, 1)

	await _createObjects(scene001, data, progressCallback)

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
	# 恒等映射：本项目位置为恒等转换（unityToGodotPosition 直通），
	# 旋转数值同样直写 Godot YXZ 欧拉（四元数代数与手性无关）。
	# 实证：The Piano 关非对称部件（piece 45°）只有不取反才方向正确；
	# 此前的 y 取反在 ±45 成对的对称道路内容中从未暴露错误。
	# 注意：仅限 Scene_001 内物体使用（其镜像由载体缩放统一完成）；
	# 载体外的实体与相机数据请用 mirrorRotationRad / mirrorPosition。
	return Vector3(degToRad(unityDeg.x), degToRad(unityDeg.y), degToRad(unityDeg.z))


func unityToGodotRotationNoFlip(unityDeg: Vector3) -> Vector3:
	return Vector3(degToRad(unityDeg.x), degToRad(unityDeg.y), degToRad(unityDeg.z))


## 左右镜像位置：X 分量取反（MIRROR_X=false 时原样返回）
func mirrorPosition(p: Vector3) -> Vector3:
	return Vector3(-p.x if MIRROR_X else p.x, p.y, p.z)


## 左右镜像姿态：对 Godot YXZ 基做 YZ 镜像面反射 B' = M·B·M（M=diag(-1,1,1)），
## 与 mirrorPosition 的 X 取反严格一致。入参 arproj 欧拉度数（恒等映射为 Godot YXZ），
## 返回 Godot YXZ 弧度欧拉。用于 Scene_001 载体覆盖不到的实体
## （玩家/相机/平行光/相机触发器数据）。
func mirrorRotationRad(unityDeg: Vector3) -> Vector3:
	var R := Basis.from_euler(Vector3(deg_to_rad(unityDeg.x), deg_to_rad(unityDeg.y), deg_to_rad(unityDeg.z)))
	if MIRROR_X:
		var M := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
		R = M * R * M
	return R.get_euler()


# ==================== 基础物体创建 ====================

func _createLight(parent: Node, data: Dictionary) -> DirectionalLight3D:
	var lightData: Dictionary = data.get("directionalLight", {})
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	var pos: Vector3 = getVector3FromDict(lightData, "position", Vector3(0, 10, 0))
	light.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(lightData, "eulerAngles", Vector3(50, 135, 0))
	# 平行光在 Scene_001 载体之外，需随场景镜像（旋转共轭 M·R·M）。
	# 其照射方向沿自身 -Z；相机 Rotator 经 Camera3D 内置 Ry(180) 后视线落在 +Z，
	# 故平行光额外绕 Y 轴 180° 使 -Z 指向镜像后朝下、照射地面。
	var lightRot := Basis.from_euler(mirrorRotationRad(rot))
	if MIRROR_X:
		lightRot = lightRot * Basis.from_euler(Vector3(0.0, PI, 0.0))
	light.rotation = lightRot.get_euler()
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

	# 相机跟随目标设置
	var follower: CameraFollower = cameraRoot as CameraFollower
	if follower:
		follower.target = NodePath("../Player")

	# 获取相机节点 (CameraRoot/Rotator/Scale/Camera3D)
	var camNode: Camera3D = cameraRoot.get_node_or_null("Rotator/Scale/Camera3D") as Camera3D
	if not camNode:
		camNode = cameraRoot.get_node_or_null("Camera3D") as Camera3D

	var envData: Dictionary = data.get("environment", {})
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

	# 读取 Main Camera 配置
	var camData: Dictionary = data.get("mainCamera", {})

	var customData: Variant = JSON.parse_string(str(camData.get("customData", "{}")))
	if customData is Dictionary:
		var custom: Dictionary = customData as Dictionary

		# 跟随相机枢轴 = 玩家出生点 + pivotOffset。
		# mainCamera.position 是原版编辑器的预览摆放，运行时不使用——
		# 运行时视角由 targetRotation / targetDistance / pivotOffset 驱动
		# （此前把 position 赋给枢轴，导致相机叠上后退距离后压在玩家身上）。
		var pivot: Dictionary = custom.get("pivotOffset", {})
		var pivotVec: Vector3 = Vector3(float(pivot.get("x", 0.0)), float(pivot.get("y", 0.0)), float(pivot.get("z", 0.0)))
		var playerData: Dictionary = data.get("player", {})
		var playerPos: Vector3 = getVector3FromDict(playerData, "position", Vector3.ZERO)
		# 相机在载体之外：枢轴与注视点随镜像世界取反 x
		cameraRoot.position = mirrorPosition(playerPos + pivotVec)

		# Rotator 旋转（targetRotation）与注视点偏移（pivotOffset，
		# 与运行时 CameraTrigger.offset 同一载体：offset 补间的就是 rotator.position）
		var rotator: Node3D = cameraRoot.get_node_or_null("Rotator") as Node3D
		var rot: Dictionary = custom.get("targetRotation", {})
		var rotEuler: Vector3 = Vector3(float(rot.get("x", 45.0)), float(rot.get("y", 45.0)), float(rot.get("z", 0.0)))
		if rotator:
			rotator.rotation = mirrorRotationRad(rotEuler)
			rotator.position = mirrorPosition(pivotVec)
		else:
			cameraRoot.rotation = mirrorRotationRad(rotEuler)

		# 相机距离 targetDistance -> Camera3D Z 轴偏移
		var targetDist: float = float(custom.get("targetDistance", 25.0))
		if camNode:
			camNode.position = Vector3(0.0, 0.0, -targetDist)
			var fovVal: Variant = custom.get("fov", 80.0)
			camNode.fov = float(fovVal)

	# 对实例内部节点（相机距离/fov/environment、Rotator 位姿）有覆写，
	# 登记 editable：否则 pack 时这些参数会被静默丢弃，且树中看不到内部节点
	_overrideInstances.append(cameraRoot)

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
	player.position = mirrorPosition(pos)
	var rot: Vector3 = getVector3FromDict(playerData, "eulerAngles", Vector3(0, 90, 0))
	# 玩家在载体之外：出生位置取反 x，朝向做旋转共轭
	var mirroredRot: Vector3 = mirrorRotationRad(rot)
	player.rotation = mirroredRot
	# 关键：运行时朝向由 firstDirection 驱动（_ready 中 rotation_degrees = currentDirection，
	# LevelManager.mainLineTransform 亦由 firstDirection 构建），仅改场景节点 rotation 无效，
	# 必须同步写入镜像后的 firstDirection（弧度转回度数）
	player.firstDirection = Vector3(rad_to_deg(mirroredRot.x), rad_to_deg(mirroredRot.y), rad_to_deg(mirroredRot.z))

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

func _createObjects(parent: Node, data: Dictionary, progressCallback: Callable = Callable()) -> void:
	var meshes: Array = data.get("meshes", [])
	var materials: Array = data.get("materials", [])
	var sprites: Array = data.get("sprites", [])
	var objects: Array = data.get("objects", [])

	var nodeMap: Dictionary = {}
	var rootNodes: Array[Node] = []

	# 1. 实例化所有对象。节点创建必须留在主线程（Godot 场景 API 非线程安全），
	#    改用时间预算分片：单帧工作量超过 FRAME_BUDGET_MS 即让出编辑器一帧并回报进度
	var totalObjects: int = objects.size()
	var builtCount: int = 0
	var chunkStartMs: int = Time.get_ticks_msec()
	for rawObj: Variant in objects:
		if not rawObj is Dictionary:
			continue
		var objData: Dictionary = rawObj as Dictionary
		var objId: int = toIntSafe(objData.get("id", -1))
		var node: Node = _createSingleObject(objData, meshes, materials, sprites)
		if node:
			nodeMap[objId] = node
		builtCount += 1
		if Time.get_ticks_msec() - chunkStartMs >= FRAME_BUDGET_MS:
			if progressCallback.is_valid():
				progressCallback.call(builtCount, totalObjects)
			await _nextEditorFrame()
			chunkStartMs = Time.get_ticks_msec()

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
				_attachChildObject(parentNode, node)
			else:
				# parentId 为 -1, 0 或找不到父节点的，作为根节点挂在 Scene_001 下
				rootNodes.append(node)

	for rootNode: Node in rootNodes:
		parent.add_child(rootNode)

	# 3. 后处理：链接 Transform 触发器的动画器（此时 nodeMap 与父子关系均已就绪）
	_linkTriggerAnimators(nodeMap)


## 分片间让出主线程一帧；loader 已不在场景树中时取不到信号，退化为连续构建
func _nextEditorFrame() -> void:
	var tree := get_tree()
	if tree:
		await tree.process_frame


## 挂载子物体。Unity 中父级缩放必须传递给子树（子物体的局部偏移与尺寸都要被
## 父级缩放放大——如锤头挂在被拉伸成锤柄的圆柱下，偏距须乘 28.7 才落在柄端）；
## 但物理体（StaticBody3D/Area3D）不能携带缩放祖先（碰撞形状会被扭曲，
## 且不支持负缩放）。故带非单位缩放记录的物理父级，其【视觉】子物体改挂到
## 携带同款缩放（取绝对值，镜像件暂无此组合数据）的纯 Node3D 容器下恢复层级
## 语义；物理子物体仍直挂父级，保持现状。
func _attachChildObject(parentNode: Node, childNode: Node) -> void:
	var holder: Node = parentNode
	if parentNode is CollisionObject3D and not (childNode is CollisionObject3D):
		var parentScale: Vector3 = Vector3.ONE
		if parentNode is Node3D and (parentNode as Node3D).has_meta("arprojScale"):
			parentScale = (parentNode as Node3D).get_meta("arprojScale") as Vector3
		if not parentScale.is_equal_approx(Vector3.ONE):
			var container: Node3D = parentNode.get_node_or_null(NodePath("ScaledChildren")) as Node3D
			if container == null:
				container = Node3D.new()
				container.name = "ScaledChildren"
				container.scale = unityToGodotScale(parentScale)
				parentNode.add_child(container)
			holder = container
	holder.add_child(childNode)


func _createSingleObject(objData: Dictionary, meshes: Array, materials: Array, sprites: Array = []) -> Node:
	var rawType: Variant = objData.get("type", 1)
	var type: int = toIntSafe(rawType)
	var objName: String = str(objData.get("name", "unnamed")).to_lower()

	var node: Node = null
	match type:
		0: # Primitive（customData.type 为 Unity PrimitiveType）
			node = _createPrimitiveObject(objData, materials, sprites)
		1: # Model
			if objName.contains("cube") or objName.contains("box"):
				node = _createObstacleBox(objData, materials, sprites)
			elif objName.contains("gem") or objName.contains("diamond"):
				node = _createGemInstance(objData)
			elif objName.contains("crown"):
				node = _createCrownInstance(objData)
			else:
				node = _createMeshObject(objData, meshes, materials, sprites)
		2: # Sprite
			node = _createGroupObject(objData)
		3:
			node = _createDirectionalLightObject(objData)
		4:
			node = _createTriggerObject(objData)
		5: # Road
			node = _createRoadObject(objData, materials, sprites)
		6, 7, 8, 9, 11:
			# Particle / Player / MainCamera / Empty / Tail：
			# 单例或特殊对象，不应出现在 objects 表；按空容器导入以保留层级
			node = _createGroupObject(objData)
		10: # Text
			node = _createTextObject(objData)
		_:
			node = _createGroupObject(objData)

	# 处理 visibility 属性（VisibilityType: Shown=0 / Hidden=1 / Gone=2，游戏源码确认）：
	# 0 Shown: 正常可见物体
	# 1 Hidden: 自身不渲染（空气墙/空气地板/中国灯（暗）/场景容器图元等）——只隐藏自身网格，
	#    保留碰撞与子节点渲染；绝不能设根节点 visible=false，否则容器会连带隐藏整棵子树
	#    （旧版"全场景变黑"误判与"空气墙可见"皆源于此）
	# 2 Gone: 初始隐藏整个子树（后续关卡场景，由 VisibilityTrigger 动态激活）
	if node is Node3D:
		var vis: int = toIntSafe(objData.get("visibility", 0))
		if vis == 2:
			(node as Node3D).visible = false
		elif vis == 1:
			_hideOwnVisual(node)
		_applyAnimatable(node as Node3D, objData)

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


## 统一应用 ARPhros 物体的名称与变换（位置/旋转/缩放）；
## 原始缩放记录到 meta "arprojScale"（含符号，供动画器烘焙）、
## 分组记录到 meta "arprojGroups"，供后处理链接读取。
## 节点缩放保留原始符号（scale.x=-1 的镜像件需保持翻转外观）；
## 形状资源烘焙请使用 _objectScale（绝对值）。
func _applyObjectTransform(node: Node3D, objData: Dictionary, withScale: bool = true) -> void:
	node.name = "%s_%d" % [str(objData.get("name", "Object")), toIntSafe(objData.get("id", 0))]
	node.position = unityToGodotPosition(getVector3FromDict(objData, "position"))
	node.rotation = unityToGodotRotation(getVector3FromDict(objData, "eulerAngles"))
	var nodeScale: Vector3 = _nodeScale(objData)
	node.set_meta("arprojScale", nodeScale.abs())
	if withScale:
		node.scale = nodeScale
	var groupIds: Array[int] = []
	for rawG: Variant in objData.get("groupId", []) as Array:
		groupIds.append(toIntSafe(rawG))
	node.set_meta("arprojGroups", groupIds)


## 由 arproj 缩放取物体尺寸（绝对值，专供形状资源烘焙——负尺寸非法）
func _objectScale(objData: Dictionary) -> Vector3:
	return unityToGodotScale(getVector3FromDict(objData, "scale", Vector3.ONE)).abs()


## 节点实际缩放：保留原始符号（scale.x=-1 的镜像件需保持翻转外观）
func _nodeScale(objData: Dictionary) -> Vector3:
	return unityToGodotScale(getVector3FromDict(objData, "scale", Vector3.ONE))


## visibility=1：仅隐藏自身的网格表现（直接子级 MeshInstance3D），不影响碰撞与子树
func _hideOwnVisual(node: Node) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false


## 从 Ground.tscn 内部复制单位 BoxMesh（剥离模板材质引用），供盒体/纯视觉立方体使用。
## 所有使用方都会立刻 material_override 覆盖，表面材质是死数据；
## 原样借用会让生成场景残留对 #Template 材质的 ext_resource 引用。
func _ensureGroundTemplateParts() -> void:
	if _groundPartsLoaded:
		return
	_groundPartsLoaded = true
	var groundScene: PackedScene = load(GROUND_TEMPLATE) as PackedScene
	if groundScene == null:
		return
	var inst: Node = groundScene.instantiate()
	var mi: MeshInstance3D = inst.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi and mi.mesh:
		_groundTemplateMeshCache = mi.mesh.duplicate()
		if _groundTemplateMeshCache is PrimitiveMesh:
			(_groundTemplateMeshCache as PrimitiveMesh).material = null
	inst.free()


func _groundTemplateMesh() -> Mesh:
	_ensureGroundTemplateParts()
	if _groundTemplateMeshCache == null:
		_groundTemplateMeshCache = BoxMesh.new()
	return _groundTemplateMeshCache


## 直接实例化 Ground.tscn 作为盒体的旧路径已删除：实例内部材质覆写依赖
## editable instance，实测部分关卡的 Road 覆写不生效（导入后丢色），
## 盒体一律内联构建（见 _createGroundBox）。


## ARPhros type 0：customData.type 为 Unity PrimitiveType（0=Sphere / 3=Cube / 4=Plane）时
## 是图元物体（如"地板/Cube/中国灯"），按需生成网格与碰撞体；
## 其余（无 customData 的容器，如"场景元件"）保持纯分组。
## 全部使用单位网格 + 子节点缩放；碰撞体根节点不缩放。
func _createPrimitiveObject(objData: Dictionary, materials: Array, sprites: Array = []) -> Node:
	var custom: Variant = JSON.parse_string(str(objData.get("customData", "{}")))
	var customDict: Dictionary = custom as Dictionary if custom is Dictionary else {}
	var canCollide: bool = bool(objData.get("canCollide", false))
	match toIntSafe(customDict.get("type", -1)):
		3: # Cube（Unity 单位立方体 1x1x1，尺寸由 scale 决定）
			if canCollide:
				return _createCubeBody(objData, materials, sprites)
			return _createPrimitiveMesh(objData, materials, sprites, _groundTemplateMesh())
		0: # Sphere（Unity 单位球，直径 1；碰撞半径取缩放最大轴的一半）
			var maxAxis: float = maxf(_objectScale(objData).x, maxf(_objectScale(objData).y, _objectScale(objData).z))
			var sphereRadius: float = 0.5 * maxAxis
			var sphereMesh: SphereMesh = SphereMesh.new()
			sphereMesh.radius = 0.5
			sphereMesh.height = 1.0
			if canCollide:
				var sphereShape: SphereShape3D = SphereShape3D.new()
				sphereShape.radius = sphereRadius
				return _createPrimitiveBody(objData, materials, sprites, sphereShape, sphereMesh)
			return _createPrimitiveMesh(objData, materials, sprites, sphereMesh)
		2: # Cylinder（Unity 圆柱：直径 2、高 2，沿 Y 轴；视觉随子节点缩放）
			var cylScale: Vector3 = _objectScale(objData)
			var cylRadius: float = maxf(cylScale.x, cylScale.z)
			var cylHeight: float = 2.0 * cylScale.y
			var cylinderMesh: CylinderMesh = CylinderMesh.new()
			cylinderMesh.top_radius = 1.0
			cylinderMesh.bottom_radius = 1.0
			cylinderMesh.height = 2.0
			if canCollide:
				var cylinderShape: CylinderShape3D = CylinderShape3D.new()
				cylinderShape.radius = cylRadius
				cylinderShape.height = cylHeight
				return _createPrimitiveBody(objData, materials, sprites, cylinderShape, cylinderMesh)
			return _createPrimitiveMesh(objData, materials, sprites, cylinderMesh)
		4: # Plane（Unity 平面为 10x10 朝上水平面）
			var planeSize: Vector3 = _objectScale(objData)
			var planeMesh: PlaneMesh = PlaneMesh.new()
			planeMesh.size = Vector2(10 * planeSize.x, 10 * planeSize.z)
			if canCollide:
				var planeShape: BoxShape3D = BoxShape3D.new()
				planeShape.size = Vector3(planeMesh.size.x, 0.01, planeMesh.size.y)
				return _createPrimitiveBody(objData, materials, sprites, planeShape, planeMesh)
			return _createPrimitiveMesh(objData, materials, sprites, planeMesh)
		_:
			return _createGroupObject(objData)


## 可碰撞图元（球/平面）：obstacleType=1 → layer 4（玩家 Area 触碰即死），
## 其余 → layer 2。调用方负责把尺寸烘进新建的 shape 资源；网格视觉缩放
## 落在子节点上，CollisionShape3D 本地缩放保持 1（避免非均匀缩放警告）
func _createPrimitiveBody(objData: Dictionary, materials: Array, sprites: Array, shape: Shape3D, mesh: Mesh) -> Node:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 4 if toIntSafe(objData.get("obstacleType", 0)) == 1 else 2
	body.collision_mask = 0

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	body.add_child(col)

	var meshInst: MeshInstance3D = MeshInstance3D.new()
	meshInst.name = "Mesh"
	meshInst.mesh = mesh
	meshInst.scale = _objectScale(objData)
	body.add_child(meshInst)

	_applyObjectTransform(body, objData, false)
	var mat: Material = _createStandardMaterial(objData, materials, sprites)
	if mat:
		meshInst.material_override = mat
	return body


## 盒体统一入口（Road/障碍盒/立方体图元）：内联构建 StaticBody3D + 借用 Ground
## 模板的单位盒网格，arproj 材质经 material_override 直挂本场景节点——pack 必然
## 写入，不依赖 editable instance，也无大量 editable 拖慢编辑器之虞。
func _createGroundBox(objData: Dictionary, materials: Array, sprites: Array, layer: int) -> Node:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = BoxShape3D.new()
	sb.add_child(col)

	var meshInst: MeshInstance3D = MeshInstance3D.new()
	meshInst.name = "MeshInstance3D"
	meshInst.mesh = _groundTemplateMesh()
	sb.add_child(meshInst)

	_applyObjectTransform(sb, objData, true)
	var mat: Material = _createStandardMaterial(objData, materials, sprites)
	if mat:
		meshInst.material_override = mat
	if toIntSafe(objData.get("visibility", 0)) == 1:
		meshInst.visible = false
	return sb


## 标记发生内部覆写的子场景实例（CameraRoot 等少量实例）为 editable instance。
## 必须在 owner 设置完成【之后】调用（过早调用标志无效，实测验证）：
## 内部覆写只有 editable instance 才会被 PackedScene.pack() 写入场景文件，
## 且内部节点会在场景树中可见、可在编辑器中继续调整。
## 只标记有覆写的实例——全量标记会在大关卡下拖垮编辑器打开速度（实测教训）。
func markEditableInstances(root: Node) -> void:
	for inst: Node in _overrideInstances:
		if is_instance_valid(inst):
			root.set_editable_instance(inst, true)


## 可碰撞立方体：与 Road 共用同一内联盒体构建（根节点缩放）
func _createCubeBody(objData: Dictionary, materials: Array, sprites: Array) -> Node:
	var layer: int = 4 if toIntSafe(objData.get("obstacleType", 0)) == 1 else 2
	return _createGroundBox(objData, materials, sprites, layer)


## 非碰撞图元：Node3D 根节点 + "Mesh" 网格子节点。
## 缩放落在根节点上：与 Unity 一致地向子物体传递（如锤头挂在被拉伸的锤柄父级下，
## 其局部偏移/尺寸须被父级缩放放大）。根为纯 Node3D 无物理体，负号镜像安全；
## visibility=1 时仅隐藏网格子节点，不影响后续挂进根节点的子树。
func _createPrimitiveMesh(objData: Dictionary, materials: Array, sprites: Array, mesh: Mesh) -> Node:
	var rootNode: Node3D = Node3D.new()
	_applyObjectTransform(rootNode, objData, true)
	# Hidden 且无碰撞：无可渲染内容，仅保留层级占位（子树照常挂载）
	if toIntSafe(objData.get("visibility", 0)) == 1:
		return rootNode

	var meshInst: MeshInstance3D = MeshInstance3D.new()
	meshInst.name = "Mesh"
	meshInst.mesh = mesh
	rootNode.add_child(meshInst)

	var mat: Material = _createStandardMaterial(objData, materials, sprites)
	if mat:
		meshInst.material_override = mat
	return rootNode


## ARPhros type 10 Text：customData {text/fontIndex/fontSize/color/horizontalAlignment/verticalAlignment}
func _createTextObject(objData: Dictionary) -> Node:
	var rootNode: Node3D = Node3D.new()
	_applyObjectTransform(rootNode, objData, true)

	var custom: Dictionary = _parseCustom(objData)
	var label: Label3D = Label3D.new()
	label.name = "Label3D"
	label.text = str(custom.get("text", ""))
	# Unity 字号→世界尺寸换算：1pt≈0.1 单位（源数据 boundsSize 印证——fontSize=36 时
	# boundsSize 宽 15 恰容 4 个汉字）。Label3D 世界高度=font_size×pixel_size，
	# 保持默认 pixel_size=0.005 不动，渲染字号放大 20 倍即得目标尺寸且光栅更清晰。
	label.font_size = int(round(float(str(custom.get("fontSize", 20))) * 20.0))
	var colorData: Variant = custom.get("color", null)
	if colorData is Dictionary:
		var c: Dictionary = colorData as Dictionary
		# arproj 颜色 alpha 可能为 0（不参与显示），强制不透明
		label.modulate = Color(float(c.get("r", 1.0)), float(c.get("g", 1.0)), float(c.get("b", 1.0)), 1.0)
	var hFlags: int = toIntSafe(custom.get("horizontalAlignment", 2))
	var vFlags: int = toIntSafe(custom.get("verticalAlignment", 512))
	# TextMeshPro 对齐位标志（见 GameAssembly dump.cs）：
	#   HorizontalAlignmentOptions: Left=1 / Center=2 / Right=4
	#   VerticalAlignmentOptions:   Top=256 / Middle=512 / Bottom=1024
	label.horizontal_alignment = _mapTextAlignH(hFlags)
	label.vertical_alignment = _mapTextAlignV(vFlags)
	if MIRROR_X:
		# 文本位于 Scene_001 载体之下，非正常变换会把字形左右翻转，反向缩放抵消
		label.scale = Vector3(-1, 1, 1)
	rootNode.add_child(label)
	return rootNode


## TextMeshPro 水平对齐位标志 → Godot Label3D（0=左/1=中/2=右）。
## HorizontalAlignmentOptions: Left=1 / Center=2 / Right=4（可 OR 组合）。
func _mapTextAlignH(flags: int) -> int:
	if (flags & 4) != 0:
		return 2
	if (flags & 2) != 0:
		return 1
	if (flags & 1) != 0:
		return 0
	return 1 # 缺省居中

## TextMeshPro 垂直对齐位标志 → Godot Label3D（0=上/1=中/2=下）。
## VerticalAlignmentOptions: Top=256 / Middle=512 / Bottom=1024（可 OR 组合）。
func _mapTextAlignV(flags: int) -> int:
	if (flags & 1024) != 0:
		return 2
	if (flags & 512) != 0:
		return 1
	if (flags & 256) != 0:
		return 0
	return 1 # 缺省居中

func _createRoadObject(objData: Dictionary, materials: Array, sprites: Array = []) -> Node:
	return _createGroundBox(objData, materials, sprites, 2)


func _createObstacleBox(objData: Dictionary, materials: Array, sprites: Array = []) -> Node:
	return _createGroundBox(objData, materials, sprites, 4)


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
	# Node3D 根节点 + "Mesh" 网格子节点。缩放落在根节点上向子树传递（Unity 层级语义，
	# 见 _createPrimitiveMesh 注释），visibility=1 时只隐藏网格子节点；
	# 根为纯 Node3D 无物理体，负号镜像安全，也不干扰 LocalScaleAnimator 的根 scale 补间
	# （meta "arprojScale" 语义不变，且动画起始值与根实际缩放一致后不再跳变）。
	var rootNode: Node3D = Node3D.new()
	_applyObjectTransform(rootNode, objData, true)

	var mesh: Mesh = _loadMeshFromJson(objData, meshes)
	if mesh == null:
		# 找不到网格资源：保留根节点占位（子树照常挂载），不再回退内置 BoxMesh——
		# 错误的替身几何体会掩盖资源缺失（An_Asian_Adventure 曾因此 1625 个物体全变方块）。
		push_warning("LevelLoader: 模型 '%s'(id=%d) 未能加载网格，保留空占位。" % [str(objData.get("name", "")), toIntSafe(objData.get("id", 0))])
		return rootNode

	var meshInst: MeshInstance3D = MeshInstance3D.new()
	meshInst.name = "Mesh"
	# Unity 模型导入器会把 RH 资产（如 Blender 导出的 .obj/.glb）顶点 X 取反并翻转绕序，
	# 等效于网格内建 diag(-1,1,1)；Godot 原样加载同一文件会得到左右镜像。
	# 物体最终线性映射须为 diag(s)·diag(-1,1,1) = diag(-sx, sy, sz)（s 为 arproj 原始带符号缩放）：
	# 根节点承载 s 后，网格子节点仅需常量翻转因子 (-1,1,1)——保留原符号语义，
	# 叠乘后仍恰为整体镜像；若改用绝对值会破坏 scale.x<0 的显式镜像件（双重翻转）。
	meshInst.scale = Vector3(-1, 1, 1)
	meshInst.mesh = mesh
	rootNode.add_child(meshInst)

	var material: Material = _createStandardMaterial(objData, materials, sprites)
	if material:
		meshInst.material_override = material

	return rootNode


func _createTriggerObject(objData: Dictionary) -> Node:
	# 直接实例化 Trigger.tscn（Area3D + BaseTrigger + CollisionShape3D + Marker3D），整体拉伸
	var triggerRoot: Area3D = null
	var triggerScene: PackedScene = load(TRIGGER_TEMPLATE) as PackedScene
	if triggerScene:
		triggerRoot = triggerScene.instantiate() as Area3D
	if triggerRoot == null:
		# 兜底：模板不可用时手工等价构建
		triggerRoot = Area3D.new()
		triggerRoot.set_script(preload("res://#Template/[Scripts]/Trigger/BaseTrigger.gd"))
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = BoxShape3D.new()
		triggerRoot.add_child(col)

	var objId: int = toIntSafe(objData.get("id", 0))
	var pos: Vector3 = getVector3FromDict(objData, "position")
	triggerRoot.position = unityToGodotPosition(pos)
	var rot: Vector3 = getVector3FromDict(objData, "eulerAngles")
	triggerRoot.rotation = unityToGodotRotationNoFlip(rot)
	var scale: Vector3 = getVector3FromDict(objData, "scale", Vector3.ONE)
	triggerRoot.scale = unityToGodotScale(scale)
	# 组定位元数据（与 _applyObjectTransform 对齐）：组员可以是触发器本身
	# （如 Stop 按组停用一批 MoveTrigger）；缺失会使 _resolveTriggerTargets 的组匹配打不中
	var groupIds: Array[int] = []
	for rawG: Variant in objData.get("groupId", []) as Array:
		groupIds.append(toIntSafe(rawG))
	triggerRoot.set_meta("arprojGroups", groupIds)

	var customData: Variant = JSON.parse_string(str(objData.get("customData", "{}")))
	var custom: Dictionary = customData as Dictionary if customData is Dictionary else {}
	var triggerType: int = toIntSafe(custom.get("type", 0))

	var dataStr: String = str(custom.get("data", ""))

	var config: Dictionary = TriggerTypeMapClass.TRIGGER_CONFIG.get(triggerType, {})
	if config.is_empty():
		# 未实现类型：保持旧行为，仅保留带碰撞体的裸触发器
		if TriggerTypeMapClass.UNMAPPED_TRIGGER_TYPES.has(triggerType):
			push_warning("LevelLoader: 触发器类型 %d 已知但未实现（%s），未挂载任何组件。" % [triggerType, str(objData.get("name", ""))])
		triggerRoot.name = "%s_%d" % [str(objData.get("name", "Trigger")), objId]
		return triggerRoot

	# 命名集中在分发器；组件创建与参数解析交给 special 构建器或通用规格
	triggerRoot.name = "%s_%d" % [str(config.get("label", "Trigger")), objId]

	var fieldSpec: Dictionary = TriggerTypeMapClass.TRIGGER_FIELD_MAP.get(triggerType, {})
	if fieldSpec.has("builder"):
		call(str(fieldSpec["builder"]), dataStr, triggerRoot, config, objId)
	else:
		var comp: Node = (config.get("component") as Script).new()
		comp.name = str(config.get("childName", "Component"))
		var fixedProps: Dictionary = config.get("fixedProps", {}) as Dictionary
		for propName: String in fixedProps:
			comp.set(propName, fixedProps[propName])
		_applyGenericFields(comp, dataStr, fieldSpec.get("fields", []) as Array)
		triggerRoot.add_child(comp)

	return triggerRoot


# ==================== 通用字段应用与 special 构建器 ====================
## 构建器统一签名：(dataStr, triggerRoot, config, objId)，由分发器经 call() 调用；
## 解析语义与旧版内联 match 分支逐行一致，组件由构建器自行 add_child。

func _applyGenericFields(comp: Node, dataStr: String, fields: Array) -> void:
	var parts: PackedStringArray = dataStr.split("|")
	for rawField: Variant in fields:
		var field: Dictionary = rawField as Dictionary
		if field.is_empty():
			continue
		var prop: String = str(field.get("prop", ""))
		match str(field.get("kind", "")):
			"floatAt":
				var idx: int = int(field.get("part", -1))
				if idx < 0 or idx >= parts.size():
					continue
				var raw: String = parts[idx].strip_edges()
				if raw.is_valid_float():
					var val: float = float(raw)
					if field.has("minValue") and val <= float(field["minValue"]):
						continue
					comp.set(prop, val)
				elif field.has("default"):
					comp.set(prop, float(field["default"]))
			"wholeFloat":
				var stripped: String = dataStr.strip_edges()
				if stripped.is_valid_float():
					var val2: float = float(stripped)
					if field.has("minValue") and val2 <= float(field["minValue"]):
						continue
					comp.set(prop, val2)
				elif field.has("default"):
					comp.set(prop, float(field["default"]))
			"vecAt":
				var vecIdx: int = int(field.get("part", -1))
				if vecIdx < 0 or vecIdx >= parts.size():
					continue
				var comps: PackedStringArray = parts[vecIdx].split(",")
				if comps.size() >= 3:
					var vecVal := Vector3(float(comps[0].strip_edges()), float(comps[1].strip_edges()), float(comps[2].strip_edges()))
					if bool(field.get("mirrorX", false)):
						vecVal.x = -vecVal.x
					comp.set(prop, vecVal)
			"vecWhole":
				var whole: PackedStringArray = dataStr.split(",")
				if whole.size() >= 3:
					var vecWhole := Vector3(float(whole[0].strip_edges()), float(whole[1].strip_edges()), float(whole[2].strip_edges()))
					if bool(field.get("mirrorX", false)):
						vecWhole.x = -vecWhole.x
					comp.set(prop, vecWhole)
			_:
				push_warning("LevelLoader: 未知的通用字段 kind '%s'（属性 %s）。" % [str(field.get("kind", "")), prop])


func _buildCameraTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, _objId: int) -> void:
	var camComp: Node = TriggerTypeMapClass.CAMERA_TRIGGER_SCRIPT.new()
	camComp.name = str(config.get("childName", "CameraTrigger"))
	# 数据格式示例: "True|15, 45, 0|True|0, 3, 0|True|25|True|5000|linear|0|True|True|0"
	# [0]: bRotation, [1]: rotation(x,y,z), [2]: bPivotOffset, [3]: pivotOffset(x,y,z),
	# [4]: bDistance, [5]: distance（Camera_Data 第 [5] 字段，非 FOV；FOV 由 type 13 FovTrigger 导入）,
	# [6]: bFactor, [7]: factor, [8]: ease, [9]: duration
	var parts: PackedStringArray = dataStr.split("|")

	# 1. 旋转 Rotation（与 _createCamera 初始化 Rotator 的
	# mirrorRotationRad 同一约定——镜像关卡下相机机位整体共轭，
	# 运行时 CameraFollower 把它直接补间进同一个 Rotator.rotation_degrees）
	if parts.size() >= 2:
		var rotParts: PackedStringArray = parts[1].split(",")
		if rotParts.size() >= 3:
			var rx: float = float(rotParts[0].strip_edges())
			var ry: float = float(rotParts[1].strip_edges())
			var rz: float = float(rotParts[2].strip_edges())
			camComp.set("rotation", mirrorRotationRad(Vector3(rx, ry, rz)))

	# 2. 偏移 Offset（注视点世界坐标，随镜像世界取反 x，补间目标为 rotator.position）
	if parts.size() >= 4:
		var posParts: PackedStringArray = parts[3].split(",")
		if posParts.size() >= 3:
			var px: float = float(posParts[0].strip_edges())
			var py: float = float(posParts[1].strip_edges())
			var pz: float = float(posParts[2].strip_edges())
			camComp.set("offset", mirrorPosition(Vector3(px, py, pz)))

	# 3. 相机距离 distance（Camera_Data 第 [5] 字段，占位待映射到 Godot 相机距离机制）
	# FOV 由 type 13 FovTrigger 通过 _applyGenericFields 导入（fieldMap: part:0 → fieldOfView）
	if parts.size() >= 6:
		var distVal: float = float(parts[5]) if parts[5].is_valid_float() else 25.0
		# TODO: 将 distVal 写入正确的位置/scale 字段

	# 4. 过渡时间 Duration（优先 [9]，否则由 [7] smoothFactor 推导）
	var durVal: float = 2.0
	if parts.size() >= 10 and parts[9].is_valid_float() and float(parts[9]) > 0.0:
		durVal = float(parts[9])
	elif parts.size() >= 8 and parts[7].is_valid_float() and float(parts[7]) > 0.0:
		var sf: float = float(parts[7])
		durVal = clamp(5000.0 / sf, 0.1, 10.0) if sf > 10.0 else 2.0
	camComp.set("duration", durVal)

	# 5. 缓动 Ease
	if parts.size() >= 9:
		camComp.set("ease", _parseEaseType(parts[8]))

	triggerRoot.add_child(camComp)


func _buildJumpTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, _objId: int) -> void:
	var jumpComp: Node = TriggerTypeMapClass.JUMP_SCRIPT.new()
	jumpComp.name = str(config.get("childName", "Jump"))
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


func _buildVisibilityTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, _objId: int) -> void:
	var activeComp: SetActive = TriggerTypeMapClass.SET_ACTIVE_SCRIPT.new() as SetActive
	activeComp.name = str(config.get("childName", "SetActive"))
	# 数据格式示例: "Gone|9372|False|" -> Mode|TargetObjId|DontRevive|
	# 已知局限：目标节点实际命名为 "<名称>_<id>"，此处相对路径按裸 id 指向，可能无法命中（沿用旧行为）
	var parts: PackedStringArray = dataStr.split("|")
	if parts.size() >= 2:
		var modeStr: String = parts[0].to_lower()
		var targetId: int = int(parts[1]) if parts[1].is_valid_int() else -1
		var singleActive: SingleActive = SingleActiveClass.new()
		# Gone/Hidden -> active=false; Active/Appear -> active=true
		singleActive.active = (modeStr == "active" or modeStr == "appear" or modeStr == "show")
		# 相对路径将在后处理或通过节点名定位
		singleActive.target = NodePath("../../%s" % targetId)
		if parts.size() >= 3:
			singleActive.dontRevive = (parts[2].to_lower() == "true")
		# 修复：actives 为 Array[SingleActive] 类型化数组，旧的 set(无类型数组) 会被静默拒绝
		activeComp.actives.append(singleActive)
	triggerRoot.add_child(activeComp)


func _buildEnvironmentTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, _objId: int) -> void:
	var fogComp: Node = TriggerTypeMapClass.SET_FOG_SCRIPT.new()
	fogComp.name = str(config.get("childName", "SetFog"))
	# 数据格式: "True|Color|True|0.125, 0, 0, 1|True|True|1, 1, 1, 1|2.5|linear"
	var parts: PackedStringArray = dataStr.split("|")
	var fogSetting: FogSettings = FogSettingsClass.new()
	fogSetting.useFog = true
	if parts.size() >= 4:
		var cParts: PackedStringArray = parts[3].split(",")
		if cParts.size() >= 4:
			fogSetting.fogColor = Color(float(cParts[0]), float(cParts[1]), float(cParts[2]), float(cParts[3]))
	if parts.size() >= 8 and parts[7].is_valid_float():
		fogComp.set("duration", float(parts[7]))
	fogComp.set("fog", fogSetting)
	triggerRoot.add_child(fogComp)


func _buildFogTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, _objId: int) -> void:
	var fogComp: Node = TriggerTypeMapClass.SET_FOG_SCRIPT.new()
	fogComp.name = str(config.get("childName", "SetFog"))
	# 数据格式: "0.01|0.1254902, 0, 0, 1|True|2.5|linear"
	var parts: PackedStringArray = dataStr.split("|")
	var fogSetting: FogSettings = FogSettingsClass.new()
	fogSetting.useFog = true
	if parts.size() >= 1 and parts[0].is_valid_float():
		fogSetting.start = 0.0
		fogSetting.end = 100.0 / float(parts[0]) if float(parts[0]) > 0 else 100.0
	if parts.size() >= 2:
		var cParts: PackedStringArray = parts[1].split(",")
		if cParts.size() >= 4:
			fogSetting.fogColor = Color(float(cParts[0]), float(cParts[1]), float(cParts[2]), float(cParts[3]))
	if parts.size() >= 4 and parts[3].is_valid_float():
		fogComp.set("duration", float(parts[3]))
	fogComp.set("fog", fogSetting)
	triggerRoot.add_child(fogComp)


# ==================== Transform 触发器（Move/Rotate/Scale, type 5/6/7） ====================

## 按段位置解析动画参数并登记待链接条目；
## 目标节点的动画器实例化延迟到 _createObjects 末尾的 _linkTriggerAnimators。
func _buildAnimatorTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, objId: int) -> void:
	var eventComp: EventTrigger = TriggerTypeMapClass.EVENT_TRIGGER_SCRIPT.new() as EventTrigger
	eventComp.name = str(config.get("childName", "EventTrigger"))
	triggerRoot.add_child(eventComp)

	# 数据格式示例: "1, 1, 1|linear|3|True|False||1|False"
	# 字段对应游戏 Trigger 基类 + Trigger.MoveRotateScale_Data（游戏源码确认）：
	# [0]: mrsData.targetVector(x,y,z)  [1]: ease(LeanTweenType 成员名)  [2]: target 对象 id
	# [3]: mrsData.asOffset（True=相对偏移 / False=绝对值）
	# [4]: useGroup  [5]: groups 列表（空组序列化为空段）
	# [6]: duration 秒  [7]: mrsData.reverse（True 时交换 start/end）
	var parts: PackedStringArray = dataStr.split("|")
	if parts.size() < 8:
		push_warning("LevelLoader: 动画触发器 %d 参数段不足（%d/8），已跳过。" % [objId, parts.size()])
		return

	var vecParts: PackedStringArray = parts[0].split(",")
	if vecParts.size() < 3:
		push_warning("LevelLoader: 动画触发器 %d 目标向量格式错误：%s" % [objId, parts[0]])
		return
	var vecComps: Array[float] = []
	for i: int in 3:
		var compStr: String = vecParts[i].strip_edges()
		if not compStr.is_valid_float():
			# 严格校验：静默置 0 会把目标瞬移到原点
			push_warning("LevelLoader: 动画触发器 %d 向量分量 '%s' 非数值，已跳过。" % [objId, compStr])
			return
		vecComps.append(float(compStr))
	var targetValue: Vector3 = Vector3(vecComps[0], vecComps[1], vecComps[2])

	var idStr: String = parts[2].strip_edges()
	var targetId: int = idStr.to_int() if idStr.is_valid_int() else -1
	# [4]=useGroup / [5]=groups：useGroup=true 时按组定位目标，此时 targetId 允许为 -1
	var useGroup: bool = parts[4].strip_edges().to_lower() == "true"
	var groups: Array[int] = []
	for rawG: String in parts[5].split(","):
		var gs: String = rawG.strip_edges()
		if gs.is_valid_int():
			groups.append(gs.to_int())
	if targetId <= 0 and (not useGroup or groups.is_empty()):
		push_warning("LevelLoader: 动画触发器 %d 无有效目标（id=%d，useGroup=%s，组=%s），已跳过。" % [objId, targetId, str(useGroup), str(groups)])
		return

	var duration: float = 2.0
	var durStr: String = parts[6].strip_edges()
	if durStr.is_valid_float() and float(durStr) > 0.0:
		duration = float(durStr)

	var easeInfo: Dictionary = TriggerTypeMapClass.getAnimatorEase(parts[1])

	pendingAnimatorTriggers[triggerRoot] = {
		"comp": eventComp,
		"kind": str(config.get("animatorKind", "pos")),
		"targetId": targetId,
		"useGroup": useGroup,
		"groups": groups,
		"value": targetValue,
		"easeTrans": int(easeInfo["trans"]),
		"easeType": int(easeInfo["ease"]),
		"isAdd": parts[3].strip_edges().to_lower() == "true",
		"duration": duration,
		"reverse": parts[7].strip_edges().to_lower() == "true",
	}


## ARPhros type 9 Teleport：targetId|followImmediate（followImmediate 无需映射，
## InitPlayerPosition 总是强制相机跟随）
func _buildTeleportTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, _objId: int) -> void:
	var comp: Node = (config.get("component") as Script).new()
	comp.name = str(config.get("childName", "Teleport"))
	triggerRoot.add_child(comp)

	var parts: PackedStringArray = dataStr.split("|")
	var idStr: String = parts[0].strip_edges() if parts.size() > 0 else ""
	var targetId: int = idStr.to_int() if idStr.is_valid_int() else -1

	pendingAnimatorTriggers[triggerRoot] = {
		"comp": comp,
		"kind": "teleport",
		"targetId": targetId,
	}


## 解析 Sequence_Instance 段（useGroup|group|target 三 token）
func _parseSequenceInstance(parts: PackedStringArray, base: int) -> Dictionary:
	var useGroup: bool = parts[base].strip_edges().to_lower() == "true"
	var groups: Array[int] = []
	if base + 1 < parts.size():
		for rawG: String in parts[base + 1].split(","):
			var gs: String = rawG.strip_edges()
			if gs.is_valid_int():
				groups.append(gs.to_int())
	var targetId: int = -1
	if base + 2 < parts.size():
		var idStr: String = parts[base + 2].strip_edges()
		targetId = idStr.to_int() if idStr.is_valid_int() else -1
	return {"useGroup": useGroup, "groups": groups, "targetId": targetId}


## ARPhros type 10 Sequence，13 段：
## pre.useGroup|pre.group|pre.target|delay|main.useGroup|main.group|main.target|
## postDelay|post.useGroup|post.group|post.target|loop|loopDelay
func _buildSequenceTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, objId: int) -> void:
	var eventComp: EventTrigger = TriggerTypeMapClass.EVENT_TRIGGER_SCRIPT.new() as EventTrigger
	eventComp.name = str(config.get("childName", "EventTrigger"))
	triggerRoot.add_child(eventComp)

	var seqComp: Node = TriggerTypeMapClass.SEQUENCE_SCRIPT.new()
	seqComp.name = "SequenceTrigger"
	triggerRoot.add_child(seqComp)

	var parts: PackedStringArray = dataStr.split("|")
	if parts.size() < 12:
		push_warning("LevelLoader: Sequence 触发器 %d 参数段不足（%d/13），已跳过。" % [objId, parts.size()])
		return

	pendingAnimatorTriggers[triggerRoot] = {
		"comp": seqComp,
		"kind": "sequence",
		"pre": _parseSequenceInstance(parts, 0),
		"delay": float(parts[3]) if parts[3].strip_edges().is_valid_float() else 0.0,
		"main": _parseSequenceInstance(parts, 4),
		"postDelay": float(parts[7]) if parts[7].strip_edges().is_valid_float() else 0.0,
		"post": _parseSequenceInstance(parts, 8),
		"loop": parts[11].strip_edges().to_lower() == "true",
		"loopDelay": float(parts[12]) if parts[12].strip_edges().is_valid_float() else 0.0,
	}


## ARPhros type 14 Stop，3 段：targetId|useGroup|groups（如 "-1|True|14"，组员常为其他触发器）。
## 复用 SetActive 组件（active=false 停用目标触发器：visible=false + PROCESS_MODE_DISABLED
## 令 BaseTrigger 的 body_entered 彻底停发；复活回退时由其监听恢复——正确的世界回退语义）。
## 目标路径须待父子关系就绪后由 _linkStopTrigger 解析成真实相对路径。
func _buildStopTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, objId: int) -> void:
	var activeComp: SetActive = TriggerTypeMapClass.SET_ACTIVE_SCRIPT.new() as SetActive
	activeComp.name = str(config.get("childName", "SetActive"))
	triggerRoot.add_child(activeComp)

	var parts: PackedStringArray = dataStr.split("|")
	if parts.size() < 3:
		push_warning("LevelLoader: Stop 触发器 %d 参数段不足（%d/3），已跳过。" % [objId, parts.size()])
		return

	var idStr: String = parts[0].strip_edges()
	var groups: Array[int] = []
	for rawG: String in parts[2].split(","):
		var gs: String = rawG.strip_edges()
		if gs.is_valid_int():
			groups.append(gs.to_int())
	pendingAnimatorTriggers[triggerRoot] = {
		"comp": activeComp,
		"kind": "stop",
		"targetId": idStr.to_int() if idStr.is_valid_int() else -1,
		"useGroup": parts[1].strip_edges().to_lower() == "true",
		"groups": groups,
	}


## ARPhros type 8 Color：targetColor(RGBA)|ease|targetId|useGroup|groups(逗号分隔)|duration
func _buildColorTrigger(dataStr: String, triggerRoot: Area3D, config: Dictionary, objId: int) -> void:
	var eventComp: EventTrigger = TriggerTypeMapClass.EVENT_TRIGGER_SCRIPT.new() as EventTrigger
	eventComp.name = str(config.get("childName", "EventTrigger"))
	triggerRoot.add_child(eventComp)

	var parts: PackedStringArray = dataStr.split("|")
	if parts.size() < 6:
		push_warning("LevelLoader: Color 触发器 %d 参数段不足（%d/6），已跳过。" % [objId, parts.size()])
		return

	var cParts: PackedStringArray = parts[0].split(",")
	if cParts.size() < 4:
		push_warning("LevelLoader: Color 触发器 %d 目标颜色格式错误：%s" % [objId, parts[0]])
		return
	var targetColor: Color = Color(
		float(cParts[0].strip_edges()),
		float(cParts[1].strip_edges()),
		float(cParts[2].strip_edges()),
		float(cParts[3].strip_edges())
	)

	var idStr: String = parts[2].strip_edges()
	var targetId: int = idStr.to_int() if idStr.is_valid_int() else -1
	var useGroup: bool = parts[3].strip_edges().to_lower() == "true"
	var groups: Array[int] = []
	for rawG: String in parts[4].split(","):
		var gs: String = rawG.strip_edges()
		if gs.is_valid_int():
			groups.append(gs.to_int())

	var duration: float = 0.5
	var durStr: String = parts[5].strip_edges()
	if durStr.is_valid_float() and float(durStr) >= 0.0:
		duration = float(durStr)

	var easeInfo: Dictionary = TriggerTypeMapClass.getAnimatorEase(parts[1])

	pendingAnimatorTriggers[triggerRoot] = {
		"comp": eventComp,
		"kind": "color",
		"targetId": targetId,
		"useGroup": useGroup,
		"groups": groups,
		"color": targetColor,
		"duration": duration,
		"easeTrans": int(easeInfo["trans"]),
		"easeType": int(easeInfo["ease"]),
	}


## 后处理：为所有 Transform 触发器在目标节点下实例化动画器并建立信号连接。
## 必须在对象全部实例化且父子关系就绪之后调用（局部位姿才正确）。
## 解析触发器目标集合：useGroup=true 时按组匹配（arprojGroups meta），
## 否则按 targetId 直连。返回去重后的目标节点数组。
func _resolveTriggerTargets(entry: Dictionary, nodeMap: Dictionary) -> Array[Node]:
	var result: Array[Node] = []
	if bool(entry.get("useGroup", false)):
		# useGroup=true 时仅按组定位（与原版一致），组为空/无匹配即无目标，不回退直连
		var wantedGroups: Array = entry.get("groups", []) as Array
		for idKey: Variant in nodeMap:
			var cand: Node = nodeMap[idKey]
			var candGroups: Array = cand.get_meta("arprojGroups", []) as Array
			for wantedGid: Variant in wantedGroups:
				if candGroups.has(int(wantedGid)):
					result.append(cand)
					break
	else:
		var tid: int = int(entry.get("targetId", -1))
		if nodeMap.has(tid):
			result.append(nodeMap[tid])
	return result


func _linkTriggerAnimators(nodeMap: Dictionary) -> void:
	if pendingAnimatorTriggers.is_empty():
		return
	for key: Variant in pendingAnimatorTriggers:
		var entry: Dictionary = pendingAnimatorTriggers[key] as Dictionary
		var entryKind: String = str(entry.get("kind", "pos"))
		if entryKind == "color":
			_linkColorTrigger(entry, nodeMap)
			continue
		if entryKind == "teleport":
			_linkTeleportTrigger(entry, nodeMap)
			continue
		if entryKind == "sequence":
			_linkSequenceTrigger(entry, nodeMap)
			continue
		if entryKind == "stop":
			_linkStopTrigger(entry, nodeMap)
			continue
		var eventComp: EventTrigger = entry.get("comp") as EventTrigger
		if eventComp == null or not is_instance_valid(eventComp):
			push_warning("LevelLoader: 动画触发器的 EventTrigger 已失效，跳过链接。")
			continue
		var targets := _resolveTriggerTargets(entry, nodeMap)
		if targets.is_empty():
			push_warning("LevelLoader: 动画触发器未解析到任何目标（id=%d，useGroup=%s），保持未链接。" % [int(entry.get("targetId", -1)), str(entry.get("useGroup", false))])
			continue
		var kind: String = str(entry.get("kind", "pos"))
		var animatorScript: Script = TriggerTypeMapClass.ANIMATOR_SCRIPTS.get(kind, null) as Script
		if animatorScript == null:
			continue

		var rawVec: Vector3 = entry.get("value", Vector3.ZERO) as Vector3
		var isAdd: bool = bool(entry.get("isAdd", false))
		var linkedCount: int = 0
		# 组模式下可能多目标：每个目标各挂一个动画器，同一信号统一驱动
		for target: Node3D in targets:
			if target == null:
				continue
			var animator: AnimatorBase = animatorScript.new() as AnimatorBase
			animator.name = str(TriggerTypeMapClass.ANIMATOR_NODE_NAMES.get(kind, "Animator"))

			# 以目标当前局部位姿烘焙绝对值（运行时 transformType 恒为 New）
			var current: Vector3
			var endTarget: Vector3
			if kind == "rot":
				current = target.rotation
				var radVec: Vector3 = Vector3(degToRad(rawVec.x), degToRad(rawVec.y), degToRad(rawVec.z))
				endTarget = (current + radVec) if isAdd else radVec
			elif kind == "scale":
				# 视觉物体缩放已在根节点；物理体的缩放烘焙进形状（根为 1），
				# 故统一读导入时记录的原始缩放兜底
				current = target.get_meta("arprojScale", target.scale) as Vector3
				endTarget = (current + rawVec) if isAdd else rawVec
			else:
				current = target.position
				endTarget = (current + rawVec) if isAdd else rawVec

			animator.transformType = AnimatorBase.TransformType.New
			if bool(entry.get("reverse", false)):
				animator.startValue = endTarget
				animator.endOffset = current
			else:
				animator.startValue = current
				animator.endOffset = endTarget
			animator.duration = float(entry.get("duration", 2.0))
			animator.TransitionType = int(entry.get("easeTrans", Tween.TRANS_LINEAR)) as Tween.TransitionType
			animator.EaseType = int(entry.get("easeType", Tween.EASE_IN_OUT)) as Tween.EaseType
			animator.triggeredByTime = false # 仅经由 EventTrigger.triggered 调用

			target.add_child(animator, true)
			# pack() 只序列化带 CONNECT_PERSIST 标志的连接，必须显式携带
			eventComp.triggered.connect(animator.Trigger, CONNECT_PERSIST)
			linkedCount += 1
		if linkedCount > 0:
			eventComp.targetNode = targets[0]
	pendingAnimatorTriggers.clear()


## 链接 Teleport 触发器：解析传送点标记节点并填入 target
func _linkTeleportTrigger(entry: Dictionary, nodeMap: Dictionary) -> void:
	var comp: Node = entry.get("comp") as Node
	if comp == null or not is_instance_valid(comp):
		return
	var tid: int = int(entry.get("targetId", -1))
	var targetNode: Node = nodeMap.get(tid)
	if targetNode == null:
		push_warning("LevelLoader: 传送触发器目标对象 %d 不存在，保持未链接。" % tid)
		return
	comp.set("target", targetNode)


## 链接 Sequence 触发器：三段目标（其他触发器的 EventTrigger 组件）解析后填入
func _linkSequenceTrigger(entry: Dictionary, nodeMap: Dictionary) -> void:
	var seqComp: Node = entry.get("comp") as Node
	if seqComp == null or not is_instance_valid(seqComp):
		push_warning("LevelLoader: Sequence 触发器组件已失效，跳过链接。")
		return

	seqComp.set("delay", float(entry.get("delay", 0.0)))
	seqComp.set("postDelay", float(entry.get("postDelay", 0.0)))
	seqComp.set("loop", bool(entry.get("loop", false)))
	seqComp.set("loopDelay", float(entry.get("loopDelay", 0.0)))

	for phase: Array in [["preTargets", "pre"], ["mainTargets", "main"], ["postTargets", "post"]]:
		var inst: Dictionary = entry.get(str(phase[1])) as Dictionary
		var resolved := _resolveTriggerTargets(inst, nodeMap)
		var list: Array[Node] = []
		for targetNode: Node in resolved:
			if targetNode is Node3D:
				list.append(targetNode)
		if not list.is_empty():
			seqComp.set(str(phase[0]), list)


## 链接 Stop 触发器（type 14）：解析目标触发器集合，为 SetActive 组件逐个填入
## SingleActive{active=false}——路径用组件到目标根的真实相对路径（运行时树形一致，
## get_node_or_null 必命中；不重蹈 type 18 旧版"裸 id 路径打不中"的覆辙）。
func _linkStopTrigger(entry: Dictionary, nodeMap: Dictionary) -> void:
	var activeComp: Node = entry.get("comp") as Node
	if activeComp == null or not is_instance_valid(activeComp):
		push_warning("LevelLoader: Stop 触发器的 SetActive 已失效，跳过链接。")
		return

	var resolved := _resolveTriggerTargets(entry, nodeMap)
	var linkedCount: int = 0
	for targetRoot: Node in resolved:
		if targetRoot is Node3D and targetRoot != activeComp.get_parent():
			var singleActive: SingleActive = SingleActiveClass.new()
			singleActive.active = false # Stop：停用目标触发器
			singleActive.target = activeComp.get_path_to(targetRoot)
			(activeComp as SetActive).actives.append(singleActive)
			linkedCount += 1
	if linkedCount == 0:
		push_warning("LevelLoader: Stop 触发器未解析到任何目标（id=%d，useGroup=%s），保持未链接。" % [int(entry.get("targetId", -1)), str(entry.get("useGroup", false))])


## 链接 Color 触发器（type 8）：解析目标集合（useGroup 组匹配 / 直连 id），
## 为每个触发器挂载一个 SetMaterialColor 组件并连接 triggered 信号
func _linkColorTrigger(entry: Dictionary, nodeMap: Dictionary) -> void:
	var eventComp: EventTrigger = entry.get("comp") as EventTrigger
	if eventComp == null or not is_instance_valid(eventComp):
		push_warning("LevelLoader: Color 触发器的 EventTrigger 已失效，跳过链接。")
		return
	var triggerRoot: Node = eventComp.get_parent()

	var resolved := _resolveTriggerTargets(entry, nodeMap)
	var targets: Array[Node] = []
	for tgt: Node in resolved:
		if tgt is Node3D:
			targets.append(tgt)
	if targets.is_empty():
		push_warning("LevelLoader: Color 触发器未解析到任何 Node3D 目标（id=%d）。" % int(entry.get("targetId", -1)))
		return

	var comp: SetMaterialColor = TriggerTypeMapClass.SET_MATERIAL_COLOR_SCRIPT.new() as SetMaterialColor
	comp.name = "SetMaterialColor"
	comp.color = entry.get("color", Color.WHITE) as Color
	comp.duration = float(entry.get("duration", 0.5))
	comp.TransitionType = int(entry.get("easeTrans", Tween.TRANS_LINEAR)) as Tween.TransitionType
	comp.EaseType = int(entry.get("easeType", Tween.EASE_IN_OUT)) as Tween.EaseType
	for tgt: Node in targets:
		comp.targetNodes.append(tgt)
	triggerRoot.add_child(comp, true)
	eventComp.triggered.connect(comp.trigger, CONNECT_PERSIST)


func _parseEaseType(easeName: String) -> CameraFollower.Ease:
	var lower: String = easeName.to_lower().strip_edges()
	# 兼容带 "ease" 前缀的写法（如 "easeInOutSine"，见 Trigger.md 示例）
	if lower.begins_with("ease"):
		lower = lower.trim_prefix("ease")
	match lower:
		"linear": return CameraFollower.Ease.Linear
		"insine": return CameraFollower.Ease.InSine
		"outsine": return CameraFollower.Ease.OutSine
		"inoutsine": return CameraFollower.Ease.InOutSine
		"inquad": return CameraFollower.Ease.InQuad
		"outquad": return CameraFollower.Ease.OutQuad
		"inoutquad": return CameraFollower.Ease.InOutQuad
		"incubic": return CameraFollower.Ease.InCubic
		"outcubic": return CameraFollower.Ease.OutCubic
		"inoutcubic": return CameraFollower.Ease.InOutCubic
		"inquart": return CameraFollower.Ease.InQuart
		"outquart": return CameraFollower.Ease.OutQuart
		"inoutquart": return CameraFollower.Ease.InOutQuart
		"inexpo": return CameraFollower.Ease.InExpo
		"outexpo": return CameraFollower.Ease.OutExpo
		"inoutexpo": return CameraFollower.Ease.InOutExpo
		"inback": return CameraFollower.Ease.InBack
		"outback": return CameraFollower.Ease.OutBack
		"inoutback": return CameraFollower.Ease.InOutBack
		"inbounce": return CameraFollower.Ease.InBounce
		"outbounce": return CameraFollower.Ease.OutBounce
		"inoutbounce": return CameraFollower.Ease.InOutBounce
		_: return CameraFollower.Ease.InOutSine


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
	# 注意必须先 has() 再取：get(key, {}) 的默认空字典也是 Dictionary，
	# 直接判 is Dictionary 会在键缺失时提前返回，永远轮不到 meshData 分支
	if custom.has("data") and custom.get("data") is Dictionary:
		return custom.get("data") as Dictionary
	if custom.has("meshData") and custom.get("meshData") is Dictionary:
		return custom.get("meshData") as Dictionary
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
	var baseObjName: String = _stripInstanceSuffix(objName)

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

	# 2b. 按物体名称匹配（剥除实例后缀 " 1" / " (2)"，对齐模板模型文件名 HalfPyramid.obj）
	if baseObjName != objName:
		var namedMesh2: Mesh = _loadMeshByName(baseObjName)
		if namedMesh2 != null:
			return namedMesh2

	# 3. 按 meshes 中的文件名模糊匹配物体名称（含去后缀名）
	for rawInfo: Variant in meshes:
		if rawInfo is Dictionary:
			var meshInfo: Dictionary = rawInfo as Dictionary
			var fileName: String = str(meshInfo.get("fileName", ""))
			var baseName: String = fileName.get_basename()
			if baseName != "" and (objName.to_lower().contains(baseName.to_lower()) or baseObjName.to_lower().contains(baseName.to_lower())):
				var m: Mesh = _loadMeshByFilename(fileName)
				if m != null:
					return m

	return null


## 资源搜索基路径：显式路径逐个展开出 Meshes/Sprites 子目录——arplay 提取结构为
## Resources/{Meshes,Sprites}/，而 dock 传入的 extraSearchPaths 只到 Resources/ 一层，
## 不展开子目录会导致全部模型/贴图查找落空（模型回退内置 BoxMesh、材质无贴图）。
func _assetSearchPaths() -> Array[String]:
	var paths: Array[String] = []
	for basePath: String in MODEL_SEARCH_PATHS + extraSearchPaths:
		paths.append(basePath)
		var normalized: String = basePath if basePath.ends_with("/") else basePath + "/"
		paths.append(normalized + "Meshes/")
		paths.append(normalized + "Sprites/")
	return paths


func _loadMeshByFilename(fileName: String) -> Mesh:
	if loadedMeshes.has(fileName):
		return loadedMeshes[fileName] as Mesh

	for basePath: String in _assetSearchPaths():
		var fullPath: String = basePath + fileName
		if ResourceLoader.exists(fullPath):
			var resource: Resource = load(fullPath)
			if resource is Mesh:
				loadedMeshes[fileName] = resource
				return resource as Mesh

	var extensions: Array[String] = [".obj", ".glb", ".gltf", ".fbx"]
	for ext: String in extensions:
		if not fileName.ends_with(ext):
			for basePath: String in _assetSearchPaths():
				var fullPath: String = basePath + fileName + ext
				if ResourceLoader.exists(fullPath):
					var resource: Resource = load(fullPath)
					if resource is Mesh:
						loadedMeshes[fileName] = resource
						return resource as Mesh

	return null


func _loadMeshByName(name: String) -> Mesh:
	for basePath: String in _assetSearchPaths():
		var fullPath: String = basePath + name
		if ResourceLoader.exists(fullPath):
			var resource: Resource = load(fullPath)
			if resource is Mesh:
				return resource as Mesh

	var extensions: Array[String] = [".obj", ".glb", ".gltf"]
	for ext: String in extensions:
		for basePath: String in _assetSearchPaths():
			var fullPath: String = basePath + name + ext
			if ResourceLoader.exists(fullPath):
				var resource: Resource = load(fullPath)
				if resource is Mesh:
					return resource as Mesh

	return null


## 剥除物体名的实例后缀，使 "HalfPyramid 1" / "Box (2)" 落到模板模型 "HalfPyramid.obj" / "Box.obj"。
func _stripInstanceSuffix(name: String) -> String:
	var s: String = name.strip_edges()
	var rparen: int = s.rfind(")")
	if rparen > 0 and s[rparen - 1] == "(":
		return s.substr(0, rparen - 1).strip_edges()
	var space: int = s.rfind(" ")
	if space > 0 and s.substr(space + 1).is_valid_int():
		return s.substr(0, space).strip_edges()
	return s


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


## LeanTweenType 数值 → Tween 枚举（枚举序经游戏 il2cpp dump 实证，见 dump.cs LeanTweenType）。
## punch(34) 无对应曲线：返回 punch=true 由组件用"快出+弹性回落"复合近似；
## shake/pingPong 等运行时特型回退 SINE 往复语义并告警。
func _mapLeanTweenEase(easeId: int) -> Dictionary:
	var trans: Tween.TransitionType = Tween.TRANS_SINE
	var easeMode: Tween.EaseType = Tween.EASE_IN_OUT
	var isPunch: bool = false
	match easeId:
		1:
			trans = Tween.TRANS_LINEAR
		2, 3, 4:
			trans = Tween.TRANS_QUAD
			easeMode = Tween.EASE_OUT if easeId == 2 else (Tween.EASE_IN if easeId == 3 else Tween.EASE_IN_OUT)
		5, 6, 7:
			trans = Tween.TRANS_CUBIC
			easeMode = Tween.EASE_IN if easeId == 5 else (Tween.EASE_OUT if easeId == 6 else Tween.EASE_IN_OUT)
		8, 9, 10:
			trans = Tween.TRANS_QUART
			easeMode = Tween.EASE_IN if easeId == 8 else (Tween.EASE_OUT if easeId == 9 else Tween.EASE_IN_OUT)
		11, 12, 13:
			trans = Tween.TRANS_QUINT
			easeMode = Tween.EASE_IN if easeId == 11 else (Tween.EASE_OUT if easeId == 12 else Tween.EASE_IN_OUT)
		14, 15, 16:
			trans = Tween.TRANS_SINE
			easeMode = Tween.EASE_IN if easeId == 14 else (Tween.EASE_OUT if easeId == 15 else Tween.EASE_IN_OUT)
		17, 18, 19:
			trans = Tween.TRANS_EXPO
			easeMode = Tween.EASE_IN if easeId == 17 else (Tween.EASE_OUT if easeId == 18 else Tween.EASE_IN_OUT)
		20, 21, 22:
			trans = Tween.TRANS_CIRC
			easeMode = Tween.EASE_IN if easeId == 20 else (Tween.EASE_OUT if easeId == 21 else Tween.EASE_IN_OUT)
		23, 24, 25:
			trans = Tween.TRANS_BOUNCE
			easeMode = Tween.EASE_IN if easeId == 23 else (Tween.EASE_OUT if easeId == 24 else Tween.EASE_IN_OUT)
		26, 27, 28:
			trans = Tween.TRANS_BACK
			easeMode = Tween.EASE_IN if easeId == 26 else (Tween.EASE_OUT if easeId == 27 else Tween.EASE_IN_OUT)
		29, 30, 31:
			trans = Tween.TRANS_ELASTIC
			easeMode = Tween.EASE_IN if easeId == 29 else (Tween.EASE_OUT if easeId == 30 else Tween.EASE_IN_OUT)
		32:
			trans = Tween.TRANS_SPRING
			easeMode = Tween.EASE_OUT
		34:
			isPunch = true
		0, 33, 35, 36, 37, 38:
			push_warning("LevelLoader: LeanTweenType %d（%s）无直接对应曲线，回退 SINE 往复。" % [easeId, ["notUsed", "easeShake", "once", "clamp", "pingPong", "animationCurve"][easeId] if easeId in [0, 33, 35, 36, 37, 38] else "?"])
		_:
			push_warning("LevelLoader: 未知 LeanTweenType %d，回退 SINE 往复。" % easeId)
	return {"trans": trans, "ease": easeMode, "punch": isPunch}


## ARPhros objects[].animatable 自动画（Arphros.Animatable，il2cpp dump 实证）：
## StartMode ByDistance=玩家进入 distanceMinimum 半径触发 / ByTime=音乐时间过 timeMinimum 触发，
## 触发后按 ease 播放一次性位移补间。仅实现位置通道；其余通道出现时告警跳过。
func _applyAnimatable(node: Node3D, objData: Dictionary) -> void:
	var raw: String = str(objData.get("animatable", ""))
	if raw.is_empty():
		return
	var objId: int = toIntSafe(objData.get("id", 0))
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_warning("LevelLoader: 物体 %d 的 animatable 无法解析。" % objId)
		return
	var cfg: Dictionary = parsed as Dictionary

	for channel: String in ["animateRotation", "animateScale", "animateColor"]:
		if bool(cfg.get(channel, false)):
			push_warning("LevelLoader: 物体 %d 的 animatable.%s 暂不支持，已忽略。" % [objId, channel])
	if not bool(cfg.get("animatePosition", false)):
		return
	if toIntSafe(cfg.get("positionValueType", 0)) != 0:
		push_warning("LevelLoader: 物体 %d 的 animatable.positionValueType=Random 暂不支持，按 Fixed 处理。" % objId)

	var valueVec: Variant = cfg.get("positionValue", {})
	var offset := Vector3.ZERO
	if valueVec is Dictionary:
		var v: Dictionary = valueVec as Dictionary
		offset = Vector3(float(v.get("x", 0.0)), float(v.get("y", 0.0)), float(v.get("z", 0.0)))
	if not bool(cfg.get("asOffset", true)):
		# 绝对目标语义：偏移 = 目标 - 起点
		var sv: Variant = cfg.get("startPositionValue", {})
		var startVec := Vector3.ZERO
		if sv is Dictionary:
			startVec = Vector3(float(sv.get("x", 0.0)), float(sv.get("y", 0.0)), float(sv.get("z", 0.0)))
		offset = offset - startVec

	var easeInfo: Dictionary = _mapLeanTweenEase(toIntSafe(cfg.get("ease", 1)))
	var comp: Animatable = AnimatableClass.new() as Animatable
	comp.name = "Animatable"
	comp.mode = toIntSafe(cfg.get("mode", 0)) as Animatable.StartMode
	comp.timeMinimum = float(cfg.get("timeMinimum", 0.0))
	comp.distanceMinimum = float(cfg.get("distanceMinimum", 12.0))
	comp.offsetPosition = offset
	comp.duration = maxf(float(cfg.get("duration", 2.0)), 0.1)
	comp.transType = easeInfo["trans"] as Tween.TransitionType
	comp.easeType = easeInfo["ease"] as Tween.EaseType
	comp.punchReturn = bool(easeInfo["punch"])
	node.add_child(comp)


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

	for basePath: String in _assetSearchPaths():
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
