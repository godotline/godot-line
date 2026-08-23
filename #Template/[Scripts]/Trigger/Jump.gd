@tool
extends Node
signal power_changed(new_power: float)

# Unity Player rigidbody 质量 (Player.prefab m_Mass: 100)；Impulse 力 -> 初速度 = power / mass
const PLAYER_MASS: float = 100.0

@export var power: float = 500.0:
	set(value):
		power = value
		power_changed.emit(value)
		if Engine.is_editor_hint():
			_update_predictor()

@export var changeDirection: bool = false  # Unity Jump.changeDirection

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_predictor()

## 由父节点 BaseTrigger 调用的入口方法
func trigger(body: Node3D) -> void:
	var character: CharacterBody3D = body as CharacterBody3D
	if character:
		if changeDirection and Player.instance:
			Player.instance.Turn()
		# Unity: Rigidbody.AddForce(0, power, 0, Impulse)，mass=100 -> 初速度 = power / mass
		var jumpSpeed: float = power / PLAYER_MASS
		character.velocity += Vector3(0, jumpSpeed, 0)
		if Player.instance:
			Player.instance.emitGameEvent(7)

## 通知子 JumpPredictor/FallPredictor 刷新预览
func _update_predictor() -> void:
	for child in get_children():
		if child is JumpPredictor:
			child._redraw()
		if child is FallPredictor:
			child._draw_line()
