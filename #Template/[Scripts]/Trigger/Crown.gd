extends Checkpoint
class_name CrownCheckpoint

const CROWN_ROTATION_SPEED_DEGREES: float = 40.0
const AURA_TWEEN_DURATION: float = 1.25

@export var auraColor: Color = Color(1, 0.972549, 0, 1)

var crownMeshRenderer: MeshInstance3D
var crownRenderer: Sprite3D
var crownAura: CPUParticles3D
var crownCircle: CPUParticles3D
var crownTween: Tween
var auraTween: Tween
var particleDisappearTween: Tween
var usedParticalDisappear: bool = false

static var lastCollectedCrown: Node3D = null

func _ready() -> void:
	super._ready()
	var container: Node3D = checkpointContainer
	crownMeshRenderer = container.get_node_or_null("Crown") as MeshInstance3D
	crownRenderer = container.get_node_or_null("CrownSprite/CrownInside") as Sprite3D
	if not crownRenderer:
		crownRenderer = container.get_node_or_null("CrownSprite") as Sprite3D
	crownAura = container.get_node_or_null("FX_CrownAura") as CPUParticles3D
	crownCircle = container.get_node_or_null("FX_CrownAura/FX_CrownCircle") as CPUParticles3D
	if crownAura:
		_init_particles()
	call_deferred("_connect_player_start")

func _process(delta: float) -> void:
	if not checkpointContainer.visible or not is_instance_valid(crownMeshRenderer):
		return
	crownMeshRenderer.rotate_y(deg_to_rad(CROWN_ROTATION_SPEED_DEGREES) * delta)

func _init_particles() -> void:
	_set_particle_color(Color(auraColor.r, auraColor.g, auraColor.b, 0.0))
	crownAura.restart()
	crownAura.emitting = true

func _connect_player_start() -> void:
	if Engine.is_editor_hint():
		return
	var player: Player = Player.instance
	if is_instance_valid(player):
		var events: GameEvents = player.getEvents()
		if events and not events.onPlayerStart.is_connected(_on_player_start):
			events.onPlayerStart.connect(_on_player_start)

func _on_player_start() -> void:
	if used and lastCollectedCrown == self:
		AnimateCrown(false)

func _on_checkpoint_body_entered(body: Node3D) -> bool:
	if used:
		return false
	var player: Player = body as Player
	if not player:
		return false
	used = true
	lastCollectedCrown = self
	LevelManager.crown += 1
	_enter_trigger(player)
	_take_crown()
	return true

func trigger(body: Node3D) -> bool:
	return _on_checkpoint_body_entered(body)

func revive() -> void:
	_stop_crown_animations()
	super.revive()

func _take_crown() -> void:
	if not crownAura or not crownMeshRenderer or not crownRenderer:
		return

	_stop_crown_animations()
	_refresh_particles_color()
	crownAura.global_position = crownMeshRenderer.global_position
	_play_particles()

	var targetPosition: Vector3 = crownRenderer.global_position
	var halfDuration: float = AURA_TWEEN_DURATION / 2.0
	crownMeshRenderer.visible = false

	auraTween = create_tween()
	auraTween.set_parallel(true)

	var xTweener: PropertyTweener = auraTween.tween_property(
		crownAura, "global_position:x", targetPosition.x, AURA_TWEEN_DURATION
	)
	xTweener.set_ease(Tween.EASE_IN_OUT)
	xTweener.set_trans(Tween.TRANS_SINE)
	var zTweener: PropertyTweener = auraTween.tween_property(
		crownAura, "global_position:z", targetPosition.z, AURA_TWEEN_DURATION
	)
	zTweener.set_ease(Tween.EASE_IN_OUT)
	zTweener.set_trans(Tween.TRANS_SINE)
	var riseTweener: PropertyTweener = auraTween.tween_property(
		crownAura, "global_position:y", targetPosition.y + 5.0, halfDuration
	)
	riseTweener.set_ease(Tween.EASE_IN)
	riseTweener.set_trans(Tween.TRANS_SINE)
	var showTweener: CallbackTweener = auraTween.tween_callback(_show_spirit)
	showTweener.set_delay(halfDuration)
	var descendTweener: PropertyTweener = auraTween.tween_property(
		crownAura, "global_position:y", targetPosition.y, halfDuration
	)
	descendTweener.set_delay(halfDuration)
	descendTweener.set_ease(Tween.EASE_OUT)
	descendTweener.set_trans(Tween.TRANS_SINE)
	auraTween.finished.connect(_on_aura_tween_finished)

func _show_spirit() -> void:
	AnimateCrown(true)

func _on_aura_tween_finished() -> void:
	_stop_particles()
	auraTween = null

func AnimateCrown(show: bool) -> void:
	if not crownRenderer:
		return
	_stop_crown_fade()
	crownTween = create_tween()
	var targetAlpha: float = 1.0 if show else 0.0
	var fadeTweener: PropertyTweener = crownTween.tween_property(
		crownRenderer, "modulate:a", targetAlpha, AURA_TWEEN_DURATION / 4.0
	)
	fadeTweener.set_ease(Tween.EASE_OUT)
	fadeTweener.set_trans(Tween.TRANS_SINE)
	crownTween.finished.connect(_on_crown_tween_finished)

	if show or usedParticalDisappear or not crownAura:
		return
	usedParticalDisappear = true
	_stop_particle_disappear()
	crownAura.global_position = crownRenderer.global_position
	_play_particles()
	particleDisappearTween = create_tween()
	var spiritMotion: PropertyTweener = particleDisappearTween.tween_property(
		crownAura,
		"global_position:y",
		crownAura.global_position.y + 8.0,
		AURA_TWEEN_DURATION
	)
	spiritMotion.set_trans(Tween.TRANS_LINEAR)

func _on_crown_tween_finished() -> void:
	crownTween = null

func _refresh_particles_color() -> void:
	_set_particle_color(auraColor)

# CPUParticles3D 无 sub-emitter，FX_CrownCircle 由代码与 aura 并行触发
func _play_particles() -> void:
	if not crownAura:
		return
	crownAura.restart()
	crownAura.emitting = true
	if crownCircle:
		crownCircle.restart()
		crownCircle.emitting = true

func _stop_particles() -> void:
	if crownAura:
		crownAura.emitting = false
	if crownCircle:
		crownCircle.emitting = false

func _set_particle_color(color: Color) -> void:
	if not crownAura:
		return
	var systems: Array[CPUParticles3D] = [crownAura]
	for child: Node in crownAura.get_children():
		var system: CPUParticles3D = child as CPUParticles3D
		if system:
			systems.append(system)
	for system: CPUParticles3D in systems:
		system.color = color

func _stop_crown_fade() -> void:
	if crownTween and crownTween.is_valid():
		crownTween.kill()
	crownTween = null

func _stop_crown_animations() -> void:
	_stop_crown_fade()
	if auraTween and auraTween.is_valid():
		auraTween.kill()
	auraTween = null
	_stop_particle_disappear()

func _stop_particle_disappear() -> void:
	if particleDisappearTween and particleDisappearTween.is_valid():
		particleDisappearTween.kill()
	particleDisappearTween = null

func _exit_tree() -> void:
	_stop_crown_animations()
	var player: Player = Player.instance
	if is_instance_valid(player):
		var events: GameEvents = player.getEvents()
		if events and events.onPlayerStart.is_connected(_on_player_start):
			events.onPlayerStart.disconnect(_on_player_start)
	if lastCollectedCrown == self:
		lastCollectedCrown = null