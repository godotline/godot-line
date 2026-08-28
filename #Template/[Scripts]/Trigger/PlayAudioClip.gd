extends Node

## Plays an AudioStream either from a BaseTrigger collision or a direct method call.
@export var clip: AudioStream
@export_range(0.0, 1.0) var volume: float = 1.0
@export var triggeredByTrigger: bool = true

func trigger(body: Node3D) -> bool:
	if body is Player and triggeredByTrigger:
		play_clip()

func play_clip() -> void:
	AudioManager.PlayClip(clip, volume)
