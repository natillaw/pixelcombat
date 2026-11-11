class_name TitleScreen
extends Control
## Title screen (D-063, redone 2026-11-02, owner: "horripilante ventana de inicio"). A night valley under
## an aurora (parallax), the Tower in the middle with its portal open at the base, your own heroes resting
## by a campfire, fireflies. One save only (owner 2026-11-02: "solo tienes 1 partida, no se puede
## reiniciar"): Continue, or Begin when there is no save yet. A finished hardcore game may start over.
## D-080: Begin -> character creator -> welcome; Continue on a save without a Master -> creator once.

signal navigate(screen: String, arg: int)

const BG_DIR := "res://assets/pixel/packs/bg_nature/nature_6/"
const BG_LAYERS := [["1.png", 2.0], ["2.png", 5.0], ["3.png", 9.0]]   # file, drift px/s (far -> near)
const TOWER_X := 440.0
const GROUND_Y := 318.0

var _menu: GameMenu = null
var _layers: Array = []          # [TextureRect a, TextureRect b, speed]
var _t: float = 0.0


func _ready() -> void:
    UIKit.music("title")
    clip_contents = true
    var bg := ColorRect.new()
    bg.color = Color(0.04, 0.06, 0.12)
    add_child(bg)
    UIKit.fill(bg)
    _build_sky()
    var tower := TitleTower.new()
    tower.position = Vector2(TOWER_X, GROUND_Y)
    add_child(tower)
    _build_ground()
    _build_camp()
    _build_fireflies()
    _build_logo()
    _build_menu()
    _build_footer()


func _process(delta: float) -> void:
    _t += delta
    for l in _layers:
        var w: float = (l[0] as TextureRect).size.x
        var off := fmod(_t * float(l[2]), w)
        (l[0] as TextureRect).position.x = -off
        (l[1] as TextureRect).position.x = w - off


func _build_sky() -> void:
    for spec in BG_LAYERS:
        var path := BG_DIR + String(spec[0])
        if not ResourceLoader.exists(path):
            continue
        var tex: Texture2D = load(path)
        var pair: Array = []
        for k in 2:
            var r := TextureRect.new()
            r.texture = tex
            r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            r.stretch_mode = TextureRect.STRETCH_SCALE
            r.size = Vector2(640, 360)
            r.mouse_filter = Control.MOUSE_FILTER_IGNORE
            add_child(r)
            pair.append(r)
        pair.append(float(spec[1]))
        _layers.append(pair)


## A dark hill line in front of the mountains, then the grass where the heroes stand.
func _build_ground() -> void:
    var hill := Polygon2D.new()
    var pts := PackedVector2Array()
    for i in 33:
        var x := float(i) * 20.0
        pts.append(Vector2(x, GROUND_Y - 14.0 - 8.0 * sin(x * 0.021) - 5.0 * sin(x * 0.057 + 1.3)))
    pts.append(Vector2(640, 360))
    pts.append(Vector2(0, 360))
    hill.polygon = pts
    hill.color = Color(0.05, 0.09, 0.1)
    add_child(hill)
    var grass := ColorRect.new()
    grass.color = Color(0.07, 0.13, 0.1)
    grass.position = Vector2(0, GROUND_Y)
    grass.size = Vector2(640, 360 - GROUND_Y)
    grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(grass)


## Your own party (or a few strangers on a new account) resting around a campfire at the Tower's foot.
func _build_camp() -> void:
    var fire_x := TOWER_X - 70.0
    var fire := _campfire()
    if fire != null:
        fire.position = Vector2(fire_x, GROUND_Y + 14)
        add_child(fire)
    var glow := TitleGlow.new()
    glow.position = Vector2(fire_x, GROUND_Y + 8)
    add_child(glow)
    var crew: Array = Game.party_heroes() if not Game.heroes.is_empty() else []
    if crew.is_empty():
        for i in 4:
            crew.append(HeroGenerator.generate(9100 + i * 37, 1 + (i % 3)))
    var spots := [Vector2(-58, 6), Vector2(50, 4), Vector2(-34, 24), Vector2(28, 26), Vector2(84, 16)]
    for i in mini(crew.size(), spots.size()):
        var s := AnimatedSprite2D.new()
        s.sprite_frames = SpriteComposer.build_frames(crew[i])
        s.position = Vector2(fire_x, GROUND_Y + 4) + spots[i]
        var spot: Vector2 = spots[i]
        var anim := "idle_right" if spot.x < 0 else "idle_left"
        if not s.sprite_frames.has_animation(anim):
            anim = "idle_down"
        s.play(anim)
        s.frame = i
        s.modulate = Color(1.0, 0.86, 0.72)                  # lit by the fire
        add_child(s)


func _campfire() -> AnimatedSprite2D:
    if not ResourceLoader.exists(BosqueArt.FIRE):
        return null
    var tex := load(BosqueArt.FIRE) as Texture2D
    var sf := SpriteFrames.new()
    sf.set_animation_speed("default", 8.0)
    for i in 4:
        var at := AtlasTexture.new()
        at.atlas = tex
        at.region = Rect2(i * 16, 0, 16, 18)
        sf.add_frame("default", at)
    var s := AnimatedSprite2D.new()
    s.sprite_frames = sf
    s.offset = Vector2(0, -9)
    s.scale = Vector2(2, 2)
    s.play("default")
    return s


