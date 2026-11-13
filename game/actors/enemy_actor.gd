## EnemyActor — presentación de un enemigo definido por datos.
##
## Dibuja el sprite (tira de frames CC0 de SpritePilot), la sombra, la barra de
## vida y, sobre todo, la ZONA DEL TELEGRAPH: la forma exacta del golpe que va a
## caer, que se rellena durante el windup. La zona dibujada es la misma que usa
## la simulación (cone, line o circle), sin deformar. Lee [EnemySim]; nunca lo
## modifica.
class_name EnemyActor
extends Node2D

const SFX_ALERT := preload("res://assets/audio/sfx/ninja/Alert/Alert2.wav")
const SFX_SWING := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Whoosh.wav")
const SFX_IMPACT := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact2.wav")

const BAR_WIDTH := 34.0
const BAR_HEIGHT := 4.0
const DANGER := Color(1.0, 0.24, 0.16, 1.0)

var sim: EnemySim
var arena: Arena
var sprite: AnimatedSprite2D

var _sprite_height: float = 32.0
var _tint: Color = Color.WHITE
var _was_alive: bool = true
var _scale_value: float = 1.0
var _is_lpc: bool = false
## Empujon visual al recibir un golpe (decae solo).
var _kick: Vector2 = Vector2.ZERO


func setup(p_sim: EnemySim, p_arena: Arena) -> void:
	sim = p_sim
	arena = p_arena
	_was_alive = sim.alive
	_build_sprite()
	sim.telegraph_started.connect(_on_telegraph_started)
	sim.attack_active.connect(_on_attack_active)
	sim.attack_landed.connect(_on_attack_landed)
	sim.died.connect(_on_died)
	sim.hit.connect(_on_hit)
	sim.revived.connect(_on_revived)
	sim.phase_changed.connect(_on_phase_changed)
	sim.aggroed.connect(_on_aggroed)
	sim.statuses.applied.connect(_on_status_applied)


