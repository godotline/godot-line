class_name State
extends RefCounted

## ========== 持久化检查点数据 ==========

static var main_line_transform 
static var revive_position := Vector3.ZERO
static var is_turn := false
static var anim_time := 0.0
static var music_checkpoint_time := 0.0
static var is_end := false
static var percent := 0
static var line_crossing_crown := 0
static var crowns := [0, 0, 0]
static var is_relive := false
#后续代码补充，如果玩家在本局有复活即is_live=true就在结算时 crown -= 1
static var diamond := 0
static var crown := 0

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





## ============================================================
## 保存检查点（Crown 触发时调用）
## ============================================================

static func save_checkpoint(main_line: PhysicsBody3D, camera_follower: Node3D, revive_pos: Node3D = null) -> void:
	if revive_pos:
		revive_position = revive_pos.global_position
	main_line_transform = main_line.transform
	is_turn = main_line.is_turn
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
		print("State: save_checkpoint offset=", camera_checkpoint.offset, " rot=", camera_checkpoint.rotation_degrees, " rot_offset=", camera_checkpoint.rotation_offset, " target_add_pos=", camera_checkpoint.target_add_position, " target_rot=", camera_checkpoint.target_rotation, " mode=", camera_checkpoint.rotate_mode, " base_rot=", camera_checkpoint.base_rotation)
	
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
	print("State: load_to_camera_follower add_pos=", cf.add_position, " rot_offset=", cf.rotation_offset, " mode=", cf._current_rotate_mode, " base_rot=", cf._base_rotation, " target_add_pos=", cf._target_add_position, " target_rot=", cf._target_rotation, " target_speed=", cf._target_follow_speed, " target_dist=", cf._target_distance)


## ============================================================
## SaveKit 序列化 / 反序列化
## ============================================================

## 使用 SaveKitSerializer 序列化所有状态属性到字典
static func save_to_dict(s: SaveKitSerializer) -> Dictionary:
	return {
		"main_line_transform": s.encode_var(main_line_transform),
		"camera_checkpoint": s.encode_var(camera_checkpoint),

		"is_turn": s.encode_var(is_turn),
		"anim_time": s.encode_var(anim_time),
		"music_checkpoint_time": s.encode_var(music_checkpoint_time),
		"is_end": s.encode_var(is_end),
		"percent": s.encode_var(percent),
		"line_crossing_crown": s.encode_var(line_crossing_crown),
		"crowns": s.encode_var(crowns),
		"is_relive": s.encode_var(is_relive),
		"diamond": s.encode_var(diamond),
		"crown": s.encode_var(crown),
	}


## 使用 SaveKitDeserializer 从字典反序列化所有状态属性
static func load_from_dict(s: SaveKitDeserializer, data: Dictionary) -> void:
	if data.has("main_line_transform"):
		main_line_transform = s.decode_var(data["main_line_transform"], TYPE_TRANSFORM3D)
	if data.has("camera_checkpoint"):
		camera_checkpoint = s.decode_var(data["camera_checkpoint"], TYPE_DICTIONARY)

	if data.has("is_turn"):
		is_turn = s.decode_var(data["is_turn"], TYPE_BOOL)
	if data.has("anim_time"):
		anim_time = s.decode_var(data["anim_time"], TYPE_FLOAT)
	if data.has("music_checkpoint_time"):
		music_checkpoint_time = s.decode_var(data["music_checkpoint_time"], TYPE_FLOAT)
	if data.has("is_end"):
		is_end = s.decode_var(data["is_end"], TYPE_BOOL)
	if data.has("percent"):
		percent = s.decode_var(data["percent"], TYPE_INT)
	if data.has("line_crossing_crown"):
		line_crossing_crown = s.decode_var(data["line_crossing_crown"], TYPE_INT)
	if data.has("crowns"):
		crowns = s.decode_var(data["crowns"], TYPE_ARRAY)
	if data.has("is_relive"):
		is_relive = s.decode_var(data["is_relive"], TYPE_BOOL)
	if data.has("diamond"):
		diamond = s.decode_var(data["diamond"], TYPE_INT)
	if data.has("crown"):
		crown = s.decode_var(data["crown"], TYPE_INT)


## ============================================================
## 重置
## ============================================================

static func reset_to_defaults() -> void:
	main_line_transform = null
	revive_position = Vector3.ZERO
	reset_camera_checkpoint()

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
