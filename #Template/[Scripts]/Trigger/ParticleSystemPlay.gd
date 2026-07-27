extends Node3D

@export var particle_system: GPUParticles3D

var _checkpoint_index: int = -1

func _ready() -> void:
	if particle_system:
		particle_system.emitting = false

func trigger(body: Node3D) -> void:
	if not body is Player or not particle_system:
		return
	_checkpoint_index = LevelManager.checkpoint_count
	particle_system.restart()
	particle_system.emitting = true
	LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	LevelManager.CompareCheckpointIndex(_checkpoint_index, func() -> void:
		if particle_system:
			particle_system.emitting = false
	)

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_revive)
