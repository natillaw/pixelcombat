class_name GatherNode
extends Node2D
## A gathering spot in a tower floor (EconomyDefs.NODES): ore vein, fallen timber or herb patch. A hero
## that stands next to it out of combat works it; what it yields goes to the expedition ledger (kept on
## success or escape). Drawn with simple shapes; hidden in unexplored fog.
## D-117 (pista C): the spot has 3-6 charges (GatherDefs); each ~5 s work cycle gives one charge (its
## share of `amounts`) with a looping work animation; an empty spot fades away. Two heroes on one spot
## use pista A's "two on one ore" synergy when SynergyDefs exists.

const RANGE := 38.0

var kind: String = "herb"
var amounts: Dictionary = {}        # resource -> amount, rolled when the floor is entered
var progress: float = 0.0
var taken: bool = false             # empty: nothing left (kept name: bots and tests read it)
var charges: int = 3
var charges_max: int = 3
var broken: bool = false            # the synergy broke it
var _left: Dictionary = {}          # what is still in it
var _rng := RandomNumberGenerator.new()
var _swing: float = 0.0
var _work: float = 0.0              # 0..1 pulse of the last work hit (look)
var _fade: float = -1.0


func _init(p_kind: String = "herb", p_amounts: Dictionary = {}, p_charges: int = 0) -> void:
    kind = p_kind
    amounts = p_amounts
    _left = p_amounts.duplicate()
    charges_max = p_charges if p_charges > 0 else GatherDefs.CHARGES[0]
    charges = charges_max
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Charges from the spot's position (same spot, same charges), 3-6.
func roll_charges() -> void:
    _rng.seed = hash(Vector2i(position.round()))
    charges_max = _rng.randi_range(int(GatherDefs.CHARGES[0]), int(GatherDefs.CHARGES[1]))
    charges = charges_max


## What one charge gives now: its share of what is left (the last charge takes the rest).
func charge_yield() -> Dictionary:
    var out := {}
    for res in _left:
        var n := int(_left[res])
        var give := n if charges <= 1 else int(ceil(float(n) / float(charges)))
        if give > 0:
            out[res] = give
    return out


## Synergy numbers when pista A's SynergyDefs knows "Two on a Vein" (GatherDefs.SYNERGY_ID), else {} (no effect).
static func synergy() -> Dictionary:
    for c in ProjectSettings.get_global_class_list():
        if String(c["class"]) == "SynergyDefs":
            var scr: Script = load(String(c["path"]))
            var consts: Dictionary = scr.get_script_constant_map() if scr != null else {}
            for k in consts:
                var v = consts[k]
                if v is Dictionary and (v as Dictionary).has(GatherDefs.SYNERGY_ID):
                    var d = v[GatherDefs.SYNERGY_ID]
                    var out: Dictionary = GatherDefs.SYNERGY_FALLBACK.duplicate()
                    if d is Dictionary:
                        if (d as Dictionary).has("mult"):           # SynergyDefs names the speed-up "mult"
                            out["speed"] = float(d["mult"])
                        for f in ["speed", "break_chance"]:
                            if (d as Dictionary).has(f):
                                out[f] = float(d[f])
                    return out
    return {}


## One work step with these heroes on the spot. Returns what this step yields ({} most of the time).
## Empty `who` resets the current cycle. Deterministic (own seeded rng).
func work(delta: float, who: Array) -> Dictionary:
    if taken:
        return {}
    if who.is_empty():
        if progress > 0.0:
            progress = 0.0
            queue_redraw()
        return {}
    var speed := 1.0
    var syn := synergy() if who.size() >= 2 else {}
    if not syn.is_empty():
        speed = float(syn["speed"])
    progress += delta * speed
    _swing += delta * speed
    if _swing >= GatherDefs.SWING:
        _swing = 0.0
        _work = 1.0
        _chips()
    queue_redraw()
    if progress < GatherDefs.CYCLE:
        return {}
    progress = 0.0
    var got := charge_yield()
    for res in got:
        _left[res] = int(_left[res]) - int(got[res])
    charges -= 1
    if not syn.is_empty() and charges > 0 and _rng.randf() < float(syn["break_chance"]):
        broken = true
        charges = 0
    if charges <= 0:
        taken = true
        _fade = 0.0
    return got


func _process(delta: float) -> void:
    if _work > 0.0:
        _work = maxf(0.0, _work - delta * 6.0)
        queue_redraw()
    if _fade >= 0.0:
        _fade += delta
        modulate.a = clampf(1.0 - _fade / GatherDefs.FADE, 0.0, 1.0)
        scale = Vector2.ONE * (1.0 + 0.15 * _fade / GatherDefs.FADE)
        if _fade >= GatherDefs.FADE:
            queue_free()


## Chips, splinters or leaves at each work hit.
func _chips() -> void:
    if SimMode.on or not is_inside_tree():
        return
    var col: Color = GatherDefs.WORK.get(kind, GatherDefs.WORK["herb"])["chip"]
    var p := JuiceProfile.from_dict("gather", {"particles": col, "amount": 4, "spread": 70.0, "speed": 55.0, "rise": kind == "herb"})
    JuicePlayer.burst(get_parent(), position + Vector2(0, -10), Vector2.UP, p)


func verb() -> String:
    return String(GatherDefs.WORK.get(kind, GatherDefs.WORK["herb"])["verb"])


func label() -> String:
    return String(EconomyDefs.NODES.get(kind, {}).get("name", kind))


