@tool
extends "res://#Template/[Scripts]/Trigger/Single/TTFGem.gd"
class_name TTFCheckPointGem

## Embedded TTF checkpoint gem. Its parent rotator supplies the idle rotation.

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_sprirt(delta)
	if _collection_light_elapsed < COLLECTION_LIGHT_DURATION:
		_collection_light_elapsed += delta
		var progress: float = clampf(_collection_light_elapsed / COLLECTION_LIGHT_DURATION, 0.0, 1.0)
		_gem_light.light_energy = lerpf(COLLECTION_LIGHT_ENERGY, 0.0, progress)
		if _collection_light_elapsed >= COLLECTION_LIGHT_DURATION:
			_gem_light.visible = false
	if visible:
		rotate_y(delta * speed)
