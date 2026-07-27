extends Node3D

@export var images: Array[SingleImageColor] = []
@export_range(0.0, 60.0, 0.05) var duration: float = 2.0
@export var trans_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

func trigger(body: Node3D) -> void:
	if not body is Player:
		return
	for image_setting: SingleImageColor in images:
		if not image_setting:
			continue
		var image: CanvasItem = get_node_or_null(image_setting.target) as CanvasItem
		if not image:
			continue
		var tween: Tween = image.create_tween().set_trans(trans_type).set_ease(ease_type)
		tween.tween_property(image, "modulate", image_setting.color, duration)
