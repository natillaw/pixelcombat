class_name SandboxRelic
extends Node2D
## A mission marker on the map (T-011 + floor missions):
##   "relic"   gold relic to carry to EXIT          "captive" villager to escort to EXIT (rescue)
##   "clue"    point to discover (exploration)      "shrine"  point to hold (defense), shows progress
## Hidden while carried / once found.

var kind: String = "relic"
var progress: float = 0.0          # 0..1, drawn as an arc for the shrine
var _sprite: AnimatedSprite2D = null


func _init(p_kind: String = "relic") -> void:
    kind = p_kind


func _ready() -> void:
    if kind == "captive":
        var sf := CazArt.villager_frames(3)
        if sf != null:
            _sprite = AnimatedSprite2D.new()
            _sprite.sprite_frames = sf
            _sprite.offset = Vector2(0, -16)
            add_child(_sprite)
            _sprite.play("idle_down")


func _process(_delta: float) -> void:
    if kind == "shrine" or kind == "clue":
        queue_redraw()


func _draw() -> void:
    var font := ThemeDB.fallback_font
    match kind:
        "captive":
            if _sprite == null:
                draw_circle(Vector2(0, -12), 9.0, Color(0.9, 0.85, 0.7))
            draw_string(font, Vector2(-24, -40), "HELP!", HORIZONTAL_ALIGNMENT_CENTER, 48, 16, Color(1.0, 0.85, 0.4))
        "clue":
            var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
            draw_circle(Vector2(0, -10), 10.0 + pulse * 3.0, Color(0.5, 0.8, 1.0, 0.25))
            draw_arc(Vector2(0, -10), 12.0, 0.0, TAU, 24, Color(0.6, 0.9, 1.0), 2.0)
            draw_string(font, Vector2(-8, -4), "?", HORIZONTAL_ALIGNMENT_CENTER, 16, 16, Color(0.85, 0.95, 1.0))
        "shrine":
            # owner 2026-11-02 ("¿qué es este shrine?"): a rune stone that must be held (defense floors).
            # The circle is the zone a hero must stand in; the ring on the stone fills while it is held.
            var t := Time.get_ticks_msec() / 1000.0
            var held := progress > 0.0
            var col := Color(0.6, 0.85, 1.0) if held else Color(0.7, 0.6, 1.0)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
            draw_circle(Vector2.ZERO, 120.0, Color(col, 0.06))
            for k in 24:                                  # dashed, slowly turning border
                var a0 := TAU * float(k) / 24.0 + t * 0.15
                draw_arc(Vector2.ZERO, 120.0, a0, a0 + TAU / 48.0, 4, Color(col, 0.55), 2.0)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
            draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
            draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.35))
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
            # the stone: a tapering menhir with a glowing rune
            draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(6, -30), Vector2(0, -36), Vector2(-6, -30)]), Color(0.42, 0.42, 0.5))
            draw_colored_polygon(PackedVector2Array([Vector2(1, 0), Vector2(9, 0), Vector2(6, -30), Vector2(0, -36)]), Color(0.32, 0.31, 0.4))
            var glow := 0.6 + 0.4 * sin(t * 3.0)
            draw_circle(Vector2(0, -18), 7.0, Color(col, 0.25 * glow))
            draw_polyline(PackedVector2Array([Vector2(0, -25), Vector2(-3, -18), Vector2(3, -16), Vector2(0, -10)]), Color(col.lightened(0.3), glow), 1.5)
            draw_arc(Vector2(0, -18), 16.0, -PI / 2.0, -PI / 2.0 + TAU, 32, Color(0, 0, 0, 0.35), 3.0)
            if progress > 0.0:
                draw_arc(Vector2(0, -18), 16.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, col, 3.0)
            var txt := "%s %d%%" % [tr("SHRINE"), int(progress * 100.0)]
            var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
            draw_string_outline(font, Vector2(-tw / 2.0, -42), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.1, 0.05, 0.2, 0.9))
            draw_string(font, Vector2(-tw / 2.0, -42), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col.lightened(0.3))
        _:
            var pts := PackedVector2Array([Vector2(0, -22), Vector2(10, -11), Vector2(0, 0), Vector2(-10, -11)])
            draw_colored_polygon(pts, Color(1.0, 0.82, 0.25))
            draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1.0, 0.95, 0.7), 2.0)
            draw_string(font, Vector2(-24, -30), "RELIC", HORIZONTAL_ALIGNMENT_CENTER, 48, 16, Color(1.0, 0.82, 0.25))
