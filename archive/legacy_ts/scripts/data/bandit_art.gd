class_name BanditArt
extends RefCounted
## Overhaul LPC phase 4 (D-E): the bandit band drawn with LPC (LpcFactions: one outfit per type in the
## faction colour; body, skin, hair and beard vary in LpcFactions.VARIANTS looks). Same interface as
## the TPF version it replaces (EnemySprites: has, build_frames, totem_frames, BARON_ID). The old TPF
## presets were deleted in the beta cleanup (owner-approved; history keeps them).
## Enemy sheets face right: the LPC right-facing row (3) is used; "attack" is the type's attack anim,
## "hurt" the first frames of LPC hurt and "death" the whole hurt row (LPC has no separate death).

const BARON_ID := "jefe_baron_carmesi"
## The Baron's size (owner's gate): 2 = his composed sheet doubled with nearest (integer), 1 = normal
## size with a red aura and FX. Both are drawn in docs/reports/overhaul/baron_opciones.png.
const BARON_SCALE := 2
const FPS := {"idle": 3.0, "run": 12.0, "attack": 12.0, "hurt": 10.0, "death": 8.0}
static var _next := {}             # type -> next look variant (round-robin, deterministic per run)
static var _cache := {}


static func has(id: String) -> bool:
    return LpcFactions.has(id) and LpcComposer.available()


static func appearance(id: String, n: int = 0) -> Dictionary:
    return LpcFactions.look(id, n)


## The n-th look of a bandit type (n < 0: the next one in turn, so a group mixes faces).
static func build_frames(id: String, n: int = -1) -> SpriteFrames:
    if n < 0:
        n = int(_next.get(id, 0))
        _next[id] = (n + 1) % LpcFactions.VARIANTS
    var key := "%s/%d" % [id, n]
    if _cache.has(key):
        return _cache[key]
    var lk := LpcFactions.look(id, n)
    var layers := LpcComposer.layers_from(LpcFactions.layers(id, n), String(lk["body"]))
    var attack := String(LpcFactions.BANDIT[id].get("attack", "slash"))
    var src := {"idle": "idle", "run": "run", "attack": attack, "hurt": "hurt", "death": "hurt"}
    var scale := BARON_SCALE if id == BARON_ID else 1
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    for anim in src:
        var img := LpcComposer.compose_anim(layers, String(src[anim]))
        if img == null:
            img = LpcComposer.compose_anim(layers, "walk")
        if img == null:
            continue
        var row := 3 if img.get_height() >= 4 * LpcComposer.FRAME else 0
        var strip := img.get_region(Rect2i(0, row * LpcComposer.FRAME, img.get_width(), LpcComposer.FRAME))
        if scale != 1:
            strip.resize(strip.get_width() * scale, strip.get_height() * scale, Image.INTERPOLATE_NEAREST)
        var tex := ImageTexture.create_from_image(strip)
        var cell := LpcComposer.FRAME * scale
        var cols := strip.get_width() / cell
        if anim == "hurt":
            cols = mini(cols, 2)
        sf.add_animation(anim)
        sf.set_animation_speed(anim, float(FPS[anim]))
        sf.set_animation_loop(anim, anim == "idle" or anim == "run")
        for c in cols:
            var at := AtlasTexture.new()
            at.atlas = tex
            at.region = Rect2(c * cell, 0, cell, cell)
            sf.add_frame(anim, at)
    _cache[key] = sf
    return sf


## Sabotage totem: the band's banner from the camp props, doubled (one still frame for every animation).
static func totem_frames() -> SpriteFrames:
    var d: Dictionary = BosqueArt.defs()["camp"].get("estandarte", {})
    var img := BosqueArt._img(BosqueArt.CAMP)
    if d.is_empty() or img == null:
        return null
    var rc: Array = d["rect"]
    var part := img.get_region(Rect2i(int(rc[0]), int(rc[1]), int(rc[2]), int(rc[3])))
    part.resize(part.get_width() * 2, part.get_height() * 2, Image.INTERPOLATE_NEAREST)
    var tex := ImageTexture.create_from_image(part)
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    for anim in FPS:
        sf.add_animation(anim)
        sf.add_frame(anim, tex)
    return sf
