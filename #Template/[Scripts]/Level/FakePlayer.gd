@tool
class_name FakePlayer
extends Node3D

## 假线系统组件 — 挂载在 CharacterBody3D 下，沿预设方向自动移动。

enum State {
	Moving,
	Stopped
}

## ========== Exports ==========
@export var speed: float = 12.0
@export var characterMaterial: StandardMaterial3D
@export var startPosition: Vector3 = Vector3.ZERO
@export var firstDirection: Vector3 = Vector3(0, 90, 0)
@export var secondDirection: Vector3 = Vector3.ZERO
@export var poolSize: int = 100
## 当 isWall = true 时，FakePlayer 尾线的碰撞层设为 BaseWall (3)，
## 真实 Player 碰到会死亡。false 时不参与碰撞（纯预览）。
@export var isWall: bool = false
@export var drawDirection: bool = false

@export_group("TurnTrigger")
@export var createTurnTrigger: bool = true
@export var synchronismWithPlayer: bool = false
@export var createKey: Key = KEY_P
@export var triggerRotation: Vector3 = Vector3(0, 45, 0)
@export var triggerScale: Vector3 = Vector3(4, 3, 0.1)

## ========== State ==========
var state: State = State.Stopped
var playing: bool = false

## ========== Internals ==========
var _body: CharacterBody3D
var _current_tail: MeshInstance3D
var _tail_position: Vector3
var _tail_holder: Node3D
var _tail_pool: Array[MeshInstance3D] = []
var _mesh_instance: MeshInstance3D

var _trigger_holder: Node3D
var _trigger_id: int = 0

var _previous_frame_is_grounded: bool = true
var _last_key_state: bool = false
var _last_clicked_state: bool = false

func _ready() -> void:
	_body = _resolve_body()
	if not _body:
		push_error("FakePlayer.gd must be attached below a CharacterBody3D")
		return
	if Engine.is_editor_hint():
		return

	var collision: CollisionShape3D = _body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision:
		collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = BoxShape3D.new()
		collision.shape.size = Vector3(0.3, 0.3, 0.3)
		_body.add_child(collision)

	_mesh_instance = _body.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _mesh_instance and characterMaterial:
		_mesh_instance.set_surface_override_material(0, characterMaterial)

	_tail_holder = Node3D.new()
	_tail_holder.name = _body.name + "-TailHolder"
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		current_scene.add_child.call_deferred(_tail_holder)
	add_to_group("fake_players")

	if createTurnTrigger:
		_trigger_holder = Node3D.new()
		_trigger_holder.name = "FakePlayerTriggerHolder"
		if current_scene:
			current_scene.add_child.call_deferred(_trigger_holder)

	_set_world_position(startPosition)
	_set_world_rotation(firstDirection)
	state = State.Stopped
	_setup_collision_layers()
	call_deferred("_create_tail")

func _resolve_body() -> CharacterBody3D:
	var parent_body: CharacterBody3D = get_parent() as CharacterBody3D
	if parent_body:
		return parent_body
	var attached_node: Node = self
	if attached_node is CharacterBody3D:
		return attached_node as CharacterBody3D
	return null

## 根据 isWall 配置宿主碰撞层。
## 本体不设置障碍物层，由 _setup_tail_collision 在 tail 上设置。
func _setup_collision_layers() -> void:
	if not _body:
		return
	_body.collision_layer = 1
	_body.collision_mask = 2

## 给单个 tail 设置/移除障碍物碰撞。
func _setup_tail_collision(tail: MeshInstance3D) -> void:
	var body: StaticBody3D = tail.get_node_or_null("TailObstacle") as StaticBody3D
	if body:
		body.queue_free()
	if isWall:
		body = StaticBody3D.new()
		body.name = "TailObstacle"
		body.collision_layer = 1 << 2  # BaseWall
		body.collision_mask = 0
		body.add_to_group("obstacle")
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		col.shape.size = Vector3(1, 1, 1)
		body.add_child(col)
		tail.add_child(body)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _body:
		return

	match state:
		State.Moving:
			var forward: Vector3 = _body.global_transform.basis * Vector3.BACK
			_body.velocity.x = forward.x * speed
			_body.velocity.z = forward.z * speed
			if not _body.is_on_floor():
				_body.velocity.y -= 9.8 * delta
			_body.move_and_slide()

			if _current_tail and _body.is_on_floor():
				var world_position: Vector3 = _get_world_position()
				var midpoint: Vector3 = (_tail_position + world_position) * 0.5
				_current_tail.global_position = midpoint
				var distance: float = _tail_position.distance_to(world_position)
				_current_tail.scale = Vector3(1, 1, distance)
				if distance > 0.001:
					_current_tail.look_at(world_position, Vector3.UP)

			var is_grounded_now: bool = _body.is_on_floor()
			if _previous_frame_is_grounded != is_grounded_now:
				_previous_frame_is_grounded = is_grounded_now
				if is_grounded_now:
					_create_tail()
				else:
					_current_tail = null

			if LevelManager.GameState == LevelManager.GameStatus.Moving or LevelManager.GameState == LevelManager.GameStatus.Died:
				state = State.Stopped

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _body:
		return

	match state:
		State.Moving:
			if not synchronismWithPlayer:
				var key_pressed: bool = Input.is_key_pressed(createKey)
				if key_pressed and not _last_key_state:
					_create_turn_trigger()
				_last_key_state = key_pressed
			else:
				var clicked: bool = LevelManager.Clicked
				if clicked and not _last_clicked_state:
					_create_turn_trigger()
				_last_clicked_state = clicked

