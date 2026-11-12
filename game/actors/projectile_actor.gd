## ProjectileActor — presentación de un proyectil (flecha, daga, hechizo...).
##
## Dibuja por código según el `visual` de la skill, con una estela corta y una
## sombra en el suelo. Lee [ProjectileSim]; se libera cuando el proyectil muere.
class_name ProjectileActor
extends Node2D

const LIFT := Vector2(0.0, -18.0)
const TRAIL_POINTS := 6

var sim: ProjectileSim

var _trail: Array[Vector2] = []
var _age: float = 0.0
## Sprite animado del paquete de efectos (si el `visual` tiene uno); si no, se dibuja por codigo.
var _sprite: AnimatedSprite2D = null


func setup(p_sim: ProjectileSim) -> void:
	sim = p_sim
	position = sim.position
	z_index = 5
	var spec := FxLibrary.projectile_fx(String(sim.visual))
	if not spec.is_empty():
		_build_sprite(spec)


func _build_sprite(spec: Dictionary) -> void:
	var effect := FxLibrary.effect(String(spec["id"]))
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FxLibrary.frames(String(spec["id"]))
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pivot: Array = effect["pivot"]
	_sprite.offset = Vector2(float(effect["w"]) * 0.5 - float(pivot[0]), float(effect["h"]) * 0.5 - float(pivot[1]))
	_sprite.scale = Vector2.ONE * float(spec["scale"])
	var tint: Array = spec["tint"]
	_sprite.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]), float(tint[3]))
	_sprite.material = FxSprite.additive()
	_sprite.position = LIFT
	_sprite.rotation = sim.direction.angle()
	# Los efectos que no hacen bucle se repiten mientras vuela el proyectil.
	_sprite.animation_finished.connect(func() -> void: _sprite.play(&"play"))
	add_child(_sprite)
	_sprite.play(&"play")


