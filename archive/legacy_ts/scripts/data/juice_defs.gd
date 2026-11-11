class_name JuiceDefs
extends RefCounted
## D-110 (pista C): impact juice as data. One profile per skill and per basic attack (by class), with a
## fallback by type (enemy, bandit, boss, death). JuicePlayer reads these through JuiceProfile, which
## can be overridden by a saved resource at res://assets/juice/<id>.tres (tools/build_juice_profiles.gd
## writes them from this table). Presentation only: never a damage, timing or position change.
##
## Fields (all optional, defaults in DEFAULT):
##   flash: Color · flash_frames: 2-4 · particles: Color · amount: int · spread: degrees around the blow
##   speed: px/s · kick: sprite shake in px (target) · recoil: attacker bounce in px · squash: 0..0.3
##   shake: camera px (capped at MAX_SHAKE, only when the filter allows) · freeze: seconds (0.03-0.05,
##   render only, filtered) · sound: audio hook id · heavy: counts as a heavy blow for the filter
##   extra: second particle colour (embers, shards) · rise: particles float up (holy sparks)

const MAX_SHAKE := 2.0                   # camera px, never more (owner, pista C)
const FREEZE_MIN := 0.03
const FREEZE_MAX := 0.05
const FRAME := 1.0 / 60.0                # flash frames are counted at 60 fps
const PARTICLE_PX := 2                   # every juice particle is a 2x2 pixel

const DEFAULT := {"flash": Color(1, 1, 1), "flash_frames": 2, "particles": Color(0.9, 0.85, 0.75), "amount": 5,
    "spread": 50.0, "speed": 70.0, "kick": 1, "recoil": 0, "squash": 0.0, "shake": 0.0, "freeze": 0.0,
    "sound": "hit", "heavy": false, "extra": Color(0, 0, 0, 0), "rise": false}

## Heavy (filtered) treatment added on crits, finishing blows, bosses and heavy skills.
const HEAVY_BOOST := {"shake": 2.0, "freeze": 0.04, "flash_frames": 4, "amount_mult": 1.8, "squash": 0.15}

const BASIC := {
    # warrior: dry blow and dust (a shield block sparks: "block")
    "basic.warrior": {"particles": Color(0.72, 0.62, 0.48), "amount": 6, "kick": 2, "recoil": 1, "sound": "hit_blunt"},
    # rogue: quick cuts, small sparks per dagger
    "basic.rogue": {"particles": Color(1.0, 0.92, 0.6), "amount": 3, "spread": 30.0, "speed": 95.0, "kick": 1, "sound": "hit_slash"},
    # archer: splinters where the arrow lands
    "basic.archer": {"particles": Color(0.7, 0.52, 0.32), "amount": 4, "spread": 35.0, "speed": 90.0, "kick": 1, "sound": "hit_arrow"},
    "basic.mage": {"flash": Color(0.75, 0.6, 1.0), "particles": Color(0.7, 0.5, 1.0), "amount": 5, "kick": 1, "sound": "hit_magic"},
    "basic.cleric": {"flash": Color(1.0, 0.92, 0.6), "particles": Color(1.0, 0.85, 0.35), "amount": 5, "rise": true, "kick": 1, "sound": "hit_holy"},
    "basic.commoner": {"particles": Color(0.8, 0.75, 0.65), "amount": 3, "kick": 1, "sound": "hit_blunt"},
}

