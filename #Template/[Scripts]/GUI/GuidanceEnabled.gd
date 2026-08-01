extends Button
class_name GuidanceEnabled

@export var image: TextureRect
@export var background: Control
@export var on_texture: Texture2D
@export var off_texture: Texture2D
@export var enabled_by_default: bool = false

var _controller: GuidanceController = null
var _enabled: bool = false
var _holder_process_mode: int = Node.PROCESS_MODE_INHERIT
var _holder_process_mode_cached: bool = false

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	# Player creates StartPage during its own _ready(), so the controller can
	# become available one frame after this button.
	for attempt: int in range(3):
		_controller = GuidanceController.Instance
		if _controller:
			if not pressed.is_connected(toggle_guidance):
				pressed.connect(toggle_guidance)
			set_guidance(enabled_by_default)
			return
		await get_tree().process_frame
	visible = false

func toggle_guidance() -> void:
	set_guidance(not _enabled)

func set_guidance(value: bool) -> void:
	_enabled = value
	if image:
		image.texture = on_texture if _enabled else off_texture
	if not _controller:
		return

	var holder: Node3D = _controller.box_holder
	if not holder:
		_disable_without_holder()
		return

	if not _holder_process_mode_cached:
		_holder_process_mode = holder.process_mode
		_holder_process_mode_cached = true
	if _enabled:
		holder.process_mode = _holder_process_mode
		holder.visible = true
	else:
		holder.visible = false
		holder.process_mode = Node.PROCESS_MODE_DISABLED

func _disable_without_holder() -> void:
	disabled = true
	_set_image_visible(image, false)
	_set_control_visible(background, false)
	_set_nested_images_visible(self, false)

func _set_nested_images_visible(node: Node, should_be_visible: bool) -> void:
	for child: Node in node.get_children():
		if child is TextureRect:
			_set_image_visible(child as TextureRect, should_be_visible)
		elif child is TextureButton:
			var texture_button: TextureButton = child as TextureButton
			texture_button.visible = should_be_visible
			if not should_be_visible:
				texture_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_nested_images_visible(child, should_be_visible)

func _set_image_visible(target: TextureRect, should_be_visible: bool) -> void:
	if not target:
		return
	target.visible = should_be_visible
	if not should_be_visible:
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _set_control_visible(target: Control, should_be_visible: bool) -> void:
	if not target:
		return
	target.visible = should_be_visible
	if not should_be_visible:
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE
