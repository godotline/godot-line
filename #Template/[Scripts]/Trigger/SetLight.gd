extends Node3D

@export var light_settings: LightSettings = LightSettings.new()
@export_range(0.0, 60.0, 0.05) var duration: float = 2.0
@export var trans_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

func trigger(body: Node3D) -> void:
	var player: Player = body as Player
	if not player or not light_settings:
		return
	var scene_light: DirectionalLight3D = player.get_scene_light()
	if scene_light:
		light_settings.apply_tweened(scene_light, duration, trans_type, ease_type)
