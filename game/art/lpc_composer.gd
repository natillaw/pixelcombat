class_name LpcComposer
extends RefCounted
## Overhaul LPC (D-A): composes a character from the imported LPC sheets (assets/pixel/lpc/lpc_index.json,
## written by tools/import_lpc.py). Same public API as SpriteComposer (FRAME, pose_texture, build_frames,
## clear_cache) plus visual_layers(); results cached per (layers hash). Frames are 64 px; rows are
## up, left, down, right; "hurt" has one row (used for every direction). A layer that lacks an
## animation (a dagger has no idle) borrows its walk sheet's first frames, so the weapon stays in hand.

const ROOT := "res://assets/pixel/lpc/"
const FRAME := 64
const DIRS := ["up", "left", "down", "right"]
const FPS := {"idle": 3.0, "combat_idle": 3.0, "walk": 10.0, "run": 12.0, "slash": 12.0, "thrust": 12.0,
    "shoot": 14.0, "spellcast": 10.0, "hurt": 10.0}
const LOOP := ["idle", "combat_idle", "walk", "run"]

static var _index: Dictionary = {}
static var _img_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func index() -> Dictionary:
    if _index.is_empty():
        var d = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "lpc_index.json"))
        _index = d if d is Dictionary else {"pieces": {}, "anims": []}
    return _index


static func available() -> bool:
    return FileAccess.file_exists(ROOT + "lpc_index.json")


static func _img(rel: String) -> Image:
    if _img_cache.has(rel):
        return _img_cache[rel]
    var tex := load(ROOT + rel) as Texture2D
    var img: Image = null
    if tex != null:
        img = tex.get_image()
        if img.is_compressed():
            img.decompress()
        img.convert(Image.FORMAT_RGBA8)
    _img_cache[rel] = img
    return img


## The look's layers (piece, variant, z), sorted bottom to top.
static func visual_layers(look: Dictionary, hero_class: String = "", equipment: Dictionary = {}) -> Array:
    return layers_from(LpcWardrobe.layers_for(look, hero_class, equipment), String(look.get("body", "male")))


## Same, from an explicit [[piece, variant], ...] list (bandits, races).
static func layers_from(pairs: Array, body: String) -> Array:
    var out: Array = []
    for pv in pairs:
        var piece: Dictionary = index()["pieces"].get(String(pv[0]), {})
        for layer in piece.get("layers", []):
            var files: Dictionary = (layer["files"] as Dictionary).get(body, {})
            var by_anim: Dictionary = files.get(String(pv[1]), files.get("default", {}))
            if not by_anim.is_empty():
                out.append({"piece": pv[0], "z": int(layer["z"]), "anims": by_anim})
    out.sort_custom(func(a, b): return int(a["z"]) < int(b["z"]))
    return out


## One animation sheet (all directions) of the composed character.
static func compose_anim(layers: Array, anim: String) -> Image:
    var base: Image = null
    for l in layers:
        if (l["anims"] as Dictionary).has(anim):
            base = _img(String(l["anims"][anim]))
            break
    if base == null:
        return null
    var out := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
    for l in layers:
        var a: Dictionary = l["anims"]
        var rel := String(a.get(anim, a.get("walk", "")))
        if rel == "":
            continue
        var src := _img(rel)
        if src == null:
            continue
        var w := mini(src.get_width(), out.get_width())
        var h := mini(src.get_height(), out.get_height())
        out.blend_rect(src, Rect2i(0, 0, w, h), Vector2i.ZERO)
    return out


static func _key(layers: Array) -> String:
    return str(layers.map(func(l): return str(l["piece"]) + ":" + str((l["anims"] as Dictionary).get("walk", ""))).hash())


## Full animation set: "<anim>_<dir>" for every anim and direction.
static func build_frames_for(look: Dictionary, hero_class: String = "", equipment: Dictionary = {}) -> SpriteFrames:
    var layers := visual_layers(look, hero_class, equipment)
    var key := _key(layers) + "/frames"
    if _tex_cache.has(key):
        return _tex_cache[key]
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    for anim in index().get("anims", []):
        var img := compose_anim(layers, String(anim))
        if img == null:
            continue
        var tex := ImageTexture.create_from_image(img)
        var cols := img.get_width() / FRAME
        var rows := img.get_height() / FRAME
        for d in DIRS.size():
            var name := "%s_%s" % [anim, DIRS[d]]
            sf.add_animation(name)
            sf.set_animation_speed(name, float(FPS.get(anim, 10.0)))
            sf.set_animation_loop(name, LOOP.has(anim))
            var row := d if rows > d else 0
            for c in cols:
                var at := AtlasTexture.new()
                at.atlas = tex
                at.region = Rect2(c * FRAME, row * FRAME, FRAME, FRAME)
                sf.add_frame(name, at)
    _tex_cache[key] = sf
    return sf


## One still frame (cards, portraits): the first frame of anim facing down.
static func pose_texture_for(look: Dictionary, hero_class: String = "", anim: String = "idle", equipment: Dictionary = {}) -> Texture2D:
    var layers := visual_layers(look, hero_class, equipment)
    var key := _key(layers) + "/" + anim
    if _tex_cache.has(key):
        return _tex_cache[key]
    var img := compose_anim(layers, anim)
    if img == null:
        return null
    var row := 2 if img.get_height() >= 3 * FRAME else 0
    var tex := ImageTexture.create_from_image(img.get_region(Rect2i(0, row * FRAME, FRAME, FRAME)))
    _tex_cache[key] = tex
    return tex


## The attack each class plays (overhaul: ItemDefs.BASES[*].attack_anim takes over once items are LPC).
const ATTACK_BY_CLASS := {"class.archer": "shoot", "class.mage": "spellcast", "class.cleric": "spellcast", "class.rogue": "thrust"}


## SpriteComposer-compatible frames for a hero: the LPC set plus the old names the game plays
## (idle, idle_<dir>, walk_<dir>, ready_<side>, attack_<side>, down_<side>).
static func build_frames_legacy(look: Dictionary, hero_class: String, equipment: Dictionary = {}) -> SpriteFrames:
    var sf := build_frames_for(look, hero_class, equipment)
    if sf.has_animation("attack_right"):
        return sf
    var attack := String(ATTACK_BY_CLASS.get(hero_class, "slash"))
    var alias := {"idle": "idle_down"}
    for d in DIRS:
        alias["idle_" + d] = "idle_" + d
        alias["walk_" + d] = "walk_" + d
    for side in DIRS:                                 # all four directions (HeroAnim.dir_anim)
        alias["ready_" + side] = "combat_idle_" + side
        alias["attack_" + side] = attack + "_" + side
        alias["down_" + side] = "hurt_" + side
    for old in alias:
        var src := String(alias[old])
        if old == src or not sf.has_animation(src):
            continue
        sf.add_animation(old)
        sf.set_animation_speed(old, sf.get_animation_speed(src))
        sf.set_animation_loop(old, sf.get_animation_loop(src))
        for i in sf.get_frame_count(src):
            sf.add_frame(old, sf.get_frame_texture(src, i))
    return sf


## Feet offset for a centred 64 px LPC frame (feet near the bottom of the cell).
const FEET_OFFSET := Vector2(0, -26)


static func clear_cache() -> void:
    _tex_cache.clear()
    _img_cache.clear()
