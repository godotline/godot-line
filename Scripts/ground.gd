extends MeshInstance3D

@export var start_visible := true

func _ready() -> void:
	$".".visible = start_visible
