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

static var game_state: GameStatus = GameStatus.Waiting
static var get_input := true

static var clicked: bool:
	get:
		if get_input:
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)
		return false

static var default_gravity: Vector3:
	get:
		return Vector3(0.0, -9.3, 0.0)

static var player_position: Vector3:
	get:
		if Player.instance:
			return Player.instance.global_position
		return Vector3.ZERO
	set(value):
		if Player.instance:
			Player.instance.global_position = value

static var camera_position: Vector3:
	get:
		if OldCameraFollower.instance:
			return OldCameraFollower.instance.global_position
		return Vector3.ZERO
	set(value):
		if OldCameraFollower.instance:
			OldCameraFollower.instance.global_position = value

## ========== 复活信号 ==========

signal player_revived

static var _revive_listeners: Array[Callable] = []

static func add_revive_listener(callable: Callable) -> void:
	if callable not in _revive_listeners:
		_revive_listeners.append(callable)

static func remove_revive_listener(callable: Callable) -> void:
	_revive_listeners.erase(callable)

static func emit_revive() -> void:
	for listener in _revive_listeners:
		listener.call()

static func reset_revive_listeners() -> void:
	_revive_listeners.clear()

## ========== 持久化检查点数据 ==========

static var main_line_transform
static var revive_position := Vector3.ZERO
static var is_turn := false
static var player_direction_index := 0
static var anim_time := 0.0
static var music_checkpoint_time := 0.0
static var is_end := false
static var percent := 0
static var line_crossing_crown := 0
static var crowns := [0, 0, 0]
static var is_relive := false
static var diamond := 0
static var crown := 0
static var current_checkpoint: Node = null
static var player_speed := 12.0
static var gravity := Vector3(0, -9.8, 0)
static var player_first_direction := Vector3.ZERO
static var player_second_direction := Vector3.ZERO

