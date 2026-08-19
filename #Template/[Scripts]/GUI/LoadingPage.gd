extends CanvasLayer
class_name LoadingPage

@onready var root: Control = $Root
@onready var background: ColorRect = $Root/Background
@onready var loadingImage: TextureRect = $Root/Rotator
@onready var loadingText: Label = $Root/LoadingText

func _ready() -> void:
	root.modulate.a = 0.0
	set_process(true)

func reveal(backgroundColor: Color) -> Tween:
	background.color = backgroundColor
	var contentColor: Color = _content_color_for(backgroundColor)
	loadingImage.modulate = contentColor
	loadingText.modulate = contentColor
	var tween: Tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(root, "modulate:a", 1.0, 0.4)
	return tween

func _process(delta: float) -> void:
	loadingImage.rotation += delta * 2.4

static func _content_color_for(color: Color) -> Color:
	var luminance: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color.BLACK if luminance > 0.55 else Color.WHITE
