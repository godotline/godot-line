extends Node

@export var achievementKey: String = ""

func trigger(body: Node3D) -> bool:
	if not body is Player:
		return false
	# 对齐 Unity：AchievementManager 单例（class_name，static func AddAchievement），未集成时跳过
	var manager: GDScript = GlobalClassLookup.findScript("AchievementManager")
	if manager:
		manager.AddAchievement(achievementKey)
	return true
