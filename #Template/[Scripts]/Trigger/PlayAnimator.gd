extends Node

## 动画播放触发器 - 纯组件模式
## 作为 BaseTrigger 的子节点，依赖父节点处理碰撞

@export var animators: Array[AnimationPlayer] = []
@export var dont_revive: bool = false

var _played: Array[bool] = []
var _finished: Array[bool] = []
var _progress: Array[float] = []
var _play_state: Array[bool] = []
var _animation_names: Array[StringName] = []
var _waiting_to_resume: bool = false

func _ready() -> void:
	add_to_group("checkpoint_animators")
	for player: AnimationPlayer in animators:
		if is_instance_valid(player):
			player.speed_scale = 0.0
		_played.append(false)
		_finished.append(false)
		_progress.append(0.0)
		_play_state.append(false)
		_animation_names.append(StringName())
	set_process(false)

func _process(_delta: float) -> void:
	if not _waiting_to_resume:
		set_process(false)
		return
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return

	for index: int in range(animators.size()):
		if _play_state[index] and is_instance_valid(animators[index]):
			animators[index].speed_scale = 1.0
			animators[index].play()
	_waiting_to_resume = false
	set_process(false)

## 由父节点 BaseTrigger 调用的入口方法
func trigger(_body: Node3D) -> void:
	if LevelManager.GameState == LevelManager.GameStatus.Waiting or LevelManager.GameState == LevelManager.GameStatus.Died:
		return
	for index: int in range(animators.size()):
		if not _finished[index]:
			_play(index)

## Called by Checkpoint when its state is captured.
func capture_checkpoint_state() -> void:
	if dont_revive:
		return
	for index: int in range(animators.size()):
		_get_state(index)

## Called by Checkpoint after the player has been restored.
func restore_checkpoint_state() -> void:
	if dont_revive:
		return

	var resume_after_start: bool = false
	for index: int in range(animators.size()):
		if not _played[index]:
			continue
		_set_state(index)
		if _play_state[index]:
			resume_after_start = true

	_waiting_to_resume = resume_after_start
	set_process(_waiting_to_resume)

func _play(index: int) -> void:
	if index >= animators.size():
		return
	var player: AnimationPlayer = animators[index]
	if not is_instance_valid(player):
		return
	player.speed_scale = 1.0
	var animation_name: StringName = _find_animation_name(player)
	if not animation_name.is_empty():
		player.play(animation_name)
	_played[index] = true
	_finished[index] = true

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
	var animation_name: StringName = player.current_animation
	_animation_names[index] = animation_name
	if not animation_name.is_empty() and player.has_animation(animation_name):
		var animation: Animation = player.get_animation(animation_name)
		if animation and animation.get_length() > 0.0:
			_progress[index] = player.current_animation_position / animation.get_length()
	_play_state[index] = _played[index]

func _set_state(index: int) -> void:
	if index >= animators.size():
		return
	var player: AnimationPlayer = animators[index]
	if not is_instance_valid(player):
		return
	var animation_name: StringName = _animation_names[index]
	if animation_name.is_empty() or animation_name == "RESET" or not player.has_animation(animation_name):
		animation_name = _find_animation_name(player)
	if not animation_name.is_empty():
		player.speed_scale = 1.0
		player.play(animation_name)
		var animation: Animation = player.get_animation(animation_name)
		if animation:
			player.seek(_progress[index] * animation.get_length(), true)
	player.pause()
	_played[index] = _play_state[index]
	_finished[index] = _play_state[index]

func _find_animation_name(player: AnimationPlayer) -> StringName:
	for animation_name: StringName in player.get_animation_list():
		if animation_name != "RESET":
			return animation_name
	return StringName()

func _exit_tree() -> void:
	_waiting_to_resume = false
