extends Area3D

@export var animators: Array[NodePath] = []
@export var dont_revive: bool = false

var _animation_players: Array[AnimationPlayer] = []
var _played: Array[bool] = []
var _finished: Array[bool] = []
var _progress: Array[float] = []
var _play_state: Array[bool] = []
var _trigger_index := -1
var _last_checkpoint_count := 0
var _waiting_to_resume := false

func _ready() -> void:
	_last_checkpoint_count = LevelManager.checkpoint_count
	for path in animators:
		var node = get_node_or_null(path)
		if node is AnimationPlayer:
			_animation_players.append(node)
			node.speed_scale = 0.0
			_played.append(false)
			_finished.append(false)
			_progress.append(0.0)
			_play_state.append(false)

func _process(_delta: float) -> void:
	if LevelManager.checkpoint_count > _last_checkpoint_count:
		_trigger_index = LevelManager.checkpoint_count
		for i in _animation_players.size():
			_get_state(i)
		_last_checkpoint_count = LevelManager.checkpoint_count
	if _waiting_to_resume and LevelManager.GameState == LevelManager.GameStatus.Playing:
		for i in _animation_players.size():
			if _play_state[i]:
				_animation_players[i].play()
		_waiting_to_resume = false

func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	if LevelManager.GameState == LevelManager.GameStatus.Waiting or LevelManager.GameState == LevelManager.GameStatus.Died:
		return
	for i in _animation_players.size():
		if not _finished[i]:
			_play(i)
	if not dont_revive:
		LevelManager.remove_revive_listener(_on_revive)
		LevelManager.add_revive_listener(_on_revive)

func _play(index: int) -> void:
	var player = _animation_players[index]
	player.speed_scale = 1.0
	for anim_name in player.get_animation_list():
		if anim_name != "RESET":
			player.play(anim_name)
			break
	_played[index] = true
	_finished[index] = true

func _stop(index: int) -> void:
	_animation_players[index].stop()

func _get_state(index: int) -> void:
	var player = _animation_players[index]
	var anim_name = player.current_animation
	if anim_name != "":
		var anim = player.get_animation(anim_name)
		if anim and anim.get_length() > 0.0:
			_progress[index] = player.current_animation_position / anim.get_length()
	_play_state[index] = _played[index]

func _set_state(index: int) -> void:
	var player = _animation_players[index]
	var anim_name = ""
	for name in player.get_animation_list():
		if name != "RESET":
			anim_name = name
			break
	if anim_name != "":
		player.play(anim_name)
		var anim = player.get_animation(anim_name)
		if anim:
			player.seek(_progress[index] * anim.get_length(), true)
	player.pause()
	_played[index] = _play_state[index]

func _on_revive() -> void:
	LevelManager.remove_revive_listener(_on_revive)
	for i in _animation_players.size():
		_seek_and_pause(i)
	LevelManager.CompareCheckpointIndex(_trigger_index, func():
		for i in _animation_players.size():
			if not dont_revive:
				_finished[i] = false
		_waiting_to_resume = true
		LevelManager.add_revive_listener(_on_revive)
	)

func _seek_and_pause(index: int) -> void:
	var player = _animation_players[index]
	var anim_name = ""
	for name in player.get_animation_list():
		if name != "RESET":
			anim_name = name
			break
	if anim_name != "":
		player.play(anim_name)
		var anim = player.get_animation(anim_name)
		if anim:
			player.seek(_progress[index] * anim.get_length(), true)
	player.pause()

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_revive)
