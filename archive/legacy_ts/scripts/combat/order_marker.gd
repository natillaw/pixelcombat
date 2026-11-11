class_name OrderMarker
extends Node2D
## Feedback for a given order: a ring that shrinks and fades where the order points.

var color: Color = Color.WHITE
var _t: float = 0.0
const LIFE := 0.6


func _process(delta: float) -> void:
    _t += delta
    if _t >= LIFE:
        queue_free()
    queue_redraw()


func _draw() -> void:
    var k := 1.0 - _t / LIFE
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
    draw_arc(Vector2.ZERO, 8.0 + 14.0 * k, 0.0, TAU, 24, Color(color, k), 2.0)
