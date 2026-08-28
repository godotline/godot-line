extends Node

## Applies a level-local gravity override. Add this as a BaseTrigger child.
@export var gravity: Vector3 = Vector3(0.0, -9.3, 0.0)

var checkpointIndex: int = -1

func trigger(body: Node3D) -> bool:
	var player: Player = body as Player
	if not player:
		return
	checkpointIndex = LevelManager.checkpointCount
	player.set_gravity_override(gravity)
	LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	LevelManager.CompareCheckpointIndex(checkpointIndex, func() -> void:
		var player: Player = Player.instance
		if player:
			player.clear_gravity_override()
	)

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_revive)
