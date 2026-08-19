extends Node3D

@export var offset: Vector3 = Vector3.ZERO
@export var keepOriginY: bool = false
@export var playerPath: NodePath

var player: Player

func _ready() -> void:
	player = get_node_or_null(playerPath) as Player if not playerPath.is_empty() else Player.instance

func _process(_delta: float) -> void:
	if LevelManager.GameState != LevelManager.GameStatus.Moving and LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if not player:
		player = Player.instance
	if not player:
		return
	var targetPosition: Vector3 = player.global_position + offset
	if keepOriginY:
		targetPosition.y = global_position.y
	global_position = targetPosition
