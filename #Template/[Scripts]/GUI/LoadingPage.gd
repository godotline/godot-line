extends CanvasLayer
class_name LoadingPage

@onready var root: Control = $Root
@onready var background: ColorRect = $Root/Background
@onready var rotator: TextureRect = $Root/Rotator
@onready var loading_text: Label = $Root/LoadingText

func _ready() -> void:
	root.modulate.a = 0.0
	set_process(true)

func reveal(background_color: Color) -> Tween:
	background.color = background_color
	var content_color: Color = _content_color_for(background_color)
	rotator.modulate = content_color
	loading_text.modulate = content_color
	var tween: Tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(root, "modulate:a", 1.0, 0.4)
	return tween

func _process(delta: float) -> void:
	rotator.rotation += delta * 2.4

static func _content_color_for(color: Color) -> Color:
	var luminance: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color.BLACK if luminance > 0.55 else Color.WHITE
