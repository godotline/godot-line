class_name SetLatency
extends RefCounted

## 音画延迟/音量设置持久化工具
## 对齐 Unity SetLatency.cs 的 PlayerPrefs 行为
## Unity 用 PlayerPrefs.GetFloat/SetFloat("MusicDelay"/"MusicVolume")
## Godot 用 ConfigFile 存到 user://settings.cfg

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "audio"

## 保存当前延迟和音量设置
static func save_settings(delay: float, volume: float) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "music_delay", delay)
	config.set_value(SECTION, "music_volume", volume)
	config.save(SETTINGS_PATH)

## 加载已保存的设置，返回 { "delay": float, "volume": float }
## 首次使用时自动回退为默认值（delay=0.0, volume=1.0）
static func load_settings() -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return { "delay": 0.0, "volume": 1.0 }
	return {
		"delay": config.get_value(SECTION, "music_delay", 0.0),
		"volume": config.get_value(SECTION, "music_volume", 1.0)
	}