func _process(delta: float) -> void:
	if sim == null:
		return
	_age += delta
	if not sim.alive:
		queue_free()
		return
	position = sim.position
	if _sprite != null:
		_sprite.rotation = sim.direction.angle()
	_trail.append(sim.position)
	if _trail.size() > TRAIL_POINTS:
		_trail.pop_front()
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	# Sombra en el suelo.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, maxf(sim.radius, 3.0), Color(0.0, 0.0, 0.0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Estela: puntos anteriores con alpha creciente.
	for i: int in range(_trail.size()):
		var point := _trail[i] - sim.position + LIFT
		var alpha := float(i + 1) / float(_trail.size() + 1) * 0.35
		draw_circle(point, maxf(sim.radius * 0.5, 2.0) * (float(i + 1) / float(_trail.size())), Color(_main_color().r, _main_color().g, _main_color().b, alpha))

	var direction := sim.direction
	var center := LIFT
	var side := direction.orthogonal()
	if _sprite != null:
		# El sprite del paquete ya es el cuerpo; solo se anade el aro de peligro de los hostiles.
		if sim.hostile:
			draw_arc(center, sim.radius + 3.5, 0.0, TAU, 20, Color(1.0, 0.28, 0.2, 0.85), 1.5)
		return
	match sim.visual:
		"arrow":
			var tail := center - direction * 15.0
			draw_line(tail, center, Color(0.85, 0.78, 0.6, 1.0), 1.5)
			draw_colored_polygon(PackedVector2Array([center + direction * 4.0, center - direction * 1.0 + side * 2.5, center - direction * 1.0 - side * 2.5]), Color(0.9, 0.9, 0.95, 1.0))
			draw_line(tail, tail - direction * 3.0 + side * 3.0, Color(0.7, 0.3, 0.25, 1.0), 1.0)
			draw_line(tail, tail - direction * 3.0 - side * 3.0, Color(0.7, 0.3, 0.25, 1.0), 1.0)
		"knife":
			var spin := _age * 24.0
			var blade := Vector2.from_angle(spin) * 5.0
			draw_line(center - blade, center + blade, Color(0.85, 0.88, 0.95, 1.0), 2.0)
			draw_line(center - blade.orthogonal() * 0.6, center + blade.orthogonal() * 0.6, Color(0.5, 0.5, 0.6, 1.0), 1.0)
		"bolt":
			draw_circle(center, sim.radius + 2.0, Color(0.7, 0.45, 1.0, 0.30))
			draw_circle(center, sim.radius * 0.7, Color(0.85, 0.7, 1.0, 1.0))
			draw_circle(center, sim.radius * 0.35, Color.WHITE)
		"orb":
			var pulse := 0.5 + 0.5 * sin(_age * 18.0)
			draw_circle(center, sim.radius + 4.0 + pulse * 2.0, Color(0.6, 0.3, 1.0, 0.25))
			draw_circle(center, sim.radius, Color(0.75, 0.5, 1.0, 0.95))
			draw_circle(center, sim.radius * 0.5, Color(1.0, 0.95, 1.0, 1.0))
		"fire":
			var flicker := 0.5 + 0.5 * sin(_age * 30.0)
			draw_circle(center, sim.radius + 3.0 + flicker * 2.0, Color(1.0, 0.35, 0.1, 0.35))
			draw_circle(center, sim.radius, Color(1.0, 0.55, 0.15, 1.0))
			draw_circle(center, sim.radius * 0.5, Color(1.0, 0.95, 0.5, 1.0))
		"ice":
			var tip := center + direction * 9.0
			var back := center - direction * 7.0
			draw_colored_polygon(PackedVector2Array([tip, center + side * 3.0, back, center - side * 3.0]), Color(0.7, 0.92, 1.0, 1.0))
			draw_line(back, tip, Color.WHITE, 1.0)
		"wisp":
			var glow := 0.5 + 0.5 * sin(_age * 14.0)
			draw_circle(center, sim.radius + 4.0 + glow * 2.0, Color(0.4, 0.9, 1.0, 0.25))
			draw_circle(center, sim.radius, Color(0.6, 0.95, 1.0, 0.95))
			draw_circle(center, sim.radius * 0.45, Color.WHITE)
		"stinger":
			draw_line(center - direction * 7.0, center + direction * 5.0, Color(1.0, 0.85, 0.2, 1.0), 2.0)
			draw_colored_polygon(PackedVector2Array([center + direction * 8.0, center + direction * 2.0 + side * 2.5, center + direction * 2.0 - side * 2.5]), Color(0.2, 0.15, 0.1, 1.0))
		"spit":
			var blob := 0.5 + 0.5 * sin(_age * 20.0)
			draw_circle(center, sim.radius + 2.0 + blob * 1.5, Color(0.4, 0.85, 0.2, 0.35))
			draw_circle(center, sim.radius, Color(0.55, 0.9, 0.25, 1.0))
			draw_circle(center + Vector2(-2, -2), sim.radius * 0.35, Color(0.85, 1.0, 0.6, 1.0))
		_:
			draw_circle(center, sim.radius, _main_color())
	# Los proyectiles enemigos llevan un aro rojo para leerlos como peligro.
	if sim.hostile:
		draw_arc(center, sim.radius + 3.5, 0.0, TAU, 20, Color(1.0, 0.28, 0.2, 0.85), 1.5)


func _main_color() -> Color:
	match sim.visual:
		"bolt", "orb":
			return Color(0.75, 0.5, 1.0, 1.0)
		"fire":
			return Color(1.0, 0.5, 0.15, 1.0)
		"wisp":
			return Color(0.5, 0.92, 1.0, 1.0)
		"stinger":
			return Color(1.0, 0.85, 0.2, 1.0)
		"spit":
			return Color(0.55, 0.9, 0.25, 1.0)
		"ice":
			return Color(0.7, 0.92, 1.0, 1.0)
		_:
			return Color(0.9, 0.9, 0.85, 1.0)
