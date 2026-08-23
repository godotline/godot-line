class_name LevelManager
extends RefCounted

## ========== 游戏状态枚举 ==========

enum GameStatus {
	Waiting,
	Playing,
	Moving,
	Died,
	Completed
}

enum Direction {
	First,
	Second
}

## ========== 游戏状态管理 ==========

static var GameState: GameStatus = GameStatus.Waiting
static var getInput: bool = true

## 帧缓存 — Clicked 状态（每帧只计算一次）
static var clickedCached: bool = false
static var clickedFrame: int = -1

static var Clicked: bool:
	get:
		if not getInput:
			return false
		var currentFrame: int = Engine.get_process_frames()
		if currentFrame != clickedFrame:
			clickedCached = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
				or Input.is_key_pressed(KEY_SPACE) \
				or Input.is_key_pressed(KEY_ENTER) \
				or Input.is_key_pressed(KEY_KP_ENTER)
			clickedFrame = currentFrame
		return clickedCached

static var DefaultGravity: Vector3:
	get:
		return Vector3(0.0, -9.3, 0.0)

static var PlayerPosition: Vector3:
	get:
		if Player.instance:
			return Player.instance.global_position
		return Vector3.ZERO
	set(value):
		if Player.instance:
			Player.instance.global_position = value

static var CameraPosition: Vector3:
	get:
		if OldCameraFollower.instance:
			return OldCameraFollower.instance.global_position
		return Vector3.ZERO
	set(value):
		if OldCameraFollower.instance:
			OldCameraFollower.instance.global_position = value

## ========== 复活信号 ==========

signal player_revived

static var reviveListeners: Array[Callable] = []

static func add_revive_listener(callable: Callable) -> void:
	if callable not in reviveListeners:
		reviveListeners.append(callable)

static func remove_revive_listener(callable: Callable) -> void:
	reviveListeners.erase(callable)

static func emit_revive() -> void:
	var listenersSnapshot: Array[Callable] = reviveListeners.duplicate()
	for listener in listenersSnapshot:
		if listener.is_valid():
			listener.call()
		else:
			# 移除无效的 listener
			reviveListeners.erase(listener)

static func reset_revive_listeners() -> void:
	reviveListeners.clear()

## ========== 持久化检查点数据 ==========

## 检查点尚未建立时为空，建立后保存主线变换。
static var mainLineTransform: Variant = null
static var revivePosition: Vector3 = Vector3.ZERO
static var isTurn: bool = false
static var playerDirectionIndex: int = 0
static var animTime: float = 0.0
static var musicCheckpointTime: float = 0.0
static var isEnd: bool = false
static var percent: int = 0
static var lineCrossingCrown: int = 0
static var crowns: Array[int] = [0, 0, 0]
static var isRelive: bool = false
static var gem: int = 0
static var crown: int = 0
static var currentCheckpoint: Node = null
static var checkpointCount: int = 0
static var playerSpeed: float = 12.0
static var gravity: Vector3 = Vector3(0, -9.8, 0)
static var playerFirstDirection: Vector3 = Vector3.ZERO
static var playerSecondDirection: Vector3 = Vector3.ZERO

## 相机跟随器检查点数据，整合为字典结构
static var cameraCheckpoint: Dictionary = {
	"has_checkpoint": false,
	"restore_pending": false,
	"offset": Vector3.ZERO,
	"rotation_degrees": Vector3.ZERO,
	"rotation_offset": Vector3.ZERO,
	"distance": 0.0,
	"follow_speed": 0.0,
	"rotate_mode": 0,
	"base_rotation": Vector3.ZERO,
	"target_add_position": Vector3.ZERO,
	"target_follow_speed": 0.0,
	"target_distance": 0.0,
	"target_rotation": Vector3.ZERO,
}

## ============================================================
## 保存检查点（Crown 触发时调用）
## ============================================================

