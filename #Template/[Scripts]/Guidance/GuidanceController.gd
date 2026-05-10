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
var _box_count: int = 0
var _box_scene: PackedScene
var _ready_done: bool = false

func _ready() -> void:
	Instance = self
	_box_scene = load("res://#Template/[Resources]/GuidanceBox.tscn")
	if box_holder:
		for child in box_holder.get_children():
			if child is Node3D:
				_boxes.append(child)
		for b in _boxes:
			_set_color(b, guidance_color)
	if create_lines and not _boxes.is_empty():
		_generate_lines()

func _process(_delta: float) -> void:
	if _ready_done:
		return
	if not Player.instance:
		return
	_player = Player.instance
	_ready_done = true
	if create_boxes:
		_holder = Node3D.new()
		_holder.name = "GuidanceBoxHolder"
		get_tree().current_scene.add_child(_holder)
		_spawn_box(_player.global_position - Vector3(0, 0.45, 0), Vector3(0, _player.rotation_degrees.y, 0))
	_player.onturn.connect(_on_player_turn)

func _on_player_turn() -> void:
	if create_boxes and LevelManager.GameState == LevelManager.GameStatus.Playing:
		var forward_y: float
		if _player.rotation_degrees.y == _player.firstDirection.y:
			forward_y = _player.secondDirection.y
		else:
			forward_y = _player.firstDirection.y
		_spawn_box(_player.global_position - Vector3(0, 0.45, 0), Vector3(0, forward_y, 0))

func _spawn_box(pos: Vector3, rot: Vector3) -> void:
	var box := _box_scene.instantiate() as Node3D
	box.global_position = pos
	box.rotation_degrees = rot
	_holder.add_child(box)
	box.name = "GuidanceBox_%d" % _box_count
	_box_count += 1
	_set_color(box, guidance_color)
	_boxes.append(box)
	if box is GuidanceBox:
		box.can_be_triggered = false

func _set_color(box: Node3D, color: Color) -> void:
	var sprite := box.get_node_or_null("Sprite3D") as Sprite3D
	if sprite:
		sprite.modulate = color

func _generate_lines() -> void:
	for i in range(_boxes.size()):
		if i + 1 >= _boxes.size():
			break
		var a: Node3D = _boxes[i]
		var b: Node3D = _boxes[i + 1]
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		var midpoint := 0.5 * (a.global_position + b.global_position)
		var dist := a.global_position.distance_to(b.global_position)
		var line_length := dist - box_size_y - 2 * line_gap
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
