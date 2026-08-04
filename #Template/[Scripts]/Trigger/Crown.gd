extends Checkpoint
class_name CrownCheckpoint

const CROWN_ROTATION_SPEED_DEGREES: float = 40.0
const AURA_TWEEN_DURATION: float = 1.25

@export var aura_color: Color = Color(1, 0.972549, 0, 1)

var _crown_mesh: MeshInstance3D
var _crown_sprite: Sprite3D
var _aura_particles: GPUParticles3D
var _crown_tween: Tween
var _aura_tween: Tween
var _particle_disappear_tween: Tween
var _used_particle_disappear: bool = false

static var _last_collected_crown: Node3D = null

func _ready() -> void:
	super._ready()
	var container: Node3D = _checkpoint_container
	_crown_mesh = container.get_node_or_null("Crown") as MeshInstance3D
	_crown_sprite = container.get_node_or_null("CrownSprite/CrownInside") as Sprite3D
	if not _crown_sprite:
		_crown_sprite = container.get_node_or_null("CrownSprite") as Sprite3D
	_aura_particles = container.get_node_or_null("FX_CrownAura") as GPUParticles3D
	if _aura_particles:
		_init_particles()
	call_deferred("_connect_player_start")

func _process(delta: float) -> void:
	if not _checkpoint_container.visible or not is_instance_valid(_crown_mesh):
		return
	_crown_mesh.rotate_y(deg_to_rad(CROWN_ROTATION_SPEED_DEGREES) * delta)

func _init_particles() -> void:
	_set_particle_color(Color(aura_color.r, aura_color.g, aura_color.b, 0.0))
	_aura_particles.restart()
	_aura_particles.emitting = true

func _connect_player_start() -> void:
	if Engine.is_editor_hint():
		return
	var player: Player = Player.instance
	if is_instance_valid(player) and not player.on_player_start.is_connected(_on_player_start):
		player.on_player_start.connect(_on_player_start)

func _on_player_start() -> void:
	if used and _last_collected_crown == self:
		animate_crown(false)

func _on_checkpoint_body_entered(body: Node3D) -> void:
	if used:
		return
	var player: Player = body as Player
	if not player:
		return
	used = true
	_last_collected_crown = self
	LevelManager.crown += 1
	_enter_trigger(player)
	_take_crown()

func trigger(body: Node3D) -> void:
	_on_checkpoint_body_entered(body)

func revive() -> void:
	_stop_crown_animations()
	super.revive()

func _take_crown() -> void:
	if not _aura_particles or not _crown_mesh or not _crown_sprite:
		return

	_stop_crown_animations()
	_refresh_particles_color()
	_aura_particles.global_position = _crown_mesh.global_position
	_aura_particles.restart()
	_aura_particles.emitting = true

	var target_position: Vector3 = _crown_sprite.global_position
	var half_duration: float = AURA_TWEEN_DURATION / 2.0
	_crown_mesh.visible = false

	_aura_tween = create_tween()
	_aura_tween.set_parallel(true)

	var x_tweener: PropertyTweener = _aura_tween.tween_property(
		_aura_particles, "global_position:x", target_position.x, AURA_TWEEN_DURATION
	)
	x_tweener.set_ease(Tween.EASE_IN_OUT)
	x_tweener.set_trans(Tween.TRANS_SINE)
	var z_tweener: PropertyTweener = _aura_tween.tween_property(
		_aura_particles, "global_position:z", target_position.z, AURA_TWEEN_DURATION
	)
	z_tweener.set_ease(Tween.EASE_IN_OUT)
	z_tweener.set_trans(Tween.TRANS_SINE)
	var rise_tweener: PropertyTweener = _aura_tween.tween_property(
		_aura_particles, "global_position:y", target_position.y + 5.0, half_duration
	)
	rise_tweener.set_ease(Tween.EASE_IN)
	rise_tweener.set_trans(Tween.TRANS_SINE)
	var show_tweener: CallbackTweener = _aura_tween.tween_callback(_show_spirit)
	show_tweener.set_delay(half_duration)
	var descend_tweener: PropertyTweener = _aura_tween.tween_property(
		_aura_particles, "global_position:y", target_position.y, half_duration
	)
	descend_tweener.set_delay(half_duration)
	descend_tweener.set_ease(Tween.EASE_OUT)
	descend_tweener.set_trans(Tween.TRANS_SINE)
	_aura_tween.finished.connect(_on_aura_tween_finished)

func _show_spirit() -> void:
	animate_crown(true)

func _on_aura_tween_finished() -> void:
	if _aura_particles:
		_aura_particles.emitting = false
	_aura_tween = null

func animate_crown(show: bool) -> void:
	if not _crown_sprite:
		return
	_stop_crown_fade()
	_crown_tween = create_tween()
	var target_alpha: float = 1.0 if show else 0.0
	var fade_tweener: PropertyTweener = _crown_tween.tween_property(
		_crown_sprite, "modulate:a", target_alpha, AURA_TWEEN_DURATION / 4.0
	)
	fade_tweener.set_ease(Tween.EASE_OUT)
	fade_tweener.set_trans(Tween.TRANS_SINE)
	_crown_tween.finished.connect(_on_crown_tween_finished)

	if show or _used_particle_disappear or not _aura_particles:
		return
	_used_particle_disappear = true
	_stop_particle_disappear()
	_aura_particles.restart()
	_aura_particles.emitting = true
	_aura_particles.global_position = _crown_sprite.global_position
	_particle_disappear_tween = create_tween()
	var spirit_motion: PropertyTweener = _particle_disappear_tween.tween_property(
		_aura_particles,
		"global_position:y",
		_aura_particles.global_position.y + 8.0,
		AURA_TWEEN_DURATION
	)
	spirit_motion.set_trans(Tween.TRANS_LINEAR)

func _on_crown_tween_finished() -> void:
	_crown_tween = null

func _refresh_particles_color() -> void:
	_set_particle_color(aura_color)

func _set_particle_color(color: Color) -> void:
	if not _aura_particles:
		return
	var systems: Array[GPUParticles3D] = [_aura_particles]
	for child: Node in _aura_particles.get_children():
		var system: GPUParticles3D = child as GPUParticles3D
		if system:
			systems.append(system)
	for system: GPUParticles3D in systems:
		var process_material: ParticleProcessMaterial = system.process_material as ParticleProcessMaterial
		if process_material:
			process_material.color = color

func _stop_crown_fade() -> void:
	if _crown_tween and _crown_tween.is_valid():
		_crown_tween.kill()
	_crown_tween = null

func _stop_crown_animations() -> void:
	_stop_crown_fade()
	if _aura_tween and _aura_tween.is_valid():
		_aura_tween.kill()
	_aura_tween = null
	_stop_particle_disappear()

func _stop_particle_disappear() -> void:
	if _particle_disappear_tween and _particle_disappear_tween.is_valid():
		_particle_disappear_tween.kill()
	_particle_disappear_tween = null

func _exit_tree() -> void:
	_stop_crown_animations()
	var player: Player = Player.instance
	if is_instance_valid(player) and player.on_player_start.is_connected(_on_player_start):
		player.on_player_start.disconnect(_on_player_start)
	if _last_collected_crown == self:
		_last_collected_crown = null