static func save_checkpoint(mainLine: PhysicsBody3D, cameraFollower: Node3D, revivePos: Node3D = null) -> void:
	if revivePos:
		revivePosition = revivePos.global_position
	mainLineTransform = mainLine.transform
	isTurn = mainLine._currentDirection == 1
	playerDirectionIndex = mainLine._currentDirection
	playerFirstDirection = mainLine.firstDirection
	playerSecondDirection = mainLine.secondDirection
	playerSpeed = mainLine.Speed
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity_vector") * ProjectSettings.get_setting("physics/3d/default_gravity")
	if mainLine.animationNode and mainLine.animationNode.current_animation:
		animTime = mainLine.animationNode.current_animation_position

	if cameraFollower:
		cameraCheckpoint.offset = cameraFollower.addPosition
		cameraCheckpoint.rotation_degrees = cameraFollower.rotationOffset
		cameraCheckpoint.rotation_offset = cameraFollower.rotationOffset
		cameraCheckpoint.distance = cameraFollower.distanceFromObject
		cameraCheckpoint.follow_speed = cameraFollower.followSpeed
		cameraCheckpoint.rotate_mode = cameraFollower.currentRotateMode
		cameraCheckpoint.base_rotation = cameraFollower.baseRotation
		cameraCheckpoint.target_add_position = cameraFollower.targetAddPosition
		cameraCheckpoint.target_follow_speed = cameraFollower.targetFollowSpeed
		cameraCheckpoint.target_distance = cameraFollower.targetDistance
		cameraCheckpoint.target_rotation = cameraFollower.targetRotation
		cameraCheckpoint.has_checkpoint = true
		print("LevelManager: save_checkpoint offset=", cameraCheckpoint.offset, " rot=", cameraCheckpoint.rotation_degrees, " rot_offset=", cameraCheckpoint.rotation_offset, " target_add_pos=", cameraCheckpoint.target_add_position, " target_rot=", cameraCheckpoint.target_rotation, " mode=", cameraCheckpoint.rotate_mode, " base_rot=", cameraCheckpoint.base_rotation)

	var musicPlayer: AudioStreamPlayer = mainLine.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if not musicPlayer:
		push_error("LevelManager.gd: MusicPlayer 节点未找到，无法保存音乐检查点时间")
	elif musicPlayer.playing:
		musicCheckpointTime = musicPlayer.get_playback_position()

## ============================================================
## 加载检查点到游戏对象
## ============================================================

static func load_checkpoint_to_main_line(mainLine: CharacterBody3D) -> void:
	if mainLineTransform:
		mainLine.transform = mainLineTransform
		if revivePosition != Vector3.ZERO:
			mainLine.global_position = revivePosition
		mainLine.isTurn = isTurn
		mainLine._currentDirection = playerDirectionIndex
		mainLine.firstDirection = playerFirstDirection
		mainLine.secondDirection = playerSecondDirection
		mainLine.Speed = playerSpeed
	PhysicsServer3D.area_set_param(mainLine.get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, gravity.length())
	PhysicsServer3D.area_set_param(mainLine.get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, gravity.normalized() if gravity.length() > 0 else Vector3.DOWN)


static func load_to_camera_follower(cf: Node3D) -> void:
	var cp: Dictionary = cameraCheckpoint
	if not cp.has_checkpoint:
		return
	cf.addPosition = cp.offset
	cf.rotationOffset = cp.rotation_offset
	cf.distanceFromObject = cp.distance
	cf.followSpeed = cp.follow_speed
	cf.currentRotateMode = cp.rotate_mode
	cf.baseRotation = cp.base_rotation
	cf.targetAddPosition = cp.get("target_add_position", cf.addPosition)
	cf.targetFollowSpeed = cp.get("target_follow_speed", cf.followSpeed)
	cf.targetDistance = cp.get("target_distance", cf.distanceFromObject)
	cf.targetRotation = cp.get("target_rotation", cf.rotationOffset)
	print("LevelManager: load_to_camera_follower add_pos=", cf.addPosition, " rot_offset=", cf.rotationOffset, " mode=", cf.currentRotateMode, " base_rot=", cf.baseRotation, " target_add_pos=", cf.targetAddPosition, " target_rot=", cf.targetRotation, " target_speed=", cf.targetFollowSpeed, " target_dist=", cf.targetDistance)


## ============================================================
## 重置
## ============================================================

static func reset_to_defaults() -> void:
	mainLineTransform = null
	revivePosition = Vector3.ZERO
	reset_camera_checkpoint()

	playerSpeed = 12.0
	gravity = Vector3(0, -9.8, 0)
	playerFirstDirection = Vector3.ZERO
	playerSecondDirection = Vector3.ZERO
	playerDirectionIndex = 0
	isTurn = false
	animTime = 0.0
	musicCheckpointTime = 0.0
	isEnd = false
	percent = 0
	lineCrossingCrown = 0
	crowns = [0, 0, 0]
	isRelive = false
	gem = 0
	crown = 0
	currentCheckpoint = null
	checkpointCount = 0
	GameState = GameStatus.Waiting

