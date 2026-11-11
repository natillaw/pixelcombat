class_name LootBag
extends Node2D
## D-120/D-121 (pista D): loot left on the floor of a tower floor: a body that carried something, or the
## backpack a fallen hero dropped (D-124). It glows in the colour of its best item (gold when it holds only
## materials) until someone loots it; while the Master holds F next to it a ring fills (LootDefs.LOOT_HOLD).
## Hidden in unexplored fog like the gathering spots. Pure data + drawing: SandboxScreen does the looting.

var items: Array = []                 # item dicts (ItemGen)
var res: Dictionary = {}              # resource id -> amount (materials, keys, books)
var source: String = "body"           # "body" | "pack" (a fallen hero's backpack)
var owner_name: String = ""           # whose pack it was
var hold: float = 0.0                 # 0..1: the Master's F progress
var prompt: bool = false              # the Master is next to it
var visible_to_bot: bool = true       # MasterBot gave up on it (could not reach it)
var _t: float = 0.0


func is_empty() -> bool:
    return items.is_empty() and res.is_empty()


func glow_color() -> Color:
    var best := LootService.best_rarity(items)
    if best == "":
        return Color(0.95, 0.82, 0.4)                # materials only
    return ItemDefs.rarity_color(best)


## The item shown on the floor: the best item's icon (a sack for a backpack or for materials only).
func _show_icon() -> Texture2D:
    if source == "pack" or items.is_empty():
        return ItemIcons.texture("satchel")
    var best: Dictionary = items[0]
    var rank := -2
    for it in items:
        var r := String(it.get("rarity", "common"))
        var i := -1 if r == "junk" else ItemDefs.RARITY_ORDER.find(r)
        if i > rank:
            rank = i
            best = it
    return ItemIcons.texture(String(best.get("base", "")))


## Rarity rank 0..6 (common..mythic); -1 junk or materials. Higher ranks glow more (beam, more sparks).
func _rank() -> int:
    var best := LootService.best_rarity(items)
    return -1 if best == "" or best == "junk" else ItemDefs.RARITY_ORDER.find(best)


var _icon: Texture2D = null
var _icon_for: int = -1
var _drop: float = 0.0                # 0..1: the pop when it lands (owner 2026-11-02: "make it bounce, juice it up")
var _glow_tex: Texture2D = null

const ICON_PX := 18.0                 # the icon on the floor (from the 32 px item icon)
const BOB := 2.5                      # px up and down
const DROP_TIME := 0.45


func _ready() -> void:
    z_index = 1                                      # over the ground art (the units draw on top by order)
    var g := GradientTexture2D.new()                 # soft round aura
    g.fill = GradientTexture2D.FILL_RADIAL
    g.fill_from = Vector2(0.5, 0.5)
    g.fill_to = Vector2(1.0, 0.5)
    g.width = 64
    g.height = 64
    var grad := Gradient.new()
    grad.set_color(0, Color(1, 1, 1, 0.9))
    grad.set_color(1, Color(1, 1, 1, 0.0))
    g.gradient = grad
    _glow_tex = g
    if SimMode.on:
        visible = false
        set_process(false)


func _process(delta: float) -> void:
    _t += delta
    _drop = minf(1.0, _drop + delta / DROP_TIME)
    queue_redraw()


func _draw() -> void:
    if is_empty():
        return
    var key := items.size() * 31 + int(source == "pack")
    if _icon == null or _icon_for != key:
        _icon = _show_icon()
        _icon_for = key
    var c := glow_color()
    var rank := _rank()
    var pulse := 0.5 + 0.5 * sin(_t * 3.2)
    # landing: drops from above with a small bounce, then floats
    var land := 1.0 - _drop
    var hop: float = -absf(sin(_drop * PI * 1.6)) * 14.0 * land
    var lift: float = -6.0 + hop - BOB * (0.5 + 0.5 * sin(_t * 2.6))
    # ground: shadow (shrinks while the icon is up) and the rarity aura on the floor
    var sh := 1.0 - clampf(-lift / 30.0, 0.0, 0.5)
    draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
    draw_texture_rect(_glow_tex, Rect2(Vector2(-22, -22) * (1.0 + 0.12 * pulse), Vector2(44, 44) * (1.0 + 0.12 * pulse)), false, Color(c, 0.55 + 0.2 * pulse))
    draw_circle(Vector2.ZERO, 6.0 * sh, Color(0, 0, 0, 0.35))
    draw_set_transform(Vector2.ZERO)
    if rank >= 2:                                    # rare and up: a beam of light
        var bw := 3.0 + float(rank)
        var bh := 26.0 + 8.0 * float(rank)
        draw_rect(Rect2(-bw / 2.0, lift - bh, bw, bh), Color(c, 0.18 + 0.1 * pulse))
        draw_rect(Rect2(-bw / 4.0, lift - bh, bw / 2.0, bh), Color(1, 1, 1, 0.12 + 0.08 * pulse))
    # halo behind the icon
    var hs := ICON_PX * (1.5 + 0.15 * pulse)
    draw_texture_rect(_glow_tex, Rect2(Vector2(-hs / 2.0, lift - ICON_PX / 2.0 - hs / 2.0), Vector2(hs, hs)), false, Color(c, 0.75))
    # the icon with a 1 px rarity outline
    if _icon != null:
        var r := Rect2(Vector2(-ICON_PX / 2.0, lift - ICON_PX), Vector2(ICON_PX, ICON_PX))
        for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
            draw_texture_rect(_icon, Rect2(r.position + d, r.size), false, Color(c.lightened(0.2), 0.9))
        draw_texture_rect(_icon, r, false)
    # sparkles twinkling around it (more for better items)
    for i in 2 + maxi(rank, 0):
        var a: float = float(i) * 2.399 + floor(_t * 1.3 + float(i) * 0.37) * 1.7
        var ph := fmod(_t * 1.3 + float(i) * 0.37, 1.0)
        var p := Vector2(cos(a) * 11.0, lift - ICON_PX / 2.0 + sin(a) * 9.0 - ph * 6.0)
        var al := sin(ph * PI)
        var sz := 1.0 + float(i % 2)
        draw_rect(Rect2(p - Vector2(sz, 0.5), Vector2(sz * 2.0 + 1.0, 1)), Color(1, 1, 1, al))
        draw_rect(Rect2(p - Vector2(0.5, sz), Vector2(1, sz * 2.0 + 1.0)), Color(c.lightened(0.4), al))
    if hold > 0.0:
        draw_arc(Vector2(0, lift - ICON_PX / 2.0), 15.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(hold, 0.0, 1.0), 24, Color(1, 1, 1, 0.9), 2.0)
    if prompt:
        var f := ThemeDB.fallback_font
        var txt := tr("Hold F: loot")
        var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
        draw_rect(Rect2(-tw / 2.0 - 3, lift - ICON_PX - 19, tw + 6, 11), Color(0, 0, 0, 0.6))
        draw_string(f, Vector2(-tw / 2.0, lift - ICON_PX - 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.95))
