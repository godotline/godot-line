extends Node3D
class_name GuidanceController

static var Instance: GuidanceController

@export var create_boxes: bool = false
@export var create_lines: bool = true
@export var box_holder: Node3D
@export var guidance_color: Color = Color.WHITE
@export var line_gap: float = 0.2

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
		var box_probe: Node3D = _box_scene.instantiate() as Node3D
		if box_probe:
			_box_size_y = box_probe.scale.y
			box_probe.free()
	if create_boxes:
		_holder = Node3D.new()
		_holder.name = "GuidanceBoxHolder"
		get_tree().current_scene.add_child(_holder)
	if box_holder:
		for child in box_holder.get_children():
			if child is Node3D:
				_boxes.append(child)
	for b in _boxes:
		_set_color(b, guidance_color)
	if create_lines:
		_generate_lines()
	set_process(true)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = Player.instance
		if not is_instance_valid(_player):
			return
		_player_transform = _player

	_forward = _player.secondDirection.y if _player.rotation_degrees.y == _player.firstDirection.y else _player.firstDirection.y
	if create_boxes and not _original_created:
		var original_box: Node3D = _spawn_box(
			_player_transform.global_position - Vector3(0, 0.45, 0),
			_player.firstDirection.y
		)
		if original_box:
			original_box.name = "OriginalGuidanceBox"
			var original_guidance_box: GuidanceBox = _find_guidance_box(original_box)
			if original_guidance_box:
				original_guidance_box.can_be_triggered = false
			_original_created = true

	if create_boxes and LevelManager.GameState == LevelManager.GameStatus.Playing and not _started:
		if not _player.onturn.is_connected(_on_player_turn):
			_player.onturn.connect(_on_player_turn)
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
		gb.set_color(color)

func _generate_lines() -> void:
	for i in range(_boxes.size()):
		if i + 1 >= _boxes.size():
			break
		var a: Node3D = _boxes[i]
		var b: Node3D = _boxes[i + 1]
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		var gb: GuidanceBox = _find_guidance_box(a)
		if gb and not gb.have_line:
			continue
		var midpoint: Vector3 = 0.5 * (a.global_position + b.global_position)
		var dist: float = a.global_position.distance_to(b.global_position)
		var line_length: float = dist - 0.5 * _box_size_y - 2 * line_gap
		if line_length <= 0.0:
			continue
		var line: MeshInstance3D = MeshInstance3D.new()
		line.mesh = BoxMesh.new()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = guidance_color
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
		wrapper.set_scale(Vector3(0.15, line_length, 0.15))
		wrapper.name = "%s - Line" % a.name
