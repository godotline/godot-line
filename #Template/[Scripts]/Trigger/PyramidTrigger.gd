extends Node
## PyramidTrigger - 金字塔子触发器
## 作为 BaseTrigger 的子组件，碰撞后调用父节点 Pyramid 的 trigger 方法

@export var type: Pyramid.TriggerType = Pyramid.TriggerType.Open

@export_group("Final设置")
@export var change_direction: bool = false
@export var final_direction: Vector3 = Vector3.ZERO

func trigger(_body: Node3D) -> void:
	var pyramid: Pyramid = get_parent().get_parent() as Pyramid
	if not pyramid:
		push_error("PyramidTrigger.gd: BaseTrigger 的父节点不是 Pyramid，无法触发")
		return
	pyramid.trigger(type)
	if type == Pyramid.TriggerType.Final and change_direction:
		var player: Player = Player.instance
		if player:
			player.firstDirection = final_direction
			player.secondDirection = final_direction
			player.turn()
