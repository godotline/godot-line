extends Node3D
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
	_root = $".."
	_sprite = $"../Sprite3D"
	_trigger_effect = load("res://#Template/[Resources]/Triggered.tscn")
	if not _player:
		return
	var dist_sq := global_position.distance_squared_to(_player.global_position)
	if dist_sq > appear_distance * appear_distance:
		_disappear(false)
	else:
		_appear()

func _process(_delta: float) -> void:
	if not _player:
		return
	var dist_sq := global_position.distance_squared_to(_player.global_position)
	if not triggered and dist_sq <= appear_distance * appear_distance and not _sprite.visible:
		_appear()
	if LevelManager.Clicked and not triggered and dist_sq <= trigger_distance * trigger_distance and can_be_triggered and LevelManager.GameState == LevelManager.GameStatus.Playing and not _player.disallow_input:
		_trigger()

func _trigger() -> void:
	triggered = true
	_disappear(true)
	var effect := _trigger_effect.instantiate() as Node3D
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	await get_tree().create_timer(1.0).timeout
	effect.queue_free()

func set_color(color: Color) -> void:
	_sprite.modulate = color

func _appear() -> void:
	if not _displayed:
		_displayed = true
		_index = LevelManager.checkpoint_count
		_set_all_sprites_visible(true)
		LevelManager.add_revive_listener(_reset_data)

func _disappear(only_box: bool) -> void:
	if only_box:
		_sprite.visible = false
	else:
		_set_all_sprites_visible(false)

func _set_all_sprites_visible(visible: bool) -> void:
	for child in _root.get_children():
		if child is Sprite3D:
			child.visible = visible
	_sprite.visible = visible

func _reset_data() -> void:
	LevelManager.remove_revive_listener(_reset_data)
	_displayed = false
	triggered = false
	_disappear(false)

func _on_taper_entered(body: Node3D) -> void:
	pass

func _on_taper_exited(body: Node3D) -> void:
	pass

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_reset_data)
