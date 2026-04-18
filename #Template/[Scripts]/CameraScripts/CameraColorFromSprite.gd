extends Node
class_name CameraColorFromSprite

@export var texture_rect: TextureRect
@export var sample_count: int = 100
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
	if not texture_rect or not texture_rect.texture:
		return
	
	var image := texture_rect.texture.get_image()
	if not image:
		return
	
	var main_color := _get_main_color(image)
	
	# Set camera background color
	if camera:
		var env := camera.environment
		if not env:
			env = Environment.new()
			camera.environment = env
		env.background_mode = Environment.BG_COLOR
		env.background_color = main_color

func _get_main_color(image: Image) -> Color:
	var color_count := {}
	var width := image.get_width()
	var height := image.get_height()
	
	for i in sample_count:
		var x := randi() % width
		var y := randi() % height
		var color := image.get_pixel(x, y)
		
		# Use color as key (convert to string for dictionary)
		var color_key := "%f,%f,%f,%f" % [color.r, color.g, color.b, color.a]
		if color_count.has(color_key):
			color_count[color_key]["count"] += 1
		else:
			color_count[color_key] = {"color": color, "count": 1}
	
	var main_color := Color.WHITE
	var max_count := 0
	
	for key in color_count:
		var data = color_count[key]
		if data["count"] > max_count:
			max_count = data["count"]
			main_color = data["color"]
	
	return main_color
