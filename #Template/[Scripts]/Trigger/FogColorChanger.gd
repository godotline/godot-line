@tool
extends Node3D

@export var target_fog_color = Color(1,1,1)
@export var duration = 1.0
@export var TransitionType = 1

@onready var level_manager = get_tree().current_scene

signal on_animation_start
signal on_animation_end

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		play_()

func play_():
	if not level_manager or not level_manager.Camera:
		return
		
	on_animation_start.emit()
	var tween = create_tween()
	tween.tween_property(level_manager.Camera.get_environment(), "fog_light_color", target_fog_color, duration).set_trans(TransitionType)
	tween.tween_callback(func(): on_animation_end.emit())
