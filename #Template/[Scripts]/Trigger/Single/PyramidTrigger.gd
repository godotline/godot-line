extends BaseTrigger
## PyramidTrigger - 金字塔子触发器
## 碰撞后调用父节点Pyramid的trigger方法

@export var type: Pyramid.TriggerType = Pyramid.TriggerType.Open

@export_group("Final设置")
@export var change_direction := false
@export var final_direction := Vector3.ZERO

func _on_triggered(_body: Node3D) -> void:
	var pyramid := get_parent() as Pyramid
	if not pyramid:
		push_error("PyramidTrigger.gd: 父节点不是 Pyramid，无法触发")
		return
	pyramid.trigger(type)
	if type == Pyramid.TriggerType.Final and change_direction:
		var player := Player.instance
		if player:
			player.firstDirection = final_direction
			player.secondDirection = final_direction
			player.turn()
