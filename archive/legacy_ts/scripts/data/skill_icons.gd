class_name SkillIcons
extends RefCounted
## Which KURAI skill icon (8 x 6 sheet of 32 px, AssetCatalog.SKILL_ICONS) each skill shows, picked by
## look (row-major index: 0 orb, 4 lightning, 8 heal cross, 14 bear, 19 slash, 25 explosion, 33 eye...).
## A skill not in the table gets a stable icon from its id. Data only: change the table to retheme.

const BY_SKILL := {
    # mage
    "fire_burst": 25, "meteor": 26, "chain_burn": 27, "frost_bolt": 0, "frost_nova": 6, "arcane_torrent": 4, "arcane_shield": 32, "blink": 2, "counterspell": 5,
    # cleric
    "heal": 8, "mass_heal": 1, "holy_radiance": 29, "sanctuary": 12, "smite": 30, "judgement": 4, "blessing": 9, "purify": 12,
    # warrior
    "cleave": 19, "whirlwind": 23, "earthshatter": 18, "shield_bash": 16, "shield_wall": 47, "war_cry": 21, "rallying_shout": 9, "charge": 3,
    # rogue
    "quick_slash": 17, "backstab": 38, "eviscerate": 18, "poison_blade": 10, "fan_of_knives": 15, "smoke_bomb": 36, "shadow_step": 37, "kidney_shot": 42, "ambush": 39,
    # archer
    "rapid_shot": 43, "piercing_shot": 31, "volley": 26, "rain_of_arrows": 7, "snare_shot": 46, "concussive_shot": 25, "hunters_mark": 33, "bear_trap": 14, "interrupt_shot": 44,
    # commoner / shared
    "second_breath": 13, "improvised_strike": 42, "shove": 3, "rally": 9, "dirty_trick": 35,
}
const COUNT := 48


static func index_of(skill_id: String) -> int:
    if BY_SKILL.has(skill_id):
        return int(BY_SKILL[skill_id])
    return absi(hash(skill_id)) % COUNT
