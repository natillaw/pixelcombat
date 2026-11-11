## PlayerActor — presentación del Warrior: animación LPC, VFX y sonido.
##
## Es un nodo de presentación puro. Lee el estado de [PlayerSim] en _process y
## escucha sus señales; nunca modifica la simulación.
class_name PlayerActor
extends Node2D

const SFX_SLASH := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Slash2.wav")
const SFX_SLASH_HEAVY := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Sword2.wav")
const SFX_HIT := preload("res://assets/audio/sfx/ninja/Hit_Impact/Hit2.wav")
const SFX_HIT_HEAVY := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact3.wav")
const SFX_HURT := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact.wav")
const SFX_DEATH := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact5.wav")

const SFX_DODGE := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Whoosh.wav")

const FLASH_SECONDS := 0.14
const AFTERIMAGE_INTERVAL := 0.035
const AFTERIMAGE_LIFETIME := 0.22
const DODGE_ALPHA := 0.62
const LEAP_HEIGHT := 34.0
const GOLD_TEXT := Color(1.0, 0.82, 0.3, 1.0)
const XP_TEXT := Color(0.55, 0.75, 1.0, 1.0)

var sim: PlayerSim
var arena: Arena
var sprite: AnimatedSprite2D

const FACING_HYSTERESIS := 1.15

var _facing: String = "down"
var _current_skill: Dictionary = {}
var _flash: float = 0.0
var _dead_visual: bool = false
var _death_tween: Tween = null
var _afterimage_timer: float = 0.0


func setup(p_sim: PlayerSim, p_arena: Arena) -> void:
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
	sim.dodge_started.connect(_on_dodge_started)
	sim.dodge_ended.connect(_on_dodge_ended)
	sim.attack_evaded.connect(_on_attack_evaded)
	sim.skill_denied.connect(_on_skill_denied)
	sim.ultimate_ready.connect(_on_ultimate_ready)
	sim.attack_blocked.connect(_on_attack_blocked)
	sim.xp_gained.connect(_on_xp_gained)
	sim.leveled_up.connect(_on_leveled_up)


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
		_update_dodge_visual(delta)
		_update_leap_visual()
		_apply_damage_flash()
	else:
		_apply_damage_flash()

	queue_redraw()


## Estilo Drakantos: el personaje siempre encara el cursor, se mueva o no
## (strafe). Durante un ataque la direccion queda fijada por `attack_aim`.
func _update_facing() -> void:
	if sim.is_attacking():
		return
	_facing = facing_for(sim.aim_dir, _facing)


## Direccion de 4 vias para un vector de apuntado. Con histeresis: solo cambia
## de eje cuando el otro eje gana por mas de un 15 %, para que el sprite no
## parpadee en las diagonales.
static func facing_for(direction: Vector2, current: String) -> String:
	var ax := absf(direction.x)
	var ay := absf(direction.y)
	var horizontal := current == "left" or current == "right"
	if horizontal and ay <= ax * FACING_HYSTERESIS:
		return "right" if direction.x >= 0.0 else "left"
	if not horizontal and current != "" and ax <= ay * FACING_HYSTERESIS:
		return "down" if direction.y >= 0.0 else "up"
	return _dir_name(direction)


static func _dir_name(direction: Vector2) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "right" if direction.x >= 0.0 else "left"
	return "down" if direction.y >= 0.0 else "up"


func _update_animation() -> void:
	if sim.is_attacking():
		match sim.state:
			PlayerSim.AttackState.WINDUP:
				sprite.speed_scale = 1.0
				_play("combat_idle")
			PlayerSim.AttackState.ACTIVE, PlayerSim.AttackState.RECOVERY:
				pass
		return

	if sim.dodging:
		sprite.speed_scale = 1.8
		_play("run")
		return

	sprite.speed_scale = 1.0
	if sim.velocity.length_squared() > 196.0:
		_play("walk")
		var speed_ratio := sim.velocity.length() / PlayerSim.MOVE_SPEED
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
	if state != PlayerSim.AttackState.ACTIVE or _current_skill.is_empty():
		return

	var slot := String(_current_skill.get("slot", "M1"))
	var heavy := slot != "M1"
	var anim := String(_current_skill.get("anim", "slash"))
	_facing = _dir_name(sim.attack_aim)

	sprite.speed_scale = 0.85 if heavy else 1.55
	sprite.play("%s_%s" % [anim, _facing])

	if arena == null:
		return
	arena.spawn_slash(
		sim.position,
		sim.attack_aim,
		sim.attack_range_now(),
		visual_arc(_current_skill),
		heavy
	)
	arena.play_sfx(SFX_SLASH_HEAVY if heavy else SFX_SLASH, -7.0, randf_range(0.94, 1.08))
	if String(_current_skill.get("kind", "")) == "ultimate":
		arena.spawn_impact(sim.position, Color(1.0, 0.7, 0.3, 1.0), true)
		arena.play_sfx(SFX_DEATH, -3.0, 0.75)
		arena.shake(7.0, 0.4)
	elif heavy:
		arena.shake(2.4, 0.14)


