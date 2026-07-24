@tool
extends "res://#Template/[Scripts]/Trigger/Single/Gem.gd"
class_name TTFGem

## TTF gem behavior backed by the existing Gem effects. pick_up(false) is used
## by TTF checkpoints to consume their embedded gem without increasing count.

var _counted_as_gem: bool = false

func _on_body_entered(body: Node) -> void:
	if _collected or fake or body != Player.instance:
		return
	pick_up(true)

func pick_up(add_gem: bool = true) -> void:
	if _collected or Engine.is_editor_hint():
		return

	_collected = true
	_counted_as_gem = add_gem
	_checkpoint_index = LevelManager.checkpoint_count
	set_deferred("monitoring", false)

	if add_gem:
		LevelManager.gem += 1
	if Player.instance and Player.instance.has_signal("on_get_gem"):
		Player.instance.on_get_gem.emit()

	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.visible = false
	var aura: Node3D = get_node_or_null("FX_Aura_TTF") as Node3D
	if aura:
		aura.visible = false
	var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player and animation_player.has_animation("diamond"):
		animation_player.play("diamond")

	_start_collection_effect()
	_spawn_fragments()
	if add_gem:
		LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	if _checkpoint_index >= LevelManager.checkpoint_count:
		_collected = false
		var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh:
			mesh.visible = true
		var aura: Node3D = get_node_or_null("FX_Aura_TTF") as Node3D
		if aura:
			aura.visible = true
		var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation_player and animation_player.has_animation("RESET"):
			animation_player.play("RESET")
		_reset_collection_effect()
		set_deferred("monitoring", true)
		if _counted_as_gem:
			LevelManager.gem = maxi(LevelManager.gem - 1, 0)
		_counted_as_gem = false
	LevelManager.remove_revive_listener(_on_revive)
