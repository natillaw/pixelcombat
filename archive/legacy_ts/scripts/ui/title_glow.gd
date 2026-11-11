class_name TitleGlow
extends Node2D
## Warm flickering light of a campfire on the ground (title screen). Look only.

var _t: float = 0.0


func _process(delta: float) -> void:
    _t += delta
    queue_redraw()


func _draw() -> void:
    var f := 0.85 + 0.1 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
    for i in 4:
        var r := (70.0 - float(i) * 15.0) * f
        draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.2, 0.06 + 0.03 * float(i)))
    draw_set_transform(Vector2.ZERO)
