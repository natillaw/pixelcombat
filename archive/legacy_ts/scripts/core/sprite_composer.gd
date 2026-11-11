class_name SpriteComposer
extends RefCounted
## Builds a hero's picture by stacking the Tiny Pixel Fantasy PNG layers.
## Every layer is a 576x384 sheet = 12 columns x 8 rows of 48x48 frames, all aligned,
## so layers can simply be alpha-blended on top of each other.

const ROOT := AssetCatalog.HERO_LAYERS
const FRAME := 48
const COLS := 12
const ROWS := 8
const SHEET_W := 576
const SHEET_H := 384

## Bottom to top. Keys match HeroData.appearance.
## Master prompt H: "accessory" (belt with dagger and pouch) after the top and "mask" (scarf, eye patch)
## after the facial hair. The other layers keep their old order so existing heroes look the same.
const LAYER_ORDER := ["rear_hair", "body", "bottom", "shoes", "top", "accessory", "eyes", "facial_hair", "mask", "front_hair", "hat", "held"]

## Named animations = row + list of columns inside the sheet.
## NOTE: only "idle" is used in this drop. The others are a first reading of the sheet
## (row 0 = facing front, 1 = facing left, 2 = facing right, 3 = facing back,
## rows 5/6 = slash right/left + knocked down) and get verified with the combat drop.
const ANIMS := {
    "idle": {"row": 0, "cols": [4], "fps": 1.0, "loop": true},
    "ready_right": {"row": 1, "cols": [4], "fps": 1.0, "loop": true},
    "ready_left": {"row": 2, "cols": [4], "fps": 1.0, "loop": true},
    "attack_right": {"row": 5, "cols": [2, 3, 4, 5], "fps": 10.0, "loop": false},
    "attack_left": {"row": 6, "cols": [2, 3, 4, 5], "fps": 10.0, "loop": false},
    "down_right": {"row": 5, "cols": [0, 1], "fps": 4.0, "loop": false},
    "down_left": {"row": 6, "cols": [0, 1], "fps": 4.0, "loop": false},
    # Sandbox movement (first reading of the sheet: rows 0-3 = front/left/right/back,
    # columns 0-3 = 4-frame walk cycle, column 4 = standing/ready pose).
    "walk_down": {"row": 0, "cols": [0, 1, 2, 3], "fps": 8.0, "loop": true},
    "walk_left": {"row": 2, "cols": [0, 1, 2, 3], "fps": 8.0, "loop": true},
    "walk_right": {"row": 1, "cols": [0, 1, 2, 3], "fps": 8.0, "loop": true},
    "walk_up": {"row": 3, "cols": [0, 1, 2, 3], "fps": 8.0, "loop": true},
    "idle_down": {"row": 0, "cols": [4], "fps": 1.0, "loop": true},
    "idle_left": {"row": 2, "cols": [4], "fps": 1.0, "loop": true},
    "idle_right": {"row": 1, "cols": [4], "fps": 1.0, "loop": true},
    "idle_up": {"row": 3, "cols": [4], "fps": 1.0, "loop": true},
}

static var _img_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func _layer_image(rel: String) -> Image:
    if _img_cache.has(rel):
        return _img_cache[rel]
    var path := rel if rel.begins_with("res://") else ROOT + rel + ".png"   # bandit layers: full path
    var img: Image = null
    var tex := load(path) as Texture2D
    if tex != null:
        img = tex.get_image()
        if img != null:
            img.convert(Image.FORMAT_RGBA8)
    else:
        push_warning("Sprite layer not found: " + path)
    _img_cache[rel] = img
    return img


## One 48x48 frame of the finished hero.
static func compose_frame(appearance: Dictionary, col: int, row: int) -> Image:
    var out := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
    var src_rect := Rect2i(col * FRAME, row * FRAME, FRAME, FRAME)
    for key in LAYER_ORDER:
        var rel: String = String(appearance.get(key, ""))
        if rel == "":
            continue
        var img := _layer_image(rel)
        if img == null:
            continue
        out.blend_rect(img, src_rect, Vector2i.ZERO)
    return out


