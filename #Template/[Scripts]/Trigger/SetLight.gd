extends Node

@export var light: LightSettings = LightSettings.new()
@export_range(0.0, 60.0, 0.05) var duration: float = 2.0
@export var transType: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease: Tween.EaseType = Tween.EASE_IN_OUT

func trigger(body: Node3D) -> void:
	var player: Player = body as Player
	if not player or not light:
		return
	var sceneLight: DirectionalLight3D = player.get_scene_light()
	if sceneLight:
		light.apply_tweened(sceneLight, duration, transType, ease)
