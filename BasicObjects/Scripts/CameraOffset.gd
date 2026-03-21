@tool
extends Node3D

@export var end_rot = Vector3(-45,45,0)
@export var end_pos = Vector3(5,5,5)
@export var duration = 1.0
@export var TransitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT
@export var Camera: Camera3D

signal on_animation_start
signal on_animation_end

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		play_()
		
func _ready() -> void:
	if not Engine.is_editor_hint():
		$MeshInstance3D.visible = false

func play_():
	on_animation_start.emit()
	var tween = create_tween()
	tween.parallel().tween_property(Camera,"position",Camera.position+end_pos,duration).set_trans(TransitionType).set_ease(EaseType)
	tween.parallel().tween_property(Camera,"rotation_degrees",end_rot,duration).set_trans(TransitionType).set_ease(EaseType)
	tween.tween_callback(func(): on_animation_end.emit())
