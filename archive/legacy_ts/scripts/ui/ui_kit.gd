class_name UIKit
extends RefCounted
## Small helpers so screens stay short: colours, the pixel Theme, labels, buttons (D-063).
## The game renders at a 640x360 base scaled by a whole number (x2 720p, x3 1080p, x4 1440p). Screens
## were laid out in 1280x720 "design units": UIKit converts them (px), and text always uses the pixel
## fonts at their native sizes (m5x7 for body text, m6x11 for titles), never a fractional size.

const BG := ArtPalette.INK
const PANEL := ArtPalette.PANEL
const PANEL_LIGHT := ArtPalette.PANEL_LIGHT
const ACCENT := ArtPalette.TEXT_ACCENT
const TEXT := ArtPalette.TEXT
const MUTED := ArtPalette.TEXT_MUTED
const GOOD := ArtPalette.TEXT_GOOD
const BAD := ArtPalette.TEXT_BAD

const DESIGN_SCALE := 0.5          # 1280x720 design units -> 640x360 base pixels
const BODY := 16                   # m5x7 native size (1 font pixel = 1 base pixel)
const TITLE := 16                  # m6x11 native size
const TITLE_BIG := 32              # m6x11 x2 (screen titles)

static var _body: Font = null
static var _title: Font = null


## The audio autoloads looked up at run time (scripts run with --script have no autoloads): nothing
## happens when they are absent (headless tests, tools).
static func audio(autoload_name: String = "UiSfx") -> Node:
    var tree := Engine.get_main_loop() as SceneTree
    return tree.root.get_node_or_null(autoload_name) if tree != null and tree.root != null else null


static func sound(id: String) -> void:
    var a := audio("UiSfx")
    if a != null:
        a.call("play", id)


static func music(role: String) -> void:
    var a := audio("Music")
    if a != null:
        a.call("play_track", role)


static func get_volume(bus: String) -> float:
    var a := audio("UiSfx")
    return float(a.call("get_volume", bus)) if a != null else 1.0


static func set_volume(bus: String, v: float) -> void:
    var a := audio("UiSfx")
    if a != null:
        a.call("set_volume", bus, v)


## A design-unit length in base pixels (whole pixels only).
static func px(v: float) -> int:
    return roundi(v * DESIGN_SCALE)


static func pv(v: Vector2) -> Vector2:
    return Vector2(px(v.x), px(v.y))


## Pixel font size for a requested design size: small and normal text -> body, headings -> title.
static func fpx(design_size: int) -> int:
    return TITLE_BIG if design_size >= 28 else BODY


static func body_font() -> Font:
    if _body == null:
        _body = _pixel_font(AssetCatalog.FONT_BODY)
    return _body


static func title_font() -> Font:
    if _title == null:
        _title = _pixel_font(AssetCatalog.FONT_TITLE)
    return _title


static func _pixel_font(path: String) -> Font:
    if not ResourceLoader.exists(path):
        return ThemeDB.fallback_font
    var f := load(path) as FontFile
    if f == null:
        return ThemeDB.fallback_font
    f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
    f.hinting = TextServer.HINTING_NONE
    f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
    f.oversampling = 1.0
    return f


static func _tex(path: String) -> Texture2D:
    return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Nine-slice stylebox from a texture (frame `idx` of a horizontal sheet of frames `frame_w` wide).
static func nine(path: String, margin: int, frame_w: int = 0, idx: int = 0, content: int = 4) -> StyleBox:
    var tex := _tex(path)
    if tex == null:
        return box(PANEL, ArtPalette.PANEL_RIM, 1, 0, content)
    var s := StyleBoxTexture.new()
    s.texture = tex
    if frame_w > 0:
        s.region_rect = Rect2(idx * frame_w, 0, frame_w, tex.get_height())
    s.set_texture_margin_all(margin)
    s.set_content_margin_all(content)
    return s


