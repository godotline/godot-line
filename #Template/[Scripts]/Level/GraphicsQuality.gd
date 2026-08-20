class_name GraphicsQuality
extends RefCounted

## Runtime graphics settings shared by StartPage, ActiveByQuality, and gameplay triggers.
const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "graphics"
const QUALITY_LABELS: Array[String] = ["低", "中", "高", "极高"]
const ANTIALIASING_LABELS: Array[String] = ["Off", "x2", "x4", "x8"]

## 0: 低 (Low), 1: 中 (Medium), 2: 高 (High), 3: 极高 (Ultra)
static var qualityLevel: int = 2
static var antiAliasLevel: int = 0
static var shadowsEnabled: bool = true
static var postProcessEnabled: bool = true

static var shadowDefaults: Dictionary[int, bool] = {}
static var postProcessDefaults: Dictionary[int, Dictionary] = {}

static func setLevel(value: int) -> void:
	qualityLevel = clampi(value, 0, 3)

static func qualityLevelFromValue(value: Variant) -> int:
	if value is String:
		var labelIndex: int = QUALITY_LABELS.find(value)
		if labelIndex >= 0:
			return labelIndex
	return clampi(int(value), 0, 3)

static func antialiasingLevelFromValue(value: Variant) -> int:
	if value is String:
		var labelIndex: int = ANTIALIASING_LABELS.find(value)
		if labelIndex >= 0:
			return labelIndex
	return clampi(int(value), 0, 3)

static func getQualityLabel() -> String:
	return QUALITY_LABELS[qualityLevel]

static func getAntialiasingLabel() -> String:
	return ANTIALIASING_LABELS[antiAliasLevel]

static func loadSettings() -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	qualityLevel = clampi(int(config.get_value(SECTION, "quality_level", 2)), 0, 3)
	antiAliasLevel = clampi(int(config.get_value(SECTION, "antialiasing_level", 0)), 0, 3)
	shadowsEnabled = bool(config.get_value(SECTION, "shadows_enabled", true))
	postProcessEnabled = bool(config.get_value(SECTION, "post_process_enabled", true))
	return {
		"quality_level": qualityLevel,
		"antialiasing_level": antiAliasLevel,
		"shadows_enabled": shadowsEnabled,
		"post_process_enabled": postProcessEnabled,
	}

static func saveSettings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, "quality_level", qualityLevel)
	config.set_value(SECTION, "antialiasing_level", antiAliasLevel)
	config.set_value(SECTION, "shadows_enabled", shadowsEnabled)
	config.set_value(SECTION, "post_process_enabled", postProcessEnabled)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_error("GraphicsQuality.gd: failed to save settings (%s)" % error_string(error))

static func applyToScene(viewport: Viewport, sceneTree: SceneTree, environment: Environment) -> void:
	applyAntialiasing(viewport)
	applyShadows(sceneTree)
	applyPostProcess(environment)
	applyRenderingQuality()
	if sceneTree:
		sceneTree.call_group("active_by_quality", "applyQuality", qualityLevel)

static func applyAntialiasing(viewport: Viewport) -> void:
	if not viewport:
		return
	match antiAliasLevel:
		0:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		1:
			viewport.msaa_3d = Viewport.MSAA_2X
		2:
			viewport.msaa_3d = Viewport.MSAA_4X
		_:
			viewport.msaa_3d = Viewport.MSAA_8X

static func applyRenderingQuality() -> void:
	# 根据画质档位调节阴影贴图分辨率
	match qualityLevel:
		0:
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		1:
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		2:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		_:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)

static func applyShadows(sceneTree: SceneTree) -> void:
	if not sceneTree:
		return
	var root: Node = sceneTree.current_scene
	if not root:
		return
	var lightNodes: Array[Node] = root.find_children("*", "Light3D", true, false)
	for node: Node in lightNodes:
		var light: Light3D = node as Light3D
		if not light:
			continue
		var instanceId: int = light.get_instance_id()
		if not shadowDefaults.has(instanceId):
			shadowDefaults[instanceId] = light.shadow_enabled
		light.shadow_enabled = bool(shadowDefaults[instanceId]) if shadowsEnabled else false

static func applyPostProcess(environment: Environment) -> void:
	if not environment:
		return
	var instanceId: int = environment.get_instance_id()
	if not postProcessDefaults.has(instanceId):
		var defaults: Dictionary = {}
		for propertyName: StringName in _get_post_process_properties(environment):
			defaults[propertyName] = environment.get(propertyName)
		postProcessDefaults[instanceId] = defaults
	var savedDefaults: Dictionary = postProcessDefaults[instanceId]
	for propertyName: StringName in savedDefaults:
		environment.set(propertyName, savedDefaults[propertyName] if postProcessEnabled else false)

static func _get_post_process_properties(environment: Environment) -> Array[StringName]:
	var supported: Array[StringName] = []
	var candidates: Array[StringName] = [
		&"glow_enabled",
		&"ssao_enabled",
		&"ssil_enabled",
		&"adjustment_enabled",
	]
	var available: Dictionary[StringName, bool] = {}
	for propertyData: Dictionary in environment.get_property_list():
		available[StringName(propertyData.get("name", ""))] = true
	for propertyName: StringName in candidates:
		if available.has(propertyName):
			supported.append(propertyName)
	return supported

# ========== 兼容旧别名 ==========
static func set_level(value: int) -> void: setLevel(value)
static func quality_level_from_value(value: Variant) -> int: return qualityLevelFromValue(value)
static func antialiasing_level_from_value(value: Variant) -> int: return antialiasingLevelFromValue(value)
static func get_quality_label() -> String: return getQualityLabel()
static func get_antialiasing_label() -> String: return getAntialiasingLabel()
static func load_settings() -> Dictionary: return loadSettings()
static func save_settings() -> void: saveSettings()
static func apply_to_scene(viewport: Viewport, sceneTree: SceneTree, environment: Environment) -> void: applyToScene(viewport, sceneTree, environment)
static func apply_antialiasing(viewport: Viewport) -> void: applyAntialiasing(viewport)
static func apply_rendering_quality() -> void: applyRenderingQuality()
static func apply_shadows(sceneTree: SceneTree) -> void: applyShadows(sceneTree)
static func apply_post_process(environment: Environment) -> void: applyPostProcess(environment)
