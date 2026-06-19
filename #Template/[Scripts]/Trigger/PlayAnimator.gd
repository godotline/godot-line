extends Node3D

## 动画播放触发器 - 纯组件模式
## 作为 BaseTrigger 的子节点，依赖父节点处理碰撞

@export var animators: Array[AnimationPlayer] = []
@export var dont_revive: bool = false

var _played: Array[bool] = []
var _finished: Array[bool] = []
var _progress: Array[float] = []
var _play_state: Array[bool] = []
var _trigger_index := -1
var _last_checkpoint_count := 0
var _waiting_to_resume := false
var _process_enabled := false  ## 是否需要 _process 轮询

func _ready() -> void:
	_last_checkpoint_count = LevelManager.checkpoint_count
	set_process(false)  ## 默认关闭，避免空跑
	for player in animators:
		if player:
			player.speed_scale = 0.0
		_played.append(false)
		_finished.append(false)
		_progress.append(0.0)
		_play_state.append(false)

func _process(_delta: float) -> void:
	var should_disable := true

	if LevelManager.checkpoint_count > _last_checkpoint_count:
		_trigger_index = LevelManager.checkpoint_count
		for i in animators.size():
			_get_state(i)
		_last_checkpoint_count = LevelManager.checkpoint_count

	if _waiting_to_resume and LevelManager.GameState == LevelManager.GameStatus.Playing:
		for i in animators.size():
			if _play_state[i] and is_instance_valid(animators[i]):
				animators[i].play()
		_waiting_to_resume = false
	elif _waiting_to_resume:
		should_disable = false  ## 还在等待恢复，继续轮询

	if should_disable:
		set_process(false)  ## 工作完成，关闭 _process

## 由父节点 BaseTrigger 调用的入口方法
func trigger(_body: Node3D) -> void:
	if LevelManager.GameState == LevelManager.GameStatus.Waiting or LevelManager.GameState == LevelManager.GameStatus.Died:
		return
	for i in animators.size():
		if not _finished[i]:
			_play(i)
			_play_state[i] = true
	set_process(true)  ## 触发后启用 _process 监听 checkpoint 变化
	if _trigger_index < 0:
		_trigger_index = LevelManager.checkpoint_count
	if not dont_revive:
		LevelManager.remove_revive_listener(_on_revive)
		LevelManager.add_revive_listener(_on_revive)

func _play(index: int) -> void:
	if index >= animators.size():
		return
	var player = animators[index]
	if not is_instance_valid(player):
		return
	player.speed_scale = 1.0
	for anim_name in player.get_animation_list():
		if anim_name != "RESET":
			player.play(anim_name)
			break
	_played[index] = true
	_finished[index] = true

func _stop(index: int) -> void:
	if index >= animators.size():
		return
	var player = animators[index]
	if is_instance_valid(player):
		player.stop()

func _get_state(index: int) -> void:
	if index >= animators.size():
		return
	var player = animators[index]
	if not is_instance_valid(player):
		return
	var anim_name = player.current_animation
	if anim_name != "":
		var anim = player.get_animation(anim_name)
		if anim and anim.get_length() > 0.0:
			_progress[index] = player.current_animation_position / anim.get_length()
	_play_state[index] = _played[index]

func _set_state(index: int) -> void:
	if index >= animators.size():
		return
	var player = animators[index]
	if not is_instance_valid(player):
		return
	var anim_name = ""
	for _name in player.get_animation_list():
		if _name != "RESET":
			anim_name = _name
			break
	if anim_name != "":
		player.play(anim_name)
		var anim = player.get_animation(anim_name)
		if anim:
			player.seek(_progress[index] * anim.get_length(), true)
	player.pause()
	_played[index] = _play_state[index]

func _on_revive() -> void:
	if not is_instance_valid(self):
		return
	LevelManager.remove_revive_listener(_on_revive)

	for i in animators.size():
		if _play_state[i] and is_instance_valid(animators[i]):
			var player = animators[i]
			if player.is_playing():
				var _name = player.current_animation
				if _name != "":
					var anim = player.get_animation(name)
					if anim and anim.get_length() > 0:
						_progress[i] = player.current_animation_position / anim.get_length()

	for i in animators.size():
		_seek_and_pause(i)

	LevelManager.CompareCheckpointIndex(_trigger_index, func():
		if not is_instance_valid(self):
			return
		for i in animators.size():
			if not dont_revive:
				_finished[i] = false
		_waiting_to_resume = true
		set_process(true)  ## 复活后启用 _process 等待恢复
		LevelManager.add_revive_listener(_on_revive)
	)

func _seek_and_pause(index: int) -> void:
	if index >= animators.size():
		return
	var player = animators[index]
	if not is_instance_valid(player):
		return
	var anim_name = ""
	for _name in player.get_animation_list():
		if _name != "RESET":
			anim_name = _name
			break
	if anim_name != "":
		player.play(anim_name)
		var anim = player.get_animation(anim_name)
		if anim:
			player.seek(_progress[index] * anim.get_length(), true)
	player.pause()

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_revive)
