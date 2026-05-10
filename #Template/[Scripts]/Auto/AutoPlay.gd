extends BaseTrigger
## AutoPlay - 自动转向触发器
## 当玩家进入触发区域时自动执行转向

@export var trigger_distance: float = 0.33

var _player: Player
var _triggered: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	set_process(false)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body as Player
		set_process(true)

func _on_body_exited(body: Node3D) -> void:
	if body is Player and _player == body:
		_player = null
		set_process(false)

func _process(_delta: float) -> void:
	if not _player or _triggered:
		set_process(false)
		return
	var dist_sq := global_position.distance_squared_to(_player.global_position)
	if dist_sq <= trigger_distance:
		_triggered = true
		set_process(false)
		_player.turn()
