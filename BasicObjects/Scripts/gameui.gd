extends Control
@export var line : CharacterBody3D
@export var levelname := "level name"
var panel_shown := false

func _ready() -> void:
	$".".visible = false

func _process(_delta: float) -> void:
	if panel_shown:
		return
	if not line.is_live or State.is_end:
		show_result_panel()

func show_result_panel() -> void:
	panel_shown = true
	$diamond.text = str(State.diamond,"/10")
	$title.text = levelname
	if State.crown == 0:
		$PerfactCrownNoLight.texture = preload("res://Resources/PerfactCrownNoLight.png")
		$PerfactCrownNoLight2.texture = preload("res://Resources/PerfactCrownNoLight.png")
		$PerfactCrownNoLight3.texture = preload("res://Resources/PerfactCrownNoLight.png")
	elif State.crown == 1:
		$AnimationPlayer.play("1crown")
	elif State.crown == 2:
		$AnimationPlayer.play("2crown")
	elif State.crown == 3:
		$AnimationPlayer.play("3crown")
	else :
		$PerfactCrownNoLight.texture = preload("res://Resources/PerfactCrownNoLight.png")
		$PerfactCrownNoLight2.texture = preload("res://Resources/PerfactCrownNoLight.png")
		$PerfactCrownNoLight3.texture = preload("res://Resources/PerfactCrownNoLight.png")
	$".".visible = true


func _on_back_pressed() -> void:
	State.reset_for_restart()
	get_tree().quit()



func _on_gameplay_pressed() -> void:
	var can_revive := State.can_revive()
	State.is_relive = can_revive
	State.is_end = false
	if can_revive:
		State.restore_progress_from_checkpoint(true)
		call_deferred("_restore_from_checkpoint")
	else:
		State.clear_checkpoint()
		State.reset_progress()
		line.tree.reload_current_scene()



func _on_gamereplay_pressed() -> void:
	line.reload()

func _restore_from_checkpoint() -> void:
	if not State.restore_checkpoint_scene(get_tree()):
		line.tree.reload_current_scene()