const SKILL := {
    # commoner / shared
    "second_breath": {"flash": Color(0.6, 1.0, 0.6), "particles": Color(0.55, 1.0, 0.55), "rise": true, "kick": 0},
    "improvised_strike": {"particles": Color(0.75, 0.65, 0.5), "amount": 7, "kick": 2, "recoil": 1, "heavy": true},
    "shove": {"particles": Color(0.72, 0.62, 0.48), "amount": 6, "kick": 3},
    "rally": {"particles": Color(1.0, 0.85, 0.4), "rise": true, "kick": 0},
    "dirty_trick": {"particles": Color(0.6, 0.55, 0.45), "amount": 8, "spread": 120.0, "kick": 1},
    # warrior
    "cleave": {"particles": Color(0.72, 0.62, 0.48), "amount": 7, "spread": 90.0, "kick": 2, "recoil": 1},
    "shield_bash": {"particles": Color(1.0, 0.9, 0.55), "extra": Color(0.72, 0.62, 0.48), "amount": 7, "kick": 3, "recoil": 1, "sound": "hit_shield"},
    "war_cry": {"particles": Color(1.0, 0.55, 0.3), "kick": 0},
    "charge": {"particles": Color(0.72, 0.62, 0.48), "amount": 9, "kick": 3, "recoil": 2, "heavy": true},
    "shield_wall": {"flash": Color(0.7, 0.85, 1.0), "particles": Color(1.0, 0.9, 0.55), "kick": 0},
    "whirlwind": {"particles": Color(0.72, 0.62, 0.48), "amount": 6, "spread": 160.0, "kick": 2, "heavy": true},
    "rallying_shout": {"particles": Color(1.0, 0.75, 0.4), "rise": true, "kick": 0},
    "earthshatter": {"particles": Color(0.6, 0.5, 0.38), "amount": 12, "spread": 140.0, "speed": 110.0, "kick": 3, "heavy": true, "sound": "hit_heavy"},
    # rogue
    "quick_slash": {"particles": Color(1.0, 0.92, 0.6), "amount": 4, "spread": 25.0, "speed": 110.0, "kick": 1, "sound": "hit_slash"},
    "poison_blade": {"particles": Color(0.55, 0.9, 0.3), "amount": 5, "kick": 1, "sound": "hit_slash"},
    "shadow_step": {"flash": Color(0.6, 0.5, 0.8), "particles": Color(0.4, 0.35, 0.5), "amount": 6, "kick": 2},
    "backstab": {"particles": Color(1.0, 0.92, 0.6), "extra": Color(0.85, 0.15, 0.15), "amount": 7, "kick": 2, "heavy": true, "sound": "hit_slash"},
    "smoke_bomb": {"particles": Color(0.55, 0.55, 0.6), "amount": 8, "spread": 180.0, "speed": 40.0, "kick": 0},
    "fan_of_knives": {"particles": Color(1.0, 0.92, 0.6), "amount": 4, "spread": 160.0, "speed": 120.0, "kick": 1},
    "kidney_shot": {"particles": Color(1.0, 0.92, 0.6), "amount": 5, "kick": 2},
    "ambush": {"flash": Color(0.6, 0.5, 0.8), "particles": Color(1.0, 0.92, 0.6), "amount": 6, "kick": 2, "sound": "hit_slash"},
    "eviscerate": {"particles": Color(1.0, 0.92, 0.6), "extra": Color(0.85, 0.15, 0.15), "amount": 10, "kick": 3, "recoil": 1, "heavy": true, "sound": "hit_heavy"},
    # archer
    "rapid_shot": {"particles": Color(0.7, 0.52, 0.32), "amount": 3, "spread": 30.0, "speed": 100.0, "kick": 1, "sound": "hit_arrow"},
    "snare_shot": {"particles": Color(0.5, 0.42, 0.3), "amount": 5, "kick": 1, "sound": "hit_arrow"},
    "volley": {"particles": Color(0.7, 0.52, 0.32), "amount": 3, "spread": 60.0, "kick": 1, "sound": "hit_arrow"},
    "hunters_mark": {"flash": Color(1.0, 0.85, 0.5), "particles": Color(1.0, 0.85, 0.5), "amount": 4, "kick": 0},
    "bear_trap": {"particles": Color(0.6, 0.6, 0.62), "amount": 6, "kick": 2},
    # drawn shot: flash of the tensed bow on the archer + splinters at the target
    "piercing_shot": {"flash": Color(0.85, 0.95, 1.0), "particles": Color(0.7, 0.52, 0.32), "extra": Color(0.85, 0.95, 1.0), "amount": 8, "speed": 130.0, "kick": 3, "heavy": true, "sound": "hit_arrow_heavy"},
    "concussive_shot": {"particles": Color(0.8, 0.8, 0.85), "amount": 7, "kick": 3},
    "interrupt_shot": {"particles": Color(0.8, 0.8, 0.85), "amount": 5, "kick": 2, "sound": "hit_arrow"},
    "rain_of_arrows": {"particles": Color(0.7, 0.52, 0.32), "amount": 3, "spread": 90.0, "kick": 1, "heavy": true},
    # cleric: golden sparks that rise, shield shine
    "heal": {"flash": Color(1.0, 0.95, 0.6), "particles": Color(1.0, 0.85, 0.35), "rise": true, "kick": 0},
    "smite": {"flash": Color(1.0, 0.95, 0.7), "particles": Color(1.0, 0.85, 0.35), "amount": 7, "rise": true, "kick": 2, "sound": "hit_holy"},
    "holy_radiance": {"flash": Color(1.0, 0.95, 0.7), "particles": Color(1.0, 0.85, 0.35), "rise": true, "kick": 0},
    "blessing": {"flash": Color(1.0, 0.95, 0.7), "particles": Color(1.0, 0.9, 0.5), "rise": true, "kick": 0},
    "purify": {"particles": Color(0.9, 1.0, 0.85), "rise": true, "kick": 0},
    "sanctuary": {"flash": Color(1.0, 0.95, 0.7), "particles": Color(1.0, 0.85, 0.35), "amount": 8, "rise": true, "kick": 0},
    "judgement": {"flash": Color(1.0, 0.95, 0.7), "particles": Color(1.0, 0.85, 0.35), "amount": 10, "rise": true, "kick": 3, "heavy": true, "sound": "hit_holy"},
    "mass_heal": {"flash": Color(1.0, 0.95, 0.6), "particles": Color(1.0, 0.85, 0.35), "amount": 8, "rise": true, "kick": 0},
    # mage: fireball #FF4400 at 0.6 with embers, frost blue with shards, white-blue lightning
    "fire_burst": {"flash": Color(1.0, 0.267, 0.0, 0.6), "particles": Color(1.0, 0.267, 0.0), "extra": Color(1.0, 0.75, 0.3), "amount": 9, "spread": 120.0, "kick": 2, "heavy": true, "sound": "hit_fire"},
    "frost_bolt": {"flash": Color(0.6, 0.85, 1.0), "particles": Color(0.6, 0.85, 1.0), "extra": Color(0.95, 1.0, 1.0), "amount": 7, "kick": 2, "sound": "hit_ice"},
    "arcane_shield": {"flash": Color(0.75, 0.6, 1.0), "particles": Color(0.75, 0.6, 1.0), "kick": 0},
    "frost_nova": {"flash": Color(0.6, 0.85, 1.0), "particles": Color(0.6, 0.85, 1.0), "extra": Color(0.95, 1.0, 1.0), "amount": 8, "spread": 180.0, "kick": 2, "sound": "hit_ice"},
    "blink": {"particles": Color(0.75, 0.6, 1.0), "kick": 0},
    "chain_burn": {"flash": Color(1.0, 0.267, 0.0, 0.6), "particles": Color(1.0, 0.267, 0.0), "extra": Color(1.0, 0.75, 0.3), "amount": 7, "kick": 2, "sound": "hit_fire"},
    "meteor": {"flash": Color(1.0, 0.267, 0.0, 0.6), "particles": Color(1.0, 0.267, 0.0), "extra": Color(1.0, 0.75, 0.3), "amount": 14, "spread": 180.0, "speed": 120.0, "kick": 3, "heavy": true, "sound": "hit_fire_heavy"},
    "arcane_torrent": {"flash": Color(0.85, 0.92, 1.0), "particles": Color(0.85, 0.92, 1.0), "extra": Color(0.55, 0.7, 1.0), "amount": 9, "kick": 2, "heavy": true, "sound": "hit_lightning"},
    "counterspell": {"flash": Color(0.75, 0.85, 1.0), "particles": Color(0.55, 0.7, 1.0), "amount": 6, "kick": 1, "sound": "hit_lightning"},
}

