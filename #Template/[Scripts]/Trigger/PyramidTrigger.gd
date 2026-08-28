extends Node
## PyramidTrigger - 金字塔子触发器
## 作为 BaseTrigger 的子组件，碰撞后调用父节点 Pyramid 的 trigger 方法

@export var type: Pyramid.TriggerType = Pyramid.TriggerType.Open

@export var changeDirection: bool = false
@export var finalDirection: Vector3 = Vector3.ZERO

func trigger(body: Node3D) -> bool:
	# FakePlayer 也使用 CharacterBody3D 宿主，不能把它当作真实玩家触发金字塔。
	if body != Player.instance:
		return false

	var pyramid: Pyramid = get_parent().get_parent() as Pyramid
	if not pyramid:
		push_error("PyramidTrigger.gd: BaseTrigger 的父节点不是 Pyramid，无法触发")
		return false
	pyramid.trigger(type)
	if type == Pyramid.TriggerType.Final and changeDirection:
		var player: Player = Player.instance
		if player:
			player.firstDirection = finalDirection
			player.secondDirection = finalDirection
			player.Turn()
	return true
