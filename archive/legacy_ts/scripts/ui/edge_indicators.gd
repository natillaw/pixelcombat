class_name EdgeIndicators
extends Control
## D-082b: markers at the screen edges for heroes and pings that are out of view (CameraDefs.INDICATOR_*).
## Heroes show their slot number in their rarity colour (red when down); pings show their colour. The
## SandboxScreen asks hit() on a click and jumps the camera there. Look only, never takes the mouse itself.

var sb: SandboxScreen
var _spots: Array = []               # [{"at": screen pos, "world": Vector2, "kind": "hero"|"ping", "label", "color"}]


func _init(screen: SandboxScreen = null) -> void:
    sb = screen
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
    UIKit.fill(self)


func _process(_delta: float) -> void:
    _spots.clear()
    if sb == null or sb.camera == null or sb.mission_state != SandboxScreen.Mission.ACTIVE:
        queue_redraw()
        return
    var view := size
    var bottom := view.y - sb.hud_bottom()
    var inner := Rect2(Vector2.ONE * CameraDefs.INDICATOR_MARGIN, Vector2(view.x, bottom) - Vector2.ONE * CameraDefs.INDICATOR_MARGIN * 2.0)
    if inner.size.x <= 1.0 or inner.size.y <= 1.0:   # not laid out yet (first frame / headless): no markers
        queue_redraw()
        return
    for h in sb.heroes:
        if h.dead:
            continue
        var col: Color = Color(1.0, 0.4, 0.35) if h.downed else h.hero.star_color()
        _add(sb.world_to_screen(h.position + Vector2(0, -16)), h.position, "hero", str(h.slot + 1), col, inner)
    for m in sb.markers:
        if is_instance_valid(m):
            _add(sb.world_to_screen(m.position), m.position, "ping", "!", AiDefs.PINGS.get(m.kind, AiDefs.PINGS["move"])["color"], inner)
    queue_redraw()


func _add(screen_pos: Vector2, world: Vector2, kind: String, label: String, col: Color, inner: Rect2) -> void:
    if inner.has_point(screen_pos):
        return                                        # on screen: no marker
    var c := inner.get_center()
    var d := screen_pos - c
    if d.length() < 0.01:
        return
    var k := INF                                      # where the ray from the centre leaves the inner rect
    if absf(d.x) > 0.001:
        k = minf(k, (inner.size.x * 0.5) / absf(d.x))
    if absf(d.y) > 0.001:
        k = minf(k, (inner.size.y * 0.5) / absf(d.y))
    _spots.append({"at": c + d * k, "dir": d.normalized(), "world": world, "kind": kind, "label": label, "color": col})


## The world point of the marker under screen point p (INF = none).
func hit(p: Vector2) -> Vector2:
    for s in _spots:
        if (s["at"] as Vector2).distance_to(p) <= CameraDefs.INDICATOR_RADIUS + 4.0:
            return s["world"]
    return Vector2.INF


func spots() -> Array:
    return _spots


func _draw() -> void:
    var r := CameraDefs.INDICATOR_RADIUS
    for s in _spots:
        var at: Vector2 = s["at"]
        var dir: Vector2 = s["dir"]
        var col: Color = s["color"]
        var tip := at + dir * (r + 5.0)
        draw_colored_polygon(PackedVector2Array([tip, at + dir.orthogonal() * r * 0.7, at - dir.orthogonal() * r * 0.7]), col)
        draw_circle(at, r, Color(0.08, 0.07, 0.06, 0.85))
        draw_arc(at, r, 0.0, TAU, 20, col, 1.5)
        draw_string(ThemeDB.fallback_font, at + Vector2(-r, 4), String(s["label"]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 10, col)
