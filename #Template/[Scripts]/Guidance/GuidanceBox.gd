class_name GuidanceBox
extends Node3D

## GuidanceBox - 点击引导块（GuideTap）
## 与 Unity GuidanceBox.cs 对齐，基于距离检测与点击判定呈现和触发引导效果。

@export var triggerDistance: float = 1.0
@export var appearDistance: float = 600.0
@export var canBeTriggered: bool = true
@export var haveLine: bool = true

var _player: Player
var _root: Node3D
var _sprite: Sprite3D
var _trigger_effect: PackedScene
var _index: int = 0
var _initialized: bool = false

var triggered: bool = false
var _displayed: bool = false

func _ready() -> void:
	_try_initialize()

func _try_initialize() -> bool:
	if _initialized:
		return true

	var player: Player = Player.instance
	if not is_instance_valid(player):
		return false

	_player = player
	_root = self
	_sprite = get_node_or_null("Sprite3D") as Sprite3D
	_trigger_effect = load("res://#Template/[Resources]/Triggered.tscn")
	_initialized = true

	# Unity: if (Distance > appearDistance) Disappear(false);
	# Unity 的 Distance 返回 sqrMagnitude，直接对比 appearDistance（不做平方）
	var distSq: float = global_position.distance_squared_to(_player.global_position)
	if distSq > appearDistance:
		_disappear(false)
	return true

func _process(_delta: float) -> void:
	if not _try_initialize():
		return

	if triggered:
		return

	# 合并两次距离计算为一次（性能优化：distance_squared_to 是关键热点）
	if not is_instance_valid(_player):
		_initialized = false
		return
	var distSq: float = global_position.distance_squared_to(_player.global_position)

	# Unity Update(): if (!triggered && Distance <= appearDistance && !Renderer.enabled) Appear();
	if not _displayed and distSq <= appearDistance:
		_appear()

	# 触发检测：仅在点击时才检查近距离
	if LevelManager.Clicked and canBeTriggered and distSq <= triggerDistance * triggerDistance:
		if LevelManager.GameState == LevelManager.GameStatus.Playing and not _player.disallowInput:
			_trigger()

func _trigger() -> void:
	triggered = true
	set_process(false)
	_disappear(true)
	if _trigger_effect:
		var effect: Node3D = _trigger_effect.instantiate() as Node3D
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
		await get_tree().create_timer(1.0).timeout
		effect.queue_free()

func SetColor(color: Color) -> void:
	if not _sprite:
		_sprite = get_node_or_null("Sprite3D") as Sprite3D
		if not _sprite:
			push_warning("GuidanceBox: Sprite3D not found")
			return
	_sprite.modulate = color

# Unity: Appear() — 显示所有 SpriteRenderer
func _appear() -> void:
	if not _displayed:
		_displayed = true
		_index = LevelManager.checkpointCount
		_root.visible = true
		if _sprite:
			_sprite.visible = true
		LevelManager.add_revive_listener(_reset_data)

# Unity: Disappear(bool onlyBox)
# false = 隐藏全部（包括连线），true = 只隐藏盒子 Sprite，连线留着
func _disappear(only_box: bool) -> void:
	if only_box:
		if _sprite:
			_sprite.visible = false
	else:
		_root.visible = false
		if _sprite:
			_sprite.visible = false

func _reset_data() -> void:
	LevelManager.remove_revive_listener(_reset_data)
	_displayed = false
	triggered = false
	set_process(true)
	_disappear(false)

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_reset_data)
