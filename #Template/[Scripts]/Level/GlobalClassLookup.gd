class_name GlobalClassLookup
extends RefCounted

## 运行时按 class_name 名称解析全局类脚本，供可选集成的单例类使用（未注册时返回 null）。
static var _cache: Dictionary = {}

static func findScript(className: String) -> GDScript:
	if _cache.has(className):
		return _cache[className]
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry["class"] == className:
			var script: GDScript = load(entry["path"]) as GDScript
			_cache[className] = script
			return script
	return null