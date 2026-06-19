extends Node3D
class_name GuidanceController

static var Instance: GuidanceController

@export var create_boxes: bool = false
@export var create_lines: bool = true
@export var box_holder: Node3D
@export var guidance_color: Color = Color.WHITE
@export var line_gap: float = 0.2
@export var box_size_y: float = 1.0

var _player: CharacterBody3D
var _boxes: Array[Node3D] = []
var _holder: Node3D
var _id: int = 0
var _box_scene: PackedScene
var _started: bool = false

func _ready() -> void:
	Instance = self
	_id = 0
	_box_scene = load("res://#Template/[Resources]/GuidanceBox.tscn")
	set_process(false)  ## 默认关闭，用信号驱动
	if create_boxes:
		_holder = Node3D.new()
		_holder.name = "GuidanceBoxHolder"
		get_tree().current_scene.add_child.call_deferred(_holder)
	if box_holder:
		for child in box_holder.get_children():
			if child is Node3D:
				_boxes.append(child)
	for b in _boxes:
		_set_color(b, guidance_color)
	if create_lines and not _boxes.is_empty():
		_generate_lines()
	# 用信号驱动替代轮询
	if Player.instance:
		_connect_player_signals()
	else:
		# Player 还没就绪，等一帧
		await get_tree().process_frame
		if Player.instance:
			_connect_player_signals()

func _connect_player_signals() -> void:
	_player = Player.instance
	if not _player:
		return
	if create_boxes:
		_player.on_player_start.connect(_on_player_start)

func _on_player_start() -> void:
	if not create_boxes:
		return
	if not _holder or not _holder.is_inside_tree():
		return
	var box := _spawn_box(
		_player.global_position - Vector3(0, 0.45, 0),
		_player.firstDirection.y
	)
	box.name = "OriginalGuidanceBox"
	var gb := _find_guidance_box(box)
	if gb:
		gb.can_be_triggered = false
	_player.onturn.connect(_on_player_turn)

func _find_guidance_box(node: Node) -> GuidanceBox:
	for child in node.get_children():
		if child is GuidanceBox:
			return child
		var found := _find_guidance_box(child)
		if found:
			return found
	return null

func _on_player_turn() -> void:
	if create_boxes and LevelManager.GameState == LevelManager.GameStatus.Playing:
		var forward_y: float
		if _player.rotation_degrees.y == _player.firstDirection.y:
			forward_y = _player.secondDirection.y
		else:
			forward_y = _player.firstDirection.y
		var box := _spawn_box(
			_player.global_position - Vector3(0, 0.45, 0),
			forward_y
		)
		box.name = "GuidanceBox %d" % _id
		_id += 1

func _spawn_box(pos: Vector3, rot_y: float) -> Node3D:
	var box := _box_scene.instantiate() as Node3D
	_holder.add_child(box)
	box.global_position = pos
	box.rotation_degrees = Vector3(0, rot_y, 0)
	return box

func _set_color(box: Node3D, color: Color) -> void:
	var gb := _find_guidance_box(box)
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
		var gb := _find_guidance_box(a)
		if gb and not gb.have_line:
			continue
		var midpoint := 0.5 * (a.global_position + b.global_position)
		var dist := a.global_position.distance_to(b.global_position)
		var line_length := dist - 0.5 * box_size_y - 2 * line_gap
		if line_length <= 0.0:
			continue
		var line := MeshInstance3D.new()
		line.mesh = BoxMesh.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = guidance_color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.set_surface_override_material(0, mat)
		var wrapper := Node3D.new()
		wrapper.add_child(line)
		a.add_child(wrapper)
		wrapper.global_position = midpoint
		var direction := (b.global_position - a.global_position).normalized()
		var up := Vector3.FORWARD if abs(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var right := direction.cross(up).normalized()
		var forward := right.cross(direction).normalized()
		wrapper.global_transform.basis = Basis(right, direction, forward)
		wrapper.set_scale(Vector3(0.15, line_length, 0.15))
		wrapper.name = "%s - Line" % a.name