## D-075: a piece of the CraftPix basic UI sheets as a 9-slice (rect inside the sheet, margins l/t/r/b).
const UI_B := "res://assets/pixel/packs/ui_basic/PNG/"
static func piece(sheet: String, rect: Rect2, l: int, t: int, r: int, b: int, content: int = 5) -> StyleBox:
    var tex := _tex(UI_B + sheet)
    if tex == null:
        return box(PANEL, ArtPalette.PANEL_RIM, 1, 0, content)
    var s := StyleBoxTexture.new()
    s.texture = tex
    s.region_rect = rect
    s.texture_margin_left = l
    s.texture_margin_top = t
    s.texture_margin_right = r
    s.texture_margin_bottom = b
    s.set_content_margin_all(content)
    s.content_margin_top = maxf(content, t - 2)
    return s


## Speech bubble over a unit (owner: messages never fitted). Measured and drawn at the same size,
## word-wrapped to `max_w` px, minimal: soft parchment, thin rim, small tail at `tip`.
const BUBBLE_FS := 12
static func draw_bubble(ci: CanvasItem, text: String, tip: Vector2, max_w: float = 120.0) -> void:
    var font := ThemeDB.fallback_font
    var lines: Array = []
    var cur := ""
    for w in text.split(" "):
        var t := w if cur == "" else cur + " " + w
        if cur != "" and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FS).x > max_w:
            lines.append(cur)
            cur = w
        else:
            cur = t
    if cur != "":
        lines.append(cur)
    var lh := font.get_height(BUBBLE_FS)
    var widest := 0.0
    for ln in lines:
        widest = maxf(widest, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FS).x)
    var box := Rect2(tip.x - widest * 0.5 - 5, tip.y - 5 - lh * lines.size() - 6, widest + 10, lh * lines.size() + 6)
    ci.draw_rect(box, Color(0.97, 0.94, 0.86, 0.96))
    ci.draw_rect(box, Color(0.25, 0.17, 0.1, 0.9), false, 1.0)
    ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-3, -5), tip + Vector2(3, -5), tip]), Color(0.97, 0.94, 0.86, 0.96))
    for k in lines.size():
        ci.draw_string(font, Vector2(box.position.x + 5, box.position.y + 3 + font.get_ascent(BUBBLE_FS) + k * lh), String(lines[k]),
            HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FS, Color(0.2, 0.13, 0.08))


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, radius: int = 0, p_margin: int = 4) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(border_w)
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(p_margin)
    s.anti_aliasing = false
    return s


