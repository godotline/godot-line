# animator_base.gd
@tool
extends Node
class_name AnimatorBase

enum TransformType { New, Add }

@export_group("动画设置")
@export var transformType: TransformType = TransformType.New
@export var startValue: Vector3 = Vector3(0,0,0)
@export var endOffset: Vector3 = Vector3(0,0,0)
@export var duration: float = 2.0  # Unity 默认 2f
@export var TransitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("触发设置")
@export var triggeredByTime: bool = true  # Unity 默认 true
@export var triggerTime: float = 0.0
@export var offsetTime: bool = false  # Unity AnimatorBase.offsetTime: 提前 duration 触发
@export var dontRevive: bool = false

var isPlaying: bool = false
var _initialized: bool = false
var _finished: bool = false
var triggerIndex: int = -1
var cachedMusicPlayer: AudioStreamPlayer = null

signal on_animation_start
signal on_animation_end

# 工具按钮操作的是父节点（挂载的目标对象）
@export_tool_button("Get Original Value")
var getStartAction: Callable = func() -> void:
	var target: Node3D = get_parent() as Node3D
	if not target:
		return
	var oldValue: Vector3 = startValue
	startValue = _get_value(target)
	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("Get Original Value")
	undoRedo.add_do_property(self, "startValue", startValue)
	undoRedo.add_undo_property(self, "startValue", oldValue)
	undoRedo.commit_action(false)
	notify_property_list_changed()

@export_tool_button("Set Original Value")
var setStartAction: Callable = func() -> void:
	var target: Node3D = get_parent() as Node3D
	if not target:
		return
	var oldValue: Vector3 = _get_value(target)
	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("Set Original Value")
	undoRedo.add_do_method(self, "_set_value", target, startValue)
	undoRedo.add_undo_method(self, "_set_value", target, oldValue)
	undoRedo.commit_action(false)
	notify_property_list_changed()

@export_tool_button("Get New Value")
var getEndAction: Callable = func() -> void:
	var target: Node3D = get_parent() as Node3D
	if not target:
		return
	var oldValue: Vector3 = endOffset
	match transformType:
		TransformType.New:
			endOffset = _get_value(target)
		TransformType.Add:
			endOffset = _get_value(target) - startValue
	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("Get New Value")
	undoRedo.add_do_property(self, "endOffset", endOffset)
	undoRedo.add_undo_property(self, "endOffset", oldValue)
	undoRedo.commit_action(false)
	notify_property_list_changed()

@export_tool_button("Set New Value")
var setEndAction: Callable = func() -> void:
	var target: Node3D = get_parent() as Node3D
	if not target:
		return
	var oldValue: Vector3 = _get_value(target)
	var targetValue: Vector3
	match transformType:
		TransformType.New:
			targetValue = endOffset
			_set_value(target, endOffset)
		TransformType.Add:
			targetValue = startValue + endOffset
			_set_value(target, startValue + endOffset)
	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("Set New Value")
	undoRedo.add_do_method(self, "_set_value", target, targetValue)
	undoRedo.add_undo_method(self, "_set_value", target, oldValue)
	undoRedo.commit_action(false)
	notify_property_list_changed()

@export_tool_button("Play")
var playAction: Callable = func() -> void: Trigger()

func _init() -> void:
	pass

# 对齐 Unity：originalTransform 是显式写入的序列化值，无运行时捕获。
# startValue 由编辑器 "Get Original Value" 按钮或导入器显式填充。
func _ready() -> void:
	_initialized = true
	# 对齐 Unity Start() 中的 InitTransform()：加载/复活时把目标设为 startValue
	if not Engine.is_editor_hint():
		var target: Node3D = get_parent() as Node3D
		if target:
			_set_value(target, startValue)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _finished or not triggeredByTime:
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if not cachedMusicPlayer:
		var player: Player = Player.instance
		if player:
			cachedMusicPlayer = player.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if cachedMusicPlayer and cachedMusicPlayer.playing and cachedMusicPlayer.get_playback_position() > _effectiveTriggerTime():
		Trigger()

## Unity InitTime(): offsetTime 时提前 duration 触发
func _effectiveTriggerTime() -> float:
	return triggerTime - duration if offsetTime else triggerTime

# 动画 tween 的是父节点
func Trigger() -> void:
	if _finished and not Engine.is_editor_hint():
		return
	isPlaying = true
	if not Engine.is_editor_hint():
		_finished = true
	triggerIndex = LevelManager.checkpointCount
	on_animation_start.emit()
	if not dontRevive and not Engine.is_editor_hint():
		LevelManager.add_revive_listener(_on_revive)
	var target: Node3D = get_parent() as Node3D
	if not target:
		push_error("AnimatorBase.gd: 父节点为空，无法播放动画")
		return
	_set_value(target, startValue)
	var tween: Tween = create_tween()
	var targetValue: Vector3 = endOffset
	if transformType == TransformType.Add:
		targetValue = startValue + endOffset
	targetValue = _adjust_target_value(startValue, targetValue, transformType == TransformType.Add)
	tween.tween_property(target, _get_property_name(), targetValue, duration).set_trans(TransitionType).set_ease(EaseType)
	tween.tween_callback(func():
		on_animation_end.emit()
		isPlaying = false
		if Engine.is_editor_hint():
			_set_value(target, startValue)
	)

func _on_revive() -> void:
	LevelManager.remove_revive_listener(_on_revive)
	LevelManager.CompareCheckpointIndex(triggerIndex, func():
		var target: Node3D = get_parent() as Node3D
		if not target:
			push_error("AnimatorBase.gd: 父节点为空，无法恢复动画状态")
			return
		_set_value(target, startValue)
		isPlaying = false
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

# 虚方法：旋转类子类可覆写以应用 RotateMode 等旋转路径调整
func _adjust_target_value(_start: Vector3, targetValue: Vector3, _isAdd: bool) -> Vector3:
	return targetValue
