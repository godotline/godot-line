extends Node3D

@export var particlesystem: GPUParticles3D

var checkpointIndex: int = -1

func _ready() -> void:
	if particlesystem:
		particlesystem.emitting = false

func trigger(body: Node3D) -> void:
	if not body is Player or not particlesystem:
		return
	checkpointIndex = LevelManager.checkpointCount
	particlesystem.restart()
	particlesystem.emitting = true
	LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	LevelManager.CompareCheckpointIndex(checkpointIndex, func() -> void:
		if particlesystem:
			particlesystem.emitting = false
	)

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_revive)