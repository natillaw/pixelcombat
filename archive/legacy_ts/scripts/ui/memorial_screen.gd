class_name MemorialScreen
extends Control
## The Memorial of the fallen (T-013, D-011). Redone 2026-11-02 (owner: "¿se supone que esto es un memorial?
## ¿dónde está la creatividad?"): a moonlit garden of headstones. Every fallen hero has a stone with their
## name carved in it and a candle that never goes out; hovering a stone raises the hero's spirit, and
## clicking it opens their epitaph on parchment (class, level, how and where they fell, who they were).
## Read-only: entries come from Game.memorial and are never edited.

signal back_requested

const PER_PAGE := 10
const STONE := Vector2(52, 58)

var _page: int = 0
var _garden: Control = null
var _epitaph: PanelContainer = null
var _sky: MemorialSky = null


static func entry_text(m: Dictionary) -> String:
    var cls: String = String(HeroTables.CLASSES.get(String(m.get("class", "class.none")), HeroTables.CLASSES["class.none"])["name"])
    var lines: Array = []
    lines.append("#%d  %s  -  %d-star %s, Lv %d" % [int(m.get("n", 0)), m.get("name", "?"), int(m.get("stars", 1)), cls, int(m.get("level", 1))])
    var cause := String(m.get("cause", ""))
    var mission := String(m.get("mission", ""))
    if cause != "" or mission != "":
        lines.append("    %s%s" % [cause, "  (%s)" % mission if mission != "" else ""])
    var bg := String(m.get("background", ""))
    if bg != "":
        lines.append("    %s" % bg)
    return "\n".join(lines)


## A one-line epitaph from the hero's first trait (who they were, in a few words).
static func epitaph_line(m: Dictionary) -> String:
    var traits: Array = m.get("traits", [])
    if traits.is_empty():
        return "Gone, never forgotten."
    var t: Dictionary = HeroTables.TRAITS.get(String(traits[0]), {})
    return String(t.get("desc", "Gone, never forgotten."))


func _ready() -> void:
    clip_contents = true
    UIKit.music("title")
    _sky = MemorialSky.new()
    add_child(_sky)
    UIKit.fill(_sky)
    var top := HBoxContainer.new()
    top.position = Vector2(8, 6)
    add_child(top)
    top.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(100, 36)))
    var title := UIKit.label("Memorial", 28, Color(0.85, 0.88, 1.0))
    title.add_theme_constant_override("outline_size", 4)
    title.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.1))
    top.add_child(title)
    var count := UIKit.label("   %d %s" % [Game.memorial.size(), tr("fallen")], 14, Color(0.7, 0.74, 0.9))
    count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    top.add_child(count)
    _garden = Control.new()
    add_child(_garden)
    UIKit.fill(_garden)
    _garden.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_garden()
    if not Game.memorial.is_empty():
        _show_epitaph(Game.memorial[Game.memorial.size() - 1])    # the newest loss, open on arrival