func _build_sprite() -> void:
	var sprite_data: Dictionary = sim.data["sprite"]
	if sprite_data.has("lpc"):
		_build_lpc_sprite(sprite_data)
		return
	var frame_size := int(sprite_data["frame"])
	var texture: Texture2D = load(String(sprite_data["sheet"]))
	var frames := SpriteFrames.new()
	frames.add_animation(&"move")
	frames.set_animation_speed(&"move", float(sprite_data["fps"]))
	frames.set_animation_loop(&"move", true)
	for i: int in range(int(sprite_data["frames"])):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame(&"move", atlas)
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var sprite_scale := float(sprite_data["scale"]) * (1.25 if sim.elite else 1.0)
	_scale_value = sprite_scale
	_sprite_height = float(frame_size) * sprite_scale
	sprite = AnimatedSprite2D.new()
	sprite.name = "CreatureSprite"
	sprite.sprite_frames = frames
	sprite.centered = true
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.position = Vector2(0.0, -_sprite_height * 0.5 + 4.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite_data.has("tint"):
		var tint: Array = sprite_data["tint"]
		_tint = Color(float(tint[0]), float(tint[1]), float(tint[2]), float(tint[3]))
		sprite.modulate = _tint
	if sim.elite:
		_tint = Color(_tint.r * 1.2, _tint.g * 1.05, _tint.b * 0.65, _tint.a)
		sprite.modulate = _tint
	add_child(sprite)
	sprite.play(&"move")


## Enemigo humano: personaje LPC compuesto (cuerpo, ropa, arma) con las animaciones del
## jugador; el sprite no se voltea, se elige la fila de la direccion.
func _build_lpc_sprite(sprite_data: Dictionary) -> void:
	var lpc: Dictionary = sprite_data["lpc"]
	var equipment: Dictionary = {"_items": true}
	for slot: String in lpc.get("equipment", {}):
		equipment[slot] = lpc["equipment"][slot]
	_is_lpc = true
	var frames := LpcComposer.build_frames_for(lpc["look"], "enemy." + String(sim.data["id"]), equipment)
	var sprite_scale := float(sprite_data["scale"]) * (1.25 if sim.elite else 1.0)
	_scale_value = sprite_scale
	_sprite_height = 50.0 * sprite_scale
	sprite = AnimatedSprite2D.new()
	sprite.name = "LpcSprite"
	sprite.sprite_frames = frames
	sprite.centered = true
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.position = LpcComposer.FEET_OFFSET * sprite_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite_data.has("tint"):
		var tint: Array = sprite_data["tint"]
		_tint = Color(float(tint[0]), float(tint[1]), float(tint[2]), float(tint[3]))
	if sim.elite:
		_tint = Color(_tint.r * 1.2, _tint.g * 1.05, _tint.b * 0.65, _tint.a)
	sprite.modulate = _tint
	add_child(sprite)
	sprite.play(&"combat_idle_down")


func _lpc_animation() -> void:
	var direction := "down"
	if absf(sim.facing.x) > absf(sim.facing.y) * 1.15:
		direction = "right" if sim.facing.x > 0.0 else "left"
	else:
		direction = "down" if sim.facing.y >= 0.0 else "up"
	var anim := "combat_idle"
	match sim.state:
		EnemySim.State.CHASE:
			anim = "walk"
		EnemySim.State.ACTIVE:
			anim = String(sim.current_attack.get("anim", "slash"))
		EnemySim.State.STUN, EnemySim.State.DEAD:
			anim = "hurt"
	var full := "%s_%s" % [anim, direction]
	if not sprite.sprite_frames.has_animation(full):
		full = "combat_idle_" + direction
	if sprite.animation != full or not sprite.is_playing():
		sprite.play(full)


func _process(delta: float) -> void:
	if sim == null:
		return
	if arena != null and arena.is_frozen():
		sprite.speed_scale = 0.0
		return
	position = sim.position + _kick
	_kick *= exp(-12.0 * delta)
	if _is_lpc:
		_lpc_animation()
	elif absf(sim.facing.x) > 0.05:
		sprite.flip_h = sim.facing.x < 0.0

	if sim.alive:
		if not _was_alive:
			_restore_visual()
		_apply_state_visual()
	else:
		_was_alive = false
		var t := clampf(sim.state_time / 0.35, 0.0, 1.0)
		sprite.modulate = Color(0.6, 0.55, 0.55, 1.0 - t)
		if sim.summoned and sim.state_time > 1.2:
			queue_free()
			return
		if _is_lpc:
			# Los humanos caen de lado sobre la ultima pose de daño y se desvanecen; sin encoger.
			var fall := clampf(sim.state_time / 0.45, 0.0, 1.0)
			var side := -1.0 if sim.facing.x >= 0.0 else 1.0
			sprite.rotation = side * fall * PI * 0.5
			sprite.position = LpcComposer.FEET_OFFSET * _scale_value + Vector2(0.0, 8.0 * fall * _scale_value)
		else:
			sprite.scale = Vector2.ONE * _scale_value * (1.0 - 0.3 * t)
	queue_redraw()


func _apply_state_visual() -> void:
	if sim.hit_flash_ticks > 0:
		sprite.modulate = Color(1.9, 1.5, 1.5, 1.0)
	elif sim.state == EnemySim.State.PHASE:
		var roar := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		sprite.modulate = Color(1.0 + 0.8 * roar, 0.85 + 0.2 * roar, 0.7, 1.0)
	elif sim.state == EnemySim.State.TELEGRAPH:
		# Parpadeo rojo cada vez mas rapido al acercarse el golpe.
		var rate := 12.0 + 20.0 * sim.telegraph_progress()
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * rate)
		sprite.modulate = Color(1.0 + 0.5 * pulse, 1.0 - 0.35 * pulse, 1.0 - 0.35 * pulse, 1.0)
	else:
		sprite.modulate = _tint * _status_tint()
	sprite.speed_scale = 0.5 if sim.state == EnemySim.State.TELEGRAPH or sim.statuses.has("slow") else 1.0
	if sim.state == EnemySim.State.STUN:
		sprite.speed_scale = 0.0


