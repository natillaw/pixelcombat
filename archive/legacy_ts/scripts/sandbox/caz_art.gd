class_name CazArt
extends RefCounted
## Art from "Tiny Pixel Fantasy - Base Pack" by Caz (same artist as the hero sprites; D-023, D-024).
## Installed at assets/pixel/caz-base/. Everything returns null when the pack is missing, so callers
## fall back to ProcArt. Images are 1 px = 1 tile px (tiles are 16 px; one map cell = 48 px).

const ROOT := AssetCatalog.CAZ_TILES
const CHAR_ROOT := AssetCatalog.CAZ_CHARACTERS

const GRASS := ["Outside/Outside_1_1", "Outside/Outside_1_1", "Outside/Outside_1_2", "Outside/Outside_1_3", "Outside/Outside_1_4"]
const DIRT := ["Outside/Outside_3_1", "Outside/Outside_3_2", "Outside/Outside_3_3"]
const COBBLE := ["CityExterior/CityExterior_1_1", "CityExterior/CityExterior_1_1", "CityExterior/CityExterior_1_1", "CityExterior/CityExterior_1_1", "CityExterior/CityExterior_1_1", "CityExterior/CityExterior_2_1"]
const PLAZA := ["Outside/Outside_8_1", "Outside/Outside_8_2", "Outside/Outside_8_3", "Outside/Outside_8_4", "Outside/Outside_8_5"]
const WATER := "Outside/Outside_5_1"
const BIG_TREES := ["Outside/Outside_16_5", "Outside/Outside_16_6", "Outside/Outside_16_3", "Outside/Outside_16_4"]
const SMALL_TREES := ["Outside/Outside_16_1", "Outside/Outside_16_2", "Outside/Outside_15_1", "Outside/Outside_15_2"]
const DEAD_TREES := ["Outside/Outside_18_3", "Outside/Outside_18_4", "Outside/Outside_17_1"]
const STUMPS := ["Outside/Outside_19_1", "Outside/Outside_19_2", "Outside/Outside_20_1"]
const BUSHES := ["OutsideFeatures/OutsideFeatures_1_1", "OutsideFeatures/OutsideFeatures_2_1", "Outside/Outside_14_1", "Outside/Outside_14_2"]
const ROCKS := ["OutsideFeatures/OutsideFeatures_3_1", "OutsideFeatures/OutsideFeatures_7_1"]
const FLOWER := "OutsideFeatures/OutsideFeatures_12_1"
const LOG := "OutsideFeatures/OutsideFeatures_4_1"

## Facade pieces (48 x 32), roofs (48 x 48), doors (16 x 32), windows (16 x 16).
const WALLS := {"plaster": "RuralTownExterior/RuralTownExterior_1_1", "stone": "CityExterior/CityExterior_11_1",
    "timber": "CityExterior/CityExterior_15_1"}
const ROOFS := {"thatch": "RuralTownExterior/RuralTownExterior_5_1", "tile": "CityExterior/CityExterior_17_1"}
const DOOR := "RuralTownExterior/RuralTownExterior_2_1"
const DOOR_IRON := "CityExterior/CityExterior_12_1"
const WINDOW_LIT := "RuralTownExterior/RuralTownExterior_4_2"
const WINDOW_STONE := "CityExterior/CityExterior_16_2"
const ARCH := "CityExterior/CityExterior_7_1"

static var _img_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func available() -> bool:
    return ResourceLoader.exists(ROOT + GRASS[0] + ".png")


static func image(name: String) -> Image:
    if _img_cache.has(name):
        return _img_cache[name]
    var img: Image = null
    var path := (CHAR_ROOT if name.begins_with("TPF_") else ROOT) + name + ".png"
    if ResourceLoader.exists(path):
        var tex := load(path) as Texture2D
        if tex != null:
            img = tex.get_image()
            img.convert(Image.FORMAT_RGBA8)
    _img_cache[name] = img
    return img


static func texture(name: String) -> Texture2D:
    if _tex_cache.has(name):
        return _tex_cache[name]
    var t: Texture2D = null
    var path := ROOT + name + ".png"
    if ResourceLoader.exists(path):
        t = load(path) as Texture2D
    _tex_cache[name] = t
    return t


static func pick(list: Array, r: RandomNumberGenerator) -> Image:
    return image(String(list[r.randi() % list.size()]))


