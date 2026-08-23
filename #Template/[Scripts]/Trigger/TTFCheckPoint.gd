extends Checkpoint
class_name TTFCheckPoint

## TTF checkpoint variant. The inherited Checkpoint owns all gameplay snapshots
## and revival behavior; this script adds the TTF presentation and gem pickup.

@export var rotator: Node3D
@export var checkpointGem: Node3D
@export var checkPointText: Node3D
@export var rotationSpeed: float = 90.0
@export var bobFrequency: float = 2.0
@export var bobAmplitude: float = 0.005
@export var textTargetZ: float = 100.0
@export var textMoveDuration: float = 1.5

var rotatorStartPosition: Vector3 = Vector3.ZERO
var visualTime: float = 0.0

func _ready() -> void:
	super._ready()
	if not rotator:
		rotator = checkpointContainer.get_node_or_null("Rotator") as Node3D
	if not checkpointGem and rotator:
		checkpointGem = rotator.get_node_or_null("CheckPoint_Gem/Area3D/Gem") as Node3D
	if not checkPointText:
		checkPointText = checkpointContainer.get_node_or_null("CheckPointText") as Node3D
	if rotator:
		rotatorStartPosition = rotator.position

func _process(delta: float) -> void:
	if not rotator or not checkpointContainer or not checkpointContainer.visible:
		return
	visualTime += delta
	rotator.rotate_y(deg_to_rad(rotationSpeed) * delta)
	var offsetY: float = sin(visualTime * bobFrequency) * bobAmplitude
	rotator.position = rotatorStartPosition + Vector3.UP * offsetY

func _on_checkpoint_body_entered(body: Node3D) -> void:
	EnterTrigger(body)

func EnterTrigger(body: Node3D) -> void:
	if used or not body is Player:
		return

	_enter_trigger(body)
	if checkpointGem and checkpointGem.has_method("pick_up"):
		checkpointGem.call("pick_up", false)
	_move_checkpoint_text()

func _move_checkpoint_text() -> void:
	if not checkPointText:
		return
	var tween: Tween = checkPointText.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(checkPointText, "position:z", textTargetZ, textMoveDuration)