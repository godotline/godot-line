extends Button

@export var icon: TextureRect
@export var on_texture: Texture2D
@export var off_texture: Texture2D
@export var enabled_by_default: bool = false

var _controller: GuidanceController
var _enabled: bool = false

func _ready() -> void:
	_controller = GuidanceController.Instance
	if not _controller:
		visible = false
		return
	pressed.connect(toggle_guidance)
	set_guidance(enabled_by_default)

func toggle_guidance() -> void:
	set_guidance(not _enabled)

func set_guidance(value: bool) -> void:
	_enabled = value
	if icon:
		icon.texture = on_texture if _enabled else off_texture
	var holder: Node3D = _controller.box_holder
	if holder:
		holder.visible = _enabled
	else:
		disabled = true
