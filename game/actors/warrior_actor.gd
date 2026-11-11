## WarriorActor — presentación del Warrior: animación LPC, VFX y sonido.
##
## Es un nodo de presentación puro. Lee el estado de [WarriorSim] en _process y
## escucha sus señales; nunca modifica la simulación.
class_name WarriorActor
extends Node2D

const SFX_SLASH := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Slash2.wav")
const SFX_SLASH_HEAVY := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Sword2.wav")
const SFX_HIT := preload("res://assets/audio/sfx/ninja/Hit_Impact/Hit2.wav")
const SFX_HIT_HEAVY := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact3.wav")
const SFX_HURT := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact.wav")
const SFX_DEATH := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact5.wav")

const FLASH_SECONDS := 0.14

var sim: WarriorSim
var arena: Arena
var sprite: AnimatedSprite2D

var _facing: String = "down"
var _current_skill: Dictionary = {}
var _flash: float = 0.0
var _dead_visual: bool = false
var _death_tween: Tween = null


func setup(p_sim: WarriorSim, p_arena: Arena) -> void:
	sim = p_sim
	arena = p_arena
	_build_sprite()
	_connect_signals()


func _build_sprite() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.name = "LpcSprite"
	sprite.sprite_frames = WarriorLook.frames()
	sprite.position = LpcComposer.FEET_OFFSET
	sprite.centered = true
	sprite.z_index = 1
	add_child(sprite)
	sprite.play("combat_idle_down")
	_facing = "down"


func _connect_signals() -> void:
	sim.attack_started.connect(_on_attack_started)
	sim.attack_state_changed.connect(_on_attack_state_changed)
	sim.attack_hit.connect(_on_attack_hit)
	sim.attack_finished.connect(_on_attack_finished)
	sim.damage_taken.connect(_on_damage_taken)
	sim.died.connect(_on_died)
	sim.vengeful_changed.connect(_on_vengeful_changed)


func _process(delta: float) -> void:
	if sim == null:
		return
	position = sim.position
	_flash = maxf(0.0, _flash - delta)

	if sim.alive:
		if _dead_visual:
			_restore_visual()
		_update_facing()
		_update_animation()
		_apply_damage_flash()
	else:
		_apply_damage_flash()

	queue_redraw()


func _update_facing() -> void:
	if sim.is_attacking():
		return
	if sim.velocity.length_squared() > 64.0:
		_facing = _dir_name(sim.velocity)
	else:
		_facing = _dir_name(sim.aim_dir)


func _dir_name(direction: Vector2) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "right" if direction.x >= 0.0 else "left"
	return "down" if direction.y >= 0.0 else "up"


func _update_animation() -> void:
	if sim.is_attacking():
		match sim.state:
			WarriorSim.AttackState.WINDUP:
				sprite.speed_scale = 1.0
				_play("combat_idle")
			WarriorSim.AttackState.ACTIVE, WarriorSim.AttackState.RECOVERY:
				pass
		return

	sprite.speed_scale = 1.0
	if sim.velocity.length_squared() > 196.0:
		_play("walk")
		var speed_ratio := sim.velocity.length() / WarriorSim.MOVE_SPEED
		sprite.speed_scale = clampf(0.75 + speed_ratio * 0.55, 0.75, 1.4)
	else:
		_play("combat_idle")


func _play(anim: String) -> void:
	var full := "%s_%s" % [anim, _facing]
	if sprite.animation == full and sprite.is_playing():
		return
	sprite.play(full)


func _on_attack_started(skill: Dictionary, direction: Vector2) -> void:
	_current_skill = skill
	_facing = _dir_name(direction)


func _on_attack_state_changed(state: int) -> void:
	if state != WarriorSim.AttackState.ACTIVE or _current_skill.is_empty():
		return

	var slot := String(_current_skill.get("slot", "M1"))
	var heavy := slot == "M2"
	var anim := String(_current_skill.get("anim", "slash"))
	_facing = _dir_name(sim.attack_aim)

	sprite.speed_scale = 0.85 if heavy else 1.55
	sprite.play("%s_%s" % [anim, _facing])

	if arena == null:
		return
	arena.spawn_slash(
		sim.position,
		sim.attack_aim,
		float(_current_skill.get("range", 78.0)),
		float(_current_skill.get("arc", 110.0)),
		heavy
	)
	arena.play_sfx(SFX_SLASH_HEAVY if heavy else SFX_SLASH, -7.0, randf_range(0.94, 1.08))
	if heavy:
		arena.shake(2.4, 0.14)


func _on_attack_hit(skill: Dictionary, _target: Object, damage: float, critical: bool, hit_position: Vector2) -> void:
	if arena == null:
		return
	var heavy := String(skill.get("slot", "M1")) == "M2"
	arena.spawn_damage_number(hit_position, damage, critical)
	arena.spawn_impact(hit_position, Color(1.0, 0.72, 0.32, 1.0), heavy)
	arena.play_sfx(SFX_HIT_HEAVY if heavy else SFX_HIT, -5.0, randf_range(0.92, 1.06))
	arena.shake(2.0 if not heavy else 3.0, 0.12)


func _on_attack_finished(_skill: Dictionary) -> void:
	_current_skill = {}
	sprite.speed_scale = 1.0


func _on_damage_taken(_amount: float, _source_position: Vector2, is_dot: bool) -> void:
	if is_dot:
		return
	_flash = FLASH_SECONDS
	if arena != null:
		arena.play_sfx(SFX_HURT, -6.0, randf_range(0.92, 1.05))
		arena.shake(3.2, 0.18)


func _on_died() -> void:
	_dead_visual = true
	if arena != null:
		arena.play_sfx(SFX_DEATH, -4.0, 0.9)
		arena.shake(5.0, 0.35)

	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = create_tween().set_parallel(true)
	_death_tween.tween_property(sprite, "rotation", 1.35, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_death_tween.tween_property(sprite, "position", LpcComposer.FEET_OFFSET + Vector2(12.0, -6.0), 0.38)
	_death_tween.tween_property(sprite, "modulate", Color(0.55, 0.55, 0.62, 0.85), 0.38)


func _restore_visual() -> void:
	_dead_visual = false
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	sprite.rotation = 0.0
	sprite.position = LpcComposer.FEET_OFFSET
	sprite.modulate = Color.WHITE
	sprite.speed_scale = 1.0
	sprite.play("combat_idle_%s" % _facing)


func _on_vengeful_changed(active: bool, _seconds_left: float) -> void:
	if active and arena != null:
		arena.play_sfx(SFX_HIT, -16.0, 0.65)


func _apply_damage_flash() -> void:
	if _dead_visual:
		return
	if _flash > 0.0:
		var t := _flash / FLASH_SECONDS
		sprite.modulate = Color(1.0 + t * 0.9, 0.72 + (1.0 - t) * 0.28, 0.72 + (1.0 - t) * 0.28, 1.0)
	else:
		sprite.modulate = Color.WHITE


func _draw() -> void:
	if sim == null:
		return

	# Sombra elíptica bajo los pies.
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 13.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Aura de Vengeful Fury cuando la pasiva está cargada.
	if sim.vengeful_active and sim.alive:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		var aura := Color(1.0, 0.38, 0.12, 0.30 + 0.22 * pulse)
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, 19.0 + pulse * 2.0, Color(1.0, 0.35, 0.10, 0.10 + 0.06 * pulse))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2(0, -2), 20.0 + pulse * 2.0, 0.0, TAU, 32, aura, 2.0)
