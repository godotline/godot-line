# animator_base.gd
@tool
extends Node3D
class_name AnimatorBase

enum TransformType { New, Add }

@export_group("动画设置")
@export var transform_type: TransformType = TransformType.New
@export var start_value: Vector3 = Vector3(0,0,0)
@export var end_offset: Vector3 = Vector3(0,0,0)
@export var duration: float = 1.0
@export var TransitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("触发设置")
@export var triggered_by_time: bool = false
@export var trigger_time: float = 0.0
@export var dont_revive: bool = false

var _is_playing: bool = false
var _initialized: bool = false
var _finished: bool = false
var _trigger_index := -1
var _cached_music_player: AudioStreamPlayer = null

signal on_animation_start
signal on_animation_end

# 工具按钮操作的是自身（子节点）
@export_tool_button("Get Original Value")
var get_start_action: Callable = func() -> void:
	start_value = _get_value(self)

@export_tool_button("Set Original Value")
var set_start_action: Callable = func() -> void:
	_set_value(self, start_value)

@export_tool_button("Get New Value")
var get_end_action: Callable = func() -> void:
	match transform_type:
		TransformType.New:
			end_offset = _get_value(self)
		TransformType.Add:
			end_offset = _get_value(self) - start_value

@export_tool_button("Set New Value")
var set_end_action: Callable = func() -> void:
	match transform_type:
		TransformType.New:
			_set_value(self, end_offset)
		TransformType.Add:
			_set_value(self, start_value + end_offset)

@export_tool_button("Play")
var play_action: Callable = func() -> void: Trigger()

func _init() -> void:
	if Engine.is_editor_hint():
		if transform_type == TransformType.Add:
			start_value = _get_value(self)

func _ready() -> void:
	_initialized = true

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _finished or not triggered_by_time:
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if not _cached_music_player:
		var player := Player.instance
		if player:
			_cached_music_player = player.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if _cached_music_player and _cached_music_player.playing and _cached_music_player.get_playback_position() > trigger_time:
		Trigger()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not _is_playing and _initialized:
		pass

# 动画 tween 的是父节点
func Trigger() -> void:
	if _finished and not Engine.is_editor_hint():
		return
	_is_playing = true
	if not Engine.is_editor_hint():
		_finished = true
	_trigger_index = LevelManager.checkpoint_count
	on_animation_start.emit()
	if not dont_revive and not Engine.is_editor_hint():
		LevelManager.add_revive_listener(_on_revive)
	var target: Node3D = get_parent() as Node3D
	if not target:
		push_error("AnimatorBase.gd: 父节点为空，无法播放动画")
		return
	_set_value(target, start_value)
	var tween: Tween = create_tween()
	var target_value: Vector3 = end_offset
	if transform_type == TransformType.Add:
		target_value = start_value + end_offset
	tween.tween_property(target, _get_property_name(), target_value, duration).set_trans(TransitionType).set_ease(EaseType)
	tween.tween_callback(func():
		on_animation_end.emit()
		_is_playing = false
		if Engine.is_editor_hint():
			_set_value(target, start_value)
	)

func _on_revive() -> void:
	LevelManager.remove_revive_listener(_on_revive)
	LevelManager.CompareCheckpointIndex(_trigger_index, func():
		var target: Node3D = get_parent() as Node3D
		if not target:
			push_error("AnimatorBase.gd: 父节点为空，无法恢复动画状态")
			return
		_set_value(target, start_value)
		_is_playing = false
		_finished = false
	)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)

# 虚方法
func _get_value(_target: Node3D) -> Vector3:
	return Vector3.ZERO

func _set_value(_target: Node3D, _value: Vector3) -> void:
	pass

func _get_property_name() -> String:
	return ""
