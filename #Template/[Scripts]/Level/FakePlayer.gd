@tool
class_name FakePlayer
extends CharacterBody3D

## 假线系统 — 沿预设路径自动移动的假玩家（与 Unity FakePlayer.cs 一致）

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
@export var isWall: bool = false
@export var drawDirection: bool = false

## ========== State ==========
var state: State = State.Stopped
var playing: bool:
	get:
		return state == State.Moving

## ========== Internals ==========
var current_tail: MeshInstance3D
var _tail_position: Vector3
var _tail_holder: Node3D
var _tail_pool: Array[MeshInstance3D] = []
var _mesh_instance: MeshInstance3D
var _on_floor: bool = true
var _was_on_floor: bool = true

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 自动创建碰撞体（必须有才能用 is_on_floor）
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision:
		collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = BoxShape3D.new()
		collision.shape.size = Vector3(0.3, 0.3, 0.3)
		add_child(collision)
	# 碰撞层：自身 layer1，检测 layer2(地板)
	collision_layer = 1
	collision_mask = 2

	_mesh_instance = $MeshInstance3D
	if _mesh_instance and characterMaterial:
		_mesh_instance.set_surface_override_material(0, characterMaterial)

	_tail_holder = Node3D.new()
	_tail_holder.name = name + "TailHolder"
	get_tree().current_scene.add_child.call_deferred(_tail_holder)

	firstDirection = firstDirection
	secondDirection = secondDirection
	rotation_degrees = firstDirection

	state = State.Stopped
	_create_initial_tail()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	match state:
		State.Moving:
			var forward := global_transform.basis * Vector3.FORWARD * speed
			velocity.x = forward.x
			velocity.z = forward.z
			if not is_on_floor():
				velocity.y -= 9.8 * delta
			move_and_slide()

			_on_floor = is_on_floor()
			if current_tail and _on_floor:
				var midpoint := (_tail_position + global_position) * 0.5
				midpoint.y = global_position.y
				current_tail.global_position = midpoint

				var distance := _tail_position.distance_to(global_position)
				current_tail.scale = Vector3(1, 1, distance)
				current_tail.look_at(global_position, Vector3.UP)

			if _was_on_floor != _on_floor:
				_was_on_floor = _on_floor
				if _on_floor:
					_create_tail()
			if not _on_floor:
				current_tail = null

			if LevelManager.GameState == LevelManager.GameStatus.Died or LevelManager.GameState == LevelManager.GameStatus.Moving:
				state = State.Stopped

## 转向
func turn() -> void:
	rotation_degrees = secondDirection if rotation_degrees == firstDirection else firstDirection
	_create_tail()

## 创建新的线段（从池中获取或新建）
func _create_tail() -> void:
	var now_q := global_transform.basis.get_rotation_quaternion()
	var tail_half := 0.5

	if current_tail:
		var last_q := current_tail.global_transform.basis.get_rotation_quaternion()
		var angle := last_q.angle_to(now_q)
		if angle >= 0.0 and angle <= deg_to_rad(90.0):
			tail_half = 0.5 * tan(angle * 0.5)
		else:
			tail_half = -0.5 * tan((deg_to_rad(180.0) - angle) * 0.5)
		var end := _tail_position + last_q * Vector3.FORWARD * (_tail_position.distance_to(global_position) + tail_half)
		var mid := (_tail_position + end) * 0.5
		mid.y = global_position.y
		current_tail.global_position = mid
		current_tail.scale = Vector3(1, 1, _tail_position.distance_to(end))
		current_tail.look_at(global_position, Vector3.UP)

	_tail_position = global_position + now_q * Vector3.BACK * abs(tail_half)

	if _tail_pool.size() < poolSize:
		current_tail = _create_tail_segment()
		_tail_holder.add_child(current_tail)
		_tail_pool.append(current_tail)
	else:
		current_tail = _tail_pool.pop_front()
		_tail_pool.append(current_tail)

## 创建初始线段
func _create_initial_tail() -> void:
	_tail_position = global_position + transform.basis * Vector3.BACK * 0.5
	if _tail_pool.size() < poolSize:
		current_tail = _create_tail_segment()
		_tail_holder.add_child(current_tail)
		_tail_pool.append(current_tail)

func _create_tail_segment() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "FakeTail"
	# 使用角色自己的 mesh，与 Player 尾线逻辑一致
	if _mesh_instance:
		mi.mesh = _mesh_instance.mesh
		if characterMaterial:
			mi.set_surface_override_material(0, characterMaterial)
	return mi

## 清除所有线段并重置池
func clear_pool() -> void:
	for tail in _tail_pool:
		if is_instance_valid(tail):
			tail.queue_free()
	_tail_pool.clear()
	current_tail = null

## 保存当前状态用于复位
func get_reset_data() -> Dictionary:
	return {
		"playing": playing,
		"speed": speed,
		"position": global_position,
		"rotation": rotation_degrees
	}

## 从保存的数据恢复状态
func set_reset_data(data: Dictionary) -> void:
	speed = data.get("speed", 12.0)
	global_position = data.get("position", startPosition)
	rotation_degrees = data.get("rotation", firstDirection)
	state = State.Moving if data.get("playing", false) else State.Stopped
	clear_pool()
	_create_initial_tail()
