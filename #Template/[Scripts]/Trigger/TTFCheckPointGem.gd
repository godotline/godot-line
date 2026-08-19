@tool
extends "res://#Template/[Scripts]/Trigger/TTFGem.gd"
class_name TTFCheckPointGem

## Embedded TTF checkpoint gem. Its parent rotator supplies the idle rotation.

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_sprirt(delta)
	if collectionLightElapsed < COLLECTION_LIGHT_DURATION:
		collectionLightElapsed += delta
		var progress: float = clampf(collectionLightElapsed / COLLECTION_LIGHT_DURATION, 0.0, 1.0)
		gemLight.light_energy = lerpf(COLLECTION_LIGHT_ENERGY, 0.0, progress)
		if collectionLightElapsed >= COLLECTION_LIGHT_DURATION:
			gemLight.visible = false