func _restore_visual() -> void:
	_was_alive = true
	sprite.rotation = 0.0
	if _is_lpc:
		sprite.position = LpcComposer.FEET_OFFSET * _scale_value
	sprite.modulate = _tint
	sprite.scale = Vector2.ONE * _scale_value


func _on_telegraph_started(_attack: Dictionary, _direction: Vector2) -> void:
	if arena == null:
		return
	arena.play_sfx(SFX_ALERT, -13.0, randf_range(0.96, 1.06))
	arena.spawn_floating_text(sim.position + Vector2(0.0, -_sprite_height - 6.0), "!", DANGER)


func _on_attack_active(_attack: Dictionary, _direction: Vector2) -> void:
	if arena != null:
		arena.play_sfx(SFX_SWING, -11.0, randf_range(0.85, 0.95))


func _on_attack_landed(damage: float) -> void:
	if arena == null or damage <= 0.0:
		return
	var warrior_position: Vector2 = sim.world.player.position
	arena.spawn_impact(warrior_position, Color(0.95, 0.25, 0.18, 1.0), false)
	arena.spawn_damage_number(warrior_position, damage, false)
	arena.play_sfx(SFX_IMPACT, -6.0, randf_range(0.9, 1.0))


## Rugido del jefe al entrar en una fase nueva.
func _on_phase_changed(index: int, phase_name: String) -> void:
	if arena == null:
		return
	arena.spawn_floating_text(sim.position + Vector2(0.0, -_sprite_height - 12.0), phase_name.to_upper(), Color(1.0, 0.82, 0.3, 1.0))
	arena.spawn_impact(sim.position, Color(1.0, 0.6, 0.2, 1.0), true)
	arena.play_event("boss_phase", sim.position)
	arena.play_sfx(SFX_IMPACT, -2.0, 0.55)
	arena.shake(6.0, 0.5)


## Aviso flotante al recibir un estado (STUN, SLOW, POISON).
## Al despertar un enemigo (o un campamento entero) sale un aviso dorado sobre el.
func _on_aggroed() -> void:
	if arena == null or sim.summoned:
		return
	arena.spawn_floating_text(sim.position + Vector2(0.0, -_sprite_height - 12.0), "!", Color(1.0, 0.82, 0.3, 1.0))
	arena.play_event("alert", sim.position)


func _on_status_applied(id: String) -> void:
	if arena == null:
		return
	var definition := StatusCatalog.status(id)
	var color_data: Array = definition["color"]
	arena.play_event("status_" + id, sim.position + Vector2(0.0, -_sprite_height * 0.6))
	arena.spawn_floating_text(sim.position + Vector2(0.0, -_sprite_height - 6.0), String(definition["name"]).to_upper(), Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), 1.0))


## Tinte del sprite segun los estados: azul con slow, verde con veneno.
func _status_tint() -> Color:
	var tint := Color.WHITE
	if sim.statuses.has("slow"):
		tint = Color(0.65, 0.85, 1.25, 1.0)
	if sim.statuses.has("poison"):
		tint = Color(tint.r * 0.75, tint.g * 1.15, tint.b * 0.7, 1.0)
	return tint


## Puntos de color sobre la cabeza (uno por estado activo) y estrellas con stun.
func _draw_status_icons() -> void:
	var ids := sim.statuses.active_ids()
	if ids.is_empty():
		return
	var y := -_sprite_height - 10.0
	var x := -float(ids.size() - 1) * 4.5
	for id: String in ids:
		var color_data: Array = StatusCatalog.status(id)["color"]
		draw_circle(Vector2(x, y), 3.0, Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), 1.0))
		x += 9.0
	if sim.statuses.is_stunned():
		var spin := Time.get_ticks_msec() * 0.008
		for i: int in range(3):
			var angle := spin + float(i) * TAU / 3.0
			draw_circle(Vector2(cos(angle) * 12.0, -_sprite_height + 4.0 + sin(angle) * 4.0), 2.0, Color(1.0, 0.9, 0.3, 1.0))


