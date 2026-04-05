extends Control
@export var line : CharacterBody3D
@export var levelname := "level name"
@export var crown_no_light: Texture2D
var 一 := false

func _ready() -> void:
	$".".visible = false

func _process(_delta: float) -> void:
	if not 一:
		if not line.is_live:
			visible()
		if State.is_end:
			visible()

func visible() -> void:
	一 = true
	if State.is_relive == true:
		State.crown -= 1
	$diamond.text = str(State.diamond,"/10")
	$title.text = levelname
	if State.crown == 0:
		$PerfactCrownNoLight.texture = crown_no_light
		$PerfactCrownNoLight2.texture = crown_no_light
		$PerfactCrownNoLight3.texture = crown_no_light
	elif State.crown == 1:
		$AnimationPlayer.play("1crown")
	elif State.crown == 2:
		$AnimationPlayer.play("2crown")
	elif State.crown == 3:
		$AnimationPlayer.play("3crown")
	else:
		$PerfactCrownNoLight.texture = crown_no_light
		$PerfactCrownNoLight2.texture = crown_no_light
		$PerfactCrownNoLight3.texture = crown_no_light
	$".".visible = true


func _on_back_pressed() -> void:
	get_tree().quit()
	State.is_end = false
	State.is_relive = false
	State.camera_follower_restore_pending = false
	State.diamond = 0
	State.crown = 0
	State.percent = 0



func _on_gameplay_pressed() -> void:
	line.tree.reload_current_scene()
	if State.crown > 0 :
		State.is_relive = true
	State.camera_follower_restore_pending = true
	State.diamond = 0
	State.crown = 0
	State.percent = 0
	State.line_crossing_crown = 0
	State.crowns = [0, 0, 0]



func _on_gamereplay_pressed() -> void:
	line.reload()
	State.is_end = false
	State.is_relive = false
	State.camera_follower_restore_pending = false
	State.diamond = 0
	State.crown = 0
	State.percent = 0
	State.anim_time = 0.0
	State.music_checkpoint_time = 0.0
