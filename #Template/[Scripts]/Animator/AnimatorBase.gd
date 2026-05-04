# animator_base.gd
@tool
extends Node3D
class_name AnimatorBase

enum TransformType { New, Add }

@export_group("动画设置")
@export var transform_type: TransformType = TransformType.New
@export var start_value = Vector3(0,0,0)
@export var end_offset = Vector3(0,0,0)
@export var duration = 1.0
@export var TransitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("触发设置")
@export var triggered_by_time: bool = false
@export var trigger_time: float = 0.0
@export var dont_revive: bool = false

var _is_playing = false
var _initialized = false
var _finished = false
var _trigger_index := -1

signal on_animation_start
signal on_animation_end

@export_tool_button("Get Original Value")
var get_start_action = func():
	start_value = _get_value()

@export_tool_button("Set Original Value")
var set_start_action = func():
	_set_value(start_value)

@export_tool_button("Get New Value")
var get_end_action = func():
	match transform_type:
		TransformType.New:
			end_offset = _get_value()
		TransformType.Add:
			end_offset = _get_value() - start_value

@export_tool_button("Set New Value")
var set_end_action = func():
	match transform_type:
		TransformType.New:
			_set_value(end_offset)
		TransformType.Add:
			_set_value(start_value + end_offset)

@export_tool_button("Play")
var play_action = func(): Trigger()

func _init() -> void:
	if Engine.is_editor_hint():
		if transform_type == TransformType.Add:
			start_value = _get_value()

func _ready() -> void:
	_initialized = true

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _finished or not triggered_by_time:
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	var player := Player.instance
	if not player:
		return
	var music_player := player.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player and music_player.playing and music_player.get_playback_position() > trigger_time:
		Trigger()

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not _is_playing and _initialized:
		pass

func Trigger():
	if _finished and not Engine.is_editor_hint():
		return
	_is_playing = true
	if not Engine.is_editor_hint():
		_finished = true
	_trigger_index = LevelManager.checkpoint_count
	on_animation_start.emit()
	if not dont_revive and not Engine.is_editor_hint():
		LevelManager.add_revive_listener(_on_revive)
	_set_value(start_value)
	var tween = create_tween()
	var target_value = end_offset
	if transform_type == TransformType.Add:
		target_value = start_value + end_offset
	tween.tween_property(self, _get_property_name(), target_value, duration).set_trans(TransitionType).set_ease(EaseType)
	tween.tween_callback(func():
		on_animation_end.emit()
		_is_playing = false
		if Engine.is_editor_hint():
			_set_value(start_value)
	)

func _on_revive() -> void:
	LevelManager.remove_revive_listener(_on_revive)
	LevelManager.CompareCheckpointIndex(_trigger_index, func():
		_set_value(start_value)
		_is_playing = false
		_finished = false
	)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)

# 虚方法
func _get_value() -> Vector3:
	return Vector3.ZERO

func _set_value(_value: Vector3) -> void:
	pass

func _get_property_name() -> String:
	return ""
