extends Node

@export var images: Array[SingleImageColor] = []
@export_range(0.0, 3600.0, 0.01) var trigger_time: float = 0.0
@export_range(0.0, 60.0, 0.05) var duration: float = 1.0
@export var transType: Tween.TransitionType = Tween.TRANS_SINE
@export var easeType: Tween.EaseType = Tween.EASE_IN_OUT
@export var dontRevive: bool = false

var _finished: bool = false
var checkpointIndex: int = -1
var originalColors: Array[Color] = []

func _process(_delta: float) -> void:
	if _finished or LevelManager.GameState != LevelManager.GameStatus.Playing or AudioManager.time < trigger_time:
		return
	trigger_animation()

func trigger_animation() -> void:
	if _finished:
		return
	_finished = true
	checkpointIndex = LevelManager.checkpointCount
	originalColors.clear()
	for imageSetting: SingleImageColor in images:
		var image: CanvasItem = get_node_or_null(imageSetting.target) as CanvasItem if imageSetting else null
		if not image:
			originalColors.append(Color.WHITE)
			continue
		originalColors.append(image.modulate)
		image.create_tween().set_trans(transType).set_ease(easeType).tween_property(image, "modulate", imageSetting.color, duration)
	if not dontRevive:
		LevelManager.add_revive_listener(_on_revive)

func _on_revive() -> void:
	LevelManager.CompareCheckpointIndex(checkpointIndex, func() -> void:
		for index: int in images.size():
			var imageSetting: SingleImageColor = images[index]
			var image: CanvasItem = get_node_or_null(imageSetting.target) as CanvasItem if imageSetting else null
			if image and index < originalColors.size():
				image.modulate = originalColors[index]
		_finished = false
	)

func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_revive)