const TYPE := {
    "enemy": {"particles": Color(0.85, 0.3, 0.3), "amount": 4, "kick": 1, "recoil": 1, "sound": "hit_flesh"},
    "bandit": {"particles": Color(0.85, 0.3, 0.3), "extra": Color(0.72, 0.62, 0.48), "amount": 5, "kick": 1, "recoil": 1, "sound": "hit_slash"},
    "boss": {"particles": Color(0.9, 0.35, 0.25), "extra": Color(0.72, 0.62, 0.48), "amount": 8, "kick": 3, "recoil": 2, "heavy": true, "sound": "hit_heavy"},
    "dot": {"flash_frames": 2, "particles": Color(0.7, 0.4, 0.9), "amount": 2, "kick": 0, "sound": ""},
    "block": {"flash": Color(0.7, 0.85, 1.0), "particles": Color(1.0, 0.9, 0.55), "amount": 6, "spread": 70.0, "speed": 100.0, "kick": 1, "sound": "hit_shield"},
    # death "pop": squash and stretch, flash, particles (the fade is the unit's own death animation)
    "death": {"flash": Color(1, 1, 1), "flash_frames": 4, "particles": Color(0.85, 0.3, 0.3), "amount": 12, "spread": 180.0, "speed": 80.0, "kick": 0, "squash": 0.3, "sound": "death_pop"},
}


