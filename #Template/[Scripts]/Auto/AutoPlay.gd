extends Area3D
## AutoPlay - 自动转向触发器（与 Unity 版一致）
## 使用 _physics_process 模拟 Unity 的 OnTriggerStay + sqrMagnitude 距离检测

var playerRef: Node3D
var _triggered: bool = false
var _active: bool = false

const TRIGGER_DISTANCE_SQ: float = 0.33

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	set_physics_process(false)

func _on_body_entered(body: Node3D) -> void:
	if body is Player and _active:
		playerRef = body
		set_physics_process(true)

func _on_body_exited(body: Node3D) -> void:
	if body == playerRef:
		playerRef = null
		set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if not _active or _triggered:
		set_physics_process(false)
		return

	# Unity uses OnTriggerStay, so do not depend on a one-time body_entered
	# signal. This also catches enabling autoplay while the player is already
	# inside the trigger volume.
	var player: Player = playerRef as Player
	if not is_instance_valid(player):
		if not monitoring:
			return
		player = null
		for body: Node3D in get_overlapping_bodies():
			if body is Player:
				player = body as Player
				break
		playerRef = player
	if not is_instance_valid(player):
		return

	var distSq: float = global_position.distance_squared_to(player.global_position)
	if distSq <= TRIGGER_DISTANCE_SQ:
		_triggered = true
		set_physics_process(false)
		player.Turn()

func SetActive(active: bool) -> void:
	_active = active
	if not active:
		playerRef = null
		set_physics_process(false)
		return
	set_physics_process(true)

func refresh_tracking() -> void:
	if not _active or not monitoring:
		return
	playerRef = null
	for body: Node3D in get_overlapping_bodies():
		if body is Player:
			playerRef = body
			break
	set_physics_process(true)