## Blits an image so its bottom-centre lands on `feet` (trees, props).
static func blit_feet(dst: Image, src: Image, feet: Vector2i) -> void:
    if src == null:
        return
    dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), feet - Vector2i(src.get_width() / 2, src.get_height()))


## Fills a cell-aligned area with 16 px tiles picked from `list`.
static func fill_tiles(dst: Image, area: Rect2i, list: Array, r: RandomNumberGenerator) -> void:
    for y in range(area.position.y, area.end.y, 16):
        for x in range(area.position.x, area.end.x, 16):
            var t := pick(list, r)
            if t != null:
                dst.blend_rect(t, Rect2i(0, 0, 16, 16), Vector2i(x, y))


## A house for a w x h px footprint: roof rows (first row keeps the ridge, the rest repeat the
## roof body) above a facade of wall pieces, with a door in the middle and lit windows.
static func house(w: int, h: int, roof: String, wall: String, tint: Color) -> Image:
    var key := "house_%d_%d_%s_%s_%s" % [w, h, roof, wall, tint.to_html()]
    if _img_cache.has(key):
        return _img_cache[key]
    var roof_img := image(String(ROOFS.get(roof, ROOFS["thatch"])))
    var wall_img := image(String(WALLS.get(wall, WALLS["plaster"])))
    var door := image(DOOR_IRON if wall == "stone" else DOOR)
    var win := image(WINDOW_STONE if wall == "stone" else WINDOW_LIT)
    if roof_img == null or wall_img == null:
        return null
    var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
    var facade_y := h - 32
    var ridge := 16 if roof == "thatch" else 10
    for x in range(0, w, 48):
        var y := 0
        var first := true
        while y < facade_y:
            if first:
                out.blend_rect(roof_img, Rect2i(0, 0, 48, mini(48, facade_y - y)), Vector2i(x, y))
                y += 48
                first = false
            else:
                var body := 48 - ridge
                out.blend_rect(roof_img, Rect2i(0, ridge, 48, mini(body, facade_y - y)), Vector2i(x, y))
                y += body
        out.blend_rect(wall_img, Rect2i(0, 0, 48, 32), Vector2i(x, facade_y))
    if tint != Color.WHITE:
        for y in facade_y:
            for x in w:
                var c := out.get_pixel(x, y)
                if c.a > 0.0:
                    out.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
    out.fill_rect(Rect2i(0, facade_y, w, 2), Color(0, 0, 0, 0.35))          # eave shadow
    if door != null:
        out.blend_rect(door, Rect2i(0, 0, 16, 32), Vector2i(w / 2 - 8, h - 32))
    if win != null:
        for x in range(12, w - 20, 32):
            if absi(x + 8 - w / 2) < 20:
                continue
            out.blend_rect(win, Rect2i(0, 0, 16, 16), Vector2i(x, facade_y + 8))
    _img_cache[key] = out
    return out


## Villager sheets (same 576 x 384 format as the heroes): SpriteFrames for walking NPCs.
static func villager_frames(index: int) -> SpriteFrames:
    var names := ["TPF_Character_1", "TPF_Character_2a", "TPF_Character_2b", "TPF_Character_3",
        "TPF_Character_4a", "TPF_Character_4b", "TPF_Character_5a", "TPF_Character_5b"]
    var key := "villager%d" % index
    if _tex_cache.has(key):
        return _tex_cache[key]
    var path := CHAR_ROOT + String(names[index % names.size()]) + ".png"
    var sf: SpriteFrames = null
    if ResourceLoader.exists(path):
        var sheet := load(path) as Texture2D
        sf = SpriteFrames.new()
        sf.remove_animation("default")
        for anim_name in SpriteComposer.ANIMS:
            var def: Dictionary = SpriteComposer.ANIMS[anim_name]
            sf.add_animation(anim_name)
            sf.set_animation_speed(anim_name, float(def["fps"]))
            sf.set_animation_loop(anim_name, bool(def["loop"]))
            for c in def["cols"]:
                var at := AtlasTexture.new()
                at.atlas = sheet
                at.region = Rect2(int(c) * SpriteComposer.FRAME, int(def["row"]) * SpriteComposer.FRAME, SpriteComposer.FRAME, SpriteComposer.FRAME)
                sf.add_frame(anim_name, at)
    _tex_cache[key] = sf
    return sf