## 相机跟随器检查点数据，整合为字典结构
static var camera_checkpoint := {
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

static func save_checkpoint(main_line: PhysicsBody3D, camera_follower: Node3D, revive_pos: Node3D = null) -> void:
	if revive_pos:
		revive_position = revive_pos.global_position
	main_line_transform = main_line.transform
	is_turn = main_line._currentDirection == 1
	player_direction_index = main_line._currentDirection
	player_first_direction = main_line.firstDirection
	player_second_direction = main_line.secondDirection
	player_speed = main_line.speed
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity_vector") * ProjectSettings.get_setting("physics/3d/default_gravity")
	if main_line.animation_node and main_line.animation_node.current_animation:
		anim_time = main_line.animation_node.current_animation_position

	if camera_follower:
		camera_checkpoint.offset = camera_follower.position - main_line.position
		camera_checkpoint.rotation_degrees = camera_follower.rotation_degrees
		camera_checkpoint.rotation_offset = camera_follower.rotation_offset
		camera_checkpoint.distance = camera_follower.distance_from_object
		camera_checkpoint.follow_speed = camera_follower.follow_speed
		camera_checkpoint.rotate_mode = camera_follower._current_rotate_mode
		camera_checkpoint.base_rotation = camera_follower._base_rotation
		camera_checkpoint.target_add_position = camera_follower._target_add_position
		camera_checkpoint.target_follow_speed = camera_follower._target_follow_speed
		camera_checkpoint.target_distance = camera_follower._target_distance
		camera_checkpoint.target_rotation = camera_follower._target_rotation
		camera_checkpoint.has_checkpoint = true
		print("LevelManager: save_checkpoint offset=", camera_checkpoint.offset, " rot=", camera_checkpoint.rotation_degrees, " rot_offset=", camera_checkpoint.rotation_offset, " target_add_pos=", camera_checkpoint.target_add_position, " target_rot=", camera_checkpoint.target_rotation, " mode=", camera_checkpoint.rotate_mode, " base_rot=", camera_checkpoint.base_rotation)

	var music_player := main_line.get_node("MusicPlayer") as AudioStreamPlayer
	if music_player and music_player.playing:
		music_checkpoint_time = music_player.get_playback_position()

## ============================================================
## 加载检查点到游戏对象
## ============================================================

static func load_checkpoint_to_main_line(main_line: CharacterBody3D) -> void:
	if main_line_transform:
		main_line.transform = main_line_transform
		if revive_position != Vector3.ZERO:
			main_line.global_position = revive_position
		main_line.is_turn = is_turn
		main_line._currentDirection = player_direction_index
		main_line.firstDirection = player_first_direction
		main_line.secondDirection = player_second_direction
		main_line.speed = player_speed
	PhysicsServer3D.area_set_param(main_line.get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, gravity.length())
	PhysicsServer3D.area_set_param(main_line.get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, gravity.normalized() if gravity.length() > 0 else Vector3.DOWN)


static func load_to_camera_follower(cf: Node3D) -> void:
	var cp := camera_checkpoint
	if not cp.has_checkpoint:
		return
	cf.add_position = cp.offset
	cf.rotation_offset = cp.rotation_offset
	cf.distance_from_object = cp.distance
	cf.follow_speed = cp.follow_speed
	cf._current_rotate_mode = cp.rotate_mode
	cf._base_rotation = cp.base_rotation
	cf._target_add_position = cp.get("target_add_position", cf.add_position)
	cf._target_follow_speed = cp.get("target_follow_speed", cf.follow_speed)
	cf._target_distance = cp.get("target_distance", cf.distance_from_object)
	cf._target_rotation = cp.get("target_rotation", cf.rotation_offset)
	print("LevelManager: load_to_camera_follower add_pos=", cf.add_position, " rot_offset=", cf.rotation_offset, " mode=", cf._current_rotate_mode, " base_rot=", cf._base_rotation, " target_add_pos=", cf._target_add_position, " target_rot=", cf._target_rotation, " target_speed=", cf._target_follow_speed, " target_dist=", cf._target_distance)


## ============================================================
## 重置
## ============================================================

static func reset_to_defaults() -> void:
	main_line_transform = null
	revive_position = Vector3.ZERO
	reset_camera_checkpoint()

	player_speed = 12.0
	gravity = Vector3(0, -9.8, 0)
	player_first_direction = Vector3.ZERO
	player_second_direction = Vector3.ZERO
	player_direction_index = 0
	is_turn = false
	anim_time = 0.0
	music_checkpoint_time = 0.0
	is_end = false
	percent = 0
	line_crossing_crown = 0
	crowns = [0, 0, 0]
	is_relive = false
	diamond = 0
	crown = 0
	game_state = GameStatus.Waiting

## 重置相机检查点为默认值
static func reset_camera_checkpoint() -> void:
	camera_checkpoint = {
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

static func game_over_normal(complete: bool) -> void:
	var percentage := 1.0 if complete else 0.0
	if game_state == GameStatus.Died or game_state == GameStatus.Completed or game_state == GameStatus.Moving:
		if Player.instance and Player.instance.has_method("get_block_count"):
			pass
		# 触发UI显示，由gameui.gd监听is_end
		is_end = true

static func game_over_revive() -> void:
	if game_state == GameStatus.Died or game_state == GameStatus.Moving:
		is_end = true

## ============================================================
## 辅助方法
## ============================================================

static func destroy_remain() -> void:
	game_state = GameStatus.Waiting

static func compare_checkpoint_index(index: int, callback: Callable) -> void:
	if Player.instance and index > Player.instance.get("Checkpoints").size() - 1:
		callback.call()

static func compare_checkpoint_index_bool(index: int) -> bool:
	if Player.instance and index > Player.instance.get("Checkpoints").size() - 1:
		return true
	return false

static func set_fps_limit(frame: int) -> void:
	Engine.max_fps = frame

static func get_color_by_content(color: Color) -> Color:
	var brightness := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color.BLACK if brightness > 0.6 else Color.WHITE