## 重置相机检查点为默认值
static func reset_camera_checkpoint() -> void:
	cameraCheckpoint = {
		"has_checkpoint": false,
		"restore_pending": false,
		"offset": Vector3.ZERO,
		"rotation_degrees": Vector3.ZERO,
		"rotation_offset": Vector3.ZERO,
		"distance": 0.0,
		"follow_speed": 0.0,
		"rotate_mode": 0,
		"base_rotation": Vector3.ZERO,
		"target_add_position": Vector3.ZERO,
		"target_follow_speed": 0.0,
		"target_distance": 0.0,
		"target_rotation": Vector3.ZERO,
	}

## ============================================================
## 游戏结束处理
## ============================================================

static func GameOverNormal(complete: bool) -> void:
	if complete:
		percent = 100
	elif Player.instance:
		var p: Player = Player.instance
		var musicPlayer: AudioStreamPlayer = p.get_node_or_null("MusicPlayer") as AudioStreamPlayer
		if musicPlayer and musicPlayer.stream:
			var totalSec: float = p.levelData.levelTotalTime if p.levelData and p.levelData.useCustomLevelTime else musicPlayer.stream.get_length()
			var currentSec: float = musicPlayer.get_playback_position()
			percent = int((currentSec / totalSec) * 100) if totalSec > 0 else 0

	if GameState == GameStatus.Died or GameState == GameStatus.Completed or GameState == GameStatus.Moving:
		# 对齐 Unity LevelManager.GameOverNormal：直接调用 LevelUI.Instance.NormalPage
		isEnd = true
		var ui: LevelUI = LevelUI.instance
		if ui:
			ui.show_end_ui()

static func GameOverRevive() -> void:
	if GameState == GameStatus.Died or GameState == GameStatus.Moving:
		if Player.instance:
			var p: Player = Player.instance
			var musicPlayer: AudioStreamPlayer = p.get_node_or_null("MusicPlayer") as AudioStreamPlayer
			if musicPlayer and musicPlayer.stream:
				var totalSec: float = p.levelData.levelTotalTime if p.levelData and p.levelData.useCustomLevelTime else musicPlayer.stream.get_length()
				var currentSec: float = musicPlayer.get_playback_position()
				percent = int((currentSec / totalSec) * 100) if totalSec > 0 else 0
		isEnd = true
		# 对齐 Unity LevelManager.GameOverRevive：直接调用 LevelUI.Instance.RevivePage
		var ui: LevelUI = LevelUI.instance
		if ui:
			ui.show_end_ui()

## ============================================================
## 辅助方法
## ============================================================

## 传送：设置玩家位置、强制相机跟随、改变朝向
static func InitPlayerPosition(player: CharacterBody3D, position: Vector3, forceCamera: bool = false, doTurn: bool = false, targetDir: Direction = Direction.First) -> void:
	player.global_position = position

	if doTurn:
		var dirIndex: int = 0 if targetDir == Direction.First else 1
		player._currentDirection = dirIndex
		player.rotation_degrees = player.currentDirection
		# 转向后重新计算速度方向
		player.velocity = player.to_global(Vector3(0, 0, 1) * player.Speed) - player.global_position

	if forceCamera:
		var cf: CameraFollower = CameraFollower.instance
		if cf:
			cf.position = position
			cf.follow = true

		var ocf: OldCameraFollower = OldCameraFollower.instance
		if ocf:
			ocf.global_position = position
			ocf.follow = true

static func DestroyRemain() -> void:
	GameState = GameStatus.Waiting

static func CompareCheckpointIndex(index: int, callback: Callable = Callable()) -> Variant:
	if index > checkpointCount - 1:
		if callback.is_valid():
			callback.call()
			return null
		return true
	return false

static func SetFPSLimit(frame: int) -> void:
	Engine.max_fps = frame

static func GetColorByContent(color: Color) -> Color:
	var brightness: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color.BLACK if brightness > 0.6 else Color.WHITE
