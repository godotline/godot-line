extends Area3D
class_name GuidanceBox

@export var trigger_distance: float = 1.0
@export var appear_distance: float = 600.0
@export var can_be_triggered: bool = true
@export var have_line: bool = true

var _player: CharacterBody3D
var _root: Node3D
var _sprite: Sprite3D
var _trigger_effect: PackedScene
var _index: int = 0

var triggered: bool = false
var _displayed: bool = false

func _ready() -> void:
	_player = Player.instance
	if not _player:
		push_error("GuidanceBox.gd: Player.instance 为空，无法初始化引导盒")
		return
	_root = $".."
	_sprite = $"../Sprite3D"
	_trigger_effect = load("res://#Template/[Resources]/Triggered.tscn")

	# Unity: if (Distance > appearDistance) Disappear(false);
	# Unity 的 Distance 返回 sqrMagnitude，直接对比 appearDistance（不做平方）
	var dist_sq: float = global_position.distance_squared_to(_player.global_position)
	if dist_sq > appear_distance:
		_disappear(false)

func _process(_delta: float) -> void:
	if triggered:
		return

	# 合并两次距离计算为一次（性能优化：distance_squared_to 是关键热点）
	if not _player:
		push_error("GuidanceBox.gd: Player.instance 为空，无法计算距离")
		return
	var dist_sq: float = global_position.distance_squared_to(_player.global_position)

	# Unity Update(): if (!triggered && Distance <= appearDistance && !Renderer.enabled) Appear();
	if not _displayed and dist_sq <= appear_distance:
		_appear()

	# 触发检测：仅在点击时才检查近距离
	if LevelManager.Clicked and can_be_triggered and dist_sq <= trigger_distance * trigger_distance:
		if not _player:
			push_error("GuidanceBox.gd: Player.instance 为空，无法触发点击")
			return
		if LevelManager.GameState == LevelManager.GameStatus.Playing and not _player.disallow_input:
			_trigger()

func _trigger() -> void:
	triggered = true
	set_process(false)
	_disappear(true)
	var effect: Node3D = _trigger_effect.instantiate() as Node3D
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	await get_tree().create_timer(1.0).timeout
	effect.queue_free()

func set_color(color: Color) -> void:
	if not _sprite:
		_sprite = $"../Sprite3D"
		# If still null, warn and skip
		if not _sprite:
			push_warning("GuidanceBox: Sprite3D not found at ../Sprite3D")
			return
	_sprite.modulate = color

# Unity: Appear() — 显示所有 SpriteRenderer（用 _root.visible 等效，且自动覆盖未来添加的子节点）
func _appear() -> void:
	if not _displayed:
		_displayed = true
		_index = LevelManager.checkpoint_count
		_root.visible = true
		LevelManager.add_revive_listener(_reset_data)

# Unity: Disappear(bool onlyBox)
# false = 隐藏全部（包括连线），true = 只隐藏盒子 Sprite，连线留着
func _disappear(only_box: bool) -> void:
	if only_box:
		_sprite.visible = false
	else:
		_root.visible = false

func _reset_data() -> void:
	LevelManager.remove_revive_listener(_reset_data)
	_displayed = false
	triggered = false
	set_process(true)
	_disappear(false)

func _on_taper_entered(body: Node3D) -> void:
	pass

func _on_taper_exited(body: Node3D) -> void:
	pass

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_reset_data)
