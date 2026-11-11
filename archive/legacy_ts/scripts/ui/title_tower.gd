class_name TitleTower
extends Node2D
## The Tower on the title screen (2026-11-02): a tall stone spire drawn in pixel steps, lit windows that
## flicker, a crystal at the top sending a beam into the aurora, and the summoning portal open at its base.
## Position = the middle of its base on the ground. Look only.

const H := 250.0                 # px from the ground to the top of the walls
const BASE_W := 96.0
const TOP_W := 56.0
const BAND := 14.0               # stone course height
const STONE := Color(0.20, 0.21, 0.30)
const STONE_DARK := Color(0.13, 0.13, 0.21)
const STONE_LIGHT := Color(0.30, 0.31, 0.43)
const WINDOW := Color(1.0, 0.75, 0.35)
const MAGIC := Color(0.72, 0.5, 1.0)

var _t: float = 0.0


func _ready() -> void:
    var path := AssetCatalog.world("tower_portal")
    if ResourceLoader.exists(path):
        var tex: Texture2D = load(path)
        var sf := SpriteFrames.new()
        for i in 6:
            var at := AtlasTexture.new()
            at.atlas = tex
            at.region = Rect2(i * 32, 0, 32, 48)
            sf.add_frame("default", at)
        sf.set_animation_speed("default", 8.0)
        var portal := AnimatedSprite2D.new()
        portal.sprite_frames = sf
        portal.scale = Vector2(2, 2)
        portal.position = Vector2(0, -48)
        portal.play()
        add_child(portal)


func _process(delta: float) -> void:
    _t += delta
    queue_redraw()


func _half_w(y: float) -> float:
    return floorf(lerpf(BASE_W, TOP_W, clampf(-y / H, 0.0, 1.0)) / 2.0)


func _draw() -> void:
    # beam from the crystal up into the sky
    var top := -H - 34.0
    var pulse := 0.5 + 0.5 * sin(_t * 1.7)
    draw_rect(Rect2(-6, -400, 12, 400 + top), Color(MAGIC, 0.06 + 0.04 * pulse))
    draw_rect(Rect2(-2, -400, 4, 400 + top), Color(MAGIC.lightened(0.4), 0.12 + 0.08 * pulse))
    # walls: stone courses, each a little narrower; the right side in shade
    var y := 0.0
    var row := 0
    while y > -H:
        var hw := _half_w(y)
        var r := Rect2(-hw, y - BAND, hw * 2.0, BAND)
        draw_rect(r, STONE)
        draw_rect(Rect2(hw * 0.25, y - BAND, hw * 0.75, BAND), STONE_DARK)          # shade
        draw_rect(Rect2(-hw, y - BAND, 2, BAND), STONE_LIGHT)                       # rim light (aurora side)
        draw_line(Vector2(-hw, y - BAND), Vector2(hw, y - BAND), Color(0.08, 0.08, 0.13), 1.0)
        var off := 10.0 if row % 2 == 0 else 0.0                                     # brick joints
        var x := -hw + off
        while x < hw:
            draw_line(Vector2(x, y - BAND), Vector2(x, y), Color(0.09, 0.09, 0.14), 1.0)
            x += 20.0
        y -= BAND
        row += 1
    # windows (warm ones flicker; two magic ones on the upper floors)
    var wins := [[-18, -70, false], [14, -112, false], [-10, -150, true], [12, -188, false], [-4, -222, true]]
    for i in wins.size():
        var w: Array = wins[i]
        var c: Color = MAGIC if bool(w[2]) else WINDOW
        var fl := 0.75 + 0.25 * sin(_t * (3.0 + float(i)) + float(i) * 1.7)
        var p := Vector2(float(w[0]), float(w[1]))
        draw_circle(p + Vector2(3, 4), 9.0, Color(c, 0.12 * fl))
        draw_rect(Rect2(p, Vector2(6, 9)), Color(0.05, 0.03, 0.08))
        draw_rect(Rect2(p + Vector2(1, 2), Vector2(4, 7)), Color(c, fl))
        draw_rect(Rect2(p + Vector2(0, -1), Vector2(6, 2)), STONE_LIGHT)
    # battlements and the roof cone
    var thw := _half_w(-H)
    for k in range(-3, 4):
        var bx := float(k) * thw / 3.5
        draw_rect(Rect2(bx - 4, -H - 10, 8, 10), STONE if k < 1 else STONE_DARK)
    draw_rect(Rect2(-thw - 3, -H - 2, thw * 2.0 + 6, 4), STONE_LIGHT)
    draw_colored_polygon(PackedVector2Array([Vector2(-thw * 0.6, -H - 10), Vector2(thw * 0.6, -H - 10), Vector2(0, top + 6)]), Color(0.24, 0.14, 0.32))
    draw_colored_polygon(PackedVector2Array([Vector2(0, -H - 10), Vector2(thw * 0.6, -H - 10), Vector2(0, top + 6)]), Color(0.16, 0.09, 0.22))
    # the crystal
    var cy := top - 4.0 * sin(_t * 1.3)
    draw_circle(Vector2(0, cy), 14.0 + 3.0 * pulse, Color(MAGIC, 0.18))
    draw_colored_polygon(PackedVector2Array([Vector2(0, cy - 10), Vector2(6, cy), Vector2(0, cy + 10), Vector2(-6, cy)]), MAGIC)
    draw_colored_polygon(PackedVector2Array([Vector2(0, cy - 10), Vector2(-6, cy), Vector2(0, cy + 10)]), MAGIC.lightened(0.45))
    # glow of the portal on the walls and the ground
    draw_circle(Vector2(0, -40), 46.0, Color(MAGIC, 0.07 + 0.03 * pulse))
    draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.25))
    draw_circle(Vector2.ZERO, 70.0, Color(MAGIC, 0.12))
    draw_set_transform(Vector2.ZERO)