## The one Theme of the game: kit panels, Dragon Regalia buttons, pixel fonts, palette colours.
static func make_theme() -> Theme:
    var t := Theme.new()
    t.default_font = body_font()
    t.default_font_size = BODY
    var ui: Dictionary = AssetCatalog.UI
    # D-075: CraftPix basic UI (wood panels with a header band, parchment insets, green buttons)
    var panel := piece("Main_tiles.png", Rect2(103, 48, 34, 37), 6, 14, 6, 7, 6)
    var parchment := piece("Main_tiles.png", Rect2(7, 48, 34, 37), 6, 14, 6, 7, 4)
    t.set_stylebox("panel", "PanelContainer", panel)
    t.set_stylebox("panel", "Panel", panel)
    t.set_stylebox("panel", "PopupPanel", panel)
    t.set_stylebox("panel", "TooltipPanel", parchment)
    t.set_color("font_color", "TooltipLabel", Color("3b2416"))
    t.set_font("font", "TooltipLabel", body_font())
    t.set_font_size("font_size", "TooltipLabel", BODY)
    for c in ["Label", "Button", "LineEdit", "CheckBox", "OptionButton", "TabBar"]:
        t.set_color("font_color", c, TEXT)
    t.set_color("font_hover_color", "Button", ArtPalette.GOLD[3])
    t.set_color("font_pressed_color", "Button", ArtPalette.GOLD[3])
    t.set_color("font_focus_color", "Button", TEXT)
    t.set_color("font_disabled_color", "Button", Color(TEXT_DISABLED))
    t.set_color("font_outline_color", "Label", ArtPalette.OUTLINE)
    t.set_stylebox("normal", "Button", piece("Buttons.png", Rect2(51, 97, 42, 15), 4, 4, 4, 5, 4))
    t.set_stylebox("hover", "Button", piece("Buttons.png", Rect2(147, 97, 42, 15), 4, 4, 4, 5, 4))
    t.set_stylebox("pressed", "Button", piece("Buttons.png", Rect2(3, 113, 42, 15), 4, 4, 4, 5, 4))
    t.set_stylebox("hover_pressed", "Button", piece("Buttons.png", Rect2(3, 113, 42, 15), 4, 4, 4, 5, 4))
    t.set_stylebox("disabled", "Button", box(Color(ArtPalette.PANEL, 0.9), ArtPalette.PANEL_RIM, 1, 0, 4))
    t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    t.set_stylebox("background", "ProgressBar", nine(String(ui["bar_frame"][0]), 2, 0, 0, 1))
    t.set_stylebox("fill", "ProgressBar", box(ArtPalette.MANA, Color(0, 0, 0, 0), 0, 0, 0))
    t.set_stylebox("normal", "LineEdit", box(ArtPalette.INK, ArtPalette.PANEL_RIM, 1, 0, 3))
    t.set_stylebox("panel", "TabContainer", panel)
    t.set_stylebox("tab_selected", "TabContainer", piece("Buttons.png", Rect2(147, 97, 42, 15), 4, 4, 4, 5, 3))
    t.set_stylebox("tab_unselected", "TabContainer", box(ArtPalette.PANEL, ArtPalette.PANEL_RIM, 1, 0, 3))
    t.set_stylebox("tab_hovered", "TabContainer", box(ArtPalette.PANEL_LIGHT, ArtPalette.PANEL_RIM, 1, 0, 3))
    t.set_constant("separation", "VBoxContainer", 4)
    t.set_constant("separation", "HBoxContainer", 4)
    t.set_constant("h_separation", "GridContainer", 4)
    t.set_constant("v_separation", "GridContainer", 4)
    return t


const TEXT_DISABLED := Color(0.45, 0.43, 0.55)


## A label in the pixel fonts. size is a design size (old 1280x720 sizes): it picks body or title.
static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
    var l := Label.new()
    l.text = StringsEs.tx(text)                       # beta: Spanish pieces inside composed texts
    l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
    var fs := fpx(size)
    if size >= 20:
        l.add_theme_font_override("font", title_font())
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", color)
    return l


## A button; min_size in design units.
static func button(text: String, callback: Callable, min_size: Vector2 = Vector2.ZERO) -> Button:
    var b := Button.new()
    b.text = StringsEs.tx(text)
    b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
    b.custom_minimum_size = pv(min_size)
    b.pressed.connect(callback)
    b.mouse_entered.connect(func(): UIKit.sound("hover"))
    b.pressed.connect(func(): UIKit.sound("click"))
    react(b)
    return b


## A small square button with a 16 px icon (and a tooltip: icons never go unexplained).
static func icon_button(icon_path: String, tip: String, callback: Callable, size_px: int = 22) -> Button:
    var b := Button.new()
    b.icon = _tex(icon_path)
    b.tooltip_text = tip
    b.custom_minimum_size = Vector2(size_px, size_px)
    b.expand_icon = false
    b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    b.pressed.connect(callback)
    b.mouse_entered.connect(func(): UIKit.sound("hover"))
    b.pressed.connect(func(): UIKit.sound("click"))
    react(b)
    return b


static func icon(path: String, tip: String = "") -> TextureRect:
    var r := TextureRect.new()
    r.texture = _tex(path)
    r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    r.tooltip_text = tip
    r.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
    return r


## A labelled bar (HP, mana, XP, stamina): kit frame + kit fill, value text optional.
static func bar(kind: String, value: float, max_value: float, width: int = 60, show_value: bool = false) -> Control:
    var p := ProgressBar.new()
    p.min_value = 0.0
    p.max_value = maxf(1.0, max_value)
    p.value = value
    p.show_percentage = false
    p.custom_minimum_size = Vector2(width, 6)
    var fill := ArtPalette.HP
    match kind:
        "mana":
            fill = ArtPalette.MANA
        "xp":
            fill = ArtPalette.XP
        "stamina":
            fill = ArtPalette.STAMINA
    p.add_theme_stylebox_override("fill", box(fill, Color(0, 0, 0, 0), 0, 0, 0))
    if not show_value:
        return p
    var hb := HBoxContainer.new()
    hb.add_child(p)
    hb.add_child(label("%d/%d" % [roundi(value), roundi(max_value)], 12, MUTED))
    return hb


