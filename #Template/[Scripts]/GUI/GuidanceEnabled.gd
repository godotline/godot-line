extends Button
class_name GuidanceEnabled

@export var image: TextureRect
@export var background: Control
@export var on: Texture2D
@export var off: Texture2D
@export var enabledByDefault: bool = false

var controller: GuidanceController = null
var enabled: bool = false
var holderProcessMode: int = Node.PROCESS_MODE_INHERIT
var holderProcessModeCached: bool = false

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	# Player creates StartPage during its own _ready(), so the controller can
	# become available one frame after this button.
	for attempt: int in range(3):
		controller = GuidanceController.Instance
		if controller:
			if not pressed.is_connected(toggle_guidance):
				pressed.connect(toggle_guidance)
			set_guidance(enabledByDefault)
			return
		await get_tree().process_frame
	visible = false

func toggle_guidance() -> void:
	set_guidance(not enabled)

func set_guidance(value: bool) -> void:
	enabled = value
	if image:
		image.texture = on if enabled else off
	if not controller:
		return

	var holder: Node3D = controller.boxHolder
	if not holder:
		_disable_without_holder()
		return

	if not holderProcessModeCached:
		holderProcessMode = holder.process_mode
		holderProcessModeCached = true
	if enabled:
		holder.process_mode = holderProcessMode
		holder.visible = true
	else:
		holder.visible = false
		holder.process_mode = Node.PROCESS_MODE_DISABLED

func _disable_without_holder() -> void:
	disabled = true
	_set_image_visible(image, false)
	_set_control_visible(background, false)
	_set_nested_images_visible(self, false)

func _set_nested_images_visible(node: Node, shouldBeVisible: bool) -> void:
	for child: Node in node.get_children():
		if child is TextureRect:
			_set_image_visible(child as TextureRect, shouldBeVisible)
		elif child is TextureButton:
			var textureButton: TextureButton = child as TextureButton
			textureButton.visible = shouldBeVisible
			if not shouldBeVisible:
				textureButton.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_nested_images_visible(child, shouldBeVisible)

func _set_image_visible(target: TextureRect, shouldBeVisible: bool) -> void:
	if not target:
		return
	target.visible = shouldBeVisible
	if not shouldBeVisible:
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _set_control_visible(target: Control, shouldBeVisible: bool) -> void:
	if not target:
		return
	target.visible = shouldBeVisible
	if not shouldBeVisible:
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE
