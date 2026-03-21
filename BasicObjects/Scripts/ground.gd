extends MeshInstance3D

@export var start_visible := true

func _ready() -> void:
	if bool(State.get("is_restoring_checkpoint")):
		return
	$".".visible = start_visible