## The whole 576x384 sheet of the finished hero.
static func compose_sheet(appearance: Dictionary) -> Image:
    var out := Image.create(SHEET_W, SHEET_H, false, Image.FORMAT_RGBA8)
    for key in LAYER_ORDER:
        var rel: String = String(appearance.get(key, ""))
        if rel == "":
            continue
        var img := _layer_image(rel)
        if img == null:
            continue
        out.blend_rect(img, Rect2i(0, 0, SHEET_W, SHEET_H), Vector2i.ZERO)
    return out


## Cheap single-pose texture (used by cards and portraits). Cached per hero + animation.
static func pose_texture(hero: HeroData, anim: String = "idle") -> Texture2D:
    if uses_lpc(hero):                                     # overhaul LPC (D-A); equipped items show (D-D)
        return LpcComposer.pose_texture_for(hero.look, hero.hero_class, "idle", ItemVisuals.equipment_layers(hero.equipment))
    var key := hero.id + "/" + anim
    if _tex_cache.has(key):
        return _tex_cache[key]
    var def: Dictionary = ANIMS.get(anim, ANIMS["idle"])
    var cols: Array = def["cols"]
    var img := compose_frame(hero.appearance, int(cols[0]), int(def["row"]))
    var tex := ImageTexture.create_from_image(img)
    _tex_cache[key] = tex
    return tex


## Full animation set for a hero (used by the battle scene in the next drop).
## Overhaul LPC (D-A): heroes with an LPC look are drawn by LpcComposer; TPF stays as a fallback.
static func uses_lpc(hero: HeroData) -> bool:
    return hero != null and not hero.look.is_empty() and LpcComposer.available()


## The face inside a pose_texture() frame (HUD portraits crop it): LPC 64 px or TPF 48 px.
static func face_region(hero: HeroData) -> Rect2:
    return Rect2(20, 17, 24, 24) if uses_lpc(hero) else Rect2(16, 10, 15, 15)


## D-072 revision (owner 2026-10-31): LPC characters are drawn at half size in the world, so the 16 px
## packs look x2 against them (proportions of the interiors). The base canvas is 640x360 stretched x2,
## so 0.5 is still one source pixel per screen pixel at 1280x720. Logic distances do not change.
const LPC_WORLD_SCALE := 0.5


static func world_scale(hero: HeroData) -> float:
    return LPC_WORLD_SCALE if uses_lpc(hero) else 1.0


## Where the feet are, for a centred sprite of this hero (LPC frames are 64 px, TPF 48 px).
static func feet_offset(hero: HeroData) -> Vector2:
    return LpcComposer.FEET_OFFSET if uses_lpc(hero) else Vector2(0, -16)


static func build_frames(hero: HeroData) -> SpriteFrames:
    if uses_lpc(hero):
        return LpcComposer.build_frames_legacy(hero.look, hero.hero_class, ItemVisuals.equipment_layers(hero.equipment))
    var key := hero.id + "/sheet"
    var sheet: ImageTexture
    if _tex_cache.has(key):
        sheet = _tex_cache[key]
    else:
        sheet = ImageTexture.create_from_image(compose_sheet(hero.appearance))
        _tex_cache[key] = sheet
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    for anim_name in ANIMS:
        var def: Dictionary = ANIMS[anim_name]
        sf.add_animation(anim_name)
        sf.set_animation_speed(anim_name, float(def["fps"]))
        sf.set_animation_loop(anim_name, bool(def["loop"]))
        for c in def["cols"]:
            var at := AtlasTexture.new()
            at.atlas = sheet
            at.region = Rect2(int(c) * FRAME, int(def["row"]) * FRAME, FRAME, FRAME)
            sf.add_frame(anim_name, at)
    return sf


static func clear_cache() -> void:
    _tex_cache.clear()
