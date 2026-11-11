class_name PingMarker
extends Node2D
## D-082: a ping on the map. A pulsing ring in the ping's colour with its icon above, for the ping's life
## (AiDefs.PINGS[kind]["life"]). An "enemy spotted" marker sticks to the foe it marks. Look only.

var kind: String = "explore"
var follow: Node2D = null           # sticks to this unit (enemy spotted), when set
var _t: float = 0.0
var _life: float = 4.0
var _color: Color = Color.WHITE
var _icon: Texture2D = null


static func make(p_kind: String, at: Vector2, unit: Node2D = null) -> PingMarker:
    var m := PingMarker.new()
    m.kind = p_kind
    m.position = at
    m.follow = unit
    m.z_index = 30
    return m


func _ready() -> void:
    var d: Dictionary = AiDefs.PINGS.get(kind, AiDefs.PINGS["explore"])
    _life = float(d["life"])
    _color = d["color"]
    var path := AssetCatalog.icon(String(d["icon"]))
    if ResourceLoader.exists(path):
        _icon = load(path) as Texture2D


func life_left() -> float:
    return maxf(0.0, _life - _t)


func _process(delta: float) -> void:
    _t += delta
    if follow != null:
        if is_instance_valid(follow) and follow.get("alive") != false:
            position = follow.position
        else:
            follow = null
    if _t >= _life:
        queue_free()
    queue_redraw()


func _draw() -> void:
    var fade := clampf((_life - _t) / 0.6, 0.0, 1.0)
    var pulse := 0.5 + 0.5 * sin(_t * 7.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
    draw_arc(Vector2.ZERO, 16.0 + 6.0 * pulse, 0.0, TAU, 28, Color(_color, 0.9 * fade), 2.5)
    draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Color(_color, 0.6 * fade), 2.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    var top := Vector2(0, -46 if follow != null else -30)
    draw_line(Vector2(0, -4), top + Vector2(0, 10), Color(_color, 0.7 * fade), 2.0)
    draw_circle(top, 11.0, Color(0.08, 0.07, 0.06, 0.85 * fade))
    draw_arc(top, 11.0, 0.0, TAU, 20, Color(_color, fade), 2.0)
    if _icon != null:
        draw_texture_rect(_icon, Rect2(top - Vector2(8, 8), Vector2(16, 16)), false, Color(1, 1, 1, fade))
