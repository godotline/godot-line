extends Node3D

## Plays an AudioStream either from a BaseTrigger collision or a direct method call.
@export var clip: AudioStream
@export_range(0.0, 1.0) var volume: float = 1.0
@export var triggered_by_trigger: bool = true

func trigger(body: Node3D) -> void:
	if body is Player and triggered_by_trigger:
		play_clip()

func play_clip() -> void:
	AudioManager.play_clip(clip, volume)
