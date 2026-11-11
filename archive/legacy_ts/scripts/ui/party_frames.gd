class_name PartyFrames
extends VBoxContainer
## D-111 (pista C): party frames down the left edge of the expedition (one per hero, Master first):
## portrait, name, health, resource, statuses, agony counter, and a red border while a creature is going
## for that hero. Click = that hero becomes the target of the next ping (SandboxScreen.select_slot).
## Bars drain smoothly: the lost chunk stays white ~0.3 s and then slides down; the portrait flashes and
## punches when hit; health goes green -> yellow -> red; healing fills smoothly with sparks.
## Reads optional pista A functions (resource_value/resource_max/resource_kind, enemies' target) when they
## exist; otherwise the parts they would feed fall back to today's fields or stay hidden.

const W := 92                            # px, whole frame
const H := 26
const FACE := 22

var sb: SandboxScreen
var _frames: Array = []


func _init(screen: SandboxScreen = null) -> void:
    sb = screen
    add_theme_constant_override("separation", 2)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
    if sb == null:
        return
    for i in sb.heroes.size():
        var f := Frame.new(sb, i)
        add_child(f)
        _frames.append(f)


func refresh() -> void:
    var targeted := targeted_heroes(sb)
    for f in _frames:
        (f as Frame).refresh(targeted)


func frame(i: int) -> Frame:
    return _frames[i] if i >= 0 and i < _frames.size() else null


## Heroes some living creature is going for (enemy.focus, or pista A's target_of()/target when present).
static func targeted_heroes(screen: SandboxScreen) -> Dictionary:
    var out := {}
    if screen == null:
        return out
    for e in screen.living_enemies():
        var t = null
        if e.has_method("target_of"):
            t = e.call("target_of")
        elif e.get("focus") != null:
            t = e.get("focus")
        if t != null and is_instance_valid(t):
            out[t.get_instance_id()] = true
    return out


## Health colour by fraction: green above 60%, yellow in between, red below 25%.
static func hp_color(frac: float) -> Color:
    if frac > 0.6:
        return ArtPalette.HP
    if frac > 0.25:
        return Color(0.95, 0.8, 0.25)
    return Color(0.9, 0.25, 0.2)


## One hero's frame.
class Frame extends Control:
    var sb: SandboxScreen
    var index: int
    var _face: TextureRect
    var _name: Label
    var _hp: SmoothBar
    var _res: SmoothBar
    var _marks: HBoxContainer
    var _agony: Label
    var _targeted: bool = false
    var _last_hp: int = -1
    var _punch: float = 0.0

    func _init(screen: SandboxScreen, i: int) -> void:
        sb = screen
        index = i
        custom_minimum_size = Vector2(PartyFrames.W, PartyFrames.H)
        mouse_filter = Control.MOUSE_FILTER_STOP

    func _ready() -> void:
        var h: SandboxHero = sb.heroes[index]
        _face = TextureRect.new()
        _face.position = Vector2(2, 2)
        _face.size = Vector2(PartyFrames.FACE, PartyFrames.FACE)
        _face.pivot_offset = _face.size * 0.5
        _face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        _face.stretch_mode = TextureRect.STRETCH_SCALE
        _face.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var full := SpriteComposer.pose_texture(h.hero) if h.hero != null else null
        if full != null:
            var at := AtlasTexture.new()
            at.atlas = full
            at.region = SpriteComposer.face_region(h.hero)
            _face.texture = at
        add_child(_face)
        _name = UIKit.label(h.hero.hero_name.split(" ")[0] if h.hero != null else "?", 12, UIKit.TEXT)
        _name.position = Vector2(PartyFrames.FACE + 5, -3)
        _name.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_name)
        var bw := PartyFrames.W - PartyFrames.FACE - 7
        _hp = SmoothBar.new(Vector2(bw, 5), true)
        _hp.position = Vector2(PartyFrames.FACE + 5, 11)
        add_child(_hp)
        _res = SmoothBar.new(Vector2(bw, 3), false)
        _res.position = Vector2(PartyFrames.FACE + 5, 18)
        _res.fixed_color = SkillDefs.RESOURCES[h.res_kind]["color"]
        add_child(_res)
        _marks = HBoxContainer.new()
        _marks.position = Vector2(PartyFrames.FACE + 5, 22)
        _marks.add_theme_constant_override("separation", 1)
        _marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_marks)
        _agony = UIKit.label("", 12, UIKit.BAD)
        _agony.position = Vector2(3, 6)
        _agony.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_agony)
        refresh({})

    func _gui_input(e: InputEvent) -> void:
        if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
            sb.select_slot(index)
            UIKit.sound("click")
            accept_event()

    func _res_values(h: SandboxHero) -> Array:
        if h.has_method("resource_value") and h.has_method("resource_max"):
            return [float(h.call("resource_value")), float(h.call("resource_max"))]
        return [float(h.res), float(h.res_max)]

    func refresh(targeted: Dictionary) -> void:
        var h: SandboxHero = sb.heroes[index]
        _hp.set_value(float(h.hp), float(maxi(1, h.max_hp)))
        var rv := _res_values(h)
        _res.set_value(rv[0], maxf(1.0, rv[1]))
        if _last_hp >= 0 and h.hp < _last_hp:
            _punch = 1.0                                     # portrait flash + punch
        _last_hp = h.hp
        _targeted = targeted.has(h.get_instance_id()) and h.alive
        var gone := h.dead or h.downed
        _face.modulate = Color(0.45, 0.45, 0.5) if gone else Color.WHITE
        _agony.text = ("%d:%02d" % [int(h.agony) / 60, int(h.agony) % 60]) if h.downed and not h.dead else ""
        if h.dead:
            _agony.text = "X"
        var tip := "%d · %s\nHP %d/%d  %s %d/%d\n%s" % [index + 1, h.hero.display_name(), h.hp, h.max_hp,
            String(SkillDefs.RESOURCES[h.res_kind]["name"]), roundi(rv[0]), roundi(rv[1]), h.order_label()]
        if h.downed:
            tip += "\n" + tr("DOWN %ds: right-click to rescue") % ceili(h.agony)
        if _targeted:
            tip += "\n" + tr("An enemy is going for this hero")
        tooltip_text = tip
        if _marks.get_child_count() != h.statuses.size():
            for c in _marks.get_children():
                c.queue_free()
            for id in h.statuses:
                var r := ColorRect.new()
                r.custom_minimum_size = Vector2(3, 3)
                r.color = CombatRules.STATUS[id]["color"]
                r.tooltip_text = String(CombatRules.STATUS[id]["name"])
                _marks.add_child(r)
        queue_redraw()

    func _process(delta: float) -> void:
        if _punch > 0.0:
            _punch = maxf(0.0, _punch - delta * 5.0)
            var s := 1.0 + 0.18 * _punch
            _face.scale = Vector2(s, s)
            _face.self_modulate = Color(1.0 + _punch * 1.5, 1.0 + _punch * 0.3, 1.0 + _punch * 0.3)
            queue_redraw()

    func _draw() -> void:
        var h: SandboxHero = sb.heroes[index]
        draw_rect(Rect2(Vector2.ZERO, size), Color(ArtPalette.INK, 0.82))
        var border := ArtPalette.OUTLINE
        if _targeted:
            border = Color(0.95, 0.15, 0.12)
        elif h.is_controlled() or sb.follow_slot == index:
            border = UIKit.ACCENT
        draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), border, false, 1.0)
        if _targeted:
            draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)).grow(-0.5), Color(border, 0.5), false, 1.0)
        draw_rect(Rect2(Vector2(1, 1), Vector2(PartyFrames.FACE + 2, PartyFrames.FACE + 2)), Color(0, 0, 0, 0.5))


