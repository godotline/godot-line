extends Node3D
class_name GuidanceController

static var Instance: GuidanceController

@export var createBoxes: bool = false
@export var createLines: bool = true
@export var boxHolder: Node3D
@export var guidanceBoxColor: Color = Color.WHITE
@export var lineGap: float = 0.2

var _player: Player
var _player_transform: Node3D
var _boxes: Array[Node3D] = []
var _holder: Node3D
var _id: int = 0
var _box_scene: PackedScene
var _box_size_y: float = 1.0
var _started: bool = false
var _original_created: bool = false
var _forward: float = 0.0

func _ready() -> void:
	Instance = self
	_id = 0
	_box_scene = load("res://#Template/[Resources]/GuidanceBox.tscn")
	if _box_scene:
		var boxProbe: Node3D = _box_scene.instantiate() as Node3D
		if boxProbe:
			_box_size_y = boxProbe.scale.y
			boxProbe.free()
	if createBoxes:
		_holder = Node3D.new()
		_holder.name = "GuidanceBoxHolder"
		get_tree().current_scene.add_child(_holder)
	if boxHolder:
		for child in boxHolder.get_children():
			if child is Node3D:
				_boxes.append(child)
	for b in _boxes:
		_set_color(b, guidanceBoxColor)
	if createLines:
		_generate_lines()
	set_process(true)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = Player.instance
		if not is_instance_valid(_player):
			return
		_player_transform = _player

	_forward = _player.secondDirection.y if _player.rotation_degrees.y == _player.firstDirection.y else _player.firstDirection.y
	if createBoxes and not _original_created:
		var originalBox: Node3D = _spawn_box(
			_player_transform.global_position - Vector3(0, 0.45, 0),
			_player.firstDirection.y
		)
		if originalBox:
			originalBox.name = "OriginalGuidanceBox"
			var originalGuidanceBox: GuidanceBox = _find_guidance_box(originalBox)
			if originalGuidanceBox:
				originalGuidanceBox.canBeTriggered = false
			_original_created = true

	if createBoxes and LevelManager.GameState == LevelManager.GameStatus.Playing and not _started:
		if not _player.OnTurn.is_connected(_on_player_turn):
			_player.OnTurn.connect(_on_player_turn)
		_started = true

func _find_guidance_box(node: Node) -> GuidanceBox:
	if node is GuidanceBox:
		return node as GuidanceBox
	for child in node.get_children():
		var found: GuidanceBox = _find_guidance_box(child)
		if found:
			return found
	return null

func _on_player_turn() -> void:
	var box: Node3D = _spawn_box(
		_player_transform.global_position - Vector3(0, 0.45, 0),
		_forward
	)
	if box:
		box.name = "GuidanceBox %d" % _id
		_id += 1

func _spawn_box(pos: Vector3, rot_y: float) -> Node3D:
	if not _box_scene or not is_instance_valid(_holder):
		push_error("GuidanceController.gd: GuidanceBox 场景未加载，无法生成引导盒")
		return null
	var box: Node3D = _box_scene.instantiate() as Node3D
	_holder.add_child(box)
	box.global_position = pos
	box.rotation_degrees = Vector3(0, rot_y, 0)
	return box

func _set_color(box: Node3D, color: Color) -> void:
	var gb: GuidanceBox = _find_guidance_box(box)
	if gb:
		gb.SetColor(color)

func _generate_lines() -> void:
	for i in range(_boxes.size()):
		if i + 1 >= _boxes.size():
			break
		var a: Node3D = _boxes[i]
		var b: Node3D = _boxes[i + 1]
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		var gb: GuidanceBox = _find_guidance_box(a)
		if gb and not gb.haveLine:
			continue
		var midpoint: Vector3 = 0.5 * (a.global_position + b.global_position)
		var dist: float = a.global_position.distance_to(b.global_position)
		var lineLength: float = dist - 0.5 * _box_size_y - 2 * lineGap
		if lineLength <= 0.0:
			continue
		var line: MeshInstance3D = MeshInstance3D.new()
		line.mesh = BoxMesh.new()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = guidanceBoxColor
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.set_surface_override_material(0, mat)
		var wrapper: Node3D = Node3D.new()
		wrapper.add_child(line)
		a.add_child(wrapper)
		wrapper.global_position = midpoint
		var direction: Vector3 = (b.global_position - a.global_position).normalized()
		var up: Vector3 = Vector3.FORWARD if abs(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var right: Vector3 = direction.cross(up).normalized()
		var forward: Vector3 = right.cross(direction).normalized()
		wrapper.global_transform.basis = Basis(right, direction, forward)
		wrapper.set_scale(Vector3(0.15, lineLength, 0.15))
		wrapper.name = "%s - Line" % a.name
