extends RefCounted
class_name TemplateCheckpointCapture

const MESSAGE: StringName = &"template_checkpoint:captured"
const VALUE_PROPERTIES: Array[StringName] = [
	&"AutoRecord",
	&"GameTime",
	&"PlayerSpeed",
	&"UsingOldCameraFollower",
	&"direction",
	&"manual_camera",
	&"manual_fog",
	&"manual_light",
	&"manual_ambient",
]
const SETTINGS_PROPERTIES: Array[StringName] = [
	&"camera_new",
	&"camera_old",
	&"fog",
	&"light",
	&"ambient",
]

static func capture(checkpoint: Node) -> void:
	if not EngineDebugger.is_active():
		return
	var current_scene: Node = checkpoint.get_tree().current_scene
	if not current_scene or current_scene.scene_file_path.is_empty():
		return

	var values: Dictionary = {}
	for property_name: StringName in VALUE_PROPERTIES:
		values[property_name] = checkpoint.get(property_name)

	var settings: Dictionary = {}
	for property_name: StringName in SETTINGS_PROPERTIES:
		var resource: Resource = checkpoint.get(property_name) as Resource
		if resource:
			settings[property_name] = inst_to_dict(resource)

	EngineDebugger.send_message(MESSAGE, [{
		"scene_path": current_scene.scene_file_path,
		"node_path": str(current_scene.get_path_to(checkpoint)),
		"values": values,
		"settings": settings,
	}])
