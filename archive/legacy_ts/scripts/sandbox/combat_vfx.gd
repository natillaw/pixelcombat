class_name CombatVFX
extends RefCounted
## Helper to generate SpriteFrames and play animated combat VFX from SpritePilot packs.
## Packs are unpacked as assets/packs/<pack>/<pack>/<size>/<file> (F-012: the folder is nested).

const BASE_DIR := AssetCatalog.PACKS
static var _cache: Dictionary = {}


static func create_strip_frames(pack_name: String, subfolder: String, filename: String, frame_width: int, frame_height: int, frame_count: int, fps: int = 12) -> SpriteFrames:
    var path := BASE_DIR + "%s/%s/%s/%s" % [pack_name, pack_name, subfolder, filename]
    if _cache.has(path):
        return _cache[path]
    if not ResourceLoader.exists(path):
        _cache[path] = null
        return null
    var tex := load(path) as Texture2D
    if tex == null:
        return null
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    sf.add_animation("fx")
    sf.set_animation_speed("fx", float(fps))
    sf.set_animation_loop("fx", false)

    for i in range(frame_count):
        var atlas := AtlasTexture.new()
        atlas.atlas = tex
        atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
        sf.add_frame("fx", atlas)
    _cache[path] = sf
    return sf


## Strip of square 16 px frames: the frame count is in the file name ("..._strip8.png").
static func spawn_strip16(parent: Node2D, pos: Vector2, pack: String, fname: String, scale_factor: float = 2.5) -> void:
    var count := int(fname.get_basename().get_slice("_strip", 1))
    if count <= 0:
        return
    spawn_effect(parent, pos, pack, "16px", fname, 16, 16, count, scale_factor)


static func spawn_effect(parent: Node2D, pos: Vector2, pack: String, folder: String, fname: String, fw: int, fh: int, count: int, scale_factor: float = 2.0) -> void:
    if SimMode.on:
        return                       # D-083 headless simulator
    if parent == null:
        return
    var sf := create_strip_frames(pack, folder, fname, fw, fh, count, 14)
    if sf == null:
        return
    var anim := AnimatedSprite2D.new()
    anim.sprite_frames = sf
    anim.position = pos
    anim.scale = Vector2(scale_factor, scale_factor)
    parent.add_child(anim)
    anim.play("fx")
    anim.animation_finished.connect(func(): anim.queue_free())


