## DummyActor — presentación del muñeco de entrenamiento.
##
## Dibuja el muñeco por código (sin texturas), su cono de telegráfico, la barra
## de vida y el aviso de muerte/respawn. Lee [DummySim]; nunca lo modifica.
class_name DummyActor
extends Node2D

const SFX_ALERT := preload("res://assets/audio/sfx/ninja/Alert/Alert2.wav")
const SFX_SWING := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Whoosh.wav")
const SFX_IMPACT := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact2.wav")

const BAR_WIDTH := 42.0
const BAR_HEIGHT := 4.0
const BAR_OFFSET := Vector2(-21.0, -72.0)

var sim: DummySim
var arena: Arena
var _was_alive: bool = true


func setup(p_sim: DummySim, p_arena: Arena) -> void:
	sim = p_sim
	arena = p_arena
	_was_alive = sim.alive
	sim.telegraph_started.connect(_on_telegraph_started)
	sim.attack_landed.connect(_on_attack_landed)
	sim.attack_missed.connect(_on_attack_missed)
	sim.died.connect(_on_died)
	sim.revived.connect(_on_revived)


func _process(_delta: float) -> void:
	if sim == null:
		return
	position = sim.position
	if sim.alive and not _was_alive:
		_was_alive = true
	elif not sim.alive and _was_alive:
		_was_alive = false
	queue_redraw()


func _on_telegraph_started(_direction: Vector2, _radius: float, _arc_degrees: float) -> void:
	if arena != null:
		arena.play_sfx(SFX_ALERT, -13.0, randf_range(0.96, 1.06))


func _on_attack_landed(damage: float) -> void:
	if arena == null:
		return
	var forward := sim.attack_direction * DummySim.ATTACK_RANGE * 0.55
	arena.spawn_impact(sim.position + forward, Color(0.95, 0.25, 0.18, 1.0), false)
	arena.spawn_damage_number(sim.position + forward, damage, false)
	arena.play_sfx(SFX_IMPACT, -6.0, randf_range(0.9, 1.0))
	arena.shake(4.0, 0.2)


func _on_attack_missed() -> void:
	if arena != null:
		arena.play_sfx(SFX_SWING, -12.0, randf_range(0.85, 0.95))


func _on_died() -> void:
	if arena != null:
		arena.play_sfx(SFX_IMPACT, -9.0, 0.7)


func _on_revived() -> void:
	_was_alive = true
	rotation = 0.0
	modulate = Color.WHITE


func _draw() -> void:
	if sim == null:
		return

	if not sim.alive:
		rotation = clampf(sim.state_time / 0.28, 0.0, 1.0) * 1.35
		modulate = Color(0.65, 0.6, 0.55, 1.0)
	else:
		rotation = 0.0
		modulate = Color.WHITE

	if sim.alive and sim.state == DummySim.State.TELEGRAPH:
		_draw_telegraph()

	# Sombra.
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 17.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var wood := Color(0.36, 0.24, 0.15)
	var wood_dark := Color(0.24, 0.15, 0.09)
	var straw := Color(0.78, 0.62, 0.30)
	var straw_dark := Color(0.58, 0.44, 0.19)
	var metal := Color(0.55, 0.57, 0.62)

	# Poste y base.
	draw_rect(Rect2(-5, -30, 10, 30), wood_dark)
	draw_rect(Rect2(-19, -5, 38, 5), wood_dark)
	draw_rect(Rect2(-14, -9, 28, 5), wood)

	# Travesaño de los brazos.
	draw_rect(Rect2(-27, -51, 54, 5), wood)
	draw_rect(Rect2(-29, -51, 4, 3), metal)
	draw_rect(Rect2(25, -51, 4, 3), metal)

	# Torso de paja.
	draw_rect(Rect2(-15, -70, 30, 25), straw)
	draw_rect(Rect2(-15, -70, 30, 4), straw_dark)
	draw_rect(Rect2(-15, -49, 30, 4), straw_dark)
	for y: float in [-64.0, -57.0, -50.0]:
		draw_line(Vector2(-14, y), Vector2(14, y), straw_dark, 1.0)
	draw_line(Vector2(-10, -70), Vector2(-7, -45), straw_dark, 1.0)
	draw_line(Vector2(8, -70), Vector2(11, -45), straw_dark, 1.0)

	# Cuerda de la cintura.
	draw_line(Vector2(-15, -46), Vector2(15, -46), Color(0.42, 0.30, 0.15), 2.0)

	# Diana pintada.
	draw_circle(Vector2(0, -58), 7.0, Color(0.62, 0.16, 0.12, 1.0))
	draw_circle(Vector2(0, -58), 4.5, Color(0.86, 0.72, 0.52, 1.0))
	draw_circle(Vector2(0, -58), 2.0, Color(0.62, 0.16, 0.12, 1.0))

	# Cabeza de paja con cuerdas.
	draw_circle(Vector2(0, -80), 9.0, straw)
	draw_arc(Vector2(0, -80), 9.0, 0.0, TAU, 18, straw_dark, 1.0)
	draw_line(Vector2(-8, -77), Vector2(8, -77), straw_dark, 1.0)

	if sim.alive:
		_draw_health_bar()

	# Destello de impacto.
	if sim.hit_flash_ticks > 0:
		draw_rect(Rect2(-30, -84, 60, 84), Color(1.0, 0.95, 0.85, 0.22))


func _draw_telegraph() -> void:
	var progress := sim.telegraph_progress()
	var half := deg_to_rad(DummySim.ATTACK_ARC * 0.5)
	var start := sim.attack_direction.angle() - half
	var arc := deg_to_rad(DummySim.ATTACK_ARC)
	var radius := DummySim.ATTACK_RANGE
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var segments := 18
	for i: int in range(segments + 1):
		var angle := start + arc * (float(i) / float(segments))
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	var fill := Color(0.92, 0.18, 0.12, 0.07 + 0.20 * progress)
	draw_colored_polygon(points, fill)
	var edge := Color(1.0, 0.30, 0.20, 0.35 + 0.55 * progress)
	draw_polyline(points, edge, 1.5)
	draw_arc(Vector2.ZERO, radius * (0.35 + 0.65 * progress), start, start + arc, 20, Color(1.0, 0.55, 0.30, 0.45 + 0.4 * progress), 1.0)


func _draw_health_bar() -> void:
	var ratio := clampf(sim.health / maxf(sim.max_health, 1.0), 0.0, 1.0)
	var bg := Rect2(BAR_OFFSET, Vector2(BAR_WIDTH, BAR_HEIGHT))
	draw_rect(bg, Color(0.05, 0.05, 0.07, 0.85))
	var fill_color := Color(0.55, 0.82, 0.38) if ratio > 0.35 else Color(0.90, 0.45, 0.25)
	draw_rect(Rect2(BAR_OFFSET, Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)), fill_color)
	draw_rect(bg, Color(0.0, 0.0, 0.0, 0.9), false, 1.0)