func turn() -> void:
	var current_rotation: Vector3 = _get_world_rotation()
	_set_world_rotation(secondDirection if current_rotation.is_equal_approx(firstDirection) else firstDirection)
	_create_tail()

func _create_tail() -> void:
	if not _body or not _tail_holder:
		return

	var now_q: Quaternion = _body.global_transform.basis.get_rotation_quaternion()
	var tail_half: float = 0.5
	var world_position: Vector3 = _get_world_position()

	if _current_tail:
		var last_q: Quaternion = _current_tail.global_transform.basis.get_rotation_quaternion()
		var angle: float = last_q.angle_to(now_q)
		if angle >= 0.0 and angle <= deg_to_rad(90.0):
			tail_half = 0.5 * tan(angle * 0.5)
		else:
			tail_half = -0.5 * tan((deg_to_rad(180.0) - angle) * 0.5)
		var end: Vector3 = _tail_position + last_q * Vector3.FORWARD * (_tail_position.distance_to(world_position) + tail_half)
		var mid: Vector3 = (_tail_position + end) * 0.5
		mid.y = world_position.y
		_current_tail.global_position = mid
		_current_tail.scale = Vector3(1, 1, _tail_position.distance_to(end))
		if _tail_position.distance_to(end) > 0.001:
			_current_tail.look_at(world_position, Vector3.UP)

	_tail_position = world_position + now_q * Vector3.FORWARD * abs(tail_half)

	if _tail_pool.size() < poolSize:
		_current_tail = _create_tail_segment()
		_tail_holder.add_child(_current_tail)
		_current_tail.global_position = world_position
		_tail_pool.append(_current_tail)
		_setup_tail_collision(_current_tail)
	else:
		_current_tail = _tail_pool.pop_front()
		_tail_pool.append(_current_tail)
		_current_tail.global_position = world_position
		_setup_tail_collision(_current_tail)

func _create_tail_segment() -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "FakeTail"
	if _mesh_instance:
		mesh_instance.mesh = _mesh_instance.mesh
		if characterMaterial:
			mesh_instance.set_surface_override_material(0, characterMaterial)
	return mesh_instance

func clear_pool() -> void:
	for tail: MeshInstance3D in _tail_pool:
		if is_instance_valid(tail):
			tail.queue_free()
	_tail_pool.clear()
	_current_tail = null

func get_reset_data() -> Dictionary:
	return {
		"playing": playing,
		"speed": speed,
		"position": _get_world_position(),
		"rotation": _get_world_rotation()
	}

func set_reset_data(data: Dictionary) -> void:
	var saved_speed: Variant = data.get("speed", 12.0)
	if saved_speed is float or saved_speed is int:
		speed = float(saved_speed)
	var saved_position: Variant = data.get("position", startPosition)
	if saved_position is Vector3:
		_set_world_position(saved_position)
	var saved_rotation: Variant = data.get("rotation", firstDirection)
	if saved_rotation is Vector3:
		_set_world_rotation(saved_rotation)
	state = State.Stopped  # 复活后强制停止，等待玩家启动
	clear_pool()
	_create_tail()

func _get_world_position() -> Vector3:
	if _body:
		return _body.global_position
	return global_position

func _set_world_position(value: Vector3) -> void:
	if _body:
		_body.global_position = value
	else:
		global_position = value

func set_world_position(value: Vector3) -> void:
	_set_world_position(value)

func _get_world_rotation() -> Vector3:
	if _body:
		return _body.rotation_degrees
	return rotation_degrees

func _set_world_rotation(value: Vector3) -> void:
	if _body:
		_body.rotation_degrees = value
	else:
		rotation_degrees = value

func _create_turn_trigger() -> void:
	if not _trigger_holder:
		return

	var area: BaseTrigger = BaseTrigger.new()
	area.name = "FakePlayerTurnTrigger %d" % _trigger_id
	_trigger_id += 1
	area.collision_layer = 0
	area.collision_mask = 1 | 4

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(1, 1, 1)
	area.add_child(collision)

	var trigger: FakePlayerTrigger = FakePlayerTrigger.new()
	trigger.targetPlayer = self
	trigger.type = FakePlayerTrigger.SetType.Turn
	area.add_child(trigger)

	_trigger_holder.add_child(area)
	area.global_position = _get_world_position()
	area.rotation_degrees = triggerRotation
	area.scale = triggerScale

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _tail_holder and is_instance_valid(_tail_holder):
		_tail_holder.queue_free()
	if _trigger_holder and is_instance_valid(_trigger_holder):
		_trigger_holder.queue_free()
