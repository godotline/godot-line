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
func apply_to(main_line: MainLine, space_rid: RID = RID()) -> void:
	if main_line:
		main_line.speed = speed
	Engine.time_scale = timeScale
	if space_rid.is_valid():
		PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, gravity.normalized())
		PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, gravity.length())
	
	for single_color in colors:
		if single_color:
			single_color.apply()


## 获取音频流（用于播放）
func get_audio_stream() -> AudioStream:
	return levelAudioClip


## 获取音频开始时间（根据检查点）
func get_audio_start_time() -> float:
	var start_time := State.music_checkpoint_time if State.music_checkpoint_time > 0.0 else State.anim_time
	return start_time if start_time > 0.0 else 0.0
