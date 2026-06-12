@tool
extends TriggerBehavior
class_name PlayAudioBehavior

## PlayAudioBehavior - 播放音效行为组件
## 当父 BaseTrigger 被触发时播放音效

@export var audio_clip: AudioStream
@export var volume: float = 1.0
@export var pitch_scale: float = 1.0

func _on_triggered(_body: Node3D) -> void:
	if not audio_clip:
		return
	
	AudioManager.play_clip(audio_clip, volume)
