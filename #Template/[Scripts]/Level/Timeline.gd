class_name Timeline
extends RefCounted

## Timeline 进度保存/恢复。对齐 Unity Player.GetTimelineProgresses / SetTimelineProgresses。
## 所有方法均为静态，可直接 Timeline.xxx() 调用。

static var timelineProgresses: Array[float] = []

static func GetTimelineProgresses(autoRecord: bool, gameTime: float) -> void:
	timelineProgresses.clear()
	var timelines: Array[AnimationPlayer] = _playedTimelines()
	if autoRecord:
		for player: AnimationPlayer in timelines:
			timelineProgresses.append(_getTime(player))
	else:
		timelineProgresses.resize(timelines.size())
		timelineProgresses.fill(gameTime)

static func SetTimelineProgresses() -> void:
	var timelines: Array[AnimationPlayer] = _playedTimelines()
	var musicDelay: float = _musicDelay()
	var count: int = mini(timelines.size(), timelineProgresses.size())
	for index: int in range(count):
		var player: AnimationPlayer = timelines[index]
		if not is_instance_valid(player):
			continue
		_evaluate(player, timelineProgresses[index] + musicDelay)
		player.speed_scale = 1.0

static func Pause() -> void:
	for player: AnimationPlayer in _playedTimelines():
		if is_instance_valid(player):
			player.pause()

static func Play() -> void:
	for player: AnimationPlayer in _playedTimelines():
		if is_instance_valid(player):
			player.play()

static func Reset() -> void:
	for player: AnimationPlayer in _playedTimelines():
		if not is_instance_valid(player):
			continue
		_evaluate(player, 0.0)
		player.pause()

static func _playedTimelines() -> Array[AnimationPlayer]:
	var mainLine: Player = Player.instance
	if not mainLine:
		var empty: Array[AnimationPlayer] = []
		return empty
	return mainLine.playedTimelines

static func _musicDelay() -> float:
	var mainLine: Player = Player.instance
	if mainLine:
		return mainLine.musicDelay
	return SetLatency.load_settings().get("delay", 0.0) as float

static func _getTime(player: AnimationPlayer) -> float:
	if not is_instance_valid(player):
		return 0.0
	if player.current_animation.is_empty() and player.assigned_animation.is_empty():
		return 0.0
	return player.current_animation_position

static func _evaluate(player: AnimationPlayer, time: float) -> void:
	var animationName: StringName = player.current_animation
	if animationName.is_empty():
		animationName = player.assigned_animation
	if animationName.is_empty() or not player.has_animation(animationName):
		return
	if player.current_animation != animationName:
		player.play(animationName)
		player.pause()
	player.seek(time, true)
