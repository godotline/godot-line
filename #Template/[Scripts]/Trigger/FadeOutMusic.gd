extends Node

@export_range(0.0, 60.0, 0.05) var duration: float = 4.0

func trigger(body: Node3D) -> bool:
	if not (body is Player and LevelManager.GameState == LevelManager.GameStatus.Playing):
		return false
	AudioManager.FadeOut(0.0, duration)
	return true
