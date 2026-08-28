@tool
extends "res://#Template/[Scripts]/Trigger/Gem.gd"
class_name TTFGem

## TTF gem behavior backed by the existing Gem effects. PickUp(false) is used
## by TTF checkpoints to consume their embedded gem without increasing count.

var countedAsGem: bool = false
const TTF_ROTATION_SPEED_RADIANS: float = 1.0471976

func _ready() -> void:
	speed = TTF_ROTATION_SPEED_RADIANS
	super._ready()

func _on_body_entered(body: Node3D) -> bool:
	if got or body != Player.instance:
		return false
	PickUp(true)
	return true

func PickUp(add_gem: bool = true) -> void:
	if got or Engine.is_editor_hint():
		return

	got = true
	countedAsGem = add_gem
	index = LevelManager.checkpointCount
	_set_monitoring(false)

	if add_gem:
		LevelManager.gem += 1
	if Player.instance:
		Player.instance.emitGameEvent(6)

	var mesh: MeshInstance3D = contentRoot.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.visible = false
	var aura: Node3D = contentRoot.get_node_or_null("FX_Aura_TTF") as Node3D
	if aura:
		aura.visible = false
	var animationPlayer: AnimationPlayer = contentRoot.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animationPlayer and animationPlayer.has_animation("diamond"):
		animationPlayer.play("diamond")

	_start_collection_effect()
	_spawn_fragments()
	if add_gem:
		LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	if index >= LevelManager.checkpointCount:
		got = false
		var mesh: MeshInstance3D = contentRoot.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh:
			mesh.visible = true
		var aura: Node3D = contentRoot.get_node_or_null("FX_Aura_TTF") as Node3D
		if aura:
			aura.visible = true
		var animationPlayer: AnimationPlayer = contentRoot.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animationPlayer and animationPlayer.has_animation("RESET"):
			animationPlayer.play("RESET")
		_reset_collection_effect()
		_set_monitoring(true)
		if countedAsGem:
			LevelManager.gem = maxi(LevelManager.gem - 1, 0)
		countedAsGem = false
	LevelManager.remove_revive_listener(_on_revive)