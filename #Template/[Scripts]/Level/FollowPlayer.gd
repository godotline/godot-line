extends Node3D

@export var offset: Vector3 = Vector3.ZERO
@export var keep_origin_y: bool = false
@export var player_path: NodePath

var _player: Player

func _ready() -> void:
	_player = get_node_or_null(player_path) as Player if not player_path.is_empty() else Player.instance

func _process(_delta: float) -> void:
	if LevelManager.GameState != LevelManager.GameStatus.Moving and LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if not _player:
		_player = Player.instance
	if not _player:
		return
	var target_position: Vector3 = _player.global_position + offset
	if keep_origin_y:
		target_position.y = global_position.y
	global_position = target_position