func _on_attack_hit(skill: Dictionary, _target: Object, damage: float, critical: bool, hit_position: Vector2) -> void:
	if arena == null:
		return
	var heavy := String(skill.get("slot", "M1")) != "M1"
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


## Durante la esquiva el sprite se vuelve semitransparente (mientras dura la
## invulnerabilidad) y deja una estela de imagenes residuales.
func _update_dodge_visual(delta: float) -> void:
	if not sim.dodging:
		_afterimage_timer = 0.0
		return
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = AFTERIMAGE_INTERVAL
		_spawn_afterimage()


func _spawn_afterimage() -> void:
	if arena == null or sprite.sprite_frames == null:
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.centered = true
	ghost.z_index = 0
	ghost.modulate = Color(0.55, 0.8, 1.0, 0.45)
	arena.fx.add_child(ghost)
	ghost.global_position = sprite.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, AFTERIMAGE_LIFETIME)
	tween.tween_callback(ghost.queue_free)


## Arco que se dibuja para la skill: el del cono, un tajo estrecho para una linea
## y 360 para un circulo.
static func visual_arc(skill: Dictionary) -> float:
	match String(skill.get("shape", "cone")):
		"line":
			return 24.0
		"circle":
			return 360.0
		_:
			return float(skill.get("arc", 110.0))


func _on_skill_denied(_slot: String, reason: String) -> void:
	if arena == null:
		return
	var label := "NO CHARGE" if reason == "charge" else "NO RAGE"
	arena.spawn_floating_text(sim.position, label, Color(1.0, 0.45, 0.35, 1.0))


## Bloqueo de la postura del Special: destello, texto y el corte de respuesta.
func _on_attack_blocked(source_position: Vector2) -> void:
	if arena == null:
		return
	var direction := (source_position - sim.position).normalized() if source_position != sim.position else sim.aim_dir
	arena.spawn_impact(sim.position + direction * 22.0, GOLD_TEXT, true)
	arena.spawn_slash(sim.position, direction, sim.attack_range_now(), visual_arc(sim.current_skill), true)
	arena.spawn_floating_text(sim.position + Vector2(0.0, -6.0), "BLOCK", GOLD_TEXT)
	arena.play_sfx(SFX_HIT_HEAVY, -3.0, 0.8)
	arena.shake(3.5, 0.18)
	_facing = _dir_name(direction)


func _on_xp_gained(amount: int, _source_position: Vector2) -> void:
	if arena != null:
		arena.spawn_floating_text(sim.position + Vector2(0.0, 6.0), "+%d XP" % amount, XP_TEXT)


func _on_leveled_up(new_level: int, unlocked: Array) -> void:
	if arena == null:
		return
	arena.spawn_impact(sim.position, GOLD_TEXT, true)
	arena.spawn_floating_text(sim.position + Vector2(0.0, -26.0), "LEVEL UP  %d" % new_level, GOLD_TEXT)
	var row := 0
	for id: StringName in unlocked:
		row += 1
		arena.spawn_floating_text(sim.position + Vector2(0.0, -26.0 - 12.0 * row), "NEW: %s" % SkillCatalog.skill(id).get("name", id), Color(0.7, 0.95, 0.7, 1.0))
	arena.play_sfx(SFX_HIT, -5.0, 1.5)
	arena.shake(2.5, 0.2)


func _on_ultimate_ready() -> void:
	if arena == null:
		return
	arena.spawn_floating_text(sim.position + Vector2(0.0, -10.0), "ULTIMATE READY", GOLD_TEXT)
	arena.play_sfx(SFX_HIT, -8.0, 0.5)


## Arco vertical del salto: el sprite sube y baja durante el windup de una skill
## aim_leap. La sombra y la posicion de la simulacion no cambian.
func _update_leap_visual() -> void:
	if _dead_visual:
		return
	var leaping := sim.state == PlayerSim.AttackState.WINDUP and String(sim.current_skill.get("anchor", "self")) == "aim_leap"
	if leaping:
		var t := clampf(sim.state_time / maxf(float(sim.current_skill["windup"]), 0.001), 0.0, 1.0)
		sprite.position = LpcComposer.FEET_OFFSET + Vector2(0.0, -sin(t * PI) * LEAP_HEIGHT)
	elif sprite.position != LpcComposer.FEET_OFFSET:
		sprite.position = LpcComposer.FEET_OFFSET


