class_name TrackSwitcher
extends Node

## 对应 Unity TimelineTrackSwitcher：在同一 AnimationPlayer 上维护
## Track_Default / Track_Target 两条等长动画，通过切换"当前动画"实现音轨的静音/启用。
## 切换时保持播放头位置（等价 Unity 的 RebuildGraph + time 还原）。
##
## 使用方式：
##   1. 在关卡中放置一个 AnimationPlayer，内含两条等长动画 Track_Default / Track_Target；
##   2. 在其子级挂载本组件（animationPlayer 留空时自动取父节点）；
##   3. 组件会自动把自己的 AnimationPlayer 注册到 Player.playedTimelines，
##      由现有的启动暂停/恢复与检查点位置捕获机制统一同步。

@export_group("Main Player")
## 目标 AnimationPlayer；留空时使用父节点
@export var animationPlayer: NodePath
@export_group("Checkpoint Memory Settings")
## 启用后，轨道状态在检查点保存并在复活时恢复（对齐 Unity enableCheckpointMemory）
@export var enableCheckpointMemory: bool = true
@export_group("Track Configuration")
@export var defaultTrackName: String = "Track_Default"
@export var targetTrackName: String = "Track_Target"

var onTarget: bool = false          ## 当前是否处于目标轨道
var savedOnTarget: bool = false     ## 检查点保存的轨道状态

func _ready() -> void:
	add_to_group("timeline_track_switchers")
	# 延迟注册：等待 Player.instance 就绪（树内 _ready 顺序不保证）
	if not Engine.is_editor_hint():
		_registerToPlayer.call_deferred()

## 自动把管理的 AnimationPlayer 注册到 Player.playedTimelines（去重）
func _registerToPlayer() -> void:
	var player: AnimationPlayer = _resolvePlayer()
	if player == null:
		push_warning("TrackSwitcher.gd: 未找到 AnimationPlayer，请检查 animationPlayer NodePath")
		return
	var mainLine: Player = Player.instance
	if mainLine and not mainLine.playedTimelines.has(player):
		mainLine.playedTimelines.append(player)

func _resolvePlayer() -> AnimationPlayer:
	var resolved: AnimationPlayer = get_node_or_null(animationPlayer) as AnimationPlayer
	if resolved == null:
		resolved = get_parent() as AnimationPlayer
	return resolved

## 切换到目标轨道（Default 静音，Target 生效）
func SwitchToTargetTrack() -> void:
	_SetTrackState(true)

## 切回默认轨道（Default 生效，Target 静音）
func SwitchToDefaultTrack() -> void:
	_SetTrackState(false)

func _SetTrackState(onTargetState: bool) -> void:
	onTarget = onTargetState
	var player: AnimationPlayer = _resolvePlayer()
	if player == null:
		return
	var targetAnim: StringName = targetTrackName if onTargetState else defaultTrackName
	if not player.has_animation(targetAnim):
		push_warning("TrackSwitcher.gd: animation not found - %s" % targetAnim)
		return
	if player.current_animation == StringName(targetAnim):
		return
	# 保持播放头位置切换（对齐 Unity RefreshGraphState：RebuildGraph + time 还原）
	var pos: float = player.current_animation_position
	var wasPlaying: bool = player.is_playing()
	player.play(targetAnim)
	player.seek(pos, true)
	if not wasPlaying:
		player.pause()

## 检查点保存轨道状态（对齐 Unity SaveState）
func SaveState() -> void:
	if not enableCheckpointMemory:
		return
	savedOnTarget = onTarget

## 复活时恢复轨道状态（对齐 Unity RestoreState）
func RestoreState() -> void:
	if not enableCheckpointMemory:
		return
	_SetTrackState(savedOnTarget)