## A bar that drains and fills smoothly. The part just lost stays white for TRAIL_HOLD and then slides
## down; healing fills over FILL_TIME with a few sparks at its edge. Whole-pixel drawing.
class SmoothBar extends Control:
    const TRAIL_HOLD := 0.3
    const DRAIN_RATE := 1.6               # fraction of the bar per second the white chunk loses
    const FILL_TIME := 0.35
    var by_health: bool = true
    var fixed_color: Color = Color(0.4, 0.6, 1.0)
    var value: float = 1.0
    var max_value: float = 1.0
    var shown: float = 1.0                # the coloured part (fraction)
    var trail: float = 1.0                # the white chunk (fraction)
    var _hold: float = 0.0
    var _sparks: Array = []               # [x, y, life]
    var _started: bool = false

    func _init(p_size: Vector2 = Vector2(60, 5), p_health: bool = true) -> void:
        custom_minimum_size = p_size
        size = p_size
        by_health = p_health
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func set_value(v: float, m: float) -> void:
        var first := not _started
        _started = true
        max_value = maxf(1.0, m)
        var frac := clampf(v / max_value, 0.0, 1.0)
        var old := clampf(value / max_value, 0.0, 1.0)
        value = v
        if first:
            shown = frac
            trail = frac
            return
        if frac < old - 0.0001:
            shown = frac                  # damage: coloured part drops at once, white chunk waits
            _hold = TRAIL_HOLD
        elif frac > old + 0.0001 and by_health:
            for i in 3:
                _sparks.append([randf_range(0.0, 1.0), randf_range(-1.0, 1.0), 0.4])

    func target() -> float:
        return clampf(value / max_value, 0.0, 1.0)

    func _process(delta: float) -> void:
        var t := target()
        if shown < t:
            shown = minf(t, shown + delta / FILL_TIME)      # healing fills smoothly
        if trail < shown:
            trail = shown
        if _hold > 0.0:
            _hold -= delta
        elif trail > shown:
            trail = maxf(shown, trail - DRAIN_RATE * delta * maxf(0.25, trail - shown + 0.25))
        for s in _sparks:
            s[2] = float(s[2]) - delta
        _sparks = _sparks.filter(func(s): return float(s[2]) > 0.0)
        queue_redraw()

    func _draw() -> void:
        var w := size.x
        draw_rect(Rect2(Vector2.ZERO, size), ArtPalette.INK)
        var tw := floorf(w * trail)
        var sw := floorf(w * shown)
        if tw > sw:
            draw_rect(Rect2(Vector2(sw, 0), Vector2(tw - sw, size.y)), Color(1, 1, 1, 0.9))
        var col := PartyFrames.hp_color(target()) if by_health else fixed_color
        if sw > 0.0:
            draw_rect(Rect2(Vector2.ZERO, Vector2(sw, size.y)), col)
            draw_rect(Rect2(Vector2.ZERO, Vector2(sw, 1)), col.lightened(0.3))
        for s in _sparks:
            var x := floorf(sw) - 1.0 - float(s[0]) * 3.0
            var y := floorf(size.y * 0.5 + float(s[1]) * 3.0 - (0.4 - float(s[2])) * 8.0)
            draw_rect(Rect2(Vector2(x, y), Vector2(1, 1)), Color(0.85, 1.0, 0.75, float(s[2]) / 0.4))
        draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), ArtPalette.OUTLINE, false, 1.0)
