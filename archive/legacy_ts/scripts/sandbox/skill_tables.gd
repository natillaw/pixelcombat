class_name SkillTables
extends RefCounted
## One active skill per hero, chosen by class (T-009). All numbers are provisional (D-012).
## kind: "target"      damage to the current/nearest enemy within `range`
##       "target_aoe"  damage to every enemy within `radius` of that target
##       "self_aoe"    damage to every enemy within `radius` of the hero
##       "self_heal"   heals the hero for `heal` of max HP
## `mult` multiplies the hero's power (max of ATK/MAG) before DEF mitigation.
## Skills are activated by the player only (key Q / panel button); they are never refused
## randomly. They are refused only when on cooldown or when there is nothing to hit.

const SKILLS := {
    "class.none": {"name": "Second Breath", "kind": "self_heal", "heal": 0.25, "cooldown": 20.0,
        "desc": "Recover 25% max HP."},
    "class.commoner": {"name": "Improvised Strike", "kind": "target", "mult": 1.4, "range": 60.0, "cooldown": 10.0,
        "desc": "A clumsy but surprisingly effective swing."},
    "class.warrior": {"name": "Cleave", "kind": "self_aoe", "mult": 1.6, "radius": 75.0, "cooldown": 12.0,
        "desc": "Hit every enemy around you."},
    "class.rogue": {"name": "Quick Slash", "kind": "target", "mult": 2.2, "range": 70.0, "cooldown": 9.0,
        "desc": "One heavy strike on a nearby enemy."},
    "class.archer": {"name": "Rapid Shot", "kind": "target", "mult": 1.9, "range": 220.0, "cooldown": 10.0,
        "desc": "Swift double shot from distance."},
    "class.cleric": {"name": "Holy Radiance", "kind": "self_heal", "heal": 0.35, "cooldown": 16.0,
        "desc": "Channel holy light to heal 35% max HP."},
    "class.mage": {"name": "Fire Burst", "kind": "target_aoe", "mult": 1.8, "range": 210.0, "radius": 80.0, "cooldown": 14.0,
        "desc": "Explosion around the target."},
}


static func for_class(class_id: String) -> Dictionary:
    return SKILLS.get(class_id, SKILLS["class.none"])