func _on_dodge_started(_direction: Vector2) -> void:
	_current_skill = {}
	sprite.speed_scale = 1.8
	if arena == null:
		return
	arena.spawn_impact(sim.position + Vector2(0.0, 6.0), Color(0.82, 0.86, 0.95, 0.9), false)
	arena.play_sfx(SFX_DODGE, -10.0, randf_range(1.05, 1.2))


func _on_dodge_ended() -> void:
	sprite.modulate = Color.WHITE
	sprite.speed_scale = 1.0


func _on_attack_evaded(_source_position: Vector2) -> void:
	if arena == null:
		return
	arena.spawn_floating_text(sim.position, "DODGE", Color(0.6, 0.85, 1.0, 1.0))
	arena.play_sfx(SFX_DODGE, -6.0, 1.4)


func _on_vengeful_changed(active: bool, _seconds_left: float) -> void:
	if active and arena != null:
		arena.play_sfx(SFX_HIT, -16.0, 0.65)


func _apply_damage_flash() -> void:
	if _dead_visual:
		return
	if _flash > 0.0:
		var t := _flash / FLASH_SECONDS
		sprite.modulate = Color(1.0 + t * 0.9, 0.72 + (1.0 - t) * 0.28, 0.72 + (1.0 - t) * 0.28, 1.0)
	elif sim != null and sim.is_invulnerable():
		sprite.modulate = Color(0.75, 0.9, 1.0, DODGE_ALPHA)
	else:
		sprite.modulate = Color.WHITE


## Escudo frontal mientras la postura del Special esta abierta: un arco del
## ancho real del bloqueo, hacia donde apunta el jugador.
func _draw_stance() -> void:
	if not sim.alive or not sim.stance_active():
		return
	var half := deg_to_rad(float(sim.current_skill["stance"]["arc"]) * 0.5)
	var angle := sim.aim_dir.angle()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
	var color := Color(0.65, 0.85, 1.0, 0.65 + 0.3 * pulse)
	draw_arc(Vector2(0, -14), 26.0, angle - half, angle + half, 28, color, 3.0)
	draw_arc(Vector2(0, -14), 21.0, angle - half, angle + half, 28, Color(color.r, color.g, color.b, 0.35), 1.0)


## Anillo que crece alrededor de los pies mientras se mantiene M2 (hold).
func _draw_charge() -> void:
	var fraction := sim.charge_fraction()
	if not sim.alive or fraction <= 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
	var full := fraction >= 1.0
	var color := Color(1.0, 0.85, 0.3, 1.0) if full else Color(1.0, 0.55, 0.2, 1.0)
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 14.0 + fraction * 16.0, Color(color.r, color.g, color.b, 0.10 + 0.10 * fraction))
	draw_arc(Vector2.ZERO, 18.0 + fraction * 12.0, -PI * 0.5, -PI * 0.5 + TAU * fraction, 40, Color(color.r, color.g, color.b, 0.9), 2.0)
	if full:
		draw_arc(Vector2.ZERO, 32.0 + pulse * 3.0, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.5 + 0.3 * pulse), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Zona marcada durante el windup de una skill con telegraph: contorno completo y
## relleno que crece hasta el borde cuando cae el golpe.
func _draw_telegraph() -> void:
	if not sim.alive or sim.state != PlayerSim.AttackState.WINDUP:
		return
	if not bool(sim.current_skill.get("telegraph", false)):
		return
	if String(sim.current_skill.get("shape", "cone")) != "circle":
		return
	var center := sim.attack_point - sim.position
	var radius := float(sim.current_skill["range"])
	var t := clampf(sim.state_time / maxf(float(sim.current_skill["windup"]), 0.001), 0.0, 1.0)
	var red := Color(1.0, 0.25, 0.15, 1.0)
	draw_set_transform(center, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, radius * t, Color(red.r, red.g, red.b, 0.16 + 0.12 * t))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(red.r, red.g, red.b, 0.85), 2.0)
	var inner := float(sim.current_skill.get("center_radius", 0.0))
	if inner > 0.0:
		draw_arc(Vector2.ZERO, inner, 0.0, TAU, 32, Color(1.0, 0.75, 0.3, 0.7), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if sim == null:
		return

	# Sombra elíptica bajo los pies.
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 13.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_telegraph()
	_draw_charge()
	_draw_stance()

	# Aura de Vengeful Fury cuando la pasiva está cargada.
	if sim.vengeful_active and sim.alive:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		var aura := Color(1.0, 0.38, 0.12, 0.30 + 0.22 * pulse)
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, 19.0 + pulse * 2.0, Color(1.0, 0.35, 0.10, 0.10 + 0.06 * pulse))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2(0, -2), 20.0 + pulse * 2.0, 0.0, TAU, 32, aura, 2.0)