# --- named effect catalog (all free packs, see docs/ASSET_REGISTRY.md) ----------------------------
## key -> [file under assets/packs/, fps, base scale]. Frames are read from the strip: the count comes
## from the file name ("_strip8", "_10f") or width/height, the frame width from width/count.
const SP_C := "spritepilot-combat-pack/spritepilot-combat-pack/"
const SP_M := "spritepilot-magic-pack/spritepilot-magic-pack/"
const SP_E := "spritepilot-effects-pack/spritepilot-effects-pack/"
const SK := "sprite_kitchen_combat_essentials_v0.1/spritesheets/"
const KILN := "KILN_FX_Free_Sampler/KILN_FX_Free_Sampler/"
const VOX := "voxel-dungeon-pack-full/fx/sheets/"
const FX := {
    # melee
    "slash": [SP_C + "32px/sword-slash-32px_strip7.png", 18, 1.6],
    "slash_heavy": [SK + "cross_slash_64x64_10f.png", 20, 1.0],
    "crescent": [SK + "crescent_slash_64x64_8f.png", 20, 0.9],
    "slash_blood": [KILN + "slash_arc_blood_S_strip7.png", 18, 1.6],
    "slash_frost": [KILN + "slash_arc_frost_S_strip7.png", 18, 1.6],
    "claw": [SP_C + "32px/claw-slash-32px_strip8.png", 18, 1.4],
    "crit": [SP_C + "32px/critical-hit-32px_strip8.png", 18, 1.6],
    "parry": [SP_C + "32px/parry-flash-32px_strip7.png", 18, 1.5],
    "slam": [SP_C + "32px/ground-slam-32px_strip9.png", 16, 2.0],
    "shockwave": [SP_C + "32px/shockwave-32px_strip8.png", 16, 2.0],
    # impacts
    "spark": [SK + "hit_spark_64x64_7f.png", 20, 0.6],
    "spark_small": [SP_E + "16px/hit-spark-16px_strip6.png", 18, 2.0],
    "spark_fire": [KILN + "hit_spark_fire_S_strip7.png", 18, 1.8],
    "spark_holy": [KILN + "hit_spark_holy_S_strip7.png", 18, 1.8],
    "fire_impact": [SK + "fire_impact_64x64_10f.png", 18, 1.0],
    "electric_impact": [SK + "electric_impact_64x64_10f.png", 18, 1.0],
    "arcane_burst": [SK + "arcane_burst_64x64_10f.png", 18, 1.0],
    "explosion": [KILN + "explosion_medium_fire_S_strip14.png", 20, 1.5],
    "explosion_big": [VOX + "explosion_play.png", 12, 1.3],
    "frost_burst": [KILN + "explosion_medium_frost_S_strip14.png", 20, 1.5],
    "lightning_holy": [KILN + "lightning_strike_holy_S_strip9.png", 16, 2.0],
    "lightning_volt": [KILN + "lightning_strike_volt_S_strip9.png", 16, 2.0],
    "blood": [KILN + "blood_splat_blood_S_strip9.png", 18, 1.2],
    "blood_toxic": [KILN + "blood_splat_toxic_S_strip9.png", 18, 1.2],
    "dust": [SK + "dash_dust_64x64_9f.png", 18, 0.8],
    "dust_puff": [VOX + "dust_puff_play.png", 12, 1.2],
    # magic and support
    "heal": [KILN + "heal_loop_holy_S_strip12.png", 14, 1.6],
    "heal_toxic": [KILN + "heal_loop_toxic_S_strip12.png", 12, 1.2],
    "heal_aura": [SP_M + "32px/healing-aura-32px_strip8.png", 12, 2.0],
    "shield": [SP_M + "32px/shield-bubble-32px_strip12.png", 14, 1.6],
    "teleport": [SP_M + "32px/teleport-32px_strip12.png", 20, 1.6],
    "portal": [SP_M + "32px/portal-32px_strip8.png", 12, 1.6],
    "poison_cloud": [SP_M + "32px/poison-cloud-32px_strip8.png", 10, 1.8],
    "poison_cloud_big": [VOX + "poison_cloud_play.png", 9, 1.6],
    "circle_arcane": [KILN + "magic_circle_loop_arcane_S_strip12.png", 14, 1.6],
    "circle_holy": [KILN + "magic_circle_loop_holy_S_strip12.png", 14, 1.6],
    "circle_big": [VOX + "magic_circle_play.png", 10, 1.0],
    "level_up": [VOX + "level_up_play.png", 10, 1.4],
    "sparkle": [VOX + "sparkle_play.png", 12, 1.0],
    "sparkle_small": [SP_E + "16px/magic-sparkle-16px_strip8.png", 12, 1.6],
    "smoke": [KILN + "smoke_puff_smoke_S_strip12.png", 12, 1.8],
    "smoke_earth": [KILN + "smoke_puff_earth_S_strip12.png", 12, 1.4],
    "fire": [SP_E + "16px/fire-16px_strip8.png", 12, 1.6],
    "ice": [SP_M + "32px/ice-shard-32px_strip8.png", 12, 1.2],
    # projectiles (looping while they fly)
    "arrow": [SP_C + "16px/arrow-16px_strip4.png", 16, 2.0],
    "fireball": [KILN + "fireball_loop_fire_S_strip10.png", 20, 1.6],
    "arcane_bolt": [KILN + "fireball_loop_arcane_S_strip10.png", 20, 1.6],
    "orb": [SP_M + "16px/energy-orb-16px_strip8.png", 16, 2.0],
    "frost_shard": [VOX + "frost_shard_play.png", 12, 1.2],
    "venom": [VOX + "venom_spit_play.png", 12, 1.2],
}

