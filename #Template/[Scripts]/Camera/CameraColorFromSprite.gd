extends Node
class_name CameraColorFromSprite

@export var textureRect: TextureRect
@export var sampleCount: int = 100
@export var camera: Camera3D

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_get_color)
	add_child(_timer)
	_timer.start()
	
	# Get color immediately on start
	_get_color()

func _get_color() -> void:
	if not textureRect or not textureRect.texture:
		return
	
	var image: Image = textureRect.texture.get_image()
	if not image:
		return
	
	var mainColor: Color = _get_main_color(image)
	
	# Set camera background color
	if camera:
		var env: Environment = camera.environment
		if not env:
			env = Environment.new()
			camera.environment = env
		env.background_mode = Environment.BG_COLOR
		env.background_color = mainColor

func _get_main_color(image: Image) -> Color:
	var colorCount: Dictionary = {}
	var width: int = image.get_width()
	var height: int = image.get_height()
	
	for i in sampleCount:
		var x: int = randi() % width
		var y: int = randi() % height
		var color: Color = image.get_pixel(x, y)
		
		# Use color as key (convert to string for dictionary)
		var colorKey: String = "%f,%f,%f,%f" % [color.r, color.g, color.b, color.a]
		if colorCount.has(colorKey):
			colorCount[colorKey]["count"] += 1
		else:
			colorCount[colorKey] = {"color": color, "count": 1}
	
	var mainColor: Color = Color.WHITE
	var maxCount: int = 0
	
	for key in colorCount:
		var data: Dictionary = colorCount[key]
		if data["count"] > maxCount:
			maxCount = data["count"]
			mainColor = data["color"]
	
	return mainColor
