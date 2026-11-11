extends SceneTree
## Visual cohesion of creatures with the heroes (D-055). Heroes (Caz's character generator) are the
## reference and are never touched (D-023). Audit: average colour and brightness of the outer contour
## (opaque pixels touching transparency) of the hero and of every creature sheet used by the game.
## --write: saves COPIES of the creature sheets with the outer contour darkened toward the hero's
## contour colour (hue kept a little) under assets/processed/outline/<same path>; originals untouched.
## --creatures: builds the normalised creature strips of AssetCatalog.CREATURES (D-063 Phase B) under
## assets/processed/creatures/<id>/{idle,run,attack,hurt,death}.png: right-facing horizontal strips of square
## frames, feet at the bottom, contour toward the heroes' ink, saturation and brightness capped to the
## heroes' range (soft palette pull, ArtPalette), optional hue shift. A missing death is generated here
## (flash, squash, fade); a missing attack or hurt is made in code (EnemySprites / SandboxEnemy).
##   godot --headless --path . --script res://tools/art_cohesion.gd [-- --write] [-- --creatures]
##   then: godot --headless --path . --import

const OUT_ROOT := "res://assets/processed/outline/"
const KEEP_HUE := 0.25            # how much of the creature's own contour colour survives


static func contour_stats(img: Image) -> Dictionary:
    var sum := Color(0, 0, 0, 0)
    var n := 0
    for y in img.get_height():
        for x in img.get_width():
            if img.get_pixel(x, y).a < 0.5:
                continue
            if _edge(img, x, y):
                sum += img.get_pixel(x, y)
                n += 1
    if n == 0:
        return {"n": 0, "lum": 0.0, "color": Color.BLACK}
    var c := Color(sum.r / n, sum.g / n, sum.b / n)
    return {"n": n, "lum": c.get_luminance(), "color": c}


static func _edge(img: Image, x: int, y: int) -> bool:
    for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var q: Vector2i = Vector2i(x, y) + d
        if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height() or img.get_pixel(q.x, q.y).a < 0.5:
            return true
    return false


## The contour, darkened toward `ink` (the heroes' contour colour), keeping a bit of its own hue.
static func outlined(src: Image, ink: Color) -> Image:
    var img := src.duplicate() as Image
    for y in src.get_height():
        for x in src.get_width():
            var c := src.get_pixel(x, y)
            if c.a < 0.5 or not _edge(src, x, y):
                continue
            var dark := ink.lerp(c * 0.45, KEEP_HUE)
            img.set_pixel(x, y, Color(dark.r, dark.g, dark.b, c.a))
    return img


static func sheets() -> Array:
    var out: Array = []
    var ids: Array = []
    for f in TowerExpedition.FLOORS.values():
        for id in f["foes"]:
            ids.append(String(EnemySprites.VOXEL_ALIAS.get(id, id)))
    var dir := DirAccess.open(EnemySprites.VOXEL_ROOT)
    if dir != null:
        for file in dir.get_files():
            if not file.ends_with(".png"):
                continue
            for id in ids:
                if file.begins_with(String(id) + "_side_") and not out.has(EnemySprites.VOXEL_ROOT + file):
                    out.append(EnemySprites.VOXEL_ROOT + file)
    for id in EnemySprites.IDS:
        for n in ["idle", "run", "death"]:
            var p: String = EnemySprites.ROOT + id + "/" + n + ".png"
            if ResourceLoader.exists(p):
                out.append(p)
    return out


## Soft palette pull toward the heroes' range: saturation x SAT_KEEP, value capped at VALUE_CAP, hue shifted.
const SAT_KEEP := 0.85
const VALUE_CAP := 0.92


static func harmonised(src: Image, hue_shift_deg: float = 0.0) -> Image:
    var img := src.duplicate() as Image
    for y in img.get_height():
        for x in img.get_width():
            var c := img.get_pixel(x, y)
            if c.a < 0.05:
                continue
            var h := fposmod(c.h + hue_shift_deg / 360.0, 1.0)
            img.set_pixel(x, y, Color.from_hsv(h, c.s * SAT_KEEP, minf(c.v, VALUE_CAP), c.a))
    return img


static func _load(path: String) -> Image:
    var img := (load(path) as Texture2D).get_image()
    if img.is_compressed():
        img.decompress()
    img.convert(Image.FORMAT_RGBA8)
    return img


## Frames of one column of a 4-direction grid (Ninja: columns down, up, left, right).
static func _column(img: Image, col: int, fw: int, rows: Array) -> Array:
    var out: Array = []
    for r in rows:
        out.append(img.get_region(Rect2i(col * fw, int(r) * fw, fw, fw)))
    return out


static func _strip_frames(img: Image, fw: int) -> Array:
    var out: Array = []
    for i in img.get_width() / fw:
        out.append(img.get_region(Rect2i(i * fw, 0, fw, img.get_height())))
    return out


static func _join(frames: Array) -> Image:
    var f0: Image = frames[0]
    var out := Image.create(f0.get_width() * frames.size(), f0.get_height(), false, Image.FORMAT_RGBA8)
    for i in frames.size():
        out.blit_rect(frames[i], Rect2i(Vector2i.ZERO, f0.get_size()), Vector2i(i * f0.get_width(), 0))
    return out


