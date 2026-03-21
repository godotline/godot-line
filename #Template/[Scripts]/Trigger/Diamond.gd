@tool
extends Area3D

@export var color := Color(0,1,0): get = get_color, set = set_color
@export var speed := 1.0
#玩家碰钻石，钻石消失
func _on_Diamond_body_entered(main_line: Node) -> void:
	State.diamond += 1
	$AnimationPlayer.play("diamond")
	await $AnimationPlayer.animation_finished
	queue_free()
#钻石旋转
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		rotate_y(delta * speed)
#设置颜色
func set_color(value: Color):
	#$MeshInstance3D.get_surface_override_material(0).albedo_color = value
	pass
#获取钻石颜色
func get_color() -> Color:
	return $MeshInstance3D.get_surface_override_material(0).albedo_color
