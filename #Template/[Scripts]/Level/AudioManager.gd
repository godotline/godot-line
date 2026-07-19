class_name AudioManager
extends RefCounted
## AudioManager - 音频管理工具
## 音效播放、音乐控制、音量管理、淡入淡出
## 所有方法和属性均为静态，可直接 AudioManager.xxx() 调用

## 播放一次性音效（自动创建 AudioStreamPlayer，播放完后自动销毁）
##  Unity 等效: AudioManager.PlayClip(clip, volume)
static func play_clip(clip: AudioStream, volume: float = 1.0) -> void:
	if not clip or not Player.instance:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = clip
	player.volume_db = linear_to_db(max(volume, 0.001))
	Player.instance.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

## 播放背景音乐，返回 AudioStreamPlayer 以便后续控制
##  Unity 等效: AudioManager.PlayTrack(clip, volume) → AudioSource
static func play_track(clip: AudioStream, volume: float = 1.0) -> AudioStreamPlayer:
	if not clip or not Player.instance:
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = clip
	player.volume_db = linear_to_db(max(volume, 0.001))
	Player.instance.add_child(player)
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
			p.play(value)

## 音乐播放速度（音高偏移，1.0 = 正常）
static var pitch: float:
	get:
		var p: AudioStreamPlayer = _get_music_player()
		return p.pitch_scale if p else 1.0
	set(value):
		var p: AudioStreamPlayer = _get_music_player()
		if p:
			p.pitch_scale = value

## 音乐音量（线性 0.0 ~ 1.0）
static var volume: float:
	get:
		var p: AudioStreamPlayer = _get_music_player()
		return db_to_linear(p.volume_db) if p else 0.0
	set(value):
		var p: AudioStreamPlayer = _get_music_player()
		if p:
			p.volume_db = linear_to_db(max(value, 0.001))

## 音乐播放进度（0.0 ~ 1.0），考虑 useCustomLevelTime
static var progress: float:
	get:
		var player: Player = Player.instance
		if not player:
			return 0.0
		var p: AudioStreamPlayer = _get_music_player()
		if not p or not p.stream:
			return 0.0
		if player.level_data and player.level_data.useCustomLevelTime:
			return p.get_playback_position() / max(player.level_data.levelTotalTime, 0.001)
		return p.get_playback_position() / max(p.stream.get_length(), 0.001)

## 停止音乐
static func stop() -> void:
	var p: AudioStreamPlayer = _get_music_player()
	if p:
		p.stop()

## 恢复播放音乐
static func play() -> void:
	var p: AudioStreamPlayer = _get_music_player()
	if p:
		p.play()

## 淡出音乐到目标音量后停止
##  Unity 等效: AudioManager.FadeOut(volume, duration)
static func fade_out(target_volume: float = 0.0, duration: float = 10.0) -> void:
	var p: AudioStreamPlayer = _get_music_player()
	if not p:
		return
	var tween: Tween = p.create_tween()
	tween.tween_property(p, "volume_db", linear_to_db(max(target_volume, 0.001)), duration)
	tween.finished.connect(func(): stop())

static func _get_music_player() -> AudioStreamPlayer:
	if not Player.instance:
		return null
	return Player.instance.get_node_or_null("MusicPlayer") as AudioStreamPlayer
