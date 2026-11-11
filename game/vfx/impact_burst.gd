## ImpactBurst — chispas y anillo de impacto (presentación pura).
class_name ImpactBurst
extends Node2D

var color: Color = Color(1.0, 0.85, 0.55, 1.0)
var heavy: bool = false
var duration: float = 0.28
var _elapsed: float = 0.0
var _directions: Array[Vector2] = []


func setup(p_color: Color, p_heavy: bool = false) -> void:
	color = p_color
	heavy = p_heavy
	duration = 0.36 if heavy else 0.24
	z_index = 32
	var count := 12 if heavy else 8
	for i: int in range(count):
		var angle := TAU * float(i) / float(count) + float((i * 37) % 100) * 0.01
		_directions.append(Vector2(cos(angle), sin(angle)))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - t
	var ring_radius := lerpf(5.0, 26.0 if not heavy else 38.0, ease(t, 0.4))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.75 * fade), 2.0 if not heavy else 3.0)

	for i: int in range(_directions.size()):
		var dir := _directions[i]
		var length := lerpf(7.0, 18.0 if not heavy else 28.0, t) * (0.7 + 0.3 * float(i % 3))
		var spark := dir * length
		var spark_color := Color(1.0, 0.95, 0.70, 0.95 * fade) if i % 2 == 0 else Color(color.r, color.g, color.b, 0.8 * fade)
		draw_line(dir * 3.0, spark, spark_color, 2.0 if not heavy else 3.0)