## Owner 2026-11-01: the packs' ores and herbs. Ore veins are the crystal pack's crystals, herbs are
## mushrooms, chanterelles and flowering bushes, stone the rock pack, timber the owner's fallen logs.
## One variant per spot (from its position), drawn x1 with its own shadow, feet on the node.
const ART := {
    "ore": ["res://assets/pixel/packs/crystals/PNG/Assets_shadow/", "^(Blue|Green|Violet|Red|White|Yellow)_crystal[0-9]"],
    "herb": ["res://assets/pixel/packs/forest_objects/PNG/Assets/", "^(Chanterelles|White-red_mushroom|Beige_green_mushroom)[0-9]"],
    "herb_bush": ["res://assets/pixel/packs/bushes/PNG/Assets_shadow/", "^Bush_(blue|orange|pink|red)_flowers[0-9]"],
    "stone": ["res://assets/pixel/packs/rocks2/PNG/Objects_separately/", "^Rock[0-9]+_[0-9]+[.]png$"],
}
static var _tex_cache := {}


static func _textures(key: String) -> Array:
    if _tex_cache.has(key):
        return _tex_cache[key]
    var out: Array = []
    if ART.has(key):
        for img in BosqueArt.pack_images(ART[key]):
            var used := (img as Image).get_used_rect()
            out.append(ImageTexture.create_from_image((img as Image).get_region(used)))
    elif key == "wood" and BosqueArt.available():
        var d: Dictionary = BosqueArt.defs()["props"]
        var props := BosqueArt._img(BosqueArt.PROPS)
        for n in ["tronco_caido", "tocon"]:
            if d.has(n):
                var rc: Array = d[n]["rect"]
                out.append(ImageTexture.create_from_image(props.get_region(Rect2i(int(rc[0]), int(rc[1]), int(rc[2]), int(rc[3])))))
    _tex_cache[key] = out
    return out


func _art() -> Texture2D:
    var key := kind
    if kind == "herb" and int(absf(position.x + position.y)) % 3 == 0:
        key = "herb_bush"
    var pool := _textures(key)
    if pool.is_empty():
        return null
    return pool[int(absf(position.x * 7.0 + position.y * 13.0)) % pool.size()]


func _draw() -> void:
    var col: Color = EconomyDefs.NODES.get(kind, {}).get("color", Color.WHITE)
    var art := _art()
    var jolt := Vector2(roundf(_work * 1.0), 0)               # the spot jolts at each work hit
    if art != null:
        draw_texture(art, (Vector2(-art.get_width() * 0.5, -art.get_height() + 4.0) + jolt).floor())
        _draw_charges(Vector2(0, -art.get_height() - 2.0), col)
        if progress > 0.0:
            var kk := clampf(progress / GatherDefs.CYCLE, 0.0, 1.0)
            draw_arc(Vector2(0, -art.get_height() * 0.5), 20.0, -PI / 2.0, -PI / 2.0 + TAU * kk, 28, col, 3.0)
        return
    draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
    draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.3))
    draw_set_transform(jolt, 0.0, Vector2.ONE)
    match kind:
        "ore":
            draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(-9, -14), Vector2(2, -19), Vector2(12, -10), Vector2(13, 0)]), Color(0.38, 0.38, 0.42))
            draw_polyline(PackedVector2Array([Vector2(-13, 0), Vector2(-9, -14), Vector2(2, -19), Vector2(12, -10), Vector2(13, 0)]), Color(0.1, 0.07, 0.15), 1.5)
            for p in [Vector2(-5, -9), Vector2(4, -12), Vector2(6, -4)]:
                draw_circle(p, 2.2, col)
        "wood":
            for i in 3:
                var y := -4.0 - 6.0 * float(i)
                draw_rect(Rect2(-14 + i * 3, y - 5, 26 - i * 6, 6), Color(0.48, 0.32, 0.18))
                draw_rect(Rect2(-14 + i * 3, y - 5, 26 - i * 6, 6), Color(0.15, 0.08, 0.05), false, 1.0)
                draw_circle(Vector2(12 - i * 3, y - 2), 2.5, Color(0.75, 0.6, 0.4))
        _:
            draw_circle(Vector2(0, -8), 10.0, Color(0.22, 0.5, 0.2))
            draw_circle(Vector2(-6, -12), 6.0, Color(0.28, 0.6, 0.24))
            draw_circle(Vector2(6, -11), 6.0, Color(0.25, 0.55, 0.22))
            for p in [Vector2(-5, -14), Vector2(3, -16), Vector2(6, -8)]:
                draw_circle(p, 2.0, Color(0.95, 0.85, 0.4))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    _draw_charges(Vector2(0, -24), col)
    if progress > 0.0:
        var k := clampf(progress / GatherDefs.CYCLE, 0.0, 1.0)
        draw_arc(Vector2(0, -10), 18.0, -PI / 2.0, -PI / 2.0 + TAU * k, 28, col, 3.0)


## Charges left as small pips over the spot (2x2 px, full = colour, spent = dark).
func _draw_charges(at: Vector2, col: Color) -> void:
    var w := charges_max * 3 - 1
    var x0 := roundf(at.x - w * 0.5)
    for i in charges_max:
        draw_rect(Rect2(Vector2(x0 + i * 3, roundf(at.y)), Vector2(2, 2)), col if i < charges else Color(0, 0, 0, 0.45))
