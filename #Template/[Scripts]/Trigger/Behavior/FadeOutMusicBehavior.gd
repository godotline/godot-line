@tool
extends TriggerBehavior
class_name FadeOutMusicBehavior

## FadeOutMusicBehavior - 淡出音乐行为组件
## 当父 BaseTrigger 被触发时淡出背景音乐

@export var fade_duration: float = 2.0

func _on_triggered(_body: Node3D) -> void:
	AudioManager.fade_out(fade_duration)
