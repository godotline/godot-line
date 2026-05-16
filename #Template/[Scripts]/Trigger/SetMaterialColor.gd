@tool
extends BaseTrigger
class_name SetMaterialColor


@export var colors: Array[SingleColor] = []
@export var duration: float = 2.0
@export var trans_type: int = 0
@export var ease_type: int = 0


func _on_triggered(_body: Node3D) -> void:
	for sc in colors:
		sc.apply_tweened(self, duration, trans_type, ease_type)
