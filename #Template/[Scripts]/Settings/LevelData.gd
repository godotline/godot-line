@tool
class_name LevelData
extends Resource

## 关卡数据资源，用于存储关卡配置

@export var saveID: int = 0
@export var levelTitleKey: String = "LevelName"
@export var speed: float = 12.0
@export var timeScale: float = 1.0
@export var gravity: Vector3 = Vector3(0, -9.8, 0)
@export var playerHeadBoxColliderSize: Vector3 = Vector3(0.3, 1.0, 0.3)

@export var levelAudioClip: AudioStream
@export var useCustomLevelTime: bool = false
@export var levelTotalTime: float = 0.0
@export var haveMultipleAudio: bool = false
@export var audioClips: Array[AudioStream] = []

@export var colors: Array[SingleColor] = []
@export var levelTitle: String = "LevelName"
@export var authors: Array[AuthorInfo] = []


## 应用关卡数据到游戏
func apply_to(main_line: Player, space_rid: RID = RID()) -> void:
	if main_line:
		main_line.speed = speed
		_apply_player_collider_size(main_line)
	Engine.time_scale = timeScale
	if space_rid.is_valid():
		PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, gravity.normalized())
		PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, gravity.length())
	
	for single_color in colors:
		if single_color:
			single_color.apply()
	
	# 应用时间缩放对音乐的影响
	_apply_time_scale_to_music(main_line)


## 获取音频流（用于播放）
func get_audio_stream() -> AudioStream:
	return levelAudioClip


## 获取音频开始时间（根据检查点）
func get_audio_start_time() -> float:
	var start_time := 	LevelManager.music_checkpoint_time if 	LevelManager.music_checkpoint_time > 0.0 else 	LevelManager.anim_time
	return start_time if start_time > 0.0 else 0.0


## 应用时间缩放到音乐播放器
func _apply_time_scale_to_music(main_line: Player) -> void:
	if main_line and main_line.has_node("MusicPlayer"):
		var music_player: AudioStreamPlayer = main_line.get_node("MusicPlayer")
		music_player.pitch_scale = timeScale


## 获取时间缩放
func get_time_scale() -> float:
	return timeScale


## 应用玩家碰撞体大小
func _apply_player_collider_size(main_line: Player) -> void:
	if main_line.has_node("CollisionShape3D"):
		var collider: CollisionShape3D = main_line.get_node("CollisionShape3D")
		if collider.shape is BoxShape3D:
			(collider.shape as BoxShape3D).size = playerHeadBoxColliderSize
