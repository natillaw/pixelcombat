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
var _was_alive: bool = true


func setup(p_sim: EnemySim, p_arena: Arena) -> void:
	sim = p_sim
	arena = p_arena
	_was_alive = sim.alive
	_build_sprite()
	sim.telegraph_started.connect(_on_telegraph_started)
	sim.attack_active.connect(_on_attack_active)
	sim.attack_landed.connect(_on_attack_landed)
	sim.died.connect(_on_died)
	sim.revived.connect(_on_revived)


func _build_sprite() -> void:
	var sprite_data: Dictionary = sim.data["sprite"]
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

	var sprite_scale := float(sprite_data["scale"])
	_sprite_height = float(frame_size) * sprite_scale
	sprite = AnimatedSprite2D.new()
	sprite.name = "CreatureSprite"
	sprite.sprite_frames = frames
	sprite.centered = true
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.position = Vector2(0.0, -_sprite_height * 0.5 + 4.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.play(&"move")


func _process(_delta: float) -> void:
	if sim == null:
		return
	position = sim.position
	if absf(sim.facing.x) > 0.05:
		sprite.flip_h = sim.facing.x < 0.0

	if sim.alive:
		if not _was_alive:
			_restore_visual()
		_apply_state_visual()
	else:
		_was_alive = false
		var t := clampf(sim.state_time / 0.35, 0.0, 1.0)
		sprite.modulate = Color(0.6, 0.55, 0.55, 1.0 - t)
		sprite.scale = Vector2.ONE * float(sim.data["sprite"]["scale"]) * (1.0 - 0.3 * t)
	queue_redraw()


func _apply_state_visual() -> void:
	if sim.hit_flash_ticks > 0:
		sprite.modulate = Color(1.9, 1.5, 1.5, 1.0)
	elif sim.state == EnemySim.State.TELEGRAPH:
		# Parpadeo rojo cada vez mas rapido al acercarse el golpe.
		var rate := 12.0 + 20.0 * sim.telegraph_progress()
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * rate)
		sprite.modulate = Color(1.0 + 0.5 * pulse, 1.0 - 0.35 * pulse, 1.0 - 0.35 * pulse, 1.0)
	else:
		sprite.modulate = Color.WHITE
	sprite.speed_scale = 0.5 if sim.state == EnemySim.State.TELEGRAPH else 1.0


func _restore_visual() -> void:
	_was_alive = true
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE * float(sim.data["sprite"]["scale"])


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
	var warrior_position: Vector2 = sim.world.warrior.position
	arena.spawn_impact(warrior_position, Color(0.95, 0.25, 0.18, 1.0), false)
	arena.spawn_damage_number(warrior_position, damage, false)
	arena.play_sfx(SFX_IMPACT, -6.0, randf_range(0.9, 1.0))


func _on_died() -> void:
	if arena != null:
		arena.play_sfx(SFX_IMPACT, -9.0, 0.7)


func _on_revived() -> void:
	_restore_visual()


func _draw() -> void:
	if sim == null:
		return
	if sim.alive and sim.state == EnemySim.State.TELEGRAPH:
		_draw_telegraph()

	# Sombra.
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, sim.radius + 3.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if sim.alive and (sim.health < sim.max_health or sim.state != EnemySim.State.IDLE):
		_draw_health_bar()


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
		"circle":
			var radius := float(attack["range"])
			draw_circle(Vector2.ZERO, radius * progress, fill)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, edge, 1.5)
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
