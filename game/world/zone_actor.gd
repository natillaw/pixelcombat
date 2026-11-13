## ZoneActor — dibuja una GroundZone (grietas, charco venenoso, campo maldito) con sprites del paquete de
## efectos repartidos por el area, mas un aro tenue que marca su borde y se desvanece al acabar.
## Solo lee la zona; el dano lo hace la simulacion.
class_name ZoneActor
extends Node2D

## visual -> efecto del paquete (se repite mientras dura la zona) y tinte.
const SPRITES := {
	"fire": {"id": "fire/ground-flames", "scale": 0.9, "tint": Color(1, 1, 1)},
	"blood": {"id": "fire/ground-flames", "scale": 0.9, "tint": Color(1.0, 0.25, 0.3)},
	"poison": {"id": "nature/poison-cloud", "scale": 1.0, "tint": Color(1, 1, 1)},
	"frost": {"id": "ice/blizzard", "scale": 0.9, "tint": Color(1, 1, 1)},
	"dark": {"id": "shadow/shadow-tendrils", "scale": 1.0, "tint": Color(0.85, 0.6, 1.0)},
}
## Peligros dibujados en codigo (placeholder hasta tener sprites propios, ver docs/PLACEHOLDERS_PENDIENTES.md).
const PROCEDURAL := ["mud", "spikes"]
const RING_COLORS := {
	"mud": Color(0.45, 0.32, 0.18),
	"spikes": Color(0.7, 0.7, 0.75),
	"dark": Color(0.55, 0.2, 0.75),
	"fire": Color(1.0, 0.45, 0.15),
	"poison": Color(0.45, 0.85, 0.25),
	"frost": Color(0.45, 0.8, 1.0),
	"blood": Color(0.8, 0.1, 0.15),
}

var zone: GroundZone
var _sprites: Array[AnimatedSprite2D] = []


func setup(p_zone: GroundZone) -> void:
	zone = p_zone
	position = zone.position
	z_index = -1
	if PROCEDURAL.has(zone.visual):
		return
	var spec: Dictionary = SPRITES.get(zone.visual, SPRITES["dark"])
	var count := clampi(int(round(zone.radius * zone.radius / 900.0)), 3, 9)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(zone.position.x * 31.0 + zone.position.y * 17.0) + 5
	for i: int in range(count):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = FxLibrary.frames(String(spec["id"]))
		var effect := FxLibrary.effect(String(spec["id"]))
		var pivot: Array = effect["pivot"]
		sprite.offset = Vector2(float(effect["w"]) * 0.5 - float(pivot[0]), float(effect["h"]) * 0.5 - float(pivot[1]))
		sprite.scale = Vector2.ONE * float(spec["scale"]) * rng.randf_range(0.8, 1.15)
		sprite.modulate = spec["tint"]
		sprite.material = FxSprite.additive()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * zone.radius * 0.8
		sprite.position = Vector2(cos(angle), sin(angle) * 0.7) * distance
		sprite.animation_finished.connect(func() -> void: sprite.play(&"play"))
		add_child(sprite)
		sprite.play(&"play")
		sprite.frame = rng.randi_range(0, maxi(sprite.sprite_frames.get_frame_count(&"play") - 1, 0))
		_sprites.append(sprite)


func _process(_delta: float) -> void:
	if zone == null or not zone.alive:
		queue_free()
		return
	var fade := clampf((1.0 - zone.age / zone.duration) * 4.0, 0.0, 1.0)
	for sprite: AnimatedSprite2D in _sprites:
		sprite.self_modulate.a = fade
	queue_redraw()


func _draw_procedural() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(zone.position.x * 13.0 + zone.position.y * 7.0) + 11
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
	if zone.visual == "mud":
		draw_circle(Vector2.ZERO, zone.radius, Color(0.30, 0.20, 0.11, 0.78))
		for i: int in range(7):
			var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, zone.radius * 0.8)
			draw_circle(at, rng.randf_range(zone.radius * 0.12, zone.radius * 0.28), Color(0.40, 0.28, 0.15, 0.7))
		for i: int in range(5):
			var at2 := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, zone.radius * 0.7)
			draw_circle(at2, 2.5, Color(0.22, 0.14, 0.08, 0.9))
	else:
		draw_circle(Vector2.ZERO, zone.radius, Color(0.10, 0.09, 0.09, 0.55))
		var rows := maxi(int(zone.radius / 9.0), 2)
		for i: int in range(rows * rows):
			var at3 := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * zone.radius * 0.85
			draw_colored_polygon(PackedVector2Array([at3 + Vector2(-4, 2), at3 + Vector2(4, 2), at3 + Vector2(0, -9)]), Color(0.72, 0.74, 0.78))
			draw_line(at3 + Vector2(0, -9), at3 + Vector2(0, -3), Color(1, 1, 1, 0.6), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if PROCEDURAL.has(zone.visual):
		_draw_procedural()
	var color: Color = RING_COLORS.get(zone.visual, RING_COLORS["dark"])
	var life := 1.0 - zone.age / zone.duration
	var fade := clampf(life * 4.0, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
	draw_arc(Vector2.ZERO, zone.radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.5 * fade), 2.0)
	if zone.age < 0.6:
		draw_arc(Vector2.ZERO, zone.radius * (zone.age / 0.6), 0.0, TAU, 40, Color(1, 1, 1, 0.6), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