func _build_garden() -> void:
    for c in _garden.get_children():
        c.queue_free()
    if Game.memorial.is_empty():
        var vigil := MemorialStone.new({}, true)
        vigil.position = Vector2(320 - STONE.x / 2, 196)
        _garden.add_child(vigil)
        var l := UIKit.label("No hero has fallen yet. May it stay that way.", 14, Color(0.78, 0.8, 0.95))
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.position = Vector2(120, 272)
        l.size = Vector2(400, 16)
        _garden.add_child(l)
        var l2 := UIKit.label("The candle is lit for the ones who will climb the tower.", 12, Color(0.6, 0.62, 0.78))
        l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l2.position = Vector2(120, 290)
        l2.size = Vector2(400, 16)
        _garden.add_child(l2)
        return
    var newest_first: Array = Game.memorial.duplicate()
    newest_first.reverse()
    var pages := ceili(float(newest_first.size()) / float(PER_PAGE))
    _page = clampi(_page, 0, pages - 1)
    var shown: Array = newest_first.slice(_page * PER_PAGE, (_page + 1) * PER_PAGE)
    # two rows of stones on the hill, the back row smaller and darker (depth)
    for i in shown.size():
        var back := i >= 5
        var col := i % 5
        var st := MemorialStone.new(shown[i])
        var x := 70.0 + float(col) * 80.0 + (40.0 if back else 0.0)
        var y := 178.0 if back else 236.0
        st.position = Vector2(x, y)
        st.scale = Vector2.ONE * (0.85 if back else 1.0)
        if back:
            st.modulate = Color(0.82, 0.84, 0.95)
        st.picked.connect(_show_epitaph)
        _garden.add_child(st)
        if back:
            _garden.move_child(st, 0)
    if pages > 1:
        var nav := HBoxContainer.new()
        nav.position = Vector2(250, 330)
        var prev := UIKit.button("<", func():
            _page -= 1
            _build_garden(), Vector2(40, 30))
        prev.disabled = _page == 0
        nav.add_child(prev)
        nav.add_child(UIKit.label("%d / %d" % [_page + 1, pages], 14, Color(0.8, 0.82, 0.95)))
        var nxt := UIKit.button(">", func():
            _page += 1
            _build_garden(), Vector2(40, 30))
        nxt.disabled = _page >= pages - 1
        nav.add_child(nxt)
        _garden.add_child(nav)


## The epitaph on parchment, next to the garden.
func _show_epitaph(m: Dictionary) -> void:
    if _epitaph != null:
        _epitaph.queue_free()
    _epitaph = PanelContainer.new()
    _epitaph.add_theme_stylebox_override("panel", UIKit.box(Color(0.93, 0.87, 0.72), Color(0.45, 0.32, 0.18), 2, 0, 8))
    _epitaph.position = Vector2(452, 40)
    _epitaph.custom_minimum_size = Vector2(176, 0)
    add_child(_epitaph)
    var ink := Color(0.24, 0.15, 0.08)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 3)
    _epitaph.add_child(v)
    var head := HBoxContainer.new()
    var snap: Dictionary = m.get("snapshot", {})
    if not snap.is_empty():
        var h := HeroData.from_dict(snap)
        var face := HeroPortrait.new(h, 1.0)
        face.modulate = Color(0.75, 0.72, 0.68)               # faded, like an old drawing
        head.add_child(face)
    var names := VBoxContainer.new()
    names.add_theme_constant_override("separation", 0)
    var nl := UIKit.label(String(m.get("name", "?")), 14, ink)
    nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    nl.custom_minimum_size = Vector2(110, 0)
    names.add_child(nl)
    var cls: String = String(HeroTables.CLASSES.get(String(m.get("class", "class.none")), HeroTables.CLASSES["class.none"])["name"])
    names.add_child(UIKit.label("%s · %s %d" % [tr(cls), tr("Lv"), int(m.get("level", 1))], 12, Color(ink, 0.8)))
    names.add_child(StarRow.new(int(m.get("stars", 1)), 10.0))
    head.add_child(names)
    v.add_child(head)
    var rule := ColorRect.new()
    rule.color = Color(ink, 0.4)
    rule.custom_minimum_size = Vector2(0, 1)
    v.add_child(rule)
    var ep := UIKit.label("\"%s\"" % tr(epitaph_line(m)), 12, ink)
    ep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ep.custom_minimum_size = Vector2(160, 0)
    v.add_child(ep)
    var cause := String(m.get("cause", ""))
    var mission := String(m.get("mission", ""))
    if cause != "" or mission != "":
        var fell := UIKit.label("%s: %s%s" % [tr("Fell"), cause, "  (%s)" % mission if mission != "" else ""], 12, Color(0.5, 0.12, 0.1))
        fell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        fell.custom_minimum_size = Vector2(160, 0)
        v.add_child(fell)
    var bg := String(m.get("background", ""))
    if bg != "":
        var b := UIKit.label(bg, 12, Color(ink, 0.85))
        b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        b.custom_minimum_size = Vector2(160, 0)
        v.add_child(b)
    v.add_child(UIKit.label("%s #%d · %s #%d" % [tr("Fallen"), int(m.get("n", 0)), tr("Summon no."), int(m.get("summon_index", 0))], 12, Color(ink, 0.6)))
    UIKit.pop_in(_epitaph)