## Retroceso visual al recibir un golpe (mas pequeño en jefes y elites, que pesan mas).
func _on_hit(amount: float, _at: Vector2) -> void:
	if sim.world == null or sim.world.player == null or amount <= 0.0:
		return
	var away: Vector2 = (sim.position - sim.world.player.position).normalized()
	var weight := 0.3 if sim.is_boss() else (0.6 if sim.elite else 1.0)
	_kick = away * clampf(3.0 + 70.0 * amount / maxf(sim.max_health, 1.0), 3.0, 12.0) * weight


func _on_died() -> void:
	if arena != null:
		arena.hit_stop(0.16 if sim.is_boss() else (0.09 if sim.elite else 0.05))
		if sim.is_boss():
			arena.slowmo(0.3, 1.0)
			arena.punch_zoom(0.07)
		arena.play_sfx(SFX_IMPACT, -9.0, 0.7)
		arena.play_event("boss_death" if sim.is_boss() else "enemy_death", sim.position)


func _on_revived() -> void:
	_restore_visual()


func _draw() -> void:
	if sim == null:
		return
	if sim.alive and sim.state == EnemySim.State.TELEGRAPH:
		_draw_telegraph()
	if sim.alive and sim.state == EnemySim.State.PHASE:
		_draw_roar()

	# Sombra.
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, sim.radius + 3.0, Color(0.0, 0.0, 0.0, 0.32))
	if sim.elite and sim.alive:
		draw_arc(Vector2.ZERO, sim.radius + 6.0, 0.0, TAU, 28, Color(1.0, 0.8, 0.25, 0.85), 2.0)
	if sim.invulnerable and sim.alive:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_arc(Vector2.ZERO, sim.radius + 12.0 + 3.0 * pulse, 0.0, TAU, 32, Color(0.45, 0.75, 1.0, 0.9), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if sim.alive and not sim.is_boss() and (sim.health < sim.max_health or sim.state != EnemySim.State.IDLE):
		_draw_health_bar()
	if sim.alive:
		_draw_status_icons()


## Onda que se expande desde el jefe durante el rugido de cambio de fase.
func _draw_roar() -> void:
	var t := clampf(sim.state_time / EnemySim.PHASE_PAUSE, 0.0, 1.0)
	var radius := sim.radius + t * 150.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.7, 0.3, 0.8 * (1.0 - t)), 3.0)
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 40, Color(1.0, 0.9, 0.5, 0.5 * (1.0 - t)), 1.5)


