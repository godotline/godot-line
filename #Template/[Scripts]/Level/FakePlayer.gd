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
## 当 isWall = true 时，FakePlayer 尾线的碰撞层设为 Obstacle (3)，
## 真实 Player 碰到会死亡。false 时不参与碰撞（纯预览）。
@export var isWall: bool = false
@export var drawDirection: bool = false:
	set(value):
		drawDirection = value
		if Engine.is_editor_hint():
			if self is Node3D:
				update_gizmos()
			var parent3d: Node3D = get_parent() as Node3D
			if parent3d:
				parent3d.update_gizmos()

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
var body: CharacterBody3D
var tail: MeshInstance3D
var tailPosition: Vector3
var tailHolder: Node3D
var tailPool: Array[MeshInstance3D] = []
var meshInstance: MeshInstance3D

var triggerHolder: Node3D
var id: int = 0

var previousFrameIsGrounded: bool = true
var lastKeyState: bool = false

func _ready() -> void:
	body = _resolve_body()
	if not body:
		push_error("FakePlayer.gd must be attached below a CharacterBody3D")
		return
	body.add_to_group("FakePlayer")
	if Engine.is_editor_hint():
		return

	var collision: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision:
		collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = BoxShape3D.new()
		collision.shape.size = Vector3(0.3, 0.3, 0.3)
		body.add_child(collision)

	meshInstance = body.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if meshInstance and characterMaterial:
		meshInstance.set_surface_override_material(0, characterMaterial)

	tailHolder = Node3D.new()
	tailHolder.name = body.name + "-TailHolder"
	var currentScene: Node = get_tree().current_scene
	if currentScene:
		currentScene.add_child.call_deferred(tailHolder)
	add_to_group("fake_players")
	if synchronismWithPlayer:
		# Follow Player.OnTurn so synchronized FakePlayers also work with autoplay.
		call_deferred("_connect_player_turn")

	if createTurnTrigger:
		triggerHolder = Node3D.new()
		triggerHolder.name = "FakePlayerTriggerHolder"
		if currentScene:
			currentScene.add_child.call_deferred(triggerHolder)

	_set_world_position(startPosition)
	_set_world_rotation(firstDirection)
	state = State.Stopped
	_setup_collision_layers()
	call_deferred("_create_tail")

func _resolve_body() -> CharacterBody3D:
	var parentBody: CharacterBody3D = get_parent() as CharacterBody3D
	if parentBody:
		return parentBody
	var attachedNode: Node = self
	if attachedNode is CharacterBody3D:
		return attachedNode as CharacterBody3D
	return null

## 根据 isWall 配置宿主碰撞层。
## 本体不设置障碍物层，由 _setup_tail_collision 在 tail 上设置。
func _setup_collision_layers() -> void:
	if not body:
		return
	body.collision_layer = 1
	body.collision_mask = 2

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
	if Engine.is_editor_hint() or not body:
		return

	match state:
		State.Moving:
			var forward: Vector3 = body.global_transform.basis * Vector3.BACK
			body.velocity.x = forward.x * speed
			body.velocity.z = forward.z * speed
			if not body.is_on_floor():
				body.velocity.y -= 9.8 * delta
			body.move_and_slide()

			if tail and body.is_on_floor():
				var worldPosition: Vector3 = _get_world_position()
				var midpoint: Vector3 = (tailPosition + worldPosition) * 0.5
				tail.global_position = midpoint
				var distance: float = tailPosition.distance_to(worldPosition)
				tail.scale = Vector3(1, 1, distance)
				if distance > 0.001:
					tail.look_at(worldPosition, Vector3.UP)

			var isGroundedNow: bool = body.is_on_floor()
			if previousFrameIsGrounded != isGroundedNow:
				previousFrameIsGrounded = isGroundedNow
				if isGroundedNow:
					_create_tail()
				else:
					tail = null

			if LevelManager.GameState == LevelManager.GameStatus.Moving or LevelManager.GameState == LevelManager.GameStatus.Died:
				state = State.Stopped

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not body:
		return

	match state:
		State.Moving:
			if not synchronismWithPlayer:
				var keyPressed: bool = Input.is_key_pressed(createKey)
				if keyPressed and not lastKeyState:
					_create_turn_trigger()
				lastKeyState = keyPressed

func _connect_player_turn() -> void:
	if not synchronismWithPlayer:
		return
	var player: Player = Player.instance
	if not player:
		if is_inside_tree():
			call_deferred("_connect_player_turn")
		return
	if player and not player.OnTurn.is_connected(_on_player_turn):
		player.OnTurn.connect(_on_player_turn)