static var _named: Dictionary = {}


static func frames_for(key: String, loop: bool = false) -> SpriteFrames:
    var ck := key + ("@loop" if loop else "")
    if _named.has(ck):
        return _named[ck]
    var entry: Array = FX.get(key, [])
    var sf: SpriteFrames = null
    if not entry.is_empty() and ResourceLoader.exists(BASE_DIR + String(entry[0])):
        var tex := load(BASE_DIR + String(entry[0])) as Texture2D
        if tex != null:
            var fname := String(entry[0]).get_file().get_basename()
            var n := 0
            var m := RegEx.create_from_string("_strip(\\d+)$|_(\\d+)f$").search(fname)
            if m != null:
                n = int(m.get_string(1) if m.get_string(1) != "" else m.get_string(2))
            if n <= 0:
                n = maxi(1, tex.get_width() / maxi(1, tex.get_height()))
            var fw := tex.get_width() / n
            sf = SpriteFrames.new()
            sf.remove_animation("default")
            sf.add_animation("fx")
            sf.set_animation_speed("fx", float(entry[1]))
            sf.set_animation_loop("fx", loop)
            for i in n:
                var at := AtlasTexture.new()
                at.atlas = tex
                at.region = Rect2(i * fw, 0, fw, tex.get_height())
                sf.add_frame("fx", at)
    _named[ck] = sf
    return sf


## Effects that happen ON the ground: drawn under the units (z between the floor and the units),
## everything else (slashes, sparks, bursts at chest height) above them.
const GROUND_FX := ["slam", "shockwave", "dust", "dust_puff", "smoke_earth", "circle_arcane", "circle_holy",
    "circle_big", "poison_cloud", "poison_cloud_big"]
const Z_GROUND := -4
const Z_AIR := 20
## Pixel art blown up past this looks like blocks: big areas get extra copies instead (area_burst).
const AREA_MAX_SCALE := 1.6


static func _sprite(key: String, loop: bool, scale_mult: float) -> AnimatedSprite2D:
    var sf := frames_for(key, loop)
    if sf == null:
        return null
    var a := AnimatedSprite2D.new()
    a.sprite_frames = sf
    a.scale = Vector2.ONE * float(FX[key][2]) * scale_mult
    a.z_index = Z_GROUND if GROUND_FX.has(key) else Z_AIR
    a.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # animated in idle, not in ticks
    return a


## Scale multiplier so one copy of `key` covers about the inner half of an area of `radius`.
static func area_scale(key: String, radius: float) -> float:
    var sf := frames_for(key)
    if sf == null or radius <= 0.0:
        return 1.0
    var native := float(sf.get_frame_texture("fx", 0).get_width()) * float(FX[key][2])
    return clampf(radius * 0.9 / maxf(1.0, native), 0.7, AREA_MAX_SCALE)


## An area effect that covers the WHOLE area that was hit: one copy in the centre and, for areas
## larger than one copy can cover, a ring of smaller copies at ~60% of the radius (ground perspective
## 0.55), slightly staggered so the blast ripples outwards. Returns how many copies were spawned.
static func area_burst(parent: Node, centre: Vector2, radius: float, key: String, delay: float = 0.0) -> int:
    if SimMode.on:
        return 0                       # D-083 headless simulator
    if parent == null or frames_for(key) == null:
        return 0
    var sc := area_scale(key, radius)
    var native := float(frames_for(key).get_frame_texture("fx", 0).get_width()) * float(FX[key][2]) * sc
    var spots: Array = [[centre, sc, 0.0]]
    var n := clampi(roundi((radius * 2.0 - native) / 45.0), 0, 6)
    for i in n:
        var ang := TAU * float(i) / float(n) + 0.4
        var p := centre + Vector2(cos(ang), sin(ang) * 0.55) * radius * 0.62
        spots.append([p, sc * 0.75, 0.04 + 0.025 * float(i)])
    for s in spots:
        _later(parent, s[0], key, float(s[1]), delay + float(s[2]))
    return spots.size()