## Zona exacta del ataque (la misma que usa la simulacion): contorno completo
## desde el primer instante y relleno que crece hasta el golpe.
func _draw_telegraph() -> void:
	var attack := sim.current_attack
	var progress := sim.telegraph_progress()
	var direction := sim.attack_direction
	var fill := Color(DANGER.r, DANGER.g, DANGER.b, 0.08 + 0.22 * progress)
	var edge := Color(1.0, 0.32, 0.22, 0.45 + 0.5 * progress)
	if progress > 0.88:
		edge = Color(1.0, 0.9, 0.8, 0.95)

	match String(attack["shape"]):
		"buff":
			# Refuerzo (escudo): anillo azul, no es una zona de dano.
			var ring := float(attack["range"])
			draw_arc(Vector2.ZERO, ring * (0.4 + 0.6 * progress), 0.0, TAU, 40, Color(0.4, 0.85, 1.0, 0.35 + 0.5 * progress), 2.0)
		"circle":
			var radius := float(attack["range"])
			if String(attack.get("id", "")) == "nova":
				# Hechizo a distancia: sin circulo de peligro alrededor del lanzador, solo un destello que se carga a sus pies.
				var glow := Color(0.7, 0.55, 1.0, 0.25 + 0.5 * progress)
				draw_arc(Vector2(0, -4), 8.0 + 10.0 * progress, 0.0, TAU, 20, glow, 1.5)
				draw_circle(Vector2(0, -4), 3.0 + 4.0 * progress, Color(glow.r, glow.g, glow.b, 0.35 * progress))
				return
			draw_circle(Vector2.ZERO, radius * progress, fill)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, edge, 1.5)
		"projectile":
			var spec: Dictionary = attack["projectile"]
			var lane_length := float(spec["range"])
			var start_half := float(spec["radius"]) + 2.0
			var half_spread := deg_to_rad(minf(float(spec["spread"]) * 0.5, 80.0)) if int(spec["count"]) > 1 else 0.0
			var lane_side := direction.orthogonal()
			var end_half := start_half + lane_length * tan(half_spread)
			var lane := PackedVector2Array([lane_side * start_half, lane_side * end_half + direction * lane_length, -lane_side * end_half + direction * lane_length, -lane_side * start_half])
			draw_colored_polygon(lane, Color(fill.r, fill.g, fill.b, 0.06))
			var reach_now := lane_length * progress
			var half_now := start_half + reach_now * tan(half_spread)
			draw_colored_polygon(PackedVector2Array([lane_side * start_half, lane_side * half_now + direction * reach_now, -lane_side * half_now + direction * reach_now, -lane_side * start_half]), fill)
			var closed_lane := lane.duplicate()
			closed_lane.append(lane[0])
			draw_polyline(closed_lane, edge, 1.5)
		"line":
			var length := float(attack["range"])
			var half_width := float(attack["width"]) * 0.5
			var side := direction.orthogonal()
			var outline := PackedVector2Array([
				side * half_width,
				side * half_width + direction * length,
				-side * half_width + direction * length,
				-side * half_width,
			])
			draw_colored_polygon(outline, Color(fill.r, fill.g, fill.b, 0.06))
			var filled := PackedVector2Array([
				side * half_width,
				side * half_width + direction * length * progress,
				-side * half_width + direction * length * progress,
				-side * half_width,
			])
			draw_colored_polygon(filled, fill)
			var closed := outline.duplicate()
			closed.append(outline[0])
			draw_polyline(closed, edge, 1.5)
		_:
			var radius := float(attack["range"])
			var arc := deg_to_rad(float(attack["arc"]))
			var start := direction.angle() - arc * 0.5
			var points := PackedVector2Array([Vector2.ZERO])
			var segments := 20
			for i: int in range(segments + 1):
				var angle := start + arc * float(i) / float(segments)
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, Color(fill.r, fill.g, fill.b, 0.06 + 0.06 * progress))
			var filled_points := PackedVector2Array([Vector2.ZERO])
			for i: int in range(segments + 1):
				var angle := start + arc * float(i) / float(segments)
				filled_points.append(Vector2(cos(angle), sin(angle)) * radius * progress)
			draw_colored_polygon(filled_points, fill)
			var closed_cone := points.duplicate()
			closed_cone.append(Vector2.ZERO)
			draw_polyline(closed_cone, edge, 1.5)


func _draw_health_bar() -> void:
	var ratio := clampf(sim.health / maxf(sim.max_health, 1.0), 0.0, 1.0)
	var origin := Vector2(-BAR_WIDTH * 0.5, -_sprite_height - 2.0)
	var bg := Rect2(origin, Vector2(BAR_WIDTH, BAR_HEIGHT))
	draw_rect(bg, Color(0.05, 0.05, 0.07, 0.85))
	var fill_color := Color(0.55, 0.82, 0.38) if ratio > 0.35 else Color(0.90, 0.45, 0.25)
	draw_rect(Rect2(origin, Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)), fill_color)
	draw_rect(bg, Color(0.0, 0.0, 0.0, 0.9), false, 1.0)
