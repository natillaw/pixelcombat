## SlashArc — presentación pura del arco de un golpe.
##
## Se dibuja por código (sin texturas) para que el telegraph y el golpe sean
## legibles y consistentes. Vive en _process: no toca la simulación.
class_name SlashArc
extends Node2D

var radius: float = 78.0
var arc_degrees: float = 110.0
var direction: Vector2 = Vector2.RIGHT
var color: Color = Color(1.0, 0.94, 0.78, 0.95)
var duration: float = 0.18
var width: float = 9.0
var heavy: bool = false

var _elapsed: float = 0.0


func setup(p_direction: Vector2, p_radius: float, p_arc: float, p_duration: float, p_heavy: bool = false) -> void:
	direction = p_direction.normalized()
	radius = p_radius
	arc_degrees = p_arc
	duration = p_duration
	heavy = p_heavy
	color = Color(1.0, 0.62, 0.24, 0.98) if heavy else Color(1.0, 0.95, 0.80, 0.95)
	width = 14.0 if heavy else 9.0
	z_index = 30


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var fade := 1.0 - t
	var half := deg_to_rad(arc_degrees * 0.5)
	var start := direction.angle() - half
	var sweep := ease(clampf(t * 1.55, 0.0, 1.0), 0.35)
	var end := start + deg_to_rad(arc_degrees) * sweep

	var segments := 18 if heavy else 14
	var previous := Vector2(cos(start), sin(start)) * radius
	for i: int in range(1, segments + 1):
		var f := float(i) / float(segments)
		var angle := lerpf(start, end, f)
		var point := Vector2(cos(angle), sin(angle)) * radius
		var line_color := color
		line_color.a *= fade * (0.35 + 0.65 * f)
		draw_line(previous, point, line_color, width * (0.45 + 0.55 * f))
		previous = point

	var tip := Vector2(cos(end), sin(end))
	draw_line(tip * (radius - width * 0.6), tip * (radius + width * 0.9), Color(1, 1, 1, fade), 2.0)

	if heavy:
		var glow := Color(1.0, 0.45, 0.15, 0.16 * fade)
		draw_circle(Vector2.ZERO, radius * 1.02, glow)
