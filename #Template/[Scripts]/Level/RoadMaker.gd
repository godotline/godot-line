extends Node3D

@export var base_floor:PackedScene
@export var road_width := 3.0

@onready var main_line:Node3D = get_parent()
@onready var past_translation := main_line.position

var road:StaticBody3D
var roads := Node3D.new()

func _ready() -> void:
	if main_line:
		if main_line.has_signal("new_line1"):
			main_line.connect("new_line1", Callable(self, "new_road"))
		if main_line.has_signal("on_sky"):
			main_line.connect("on_sky", Callable(self, "on_sky"))
	roads.name = "Roads"
	roads.position = to_global(position)
	get_tree().current_scene.call_deferred("add_child",roads)

func new_road():
	road = base_floor.instantiate()
	road.position = main_line.position
	past_translation = main_line.position
	roads.add_child(road)
	road.owner = roads

func _physics_process(_delta: float) -> void:
	if road:
		var offset := main_line.position - past_translation
		road.position = offset / 2 + past_translation
		road.scale = offset.abs() + Vector3(road_width,1,road_width)

func _input(event: InputEvent) -> void:
	if event.is_action("save"):
		save()

func save() -> void:
	var roads_scene := PackedScene.new()
	roads_scene.pack(roads)
	ResourceSaver.save(roads_scene,"res://Roads.tscn")

func on_sky():
	road = null