static func _later(parent: Node, pos: Vector2, key: String, sc: float, delay: float) -> void:
    if delay <= 0.02 or not parent.is_inside_tree():
        play(parent, pos, key, sc)
        return
    parent.create_tween().tween_callback(func(): play(parent, pos, key, sc)).set_delay(delay)   # dies with parent (B4)


## One-shot effect at a world point (frees itself). Returns the node (null if the art is missing).
static func play(parent: Node, pos: Vector2, key: String, scale_mult: float = 1.0, flip: bool = false, rot: float = 0.0) -> AnimatedSprite2D:
    if SimMode.on:
        return null                       # D-083 headless simulator
    if parent == null or key == "":
        return null
    var a := _sprite(key, false, scale_mult)
    if a == null:
        return null
    a.position = pos
    a.flip_h = flip
    a.rotation = rot
    parent.add_child(a)
    a.play("fx")
    a.animation_finished.connect(a.queue_free)
    return a


## Looping effect stuck to a unit (status auras, cast circles, zones). The caller frees it.
static func attach(unit: Node, key: String, offset: Vector2, scale_mult: float = 1.0, behind: bool = false) -> AnimatedSprite2D:
    if SimMode.on:
        return null                       # D-083 headless simulator
    if unit == null:
        return null
    var a := _sprite(key, true, scale_mult)
    if a == null:
        return null
    a.position = offset
    a.z_index = -1 if behind else 5
    a.z_as_relative = true
    a.modulate = Color(1, 1, 1, 0.85)
    unit.add_child(a)
    a.play("fx")
    return a


## A projectile that flies from `from` to `to` (rotated along its path) and plays `impact` there.
## Purely visual: the hit itself is resolved by the combat rules at once.
static func projectile(parent: Node, from: Vector2, to: Vector2, key: String, impact: String = "", speed: float = 650.0, scale_mult: float = 1.0, impact_scale: float = 1.0) -> AnimatedSprite2D:
    if SimMode.on:
        return null                       # D-083 headless simulator
    if parent == null:
        return null
    var a := _sprite(key, true, scale_mult)
    if a == null:
        play(parent, to, impact, impact_scale)
        return null
    a.position = from
    a.rotation = (to - from).angle()
    parent.add_child(a)
    a.play("fx")
    if not a.is_inside_tree():
        a.queue_free()
        play(parent, to, impact, impact_scale)
        return null
    var t := a.create_tween()
    t.tween_property(a, "position", to, maxf(0.06, from.distance_to(to) / speed))
    t.tween_callback(func():
        play(parent, to, impact, impact_scale)
        a.queue_free()
    )
    return a


# --- what each attack, skill, status and creature looks like -----------------------------------

## Basic attack by weapon (equipped base, or the class's default weapon).
const CLASS_WEAPON := {"class.warrior": "sword", "class.rogue": "dagger", "class.archer": "bow", "class.mage": "staff",
    "class.cleric": "mace", "class.commoner": "fist", "class.none": "fist"}
const WEAPON_FX := {
    "sword": {"hit": "slash"}, "greataxe": {"hit": "slash_heavy"}, "dagger": {"hit": "crescent", "scale": 0.7},
    "mace": {"hit": "spark", "extra": "dust_puff"}, "fist": {"hit": "spark_small"},
    "bow": {"proj": "arrow", "hit": "spark_small"}, "staff": {"proj": "arcane_bolt", "hit": "arcane_burst", "scale": 0.7},
    "wand": {"proj": "orb", "hit": "spark_holy"},
}

