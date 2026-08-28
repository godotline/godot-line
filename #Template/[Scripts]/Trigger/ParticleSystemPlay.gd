extends Node

# 支持 CPUParticles3D 和 GPUParticles3D（两者均有 emitting/restart API）
@export var particlesystem: Node

var checkpointIndex: int = -1

func _ready() -> void:
	if particlesystem:
		particlesystem.set("emitting", false)

func trigger(body: Node3D) -> bool:
	if not body is Player or not particlesystem:
		return
	checkpointIndex = LevelManager.checkpointCount
	particlesystem.call("restart")
	particlesystem.set("emitting", true)
	LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	LevelManager.CompareCheckpointIndex(checkpointIndex, func() -> void:
		if particlesystem:
			particlesystem.set("emitting", false)
	)

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_revive)
