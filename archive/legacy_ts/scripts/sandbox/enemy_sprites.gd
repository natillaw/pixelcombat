class_name EnemySprites
extends RefCounted
## T-024: Pixel Crawler mobs (Anokolisa, see assets/CREDITS.md). Sheets are installed by
## tools/prepare_crawler.py into ROOT/<id>/{idle,run,death}.png. All art faces right.
## Idle = 32x32 frames, run = 64x64, death = per-mob frame width (table). Feet sit at the bottom
## of every frame, so a bottom-center anchor keeps the mob on its cell.

const ROOT := AssetCatalog.PIXEL_CRAWLER_ENEMIES
const IDS := ["orc", "orc_rogue", "orc_shaman", "orc_warrior", "skeleton_base", "skeleton_mage", "skeleton_rogue", "skeleton_warrior"]
const IDLE_W := 32
const RUN_W := 64
const DEATH_W := {"orc_warrior": 96, "skeleton_base": 96}     # every other mob: 64

## Voxel Dungeon creatures (CC0, Cole Foster): side-view strips of SQUARE frames (48 px for bats, rats,
## slimes, mushrooms and eyes; 64 px for most; 96-144 px for the trex and golems), facing right.
## Used by the tower floors (TowerExpedition "foes"). Some creatures hop or fly instead of walking.
## Besides idle/run/death they bring "attack" (attack, bite, cast, slam or roar) and "hurt".
const VOXEL_ROOT := AssetCatalog.VOXEL_CREATURES
const VOXEL_W := 64
const VOXEL_SCALE := 1.0

## Voxel creatures whose name clashes with a Pixel Crawler mob ("orc" there is the training-ground
## orc): the tower uses the voxel one under its own id, so every floor creature shares one art style.
const VOXEL_ALIAS := {"orc_brute": "orc"}

static var _cache: Dictionary = {}
## D-055: creature sheets drawn from processed copies (contour darkened to match the heroes, made by
## tools/art_cohesion.gd) when they exist; the original packs are never modified. false = originals.
const USE_COHESION_COPIES := true
const COHESION_ROOT := AssetCatalog.PROCESSED_OUTLINE


static func _load_sheet(path: String) -> Texture2D:
    if USE_COHESION_COPIES:
        var copy := COHESION_ROOT + path.trim_prefix(AssetCatalog.ASSETS_ROOT)
        if ResourceLoader.exists(copy):
            return load(copy) as Texture2D
    return load(path) as Texture2D
static var _heights: Dictionary = {}


## Height in pixels of the opaque part of the idle frame (measured once per creature, cached).
static func art_height(id: String) -> int:
    if _heights.has(id):
        return int(_heights[id])
    var h := 26
    var sf := build_frames(id)
    if sf != null:
        var img := sf.get_frame_texture("idle", 0).get_image()
        if img != null:
            if img.is_compressed():
                img.decompress()
            var r := img.get_used_rect()
            h = r.size.y + (img.get_height() - r.end.y)       # feet are at the bottom of the frame
    _heights[id] = h
    return h


static func is_voxel(id: String) -> bool:
    return not IDS.has(id) and not has_processed(id) and not BanditArt.has(id) and id != FloorMods.TOTEM_ID


## D-063: creature drawn from the normalised strips of the new packs (tools/art_cohesion.gd --creatures).
static func has_processed(id: String) -> bool:
    return AssetCatalog.CREATURES.has(id) and ResourceLoader.exists(AssetCatalog.PROCESSED_CREATURES + id + "/idle.png")


static func scale_for(id: String) -> float:
    if has_processed(id):
        return float(AssetCatalog.CREATURES[id]["scale"])      # integer scales only (pixel art)
    return VOXEL_SCALE if is_voxel(id) else 1.0


static func _voxel_sheet(id: String, names: Array) -> Texture2D:
    id = String(VOXEL_ALIAS.get(id, id))
    for n in names:
        var path := VOXEL_ROOT + "%s_side_%s.png" % [id, n]
        if ResourceLoader.exists(path):
            return _load_sheet(path)
    return null


static func available(id: String) -> bool:
    for n in ["idle", "run", "death"]:
        if not ResourceLoader.exists(ROOT + id + "/" + n + ".png"):
            return false
    return true


