extends Node

@export_range(0.0, 60.0, 0.05) var duration: float = 4.0

func trigger(body: Node3D) -> bool:
	if body is Player and LevelManager.GameState == LevelManager.GameStatus.Playing:
		AudioManager.FadeOut(0.0, duration)
