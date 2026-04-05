@tool
extends Area3D

var _color := Color(0,1,0)
@export var color: Color:
	get:
		return _color
	set(value):
		_color = value
		_update_mesh_color()

@export var speed := 1.0

func _update_mesh_color():
	if has_node("MeshInstance3D"):
		$MeshInstance3D.get_surface_override_material(0).albedo_color = _color

#玩家碰钻石，钻石消失
func _on_Diamond_body_entered(main_line: Node) -> void:
	State.diamond += 1
	$AnimationPlayer.play("diamond")
	$RemainParticle.emitting = true
	await $RemainParticle.finished
	queue_free()
#钻石旋转
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		rotate_y(delta * speed)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	await get_tree().process_frame
	if has_node("RemainParticle") and has_node("MeshInstance3D"):
		var mesh_material = $MeshInstance3D.get_surface_override_material(0)
		mesh_material.albedo_color = _color
		var particle_material = $RemainParticle.draw_pass_1.surface_get_material(0)
		if particle_material:
			particle_material.albedo_color = _color
