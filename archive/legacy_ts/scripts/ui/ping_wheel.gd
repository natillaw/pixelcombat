class_name PingWheel
extends Control
## D-082: the ping wheel. Opens where the player held Shift + click; 8 pings in the inner ring
## (AiDefs.PING_ORDER, clockwise from the top) and the Master's 3 Commands in the outer ring (same effect and
## cooldown as keys 1 2 3). Releasing on an option picks it; releasing in the centre cancels. Screen space.

var centre: Vector2 = Vector2.ZERO
var cursor: Vector2 = Vector2.ZERO
var command_names: Array = ["", "", ""]   # Commands by slot ("" = not learned)
var command_cd: Array = [0.0, 0.0, 0.0]   # seconds left per slot
var _icons: Dictionary = {}


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    for k in AiDefs.PING_ORDER:
        var path := AssetCatalog.icon(String(AiDefs.PINGS[k]["icon"]))
        if ResourceLoader.exists(path):
            _icons[k] = load(path)


## What releasing at `p` picks: {"ping": kind} | {"command": slot} | {} (cancel).
static func pick_at(c: Vector2, p: Vector2) -> Dictionary:
    var v := p - c
    var r := v.length()
    if r < AiDefs.PING_WHEEL_DEAD:
        return {}
    var a := fposmod(v.angle() + PI / 2.0, TAU)          # 0 = straight up, clockwise
    if r <= AiDefs.PING_WHEEL_INNER:
        var n := AiDefs.PING_ORDER.size()
        var i := int(floor(fposmod(a + PI / float(n), TAU) / (TAU / float(n)))) % n
        return {"ping": AiDefs.PING_ORDER[i]}
    if r <= AiDefs.PING_WHEEL_OUTER + 30.0:
        var j := int(floor(fposmod(a + PI / 3.0, TAU) / (TAU / 3.0))) % 3
        return {"command": j}
    return {}


func pick() -> Dictionary:
    return pick_at(centre, cursor)


func _process(_delta: float) -> void:
    cursor = get_local_mouse_position()
    queue_redraw()


func _draw() -> void:
    var hover := pick()
    var n := AiDefs.PING_ORDER.size()
    draw_circle(centre, AiDefs.PING_WHEEL_OUTER, Color(0.05, 0.05, 0.05, 0.55))
    # outer ring: Commands
    for j in 3:
        var a0 := -PI / 2.0 - PI / 3.0 + TAU / 3.0 * float(j)
        var on: bool = hover.get("command", -1) == j
        var col := Color(1.0, 0.85, 0.4, 0.9 if on else 0.45)
        if command_names[j] == "" or float(command_cd[j]) > 0.0:
            col = Color(0.6, 0.6, 0.6, 0.5 if on else 0.3)
        draw_arc(centre, (AiDefs.PING_WHEEL_INNER + AiDefs.PING_WHEEL_OUTER) * 0.5, a0 + 0.05, a0 + TAU / 3.0 - 0.05, 24, col, AiDefs.PING_WHEEL_OUTER - AiDefs.PING_WHEEL_INNER - 6.0)
        var mid := centre + Vector2.RIGHT.rotated(a0 + PI / 3.0) * (AiDefs.PING_WHEEL_INNER + AiDefs.PING_WHEEL_OUTER) * 0.5
        var label := "%d %s" % [j + 1, tr(String(command_names[j])) if command_names[j] != "" else "—"]
        if float(command_cd[j]) > 0.0:
            label = "%d  %ds" % [j + 1, ceili(float(command_cd[j]))]
        draw_string(ThemeDB.fallback_font, mid + Vector2(-30, 3), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color(0.05, 0.04, 0.03))
    # inner ring: pings
    for i in n:
        var k: String = AiDefs.PING_ORDER[i]
        var ang := -PI / 2.0 + TAU / float(n) * float(i)
        var at := centre + Vector2.RIGHT.rotated(ang) * AiDefs.PING_WHEEL_INNER * 0.62
        var on: bool = hover.get("ping", "") == k
        var col: Color = AiDefs.PINGS[k]["color"]
        draw_circle(at, 10.0 if on else 8.5, Color(col, 0.95 if on else 0.6))
        if _icons.has(k):
            draw_texture_rect(_icons[k], Rect2(at - Vector2(5, 5), Vector2(10, 10)), false)
    draw_circle(centre, AiDefs.PING_WHEEL_DEAD, Color(0.1, 0.1, 0.1, 0.8))
    if hover.has("ping"):
        draw_string(ThemeDB.fallback_font, centre + Vector2(-60, AiDefs.PING_WHEEL_OUTER + 14), tr(String(AiDefs.PINGS[hover["ping"]]["name"])), HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color.WHITE)
    elif hover.has("command"):
        var nm: String = command_names[int(hover["command"])]
        draw_string(ThemeDB.fallback_font, centre + Vector2(-60, AiDefs.PING_WHEEL_OUTER + 14), tr(nm) if nm != "" else tr("not learned yet"), HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(1.0, 0.85, 0.4))
