## ZoneActor — dibuja una GroundZone (grietas, charco venenoso, campo maldito): un disco con borde
## que pulsa y se desvanece al acabar. Solo lee la zona; el dano lo hace la simulacion.
class_name ZoneActor
extends Node2D

const COLORS := {
	"dark": Color(0.55, 0.2, 0.75),
	"fire": Color(1.0, 0.45, 0.15),
	"poison": Color(0.45, 0.85, 0.25),
	"frost": Color(0.45, 0.8, 1.0),
	"blood": Color(0.8, 0.1, 0.15),
}

var zone: GroundZone


func setup(p_zone: GroundZone) -> void:
	zone = p_zone
	position = zone.position
	z_index = -1


func _process(_delta: float) -> void:
	if zone == null or not zone.alive:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var color: Color = COLORS.get(zone.visual, COLORS["dark"])
	var life := 1.0 - zone.age / zone.duration
	var fade := clampf(life * 4.0, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
	draw_circle(Vector2.ZERO, zone.radius, Color(color.r, color.g, color.b, (0.14 + 0.1 * pulse) * fade))
	draw_arc(Vector2.ZERO, zone.radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, (0.55 + 0.3 * pulse) * fade), 2.0)
	if zone.age < 0.6:
		draw_arc(Vector2.ZERO, zone.radius * (zone.age / 0.6), 0.0, TAU, 40, Color(1, 1, 1, 0.6), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
