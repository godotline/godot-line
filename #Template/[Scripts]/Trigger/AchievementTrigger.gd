extends Node

@export var achievementKey: String = ""

func trigger(body: Node3D) -> bool:
	if not body is Player:
		return false
	var manager: GDScript = GlobalClassLookup.findScript("AchievementManager")
	if manager:
		manager.AddAchievement(achievementKey)
	return true