## Skill look: cast = circle under the caster while casting; proj = projectile to the target (n of them,
## "rain" = falling on the area, "sky" = from above); hit = at the target; area = at the area centre
## (scaled to the radius); self = on the caster. Generic effects (heal, shield, cleanse, dash, blink,
## knock-back, interrupt) are added automatically by SandboxHero.
const SKILL_FX := {
    "second_breath": {"self": ["heal_aura"]},
    "improvised_strike": {"hit": ["slash_heavy"]},
    "shove": {"hit": ["spark"]},
    "rally": {"self": ["level_up"]},
    "dirty_trick": {"hit": ["smoke_earth"]},
    "cleave": {"area": ["crescent", "shockwave"]},
    "shield_bash": {"hit": ["spark"]},
    "war_cry": {"self": ["shockwave", "level_up"]},
    "charge": {"hit": ["slash_heavy"]},
    "shield_wall": {"self": ["parry"]},
    "whirlwind": {"area": ["crescent", "slash_heavy", "blood"]},
    "rallying_shout": {"self": ["level_up", "shockwave"]},
    "earthshatter": {"cast": "circle_big", "area": ["slam", "shockwave", "dust"]},
    "quick_slash": {"hit": ["slash_blood"]},
    "poison_blade": {"hit": ["slash", "blood_toxic"]},
    "shadow_step": {"self": ["smoke"], "hit": ["crescent"]},
    "backstab": {"hit": ["slash_blood", "crit"]},
    "smoke_bomb": {"area": ["smoke", "smoke_earth"]},
    "fan_of_knives": {"area": ["crescent", "blood"]},
    "kidney_shot": {"hit": ["crit"]},
    "ambush": {"self": ["smoke"], "hit": ["slash", "parry"]},
    "eviscerate": {"hit": ["slash_heavy", "blood", "crit"]},
    "rapid_shot": {"proj": "arrow", "n": 2, "hit": ["spark_small"]},
    "snare_shot": {"proj": "arrow", "hit": ["smoke_earth"]},
    "volley": {"cast": "circle_arcane", "proj": "arrow", "n": 6, "rain": true, "area": ["dust_puff"]},
    "hunters_mark": {"proj": "arrow", "hit": ["sparkle"]},
    "bear_trap": {"self": ["dust"]},
    "piercing_shot": {"cast": "circle_arcane", "proj": "arrow", "speed": 1100.0, "hit": ["slash_frost", "spark"]},
    "concussive_shot": {"proj": "arrow", "hit": ["shockwave"]},
    "interrupt_shot": {"proj": "arrow", "speed": 1100.0, "hit": ["parry"]},
    "rain_of_arrows": {"cast": "circle_big", "proj": "arrow", "n": 12, "rain": true, "area": ["dust", "dust_puff"]},
    "heal": {"cast": "circle_holy"},
    "smite": {"hit": ["lightning_holy", "spark_holy"]},
    "holy_radiance": {"self": ["heal_aura", "circle_holy"]},
    "blessing": {"self": ["sparkle_small"]},
    "purify": {"self": ["sparkle_small"]},
    "sanctuary": {"cast": "circle_holy", "self": ["level_up"]},
    "judgement": {"hit": ["lightning_holy", "spark_holy"]},
    "mass_heal": {"cast": "circle_big", "self": ["level_up", "heal_aura"]},
    "fire_burst": {"cast": "circle_arcane", "proj": "fireball", "area": ["explosion_big", "fire_impact"]},
    "frost_bolt": {"cast": "circle_arcane", "proj": "frost_shard", "hit": ["frost_burst"]},
    "arcane_shield": {"self": ["arcane_burst"]},
    "frost_nova": {"area": ["frost_burst", "shockwave"]},
    "blink": {},
    "chain_burn": {"cast": "circle_arcane", "proj": "fireball", "area": ["fire_impact", "fire"]},
    "meteor": {"cast": "circle_big", "proj": "fireball", "sky": true, "proj_scale": 3.0, "area": ["explosion_big", "slam", "fire_impact"]},
    "arcane_torrent": {"cast": "circle_arcane", "proj": "arcane_bolt", "proj_scale": 1.6, "hit": ["electric_impact", "arcane_burst"]},
    "counterspell": {"proj": "arcane_bolt", "hit": ["arcane_burst", "parry"]},
}