## Death made from the last pose: white flash, squash to the ground, fade (4 frames).
static func _made_death(pose: Image) -> Array:
    var w := pose.get_width()
    var h := pose.get_height()
    var out: Array = [pose]
    var flash := pose.duplicate() as Image
    for y in h:
        for x in w:
            var c := flash.get_pixel(x, y)
            if c.a > 0.05:
                flash.set_pixel(x, y, Color(1, 1, 1, c.a))
    out.append(flash)
    for k in [0.6, 0.3]:
        var sq := Image.create(w, h, false, Image.FORMAT_RGBA8)
        var small := pose.duplicate() as Image
        small.resize(w, maxi(1, roundi(h * k)), Image.INTERPOLATE_NEAREST)
        sq.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(0, h - small.get_height()))
        for y in h:
            for x in w:
                var c := sq.get_pixel(x, y)
                if c.a > 0.05:
                    sq.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * (0.5 if k < 0.5 else 0.8)))
        out.append(sq)
    return out


## The pose moved by (dx, dy) pixels inside its frame (for made-up lunges and recoils).
static func _shifted(pose: Image, dx: int, dy: int) -> Image:
    var out := Image.create(pose.get_width(), pose.get_height(), false, Image.FORMAT_RGBA8)
    out.blit_rect(pose, Rect2i(Vector2i.ZERO, pose.get_size()), Vector2i(dx, dy))
    return out


## The pose lightened toward white (hit flash), alpha kept.
static func _flashed(pose: Image, k: float) -> Image:
    var out := pose.duplicate() as Image
    for y in out.get_height():
        for x in out.get_width():
            var c := out.get_pixel(x, y)
            if c.a > 0.05:
                out.set_pixel(x, y, Color(c.lerp(Color.WHITE, k), c.a))
    return out


## Attack made from the pose: wind back, snap forward (the blow), recover (3 frames).
static func _made_attack(pose: Image) -> Array:
    var step := maxi(1, pose.get_width() / 16)
    return [_shifted(pose, -step, 0), _shifted(pose, 2 * step, 0), pose]


## Hurt made from the pose: flash, recoil (2 frames).
static func _made_hurt(pose: Image) -> Array:
    var step := maxi(1, pose.get_width() / 16)
    return [_flashed(pose, 0.6), _shifted(pose, -step, 0)]


## Builds the strips of one catalogue creature: {anim: Image}.
static func creature_strips(def: Dictionary) -> Dictionary:
    var fw := int(def["frame"])
    var anims := {}
    match String(def["layout"]):
        "grid4":
            var sheet := _load(String(def["src"]))
            var run := _column(sheet, 3, fw, [0, 1, 2, 3])
            anims["run"] = run
            anims["idle"] = [run[0], run[0], run[1], run[1]]
            anims["death"] = _made_death(run[0])
        "char":
            var dir := String(def["src"])
            anims["idle"] = [_column(_load(dir + "Idle.png"), 3, fw, [0])[0]]
            anims["run"] = _column(_load(dir + "Walk.png"), 3, fw, [0, 1, 2, 3])
            anims["attack"] = [anims["run"][0], _column(_load(dir + "Attack.png"), 3, fw, [0])[0], _column(_load(dir + "Attack.png"), 3, fw, [0])[0]]
            anims["death"] = _made_death(anims["idle"][0])      # the pack's Dead.png is a different drawing
        _:
            for anim in def["files"]:
                anims[anim] = _strip_frames(_load(String(def["src"]) + String(def["files"][anim])), fw)
            if not anims.has("death"):
                anims["death"] = _made_death((anims["idle"] as Array)[0])
    var pose: Image = (anims["idle"] as Array)[0]
    if not anims.has("attack"):
        anims["attack"] = _made_attack(pose)
    if not anims.has("hurt"):
        anims["hurt"] = _made_hurt(pose)
    var out := {}
    for anim in anims:
        out[anim] = _join(anims[anim])
    return out


func _creatures(ink: Color) -> void:
    for id in AssetCatalog.CREATURES:
        var def: Dictionary = AssetCatalog.CREATURES[id]
        var strips := creature_strips(def)
        var dir := AssetCatalog.PROCESSED_CREATURES + String(id) + "/"
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
        for anim in strips:
            var img := harmonised(strips[anim] as Image, float(def.get("recolor", 0.0)))
            img = outlined(img, ink)
            img.save_png(ProjectSettings.globalize_path(dir + String(anim) + ".png"))
        print("CREATURE %-16s %s -> %s" % [id, str(strips.keys()), dir])


func _initialize() -> void:
    var write := OS.get_cmdline_user_args().has("--write")
    var hf := SpriteComposer.build_frames(HeroGenerator.generate(101, 3))
    var hero := contour_stats(hf.get_frame_texture("idle_down", 0).get_image())
    print("HERO contour: lum %.2f colour %s (reference)" % [hero["lum"], (hero["color"] as Color).to_html(false)])
    if OS.get_cmdline_user_args().has("--creatures"):
        _creatures(hero["color"])
        quit()
        return
    var written := 0
    for path in sheets():
        var img := (load(path) as Texture2D).get_image()
        if img.is_compressed():
            img.decompress()
        img.convert(Image.FORMAT_RGBA8)
        var st := contour_stats(img)
        var line := "%-70s contour lum %.2f %s" % [String(path).get_file(), st["lum"], (st["color"] as Color).to_html(false)]
        if write:
            var out := outlined(img, hero["color"])
            var dest := OUT_ROOT + String(path).trim_prefix("res://assets/")
            DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest.get_base_dir()))
            out.save_png(ProjectSettings.globalize_path(dest))
            line += "  -> lum %.2f" % contour_stats(out)["lum"]
            written += 1
        print(line)
    print("COHESION done, %d copies written" % written)
    quit()
