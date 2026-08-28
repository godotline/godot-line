extends Node

## 动画播放触发器 - 纯组件模式
## 作为 BaseTrigger 的子节点，依赖父节点处理碰撞

@export var animators: Array[AnimationPlayer] = []
@export var dontRevive: bool = false

var played: Array[bool] = []
var finished: Array[bool] = []
var progress: Array[float] = []
var playState: Array[bool] = []
var animationNames: Array[StringName] = []
var waitingToResume: bool = false

func _ready() -> void:
	add_to_group("checkpoint_animators")
	for player: AnimationPlayer in animators:
		if is_instance_valid(player):
			player.speed_scale = 0.0
		played.append(false)
		finished.append(false)
		progress.append(0.0)
		playState.append(false)
		animationNames.append(StringName())
	set_process(false)

func _process(delta: float) -> void:
	if not waitingToResume:
		set_process(false)
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return

	for index: int in range(animators.size()):
		if playState[index] and is_instance_valid(animators[index]):
			animators[index].speed_scale = 1.0
			animators[index].play()
	waitingToResume = false
	set_process(false)

## 由父节点 BaseTrigger 调用的入口方法
func trigger(body: Node3D) -> bool:
	if LevelManager.GameState == LevelManager.GameStatus.Waiting or LevelManager.GameState == LevelManager.GameStatus.Died:
		return false
	for index: int in range(animators.size()):
		if not finished[index]:
			_play(index)
	return true

## Called by Checkpoint when its state is captured.
func capture_checkpoint_state() -> void:
	if dontRevive:
		return
	for index: int in range(animators.size()):
		_get_state(index)

## Called by Checkpoint after the player has been restored.
func restore_checkpoint_state() -> void:
	if dontRevive:
		return

	var resumeAfterStart: bool = false
	for index: int in range(animators.size()):
		if not played[index]:
			continue
		_set_state(index)
		if playState[index]:
			resumeAfterStart = true

	waitingToResume = resumeAfterStart
	set_process(waitingToResume)

func _play(index: int) -> void:
	if index >= animators.size():
		return
	var player: AnimationPlayer = animators[index]
	if not is_instance_valid(player):
		return
	player.speed_scale = 1.0
	var animationName: StringName = _find_animation_name(player)
	if not animationName.is_empty():
		player.play(animationName)
	played[index] = true
	finished[index] = true

func _stop(index: int) -> void:
	if index >= animators.size():
		return
	var player: AnimationPlayer = animators[index]
	if is_instance_valid(player):
		player.stop()

func _get_state(index: int) -> void:
	if index >= animators.size():
		return
	var player: AnimationPlayer = animators[index]
	if not is_instance_valid(player):
		return
	var animationName: StringName = player.current_animation
	animationNames[index] = animationName
	if not animationName.is_empty() and player.has_animation(animationName):
		var animation: Animation = player.get_animation(animationName)
		if animation and animation.get_length() > 0.0:
			progress[index] = player.current_animation_position / animation.get_length()
	playState[index] = played[index]

func _set_state(index: int) -> void:
	if index >= animators.size():
		return
	var player: AnimationPlayer = animators[index]
	if not is_instance_valid(player):
		return
	var animationName: StringName = animationNames[index]
	if animationName.is_empty() or animationName == "RESET" or not player.has_animation(animationName):
		animationName = _find_animation_name(player)
	if not animationName.is_empty():
		player.speed_scale = 1.0
		player.play(animationName)
		var animation: Animation = player.get_animation(animationName)
		if animation:
			player.seek(progress[index] * animation.get_length(), true)
	player.pause()
	played[index] = playState[index]
	finished[index] = playState[index]

func _find_animation_name(player: AnimationPlayer) -> StringName:
	for animationName: StringName in player.get_animation_list():
		if animationName != "RESET":
			return animationName
	return StringName()

func _exit_tree() -> void:
	waitingToResume = false