static func fill(c: Control) -> void:
    c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Margin container; px in design units.
static func margin(design_px: int) -> MarginContainer:
    var m := MarginContainer.new()
    var v := px(design_px)
    m.add_theme_constant_override("margin_left", v)
    m.add_theme_constant_override("margin_right", v)
    m.add_theme_constant_override("margin_top", v)
    m.add_theme_constant_override("margin_bottom", v)
    return m


## A short message that slides in at the top and fades (orders refused, saves, unlocks).
static func toast(parent: Control, text: String, color: Color = TEXT) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var pc := PanelContainer.new()
    pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var l := label(text, 14, color)
    pc.add_child(l)
    parent.add_child(pc)
    pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    pc.position.y = 22
    pc.z_index = 100
    var t := pc.create_tween()
    t.tween_interval(1.6)
    t.tween_property(pc, "modulate:a", 0.0, 0.4)
    t.tween_callback(pc.queue_free)


# --- D-116 (pista C): UI that reacts and eases --------------------------------------------------------

const EASE_TIME := 0.12
const HOVER_SCALE := 1.05
const PRESS_SCALE := 0.94
const FADE_TIME := 0.18


## Buttons grow a little under the mouse and punch when pressed (scale around their centre; the layout
## never moves).
static func react(b: Control) -> void:
    b.resized.connect(func(): b.pivot_offset = (b.size * 0.5).round())
    b.mouse_entered.connect(func(): UIKit._ease_scale(b, HOVER_SCALE))
    b.mouse_exited.connect(func(): UIKit._ease_scale(b, 1.0))
    if b is BaseButton:
        (b as BaseButton).button_down.connect(func(): UIKit._ease_scale(b, PRESS_SCALE, 0.05))
        (b as BaseButton).button_up.connect(func(): UIKit._ease_scale(b, 1.0))


static func _ease_scale(c: Control, to: float, t: float = EASE_TIME) -> void:
    if not is_instance_valid(c) or not c.is_inside_tree():
        return
    if c.has_meta("ui_tween"):
        var old: Tween = c.get_meta("ui_tween")
        if old != null and old.is_valid():
            old.kill()
    var tw := c.create_tween()
    c.set_meta("ui_tween", tw)
    tw.tween_property(c, "scale", Vector2.ONE * to, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A panel that pops in (fade + slight grow, eased).
static func pop_in(c: Control) -> void:
    c.modulate.a = 0.0
    c.scale = Vector2.ONE * 0.92
    c.resized.connect(func(): c.pivot_offset = (c.size * 0.5).round())
    var tw := c.create_tween().set_parallel()
    tw.tween_property(c, "modulate:a", 1.0, FADE_TIME)
    tw.tween_property(c, "scale", Vector2.ONE, FADE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A curtain that fades out over a new screen (scene fade). Frees itself.
static func fade_in(parent: Control, time: float = FADE_TIME) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var r := ColorRect.new()
    r.color = Color(ArtPalette.INK, 1.0)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(r)
    fill(r)
    r.z_index = 200
    var tw := r.create_tween()
    tw.tween_property(r, "modulate:a", 0.0, time)
    tw.tween_callback(r.queue_free)


## A plain loading curtain with a short label (heavy screens: entering a floor, the town).
static func loading_curtain(parent: Control) -> Control:
    var r := ColorRect.new()
    r.color = Color(ArtPalette.INK, 1.0)
    r.mouse_filter = Control.MOUSE_FILTER_STOP
    parent.add_child(r)
    fill(r)
    r.z_index = 200
    var l := label("Loading...", 20, MUTED)
    r.add_child(l)
    l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    return r
