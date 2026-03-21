extends Area3D
 #转向
func _on_ChangeTurn_body_entered(main_line: Node) -> void:
	if "is_turn" in main_line: main_line.is_turn = not main_line.is_turn
