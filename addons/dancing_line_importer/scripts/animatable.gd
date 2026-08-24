extends Node
class_name Animatable

## ARPhros objects[].animatable 自动画组件（语义经游戏 il2cpp dump 实证：Arphros.Animatable）
## 触发模式 StartMode：ByDistance=0（玩家进入 distanceMinimum 半径）/ ByTime=1（音乐时间≥timeMinimum）
## 触发后按 ease 播放一次性补间（isInvoked 锁存，复活回退到更早检查点时复位重触发）
## ease=punch 时冲出后回落原位；其余缓动停在目标位（与 LeanTween 行为一致）

enum StartMode { ByDistance, ByTime }

@export_group("触发")
@export var mode: StartMode = StartMode.ByDistance
@export var timeMinimum: float = 0.0
@export var distanceMinimum: float = 12.0
@export_group("补间")
@export var offsetPosition: Vector3 = Vector3.ZERO
@export var duration: float = 2.0
@export var transType: Tween.TransitionType = Tween.TRANS_SINE
@export var easeType: Tween.EaseType = Tween.EASE_IN_OUT
## LeanTween punch 曲线近似：先冲到目标（QUART/OUT）再弹回原位（ELASTIC/OUT）
@export var punchReturn: bool = false
@export var dontRevive: bool = false

var _invoked: bool = false
var _basePos: Vector3 = Vector3.ZERO
var _tween: Tween = null
var _triggerIndex: int = -1
var _cachedPlayer: Node3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var target := get_parent() as Node3D
	if target == null:
		return
	_basePos = target.position
	set_process(true)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _invoked:
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	match mode:
		StartMode.ByDistance:
			if _playerWithin(distanceMinimum):
				Invoke()
		StartMode.ByTime:
			var player := _getPlayer()
			if player == null:
				return
			var music := player.get_node_or_null("MusicPlayer") as AudioStreamPlayer
			if music != null and music.playing and music.get_playback_position() > timeMinimum:
				Invoke()


func _playerWithin(radius: float) -> bool:
	var player := _getPlayer()
	if player == null:
		return false
	var target := get_parent() as Node3D
	if target == null:
		return false
	var diff: Vector3 = player.global_position - target.global_position
	return diff.length_squared() <= radius * radius


func _getPlayer() -> Node3D:
	if not is_instance_valid(_cachedPlayer):
		var p: Player = Player.instance
		_cachedPlayer = p as Node3D if p != null else null
	return _cachedPlayer


## 触发一次性补间（对应 Arphros.Animatable.OnAnimationTriggered 的 isInvoked 锁存）
func Invoke() -> void:
	if _invoked:
		return
	_invoked = true
	_triggerIndex = LevelManager.checkpointCount
	LevelManager.add_revive_listener(_on_revive)
	var target := get_parent() as Node3D
	if target == null or offsetPosition == Vector3.ZERO:
		return
	target.position = _basePos
	_tween = create_tween()
	if punchReturn:
		# 近似 LeanTween punch：快出 + 弹性回落原位
		_tween.tween_property(target, "position", _basePos + offsetPosition, duration * 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_tween.tween_property(target, "position", _basePos, duration * 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(target, "position", _basePos + offsetPosition, duration).set_trans(transType).set_ease(easeType)


func ResetToOriginal() -> void:
	if not dontRevive:
		_invoked = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_tween = null
	if not dontRevive:
		var target := get_parent() as Node3D
		if target != null:
			target.position = _basePos


func _on_revive() -> void:
	LevelManager.remove_revive_listener(_on_revive)
	LevelManager.CompareCheckpointIndex(_triggerIndex, func() -> void:
		if is_instance_valid(self):
			ResetToOriginal()
	)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	LevelManager.remove_revive_listener(_on_revive)