## Looping aura while a status lasts: [effect, offset, scale].
const STATUS_FX := {
    "burn": ["fire", Vector2(0, -20), 1.3],
    "poison": ["heal_toxic", Vector2(0, -16), 0.9],
    "bleed": ["blood", Vector2(0, -18), 0.7],
    "stun": ["sparkle", Vector2(0, -46), 0.8],
    "root": ["smoke_earth", Vector2(0, -4), 0.8],
    "slow": ["ice", Vector2(0, -6), 0.8],
    "weaken": ["smoke", Vector2(0, -20), 0.6],
    "marked": ["circle_arcane", Vector2(0, -2), 0.8],
    "shield": ["shield", Vector2(0, -16), 1.0],
    "regen": ["heal", Vector2(0, -16), 0.7],
}

## Zones: [effect, base radius it covers at scale 1].
const ZONE_FX := {"weaken": ["smoke", 26.0], "root": ["circle_big", 36.0], "regen": ["circle_holy", 26.0]}

## Enemy strike look by creature (first matching prefix): hit at the aimed spot, optional projectile.
const ENEMY_FX := [
    # D-145 bandits: the archer shoots arrows, the mage throws fireballs, the shaman orbs, the brutes cleave
    ["bandido_arquero", {"proj": "arrow", "hit": "spark_small"}], ["bandido_mago", {"proj": "fireball", "hit": "explosion", "extra": "fire_impact"}],
    ["bandido_chaman", {"proj": "orb", "hit": "electric_impact"}], ["bandido_degollador", {"hit": "slash_blood"}],
    ["bandido_bruto", {"hit": "slash_heavy", "extra": "dust"}], ["bandido_maton", {"hit": "slam", "extra": "dust"}],
    ["capitan_bandido", {"hit": "slash_heavy", "extra": "shockwave"}], ["jefe_baron", {"hit": "slash_heavy", "extra": "blood"}],
    ["slime", {"hit": "blood_toxic"}], ["mushroom", {"hit": "poison_cloud"}], ["spider", {"proj": "venom", "hit": "blood_toxic"}],
    ["scorpion", {"hit": "claw"}], ["rat", {"hit": "claw"}], ["bat", {"hit": "claw"}], ["mimic", {"hit": "claw"}],
    ["golem_magma", {"hit": "slam", "extra": "fire_impact"}], ["golem", {"hit": "slam", "extra": "dust"}],
    ["orc_chieftain", {"hit": "slash_heavy", "extra": "shockwave"}], ["warlord", {"hit": "claw", "extra": "shockwave"}], ["mage_frost", {"proj": "frost_shard", "hit": "frost_burst"}],
    ["mage", {"proj": "fireball", "hit": "explosion"}], ["skeleton_mage", {"proj": "arcane_bolt", "hit": "arcane_burst"}],
    ["orc_shaman", {"proj": "orb", "hit": "electric_impact"}], ["eye", {"hit": "lightning_volt"}], ["ghost", {"hit": "arcane_burst"}],
    ["trex", {"hit": "claw", "extra": "shockwave"}], ["hobgoblin", {"hit": "slash_heavy"}], ["orc_brute", {"hit": "slash_heavy"}], ["", {"hit": "slash"}],
]


static func enemy_fx(type_id: String) -> Dictionary:
    for pair in ENEMY_FX:
        if type_id.begins_with(String(pair[0])):
            return pair[1]
    return {"hit": "claw"}
