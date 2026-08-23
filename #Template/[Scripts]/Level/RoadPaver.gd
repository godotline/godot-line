extends Node3D

@export var baseFloor: PackedScene
@export var roadWidth: float = 2.0
@export var roadHeight: float = 1.0

var player: Player
var roadHolder: Node3D
var roadObject: StaticBody3D
var road: StaticBody3D
var roadIndex: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	player = Player.instance
	if not player:
		player = get_parent() as Player
	if not player:
		push_error("RoadPaver.gd: Player.instance 未找到，无法铺路")
		return
	if not baseFloor:
		push_error("RoadPaver.gd: baseFloor 场景为空，无法铺路")
		return

	var currentScene: Node = get_tree().current_scene
	if not currentScene:
		push_error("RoadPaver.gd: 当前场景为空，无法创建 RoadHolder")
		return

	roadHolder = Node3D.new()
	roadHolder.name = "RoadHolder"

	var onTurn: Signal = player.OnTurn
	if not onTurn.is_connected(_on_player_turn):
		onTurn.connect(_on_player_turn)

	call_deferred("_attach_road_holder")

func _attach_road_holder() -> void:
	if not is_instance_valid(roadHolder):
		return
	var currentScene: Node = get_tree().current_scene
	if not currentScene:
		push_error("RoadPaver.gd: 当前场景为空，无法创建 RoadHolder")
		return
	if not roadHolder.is_inside_tree():
		currentScene.add_child(roadHolder)
	if not roadObject:
		_prepare_road_object()
	if roadObject and not road:
		_create_road()

func _prepare_road_object() -> void:
	if not baseFloor:
		return

	var instance: Node = baseFloor.instantiate()
	baseFloor = null
	roadObject = instance as StaticBody3D
	if roadObject:
		return

	push_error("RoadPaver.gd: baseFloor 根节点必须是 StaticBody3D")
	if instance:
		instance.queue_free()

func _create_road() -> void:
	if not player or not roadHolder or not roadObject:
		return

	var nextRoad: StaticBody3D = roadObject.duplicate() as StaticBody3D
	if not nextRoad:
		push_error("RoadPaver.gd: roadObject 复制失败")
		return

	nextRoad.name = "Road %d" % roadIndex
	roadIndex += 1
	roadHolder.add_child(nextRoad)
	nextRoad.owner = roadHolder
	nextRoad.scale = Vector3(roadWidth, roadHeight, roadWidth)
	nextRoad.global_position = _get_road_position()
	nextRoad.global_rotation = player.global_rotation
	road = nextRoad

func _get_road_position() -> Vector3:
	var verticalOffset: float = 0.5 * (roadHeight + 1.0)
	return player.global_position - Vector3(0.0, verticalOffset, 0.0)

func _on_player_turn() -> void:
	# Player emits OnTurn before applying its new rotation; defer until the turn is complete.
	call_deferred("_create_road")

func _process(delta: float) -> void:
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if not is_instance_valid(player) or not is_instance_valid(road):
		return

	var distance: float = player.Speed * delta
	road.scale = Vector3(roadWidth, roadHeight, road.scale.z + distance)
	var localTranslation: Vector3 = Vector3(0.0, 0.0, 0.5 * distance)
	var rotationBasis: Basis = road.global_transform.basis.orthonormalized()
	road.global_position += rotationBasis * localTranslation
