extends Area3D
## AutoPlay - 自动转向触发器（与 Unity 版一致）
## 使用 _physics_process 模拟 Unity 的 OnTriggerStay + sqrMagnitude 距离检测

var _player_ref: Node3D
var _triggered: bool = false

const TRIGGER_DISTANCE_SQ: float = 0.33

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	set_physics_process(false)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player_ref = body
		set_physics_process(true)

func _on_body_exited(body: Node3D) -> void:
	if body == _player_ref:
		_player_ref = null
		set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if not _player_ref or _triggered:
		set_physics_process(false)
		return
	var dist_sq := global_position.distance_squared_to(_player_ref.global_position)
	if dist_sq <= TRIGGER_DISTANCE_SQ:
		_triggered = true
		set_physics_process(false)
		_player_ref.turn()