## Every skill in SkillDefs must have its own profile (tests check it).
static func has_skill(id: String) -> bool:
    return SKILL.has(id)


## The raw table for an id: "skill.<id>", "basic.<class>", or a TYPE key. {} if unknown.
## D-145 creature attacks with their own feel: "eskill.<EnemyDefs skill>" and "eskill.basic_<projectile>"
## (a ranged creature's basic shot). Tagged on the DamageInfo by SandboxEnemy; JuicePlayer.resolve reads it.
const ENEMY := {
    "slam": {"particles": Color(0.6, 0.5, 0.38), "amount": 12, "spread": 140.0, "speed": 110.0, "kick": 3, "heavy": true, "sound": "hit_heavy"},
    "spore_cloud": {"particles": Color(0.55, 0.9, 0.3), "amount": 6, "spread": 160.0, "speed": 40.0, "kick": 0},
    "aimed_shot": {"flash": Color(0.85, 0.95, 1.0), "particles": Color(0.7, 0.52, 0.32), "amount": 8, "speed": 130.0, "kick": 3, "heavy": true, "sound": "hit_arrow_heavy"},
    "fireball": {"flash": Color(1.0, 0.27, 0.0, 0.6), "particles": Color(1.0, 0.27, 0.0), "extra": Color(1.0, 0.75, 0.2), "amount": 10, "kick": 2, "sound": "hit_fire"},
    "leap": {"particles": Color(0.6, 0.5, 0.38), "amount": 9, "spread": 120.0, "kick": 3, "sound": "hit_heavy"},
    "whirlwind": {"particles": Color(0.85, 0.3, 0.3), "extra": Color(0.72, 0.62, 0.48), "amount": 8, "spread": 180.0, "kick": 2, "heavy": true, "sound": "hit_slash"},
    "meteor": {"flash": Color(1.0, 0.4, 0.1), "particles": Color(1.0, 0.35, 0.05), "extra": Color(0.5, 0.45, 0.4), "amount": 14, "spread": 180.0, "kick": 3, "heavy": true, "sound": "hit_heavy"},
    "doom": {"flash": Color(0.7, 0.3, 1.0), "particles": Color(0.6, 0.3, 0.9), "amount": 12, "spread": 180.0, "kick": 3, "heavy": true},
    "crimson_wave": {"flash": Color(1.0, 0.2, 0.2), "particles": Color(0.85, 0.1, 0.1), "amount": 10, "spread": 160.0, "kick": 3, "heavy": true},
    "basic_arrow": {"particles": Color(0.7, 0.52, 0.32), "amount": 4, "spread": 30.0, "kick": 1, "sound": "hit_arrow"},
    "basic_fireball": {"flash": Color(1.0, 0.27, 0.0, 0.6), "particles": Color(1.0, 0.27, 0.0), "extra": Color(1.0, 0.75, 0.2), "amount": 6, "kick": 1, "sound": "hit_fire"},
    "basic_frost_shard": {"particles": Color(0.6, 0.85, 1.0), "extra": Color(0.95, 1.0, 1.0), "amount": 6, "kick": 1},
    "basic_arcane_bolt": {"particles": Color(0.7, 0.55, 1.0), "amount": 6, "kick": 1, "sound": "hit_lightning"},
    "basic_orb": {"particles": Color(0.55, 0.8, 1.0), "amount": 5, "kick": 1, "sound": "hit_lightning"},
    "basic_venom": {"particles": Color(0.55, 0.9, 0.3), "amount": 5, "kick": 1},
}


static func raw(id: String) -> Dictionary:
    if id.begins_with("skill."):
        return SKILL.get(id.substr(6), {})
    if id.begins_with("eskill."):
        return ENEMY.get(id.substr(7), {})
    if BASIC.has(id):
        return BASIC[id]
    return TYPE.get(id, {})


static func all_ids() -> Array:
    var out: Array = []
    for k in SKILL:
        out.append("skill." + String(k))
    out.append_array(BASIC.keys())
    out.append_array(TYPE.keys())
    for k in ENEMY:
        out.append("eskill." + String(k))
    return out