func _build_fireflies() -> void:
    var p := CPUParticles2D.new()
    p.amount = 26
    p.lifetime = 5.0
    p.preprocess = 5.0
    p.position = Vector2(400, 290)
    p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    p.emission_rect_extents = Vector2(260, 40)
    p.gravity = Vector2(0, -3)
    p.initial_velocity_min = 2.0
    p.initial_velocity_max = 8.0
    p.spread = 180.0
    p.color = Color(0.85, 1.0, 0.55)
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1, 1, 1, 0))
    ramp.add_point(0.3, Color(1, 1, 1, 1))
    ramp.add_point(0.6, Color(1, 1, 1, 0.2))
    ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
    p.color_ramp = ramp
    add_child(p)


func _build_logo() -> void:
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", -6)
    v.position = Vector2(24, 26)
    add_child(v)
    var top := UIKit.label("TACTICAL", 32, Color(0.75, 0.85, 1.0))
    top.add_theme_constant_override("outline_size", 4)
    top.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.16))
    v.add_child(top)
    var big := UIKit.label("SUMMONERS", 32, ArtPalette.GOLD[3])
    big.add_theme_font_size_override("font_size", 48)
    big.add_theme_constant_override("outline_size", 6)
    big.add_theme_color_override("font_outline_color", Color(0.18, 0.06, 0.02))
    big.add_theme_constant_override("shadow_offset_x", 0)
    big.add_theme_constant_override("shadow_offset_y", 3)
    big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
    v.add_child(big)
    var sub := UIKit.label("A tower, a village and the people you call.", 14, Color(0.8, 0.82, 0.95))
    sub.add_theme_constant_override("outline_size", 2)
    sub.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.1))
    v.add_child(sub)


func _build_menu() -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.03, 0.09, 0.72), Color(ArtPalette.GOLD[2], 0.6), 1, 0, 6))
    panel.position = Vector2(24, 132)
    panel.custom_minimum_size = Vector2(170, 0)
    add_child(panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 2)
    panel.add_child(v)
    var has_save := (not Game.heroes.is_empty() or Game.onboarded) and not Game.game_over
    if has_save:
        var info := UIKit.label("%s · %s %d · %d %s" % [tr("Your story continues"), tr("Day"), Game.town_clock / 24 + 1,
            Game.heroes.size(), tr("heroes")], 12, Color(0.75, 0.8, 0.95))
        v.add_child(info)
        var row := HBoxContainer.new()
        var cont := _menu_button("Continue", func(): navigate.emit("master" if Game.needs_master() else "town", 0), true)
        cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(cont)
        if Game.hardcore:                        # D-081: a hardcore game shows its skull
            row.add_child(UIKit.icon(MasterDefs.HARDCORE_ICON, "Hardcore: if your Master dies, the game ends"))
        v.add_child(row)
    elif Game.game_over:
        v.add_child(UIKit.label("Your hardcore game is over.", 14, UIKit.BAD))
        v.add_child(_menu_button("Start over", _begin, true))
    else:
        v.add_child(_menu_button("Begin", _begin, true))
    v.add_child(_menu_button("Options", func(): _open_menu("options")))
    v.add_child(_menu_button("Credits", func(): _open_menu("credits")))
    v.add_child(_menu_button("Quit", func(): get_tree().quit()))


## Title menu entry: plain text that lights up (gold, a marker and a dark band) on hover.
func _menu_button(text: String, cb: Callable, main: bool = false) -> Button:
    var b := UIKit.button(text, cb, Vector2(0, 0))
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.custom_minimum_size = Vector2(0, 22)
    var normal := UIKit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4)
    normal.content_margin_left = 12
    var hover := UIKit.box(Color(ArtPalette.GOLD[1], 0.25), Color(0, 0, 0, 0), 0, 0, 4)
    hover.border_color = ArtPalette.GOLD[3]
    hover.border_width_left = 3
    hover.content_margin_left = 12
    for st in ["normal", "focus", "disabled"]:
        b.add_theme_stylebox_override(st, normal)
    for st in ["hover", "pressed", "hover_pressed"]:
        b.add_theme_stylebox_override(st, hover)
    b.add_theme_color_override("font_color", ArtPalette.GOLD[3] if main else Color(0.88, 0.88, 0.96))
    b.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.8))
    if main:
        b.add_theme_font_override("font", UIKit.title_font())
    return b


func _build_footer() -> void:
    var l := UIKit.label("One life, one story: there is no second save.", 12, Color(0.7, 0.72, 0.85, 0.8))
    l.position = Vector2(24, 338)
    add_child(l)
    var r := UIKit.label("F11: full screen", 12, Color(0.7, 0.72, 0.85, 0.8))
    r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    r.position = Vector2(416, 338)
    r.size = Vector2(200, 14)
    add_child(r)


func _open_menu(page: String) -> void:
    _menu = GameMenu.new()
    _menu.leave_label = "Back"
    add_child(_menu)
    if page == "options":
        _menu.show_options()
    else:
        _menu.show_credits()


## The only way into a new account: no save yet, or a hardcore game that ended (D-081).
func _begin() -> void:
    Game.new_game()
    navigate.emit("master", 0)