func _on_player_turn() -> void:
	if state == State.Moving:
		_create_turn_trigger()

func Turn() -> void:
	var currentRotation: Vector3 = _get_world_rotation()
	_set_world_rotation(secondDirection if currentRotation.is_equal_approx(firstDirection) else firstDirection)
	_create_tail()

func _create_tail() -> void:
	if not body or not tailHolder:
		return

	var nowQ: Quaternion = body.global_transform.basis.get_rotation_quaternion()
	var tailHalf: float = 0.5
	var worldPosition: Vector3 = _get_world_position()

	if tail:
		var lastQ: Quaternion = tail.global_transform.basis.get_rotation_quaternion()
		var angle: float = lastQ.angle_to(nowQ)
		if angle >= 0.0 and angle <= deg_to_rad(90.0):
			tailHalf = 0.5 * tan(angle * 0.5)
		else:
			tailHalf = -0.5 * tan((deg_to_rad(180.0) - angle) * 0.5)
		var end: Vector3 = tailPosition + lastQ * Vector3.FORWARD * (tailPosition.distance_to(worldPosition) + tailHalf)
		var mid: Vector3 = (tailPosition + end) * 0.5
		mid.y = worldPosition.y
		tail.global_position = mid
		tail.scale = Vector3(1, 1, tailPosition.distance_to(end))
		if tailPosition.distance_to(end) > 0.001:
			tail.look_at(worldPosition, Vector3.UP)

	tailPosition = worldPosition + nowQ * Vector3.FORWARD * abs(tailHalf)

	if tailPool.size() < poolSize:
		tail = _create_tail_segment()
		tailHolder.add_child(tail)
		tail.global_position = worldPosition
		tailPool.append(tail)
		_setup_tail_collision(tail)
	else:
		tail = tailPool.pop_front()
		tailPool.append(tail)
		tail.global_position = worldPosition
		_setup_tail_collision(tail)

func _create_tail_segment() -> MeshInstance3D:
	var meshInstance: MeshInstance3D = MeshInstance3D.new()
	meshInstance.name = "FakeTail"
	if self.meshInstance:
		meshInstance.mesh = self.meshInstance.mesh
		if characterMaterial:
			meshInstance.set_surface_override_material(0, characterMaterial)
	return meshInstance

func ClearPool() -> void:
	for tail: MeshInstance3D in tailPool:
		if is_instance_valid(tail):
			tail.queue_free()
	tailPool.clear()
	tail = null

func get_reset_data() -> Dictionary:
	return {
		"playing": playing,
		"speed": speed,
		"position": _get_world_position(),
		"rotation": _get_world_rotation()
	}

func set_reset_data(data: Dictionary) -> void:
	playing = bool(data.get("playing", false))
	var savedSpeed: Variant = data.get("speed", 12.0)
	if savedSpeed is float or savedSpeed is int:
		speed = float(savedSpeed)
	var savedPosition: Variant = data.get("position", startPosition)
	if savedPosition is Vector3:
		_set_world_position(savedPosition)
	var savedRotation: Variant = data.get("rotation", firstDirection)
	if savedRotation is Vector3:
		_set_world_rotation(savedRotation)
	state = State.Stopped  # 复活后强制停止，等待玩家启动
	ClearPool()
	_create_tail()

func _get_world_position() -> Vector3:
	if body:
		return body.global_position
	return global_position

func _set_world_position(value: Vector3) -> void:
	if body:
		body.global_position = value
	else:
		global_position = value

func set_world_position(value: Vector3) -> void:
	_set_world_position(value)

func _get_world_rotation() -> Vector3:
	if body:
		return body.rotation_degrees
	return rotation_degrees

func _set_world_rotation(value: Vector3) -> void:
	if body:
		body.rotation_degrees = value
	else:
		rotation_degrees = value

func _create_turn_trigger() -> void:
	if not triggerHolder:
		return

	var area: BaseTrigger = BaseTrigger.new()
	area.name = "FakePlayerTurnTrigger %d" % id
	id += 1
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

	triggerHolder.add_child(area)
	area.global_position = _get_world_position()
	area.rotation_degrees = triggerRotation
	area.scale = triggerScale

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var player: Player = Player.instance
	if player and player.OnTurn.is_connected(_on_player_turn):
		player.OnTurn.disconnect(_on_player_turn)
	if tailHolder and is_instance_valid(tailHolder):
		tailHolder.queue_free()
	if triggerHolder and is_instance_valid(triggerHolder):
		triggerHolder.queue_free()
