extends Node3D

@export var ambient_settings: AmbientSettings = AmbientSettings.new()
@export_range(0.0, 3600.0, 0.01) var trigger_time: float = 0.0
@export_range(0.0, 60.0, 0.05) var duration: float = 1.0
@export var trans_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var dont_revive: bool = false

var _finished: bool = false
var _checkpoint_index: int = -1

func _process(_delta: float) -> void:
	if _finished or LevelManager.GameState != LevelManager.GameStatus.Playing or AudioManager.time < trigger_time:
		return
	trigger_animation()

func trigger_animation() -> void:
	if _finished:
		return
	_finished = true
	_checkpoint_index = LevelManager.checkpoint_count
	ambient_settings.apply_tweened(self, duration, trans_type, ease_type)
	if not dont_revive:
		LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	LevelManager.CompareCheckpointIndex(_checkpoint_index, func() -> void:
		_finished = false
	)

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_revive)
