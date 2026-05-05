extends Node3D
class_name GuidanceBox

@export var trigger_distance: float = 1.0
@export var appear_distance: float = 600.0
@export var can_be_triggered: bool = true
@export var have_line: bool = true

var _pending_body: CharacterBody3D = null
var _is_waiting: bool = false
var _player: CharacterBody3D
var _sprite: Sprite3D
var _displayed: bool = false
var _triggered: bool = false
var _trigger_ready: bool = false
var _trigger_effect: PackedScene

func _ready() -> void:
	_sprite = $"../Sprite3D"
	_player = Player.instance
	_trigger_effect = load("res://#Template/[Resources]/Triggered.tscn")
	var dist_sq := global_position.distance_squared_to(_player.global_position)
	if _player and dist_sq > appear_distance * appear_distance:
		_disappear(false)

func _process(_delta: float) -> void:
	if not _player:
		return
	var dist_sq := global_position.distance_squared_to(_player.global_position)
	if not _triggered and dist_sq <= appear_distance * appear_distance and not _displayed:
		_appear()
	if not _trigger_ready and dist_sq > trigger_distance * trigger_distance:
		_trigger_ready = true
	if LevelManager.Clicked and not _triggered and dist_sq <= trigger_distance * trigger_distance and can_be_triggered and _trigger_ready and LevelManager.GameState == LevelManager.GameStatus.Playing and _player.is_live:
		_trigger()

func _trigger() -> void:
	_triggered = true
	_disappear(true)
	_play_trigger_effect()

func _play_trigger_effect() -> void:
	if not _trigger_effect:
		return
	var effect := _trigger_effect.instantiate() as Node3D
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	var ap := effect.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap:
		ap.play("taper")
		await ap.animation_finished
	effect.queue_free()

func _appear() -> void:
	if not _displayed:
		_displayed = true
		$"..".visible = true
		_sprite.visible = true
		LevelManager.add_revive_listener(_reset_data)

func _disappear(only_box: bool) -> void:
	if only_box:
		_sprite.visible = false
	else:
		$"..".visible = false
		_sprite.visible = false

func _reset_data() -> void:
	LevelManager.remove_revive_listener(_reset_data)
	_displayed = false
	_triggered = false
	_trigger_ready = false
	_disappear(false)

func _on_taper_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not _is_waiting:
		_pending_body = body
		_is_waiting = true
		await body.onturn
		if _pending_body == null:
			return
		_trigger()

func _on_taper_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body == _pending_body:
		_pending_body = null

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_reset_data)
