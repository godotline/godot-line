extends Node3D

@export var base_floor: PackedScene
@export var road_width: float = 2.0
@export var road_height: float = 1.0

var player: Player
var road_holder: Node3D
var road_object: StaticBody3D
var road: StaticBody3D
var road_index: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	player = Player.instance
	if not player:
		player = get_parent() as Player
	if not player:
		push_error("RoadPaver.gd: Player.instance 未找到，无法铺路")
		return
	if not base_floor:
		push_error("RoadPaver.gd: base_floor 场景为空，无法铺路")
		return

	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		push_error("RoadPaver.gd: 当前场景为空，无法创建 RoadHolder")
		return

	road_holder = Node3D.new()
	road_holder.name = "RoadHolder"

	var on_turn: Signal = player.onturn
	if not on_turn.is_connected(_on_player_turn):
		on_turn.connect(_on_player_turn)

	call_deferred("_attach_road_holder")

func _attach_road_holder() -> void:
	if not is_instance_valid(road_holder):
		return
	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		push_error("RoadPaver.gd: 当前场景为空，无法创建 RoadHolder")
		return
	if not road_holder.is_inside_tree():
		current_scene.add_child(road_holder)
	if not road_object:
		_prepare_road_object()
	if road_object and not road:
		_create_road()

func _prepare_road_object() -> void:
	if not base_floor:
		return

	var instance: Node = base_floor.instantiate()
	base_floor = null
	road_object = instance as StaticBody3D
	if road_object:
		return

	push_error("RoadPaver.gd: base_floor 根节点必须是 StaticBody3D")
	if instance:
		instance.queue_free()

func _create_road() -> void:
	if not player or not road_holder or not road_object:
		return

	var next_road: StaticBody3D = road_object.duplicate() as StaticBody3D
	if not next_road:
		push_error("RoadPaver.gd: road_object 复制失败")
		return

	next_road.name = "Road %d" % road_index
	road_index += 1
	road_holder.add_child(next_road)
	next_road.owner = road_holder
	next_road.scale = Vector3(road_width, road_height, road_width)
	next_road.global_position = _get_road_position()
	next_road.global_rotation = player.global_rotation
	road = next_road

func _get_road_position() -> Vector3:
	var vertical_offset: float = 0.5 * (road_height + 1.0)
	return player.global_position - Vector3(0.0, vertical_offset, 0.0)

func _on_player_turn() -> void:
	# Player emits onturn before applying its new rotation; defer until the turn is complete.
	call_deferred("_create_road")

func _process(delta: float) -> void:
	if LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if not is_instance_valid(player) or not is_instance_valid(road):
		return

	var distance: float = player.speed * delta
	road.scale = Vector3(road_width, road_height, road.scale.z + distance)
	var local_translation: Vector3 = Vector3(0.0, 0.0, 0.5 * distance)
	var rotation_basis: Basis = road.global_transform.basis.orthonormalized()
	road.global_position += rotation_basis * local_translation
