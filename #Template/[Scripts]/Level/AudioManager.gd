class_name AudioManager
extends RefCounted
## AudioManager - 音频管理工具
## 音效播放、音乐控制、音量管理、淡入淡出
## 所有方法和属性均为静态，可直接 AudioManager.xxx() 调用

## 播放一次性音效（自动创建 AudioStreamPlayer，按音频时长销毁）
##  Unity 等效: AudioManager.PlayClip(clip, volume)
static func PlayClip(clip: AudioStream, volume: float = 1.0) -> void:
	if not clip or not Player.instance or not is_instance_valid(Player.instance):
		return
	var sceneRoot: Node = Player.instance.get_tree().current_scene
	if not sceneRoot:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = clip
	player.volume_db = linear_to_db(max(volume, 0.001))
	sceneRoot.add_child(player)
	player.play()
	var clipLength: float = clip.get_length()
	if clipLength > 0.0:
		sceneRoot.get_tree().create_timer(clipLength).timeout.connect(player.queue_free)
	else:
		player.finished.connect(player.queue_free)

## 播放背景音乐，返回 AudioStreamPlayer 以便后续控制
##  Unity 等效: AudioManager.PlayTrack(clip, volume) → AudioSource
static func PlayTrack(clip: AudioStream, volume: float = 1.0) -> AudioStreamPlayer:
	if not clip or not Player.instance or not is_instance_valid(Player.instance):
		return null
	var sceneRoot: Node = Player.instance.get_tree().current_scene
	if not sceneRoot:
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = clip
	player.volume_db = linear_to_db(max(volume, 0.001))
	sceneRoot.add_child(player)
	player.play()
	return player

## 音乐播放位置（秒）
static var time: float:
	get:
		var p: AudioStreamPlayer = _get_music_player()
		return p.get_playback_position() if p else 0.0
	set(value):
		var p: AudioStreamPlayer = _get_music_player()
		if p:
			var wasPlaying: bool = p.playing
			var wasPaused: bool = p.stream_paused
			p.play(value)
			p.stream_paused = wasPaused or not wasPlaying

## 音乐播放速度（音高偏移，1.0 = 正常）
static var Pitch: float:
	get:
		var p: AudioStreamPlayer = _get_music_player()
		return p.pitch_scale if p else 1.0
	set(value):
		var p: AudioStreamPlayer = _get_music_player()
		if p:
			p.pitch_scale = value

## 音乐音量（线性 0.0 ~ 1.0）
static var Volume: float:
	get:
		var p: AudioStreamPlayer = _get_music_player()
		return db_to_linear(p.volume_db) if p else 0.0
	set(value):
		var p: AudioStreamPlayer = _get_music_player()
		if p:
			p.volume_db = linear_to_db(max(value, 0.001))

## 音乐播放进度（0.0 ~ 1.0），考虑 useCustomLevelTime
static var Progress: float:
	get:
		var player: Player = Player.instance
		if not player:
			return 0.0
		var p: AudioStreamPlayer = _get_music_player()
		if not p or not p.stream:
			return 0.0
		if player.levelData and player.levelData.useCustomLevelTime:
			return p.get_playback_position() / max(player.levelData.levelTotalTime, 0.001)
		return p.get_playback_position() / max(p.stream.get_length(), 0.001)

## 停止音乐
static func Stop() -> void:
	var p: AudioStreamPlayer = _get_music_player()
	if p:
		p.stop()

## 恢复播放音乐
static func Play() -> void:
	var p: AudioStreamPlayer = _get_music_player()
	if p:
		if p.stream_paused:
			p.stream_paused = false
		else:
			p.play()

## 淡出音乐到目标音量后停止
##  Unity 等效: AudioManager.FadeOut(volume, duration)
static func FadeOut(targetVolume: float = 0.0, duration: float = 10.0) -> Tween:
	var p: AudioStreamPlayer = _get_music_player()
	if not p:
		return null
	var tween: Tween = p.create_tween()
	tween.tween_property(p, "volume_db", linear_to_db(max(targetVolume, 0.001)), duration).set_trans(Tween.TRANS_LINEAR)
	tween.finished.connect(func(): Stop())
	return tween

static func _get_music_player() -> AudioStreamPlayer:
	if not Player.instance or not is_instance_valid(Player.instance):
		return null
	return Player.instance.SoundTrack
