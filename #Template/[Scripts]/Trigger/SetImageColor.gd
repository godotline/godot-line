extends Node

@export var images: Array[SingleImageColor] = []
@export_range(0.0, 60.0, 0.05) var duration: float = 2.0
@export var transType: Tween.TransitionType = Tween.TRANS_SINE
@export var ease: Tween.EaseType = Tween.EASE_IN_OUT

func trigger(body: Node3D) -> bool:
	if not body is Player:
		return
	for imageSetting: SingleImageColor in images:
		if not imageSetting:
			continue
		var image: CanvasItem = get_node_or_null(imageSetting.target) as CanvasItem
		if not image:
			continue
		var tween: Tween = image.create_tween().set_trans(transType).set_ease(ease)
		tween.tween_property(image, "modulate", imageSetting.color, duration)