static func _add(sf: SpriteFrames, anim: String, tex: Texture2D, fw: int, fps: float, loop: bool) -> void:
    sf.add_animation(anim)
    sf.set_animation_speed(anim, fps)
    sf.set_animation_loop(anim, loop)
    var n := floori(float(tex.get_width()) / float(fw))
    for i in n:
        var at := AtlasTexture.new()
        at.atlas = tex
        at.region = Rect2(i * fw, 0, fw, tex.get_height())
        sf.add_frame(anim, at)


## Null when the art is not installed.
static func build_frames(id: String) -> SpriteFrames:
    if BanditArt.has(id):
        return BanditArt.build_frames(id)          # overhaul LPC: a new face per bandit (BanditArt caches each)
    if _cache.has(id):
        return _cache[id]
    var sf: SpriteFrames = null
    if id == FloorMods.TOTEM_ID:
        sf = BanditArt.totem_frames()
    elif BanditArt.has(id):
        sf = BanditArt.build_frames(id)
    elif has_processed(id):
        sf = SpriteFrames.new()
        sf.remove_animation("default")
        var fps := {"idle": 4.0, "run": 8.0, "attack": 10.0, "hurt": 10.0, "death": 8.0}
        for anim in fps:
            var path: String = AssetCatalog.PROCESSED_CREATURES + id + "/" + String(anim) + ".png"
            if ResourceLoader.exists(path):
                var tex := load(path) as Texture2D
                _add(sf, anim, tex, tex.get_height(), float(fps[anim]), anim == "idle" or anim == "run")
    elif is_voxel(id):
        var idle := _voxel_sheet(id, ["idle", "fly", "hop"])
        var run := _voxel_sheet(id, ["walk", "hop", "fly"])
        var death := _voxel_sheet(id, ["death"])
        if idle != null and run != null and death != null:
            sf = SpriteFrames.new()
            sf.remove_animation("default")
            _add(sf, "idle", idle, idle.get_height(), 8.0, true)
            _add(sf, "run", run, run.get_height(), 10.0, true)
            _add(sf, "death", death, death.get_height(), 10.0, false)
            var attack := _voxel_sheet(id, ["attack", "bite", "cast", "slam", "roar"])
            if attack != null:
                _add(sf, "attack", attack, attack.get_height(), 12.0, false)
            var hurt := _voxel_sheet(id, ["hurt"])
            if hurt != null:
                _add(sf, "hurt", hurt, hurt.get_height(), 14.0, false)
    elif available(id):
        var idle := _load_sheet(ROOT + id + "/idle.png")
        var run := _load_sheet(ROOT + id + "/run.png")
        var death := _load_sheet(ROOT + id + "/death.png")
        if idle != null and run != null and death != null:
            sf = SpriteFrames.new()
            sf.remove_animation("default")
            _add(sf, "idle", idle, IDLE_W, 6.0, true)
            _add(sf, "run", run, RUN_W, 10.0, true)
            _add(sf, "death", death, int(DEATH_W.get(id, 64)), 10.0, false)
    _cache[id] = sf
    return sf


## The enemy node stays hidden after death (combat code unchanged); this leaves a corpse that
## plays the death animation, holds, fades and frees itself.
static func spawn_death(e: Node2D, sprite: AnimatedSprite2D) -> void:
    if e == null or sprite == null or not e.is_inside_tree():
        return
    var parent := e.get_parent()
    if parent == null:
        return
    var ghost := Node2D.new()
    ghost.position = e.position
    ghost.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    var s := AnimatedSprite2D.new()
    s.sprite_frames = sprite.sprite_frames
    s.centered = false
    s.flip_h = sprite.flip_h
    s.scale = sprite.scale
    var sz := s.sprite_frames.get_frame_texture("death", 0).get_size()
    s.offset = Vector2(-sz.x * 0.5, -sz.y)
    ghost.add_child(s)
    s.play("death")
    JuicePlayer.pop(s)                    # D-110: death "pop" (squash/stretch + flash) before the fade
    parent.add_child.call_deferred(ghost)
    var t := e.get_tree().create_tween()
    t.tween_interval(1.4)
    t.tween_property(s, "modulate:a", 0.0, 0.6)
    t.tween_callback(ghost.queue_free)
