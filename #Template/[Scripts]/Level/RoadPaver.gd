extends Node
class_name RoadPaver

@export var roadObject: PackedScene
@export var roadWidth: float = 2.0
@export var roadHeight: float = 1.0

var player: Player
var roadHolder: Node3D
var road: Node3D
var roadIndex: int = 0

func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	player = Player.instance
	if not player or not roadObject:
		return

	roadHolder = Node3D.new()
	roadHolder.name = "RoadHolder"
	get_tree().current_scene.add_child(roadHolder)

	_create_road()
	player.OnTurn.connect(_create_road)

func _create_road() -> void:
	var spawnPos: Vector3 = _get_road_position()
	road = roadObject.instantiate() as Node3D
	road.name = "Road %d" % roadIndex
	roadIndex += 1
	roadHolder.add_child(road)
	road.scale = Vector3(roadWidth, roadHeight, roadWidth)
	road.global_position = spawnPos
	road.global_rotation = player.global_rotation

func _get_road_position() -> Vector3:
	return player.global_position - Vector3(0.0, 0.5 * (roadHeight + 1.0), 0.0)

func _process(delta: float) -> void:
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if not is_instance_valid(road):
		return
	var distance: float = player.Speed * delta
	road.scale = Vector3(roadWidth, roadHeight, road.scale.z + distance)
	road.global_position += (road.global_transform.basis * Vector3.BACK).normalized() * 0.5 * distance
