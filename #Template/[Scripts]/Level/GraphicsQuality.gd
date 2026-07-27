class_name GraphicsQuality
extends RefCounted

## Runtime graphics settings shared by StartPage and ActiveByQuality.
const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "graphics"
const QUALITY_LABELS: Array[String] = ["低", "中", "高", "极高"]
const ANTIALIASING_LABELS: Array[String] = ["Off", "x2", "x4", "x8"]

static var level: int = 1
static var antialiasing: int = 0
static var shadows_enabled: bool = true
static var post_process_enabled: bool = true

static var _shadow_defaults: Dictionary[int, bool] = {}
static var _post_process_defaults: Dictionary[int, Dictionary] = {}

static func set_level(value: int) -> void:
	level = clampi(value, 0, 3)

static func quality_level_from_value(value: Variant) -> int:
	if value is String:
		var label_index: int = QUALITY_LABELS.find(value)
		if label_index >= 0:
			return label_index
	return clampi(int(value), 0, 3)

static func antialiasing_level_from_value(value: Variant) -> int:
	if value is String:
		var label_index: int = ANTIALIASING_LABELS.find(value)
		if label_index >= 0:
			return label_index
	return clampi(int(value), 0, 3)

static func get_quality_label() -> String:
	return QUALITY_LABELS[level]

static func get_antialiasing_label() -> String:
	return ANTIALIASING_LABELS[antialiasing]

static func load_settings() -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	level = clampi(int(config.get_value(SECTION, "quality_level", 1)), 0, 3)
	antialiasing = clampi(int(config.get_value(SECTION, "antialiasing_level", 0)), 0, 3)
	shadows_enabled = bool(config.get_value(SECTION, "shadows_enabled", true))
	post_process_enabled = bool(config.get_value(SECTION, "post_process_enabled", true))
	return {
		"quality_level": level,
		"antialiasing_level": antialiasing,
		"shadows_enabled": shadows_enabled,
		"post_process_enabled": post_process_enabled,
	}

static func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, "quality_level", level)
	config.set_value(SECTION, "antialiasing_level", antialiasing)
	config.set_value(SECTION, "shadows_enabled", shadows_enabled)
	config.set_value(SECTION, "post_process_enabled", post_process_enabled)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_error("GraphicsQuality.gd: failed to save settings (%s)" % error_string(error))

static func apply_to_scene(viewport: Viewport, scene_tree: SceneTree, environment: Environment) -> void:
	apply_antialiasing(viewport)
	apply_shadows(scene_tree)
	apply_post_process(environment)
	scene_tree.call_group("active_by_quality", "apply_quality", level)

static func apply_antialiasing(viewport: Viewport) -> void:
	match antialiasing:
		0:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		1:
			viewport.msaa_3d = Viewport.MSAA_2X
		2:
			viewport.msaa_3d = Viewport.MSAA_4X
		_:
			viewport.msaa_3d = Viewport.MSAA_8X

static func apply_shadows(scene_tree: SceneTree) -> void:
	var root: Node = scene_tree.current_scene
	if not root:
		return
	var light_nodes: Array[Node] = root.find_children("*", "Light3D", true, false)
	for node: Node in light_nodes:
		var light: Light3D = node as Light3D
		if not light:
			continue
		var instance_id: int = light.get_instance_id()
		if not _shadow_defaults.has(instance_id):
			_shadow_defaults[instance_id] = light.shadow_enabled
		light.shadow_enabled = bool(_shadow_defaults[instance_id]) if shadows_enabled else false

static func apply_post_process(environment: Environment) -> void:
	if not environment:
		return
	var instance_id: int = environment.get_instance_id()
	if not _post_process_defaults.has(instance_id):
		var defaults: Dictionary = {}
		for property_name: StringName in _get_post_process_properties(environment):
			defaults[property_name] = environment.get(property_name)
		_post_process_defaults[instance_id] = defaults
	var saved_defaults: Dictionary = _post_process_defaults[instance_id]
	for property_name: StringName in saved_defaults:
		environment.set(property_name, saved_defaults[property_name] if post_process_enabled else false)

static func _get_post_process_properties(environment: Environment) -> Array[StringName]:
	var supported: Array[StringName] = []
	var candidates: Array[StringName] = [
		&"glow_enabled",
		&"ssao_enabled",
		&"ssil_enabled",
		&"adjustment_enabled",
	]
	var available: Dictionary[StringName, bool] = {}
	for property_data: Dictionary in environment.get_property_list():
		available[StringName(property_data.get("name", ""))] = true
	for property_name: StringName in candidates:
		if available.has(property_name):
			supported.append(property_name)
	return supported
