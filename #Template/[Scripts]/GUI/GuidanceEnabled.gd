extends Button
class_name GuidanceEnabled

## 对齐 Unity GuidanceEnabled.cs：开始界面底栏的引导线显示开关（图标切换按钮）。
## 注：Unity 的 `new bool enabled` 在 Godot 中无同名冲突，直接同名导出，
## 既是序列化默认值也是运行时状态（与 Unity 语义一致）。

@export var image: TextureRect
@export var background: Control
@export var on: Texture2D
@export var off: Texture2D
@export var enabled: bool = false

var controller: GuidanceController = null
var holderProcessMode: int = Node.PROCESS_MODE_INHERIT
var holderProcessModeCached: bool = false

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	# Player 创建 StartPage 晚于自身 _ready()，控制器可能晚一帧才可用
	for attempt: int in range(3):
		controller = GuidanceController.Instance
		if controller:
			if not pressed.is_connected(OnClick):
				pressed.connect(OnClick)
			SetGuidance(enabled)
			return
		await get_tree().process_frame
	visible = false

## 对齐 Unity OnClick()：点击取反并应用
func OnClick() -> void:
	enabled = not enabled
	SetGuidance(enabled)

## 对齐 Unity SetGuidance(bool)：切换图标并启用/停用引导容器
func SetGuidance(value: bool) -> void:
	enabled = value
	if image:
		image.texture = on if enabled else off
	if not controller:
		return

	var holder: Node3D = controller.boxHolder
	if not holder:
		_disable_without_holder()
		return

	# 首次接触时缓存容器原始 process_mode，便于恢复
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