## Night sky, moon, the hill and drifting motes (look only).
class MemorialSky extends Control:
    var _t: float = 0.0
    var _stars: Array = []

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        var r := RandomNumberGenerator.new()
        r.seed = 777
        for i in 70:
            _stars.append([Vector2(r.randf() * 640.0, r.randf() * 170.0), r.randf() * TAU, r.randf_range(0.4, 1.0)])

    func _process(delta: float) -> void:
        _t += delta
        queue_redraw()

    ## The monument at the top of the hill: a stone obelisk on steps with an eternal flame.
    func _monument(base: Vector2) -> void:
        var st := Color(0.36, 0.38, 0.46)
        var dk := Color(0.24, 0.25, 0.32)
        draw_rect(Rect2(base + Vector2(-34, -6), Vector2(68, 8)), dk)
        draw_rect(Rect2(base + Vector2(-26, -12), Vector2(52, 7)), st)
        draw_colored_polygon(PackedVector2Array([base + Vector2(-12, -12), base + Vector2(12, -12), base + Vector2(8, -78), base + Vector2(-8, -78)]), st)
        draw_colored_polygon(PackedVector2Array([base + Vector2(0, -12), base + Vector2(12, -12), base + Vector2(8, -78), base + Vector2(0, -78)]), dk)
        draw_colored_polygon(PackedVector2Array([base + Vector2(-8, -78), base + Vector2(8, -78), base + Vector2(0, -90)]), st.lightened(0.15))
        var fl := 0.8 + 0.2 * sin(_t * 9.0) + 0.1 * sin(_t * 21.0)
        var f := base + Vector2(0, -94)
        draw_circle(f, 26.0 * fl, Color(0.55, 0.7, 1.0, 0.07))
        draw_circle(f, 12.0 * fl, Color(0.6, 0.8, 1.0, 0.15))
        draw_colored_polygon(PackedVector2Array([f + Vector2(-4, 4), f + Vector2(4, 4), f + Vector2(0, -10 * fl)]), Color(0.6, 0.85, 1.0))
        draw_colored_polygon(PackedVector2Array([f + Vector2(-2, 4), f + Vector2(2, 4), f + Vector2(0, -5 * fl)]), Color(0.95, 1.0, 1.0))
        for k in 3:                                          # carved lines on the obelisk
            draw_rect(Rect2(base + Vector2(-5, -60 + k * 10), Vector2(10, 1)), Color(0.18, 0.18, 0.24))

    func _draw() -> void:
        var steps := 12
        for i in steps:                                    # sky gradient in bands (pixel look)
            var k := float(i) / float(steps - 1)
            draw_rect(Rect2(0, i * 20, 640, 21), Color(0.03, 0.04, 0.1).lerp(Color(0.12, 0.12, 0.25), k))
        for s in _stars:
            var a: float = float(s[2]) * (0.5 + 0.5 * sin(_t * 1.5 + float(s[1])))
            draw_rect(Rect2(s[0], Vector2(1, 1)), Color(1, 1, 1, a))
        var moon := Vector2(540, 70)                        # moon with a halo
        draw_circle(moon, 40.0, Color(0.7, 0.75, 1.0, 0.05))
        draw_circle(moon, 28.0, Color(0.7, 0.75, 1.0, 0.08))
        draw_circle(moon, 18.0, Color(0.92, 0.93, 0.85))
        draw_circle(moon + Vector2(5, -3), 4.0, Color(0.82, 0.83, 0.76))
        draw_circle(moon + Vector2(-6, 6), 3.0, Color(0.82, 0.83, 0.76))
        var far := PackedVector2Array()                      # far hills
        for i in 33:
            far.append(Vector2(i * 20, 180.0 - 14.0 * sin(i * 0.5) - 8.0 * sin(i * 1.3)))
        far.append(Vector2(640, 360))
        far.append(Vector2(0, 360))
        draw_colored_polygon(far, Color(0.07, 0.09, 0.16))
        var hill := PackedVector2Array()                     # the memorial hill
        for i in 33:
            var x := float(i) * 20.0
            hill.append(Vector2(x, 200.0 + 0.0006 * pow(x - 320.0, 2.0)))
        hill.append(Vector2(640, 360))
        hill.append(Vector2(0, 360))
        draw_colored_polygon(hill, Color(0.08, 0.15, 0.12))
        _monument(Vector2(320, 176))
        for i in 40:                                         # grass blades catching the moonlight
            var x := fmod(float(i) * 97.0, 640.0)
            var y := 214.0 + 0.0006 * pow(x - 320.0, 2.0) + fmod(float(i) * 53.0, 120.0)
            draw_line(Vector2(x, y), Vector2(x + 1, y - 3), Color(0.25, 0.4, 0.32, 0.6), 1.0)
        for i in 14:                                         # drifting motes (souls, fireflies)
            var p := Vector2(fmod(float(i) * 83.0 + _t * 6.0, 640.0), 300.0 - fmod(float(i) * 37.0 + _t * 9.0, 200.0))
            var a := 0.4 + 0.4 * sin(_t * 2.0 + float(i))
            draw_circle(p, 1.5, Color(0.7, 0.85, 1.0, a * 0.4))
            draw_rect(Rect2(p, Vector2(1, 1)), Color(0.85, 0.95, 1.0, a))


## (inside MemorialSky) see _monument below.
## One headstone: rounded stone with the carved name, moss in the hero's star colour, a candle that
## flickers; hovering raises the hero's spirit. Click = epitaph.
class MemorialStone extends Control:
    signal picked(m: Dictionary)
    var entry: Dictionary
    var vigil: bool = false
    var _t: float = 0.0
    var _hover: bool = false
    var _ghost: AnimatedSprite2D = null

    func _init(m: Dictionary = {}, p_vigil: bool = false) -> void:
        entry = m
        vigil = p_vigil
        custom_minimum_size = MemorialScreen.STONE
        size = MemorialScreen.STONE
        mouse_filter = Control.MOUSE_FILTER_IGNORE if vigil else Control.MOUSE_FILTER_STOP
        _t = randf() * 10.0

    func _ready() -> void:
        if vigil:
            return
        tooltip_text = String(entry.get("name", ""))
        mouse_entered.connect(func():
            _hover = true
            UIKit.sound("hover"))
        mouse_exited.connect(func(): _hover = false)
        var snap: Dictionary = entry.get("snapshot", {})
        if not snap.is_empty():
            _ghost = AnimatedSprite2D.new()
            _ghost.sprite_frames = SpriteComposer.build_frames(HeroData.from_dict(snap))
            _ghost.play("idle_down")
            _ghost.position = Vector2(size.x / 2.0, -6)
            _ghost.modulate = Color(0.6, 0.85, 1.0, 0.0)
            add_child(_ghost)

    func _gui_input(e: InputEvent) -> void:
        if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
            UIKit.sound("click")
            picked.emit(entry)

    func _process(delta: float) -> void:
        _t += delta
        if _ghost != null:
            var target := 0.55 if _hover else 0.0
            _ghost.modulate.a = move_toward(_ghost.modulate.a, target, delta * 1.5)
            _ghost.position.y = -6.0 - 4.0 * sin(_t * 1.6) - (8.0 if _hover else 0.0) * _ghost.modulate.a
        queue_redraw()

    func _draw() -> void:
        var w := size.x
        var h := size.y
        draw_set_transform(Vector2(w / 2.0, h), 0.0, Vector2(1.0, 0.3))
        draw_circle(Vector2.ZERO, w * 0.6, Color(0, 0, 0, 0.35))      # shadow on the grass
        draw_set_transform(Vector2.ZERO)
        var stone := Color(0.55, 0.57, 0.62) if not _hover else Color(0.66, 0.68, 0.74)
        var dark := stone.darkened(0.35)
        var body := Rect2(6, 16, w - 12, h - 20)
        var ol := Color(0.12, 0.12, 0.16)
        draw_circle(Vector2(w / 2.0, 18), (w - 12) / 2.0 + 1.0, ol)   # outline
        draw_rect(body.grow(1), ol)
        draw_rect(body, stone)
        draw_circle(Vector2(w / 2.0, 18), (w - 12) / 2.0, stone)       # rounded top
        draw_rect(Rect2(w * 0.62, 16, w * 0.38 - 6, h - 20), dark)     # side in shade
        draw_rect(Rect2(w / 2.0 - 1, 6, 2, 7), Color(0.3, 0.3, 0.36))  # carved cross
        draw_rect(Rect2(w / 2.0 - 3, 8, 6, 2), Color(0.3, 0.3, 0.36))
        draw_rect(Rect2(1, h - 7, w - 2, 6), ol)
        draw_rect(Rect2(2, h - 6, w - 4, 4), stone.darkened(0.2))      # base slab
        for k in 3:                                                    # flowers left at the grave
            var fp := Vector2(8 + k * 5, h - 2)
            draw_rect(Rect2(fp + Vector2(0, -4), Vector2(1, 4)), Color(0.25, 0.5, 0.3))
            draw_rect(Rect2(fp + Vector2(-1, -6), Vector2(3, 2)), [Color(0.95, 0.85, 0.9), Color(0.8, 0.5, 0.9), Color(1.0, 0.9, 0.5)][k])
        if vigil:
            _candle(Vector2(w / 2.0, h - 2))
            return
        var moss: Color = HeroTables.STAR_COLORS[clampi(int(entry.get("stars", 1)), 0, HeroTables.STAR_COLORS.size() - 1)]
        draw_rect(Rect2(6, h - 9, 10, 3), Color(moss, 0.7))
        draw_rect(Rect2(w - 18, h - 8, 8, 2), Color(moss, 0.6))
        var f := UIKit.body_font()
        var first := String(entry.get("name", "?")).split(" ")[0]
        var tw := f.get_string_size(first, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
        var fs := 16 if tw <= w - 14 else 8
        tw = f.get_string_size(first, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
        draw_string(f, Vector2((w - tw) / 2.0 + 1, 33), first, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.85, 0.87, 0.9, 0.5))   # carved: light rim
        draw_string(f, Vector2((w - tw) / 2.0, 32), first, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.2, 0.25))
        var lv := "Lv %d" % int(entry.get("level", 1))
        var lw := f.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
        draw_string(f, Vector2((w - lw) / 2.0, 44), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.25, 0.25, 0.3, 0.8))
        _candle(Vector2(w - 8, h - 2))

    func _candle(at: Vector2) -> void:
        var fl := 0.8 + 0.2 * sin(_t * 11.0) + 0.1 * sin(_t * 23.0)
        draw_circle(at + Vector2(0, -12), 14.0 * fl, Color(1.0, 0.7, 0.3, 0.12))
        draw_circle(at + Vector2(0, -12), 7.0 * fl, Color(1.0, 0.75, 0.35, 0.2))
        draw_rect(Rect2(at + Vector2(-2, -8), Vector2(4, 8)), Color(0.95, 0.92, 0.82))
        draw_rect(Rect2(at + Vector2(-1, -14 + (1.0 - fl) * 2.0), Vector2(2, 4)), Color(1.0, 0.85, 0.4))
        draw_rect(Rect2(at + Vector2(0, -15 + (1.0 - fl) * 2.0), Vector2(1, 2)), Color(1.0, 0.98, 0.85))
