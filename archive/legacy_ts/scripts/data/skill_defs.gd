class_name SkillDefs
extends RefCounted
## Skills as data (combat Phase 3). A skill = cost in the class resource (D-041) + cooldown +
## optional cast time (interruptible only by control, D-042) + targeting + a list of effects.
## Heroes start with only the basic attack on Q (D-142) and choose more at
## LEARN_LEVELS (D-045, D-142) or learn them from books (D-046). Numbers are tuning placeholders.
##
## target: "enemy" (nearest/current enemy in range) | "self" | "ally_low" (most hurt ally in range,
##         self included) | "self_aoe" (around the caster) | "target_aoe" (around the enemy target)
## effects: {"t": "damage", "mult", "kind"("power"|"physical"|"magical"|"true")}
##          {"t": "status", "id", "dur", "mult"(of power, for dots/shields) or "mag"}
##          {"t": "heal", "mult"(of magic power)} {"t": "heal_pct", "pct"} {"t": "shield", "pct"(of max hp)}
##          {"t": "knockback", "dist"} {"t": "interrupt"} {"t": "dash"} {"t": "blink", "dist"}
##          {"t": "taunt", "radius", "dur"}
##          {"t": "cleanse"} {"t": "zone", "radius", "dur", "status", "sdur", "foes"(bool), "once"(bool)}
##          {"t": "allies", "radius", "inner": [effects]}  (applies inner effects to allies around)

## D-142 (owner, 2026-11-02, replaces the D-090 "2, 5 and every 5"): heroes start with only Q (the basic
## attack, D-059) and choose 1 skill out of CHOICE_OPTIONS at levels 2, 5 and 10, one for each of W, E and R:
## at most 4 actives (Q + 3). The options not taken are gone for that choice. LEARN_LEVELS kept for old callers.
const CHOICE_LEVELS := [2, 5, 10]
const CHOICE_OPTIONS := 3
const LEARN_LEVELS := [2, 5, 10]
const MAX_SLOTS := 3   # keys W E R (Q is the basic attack: 4 actives in all)
## D-142: only these skills (effect "interrupt") break a creature's cast; stuns and knock-backs no longer do.
const INTERRUPTERS := ["ambush", "interrupt_shot", "counterspell"]
## D-142: class actions bound to F instead of a W/E/R slot (not learnable, not in the kits). The cleric's
## Resurrection is how a cleric lifts a fallen ally (agony, D-036/D-082): a channel of "channel" seconds
## that a hit breaks, the ally back with "hp" of max HP. Death is still permanent once the agony ends (D-011).
const F_ACTIONS := {
    "class.cleric": {"id": "resurrection", "name": "Resurrection", "channel": 4.0, "hp": 0.25,
        "desc": "F next to a fallen ally: a 4 s prayer lifts them (a hit breaks it)."},
}

## D-041 class resources, redone by D-090. max = base + per point of the scaling attribute.
## regen = per second (regen_combat while fighting, regen_still while standing still, when given);
## decay = per second lost out of combat; on_hit / on_hurt = gained per blow dealt / taken.
## "none" (commoners): no resource; their skills only have a cooldown.
## Mana: comes back slowly out of combat (owner, 2026-11-02) and only a trickle while fighting; a camp refills it (CampDefs).
const RESOURCES := {
    "fury": {"name": "Fury", "color": Color(0.9, 0.3, 0.2), "base": 100, "start": 0.2, "regen": 0.0, "decay": 6.0, "on_hit": 10.0, "on_hurt": 12.0},
    "energy": {"name": "Energy", "color": Color(0.95, 0.85, 0.3), "base": 100, "start": 1.0, "regen": 10.0, "decay": 0.0, "on_hit": 0.0, "on_hurt": 0.0},
    "concentration": {"name": "Concentration", "color": Color(0.55, 0.95, 0.55), "base": 100, "start": 1.0, "regen": 5.0, "regen_still": 14.0, "decay": 0.0, "on_hit": 0.0, "on_hurt": 0.0},
    "mana": {"name": "Mana", "color": Color(0.35, 0.55, 1.0), "base": 60, "per_attr": "int", "per": 6, "start": 1.0, "regen": 1.5, "regen_combat": 1.0, "decay": 0.0, "on_hit": 0.0, "on_hurt": 0.0},
    "none": {"name": "None", "color": Color(0.6, 0.6, 0.6), "base": 0, "start": 0.0, "regen": 0.0, "decay": 0.0, "on_hit": 0.0, "on_hurt": 0.0},
}
const CLASS_RESOURCE := {"class.warrior": "fury", "class.rogue": "energy", "class.archer": "concentration",
    "class.mage": "mana", "class.cleric": "mana", "class.commoner": "none", "class.none": "none"}
## Rogue combo points: every basic attack and every skill with "combo": n builds them (max COMBO_MAX);
## a "finisher" skill needs at least 1 and spends them all, x (1 + FINISHER_PER_COMBO x points).
const COMBO_MAX := 5
const COMBO_PER_BASIC := 1
const FINISHER_PER_COMBO := 0.25
## Seconds a hero counts as "in combat" after it hits, is hit or has a foe targeted (resource regen/decay).
const COMBAT_LINGER := 4.0

const KITS := {
    "class.none": {"start": ["second_breath"], "learn": ["improvised_strike", "shove", "rally"]},
    "class.commoner": {"start": ["improvised_strike", "second_breath", "shove"], "learn": ["rally", "dirty_trick", "second_breath", "improvised_strike", "shove"]},
    "class.warrior": {"start": ["cleave", "shield_bash", "war_cry"], "learn": ["charge", "shield_wall", "whirlwind", "rallying_shout", "earthshatter", "cleave", "shield_bash", "war_cry"]},
    "class.rogue": {"start": ["quick_slash", "poison_blade", "shadow_step"], "learn": ["ambush", "eviscerate", "backstab", "smoke_bomb", "fan_of_knives", "kidney_shot", "quick_slash", "poison_blade", "shadow_step"]},
    "class.archer": {"start": ["rapid_shot", "snare_shot", "volley"], "learn": ["interrupt_shot", "hunters_mark", "bear_trap", "piercing_shot", "concussive_shot", "rain_of_arrows", "rapid_shot", "snare_shot", "volley"]},
    "class.cleric": {"start": ["heal", "smite", "holy_radiance"], "learn": ["blessing", "purify", "sanctuary", "judgement", "mass_heal", "heal", "smite", "holy_radiance"]},
    "class.mage": {"start": ["fire_burst", "frost_bolt", "arcane_shield"], "learn": ["counterspell", "frost_nova", "blink", "chain_burn", "meteor", "arcane_torrent", "fire_burst", "frost_bolt", "arcane_shield"]},
}

const SKILLS := {
    # --- shared / commoner
    "second_breath": {"name": "Second Breath", "class": "", "cost": 0, "cd": 20.0, "cast": 0.0, "range": 0.0, "target": "self",
        "effects": [{"t": "heal_pct", "pct": 0.25}], "desc": "Recover 25% of max HP."},
    "improvised_strike": {"name": "Improvised Strike", "class": "class.commoner", "cost": 0, "cd": 8.0, "cast": 0.0, "range": 60.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 1.5, "kind": "power"}], "desc": "A clumsy but surprisingly effective swing."},
    "shove": {"name": "Shove", "class": "class.commoner", "cost": 0, "cd": 12.0, "cast": 0.0, "range": 55.0, "target": "enemy",
        "effects": [{"t": "knockback", "dist": 70.0}, {"t": "damage", "mult": 0.5, "kind": "power"}], "desc": "Push a foe away."},
    "rally": {"name": "Rally", "class": "class.commoner", "cost": 0, "cd": 25.0, "cast": 0.0, "range": 0.0, "target": "self",
        "effects": [{"t": "allies", "radius": 140.0, "inner": [{"t": "shield", "pct": 0.12}]}], "desc": "Shield nearby allies for 12% of their max HP."},
    "dirty_trick": {"name": "Dirty Trick", "class": "class.commoner", "cost": 0, "cd": 16.0, "cast": 0.0, "range": 55.0, "target": "enemy",
        "effects": [{"t": "status", "id": "weaken", "dur": 4.0}, {"t": "status", "id": "slow", "dur": 3.0}], "desc": "Sand in the eyes: weaken and slow a foe."},
    # --- warrior (fury)
    "cleave": {"name": "Cleave", "class": "class.warrior", "cost": 30, "cd": 9.0, "cast": 0.0, "range": 75.0, "target": "self_aoe",
        "effects": [{"t": "damage", "mult": 1.4, "kind": "power"}], "desc": "Hit every enemy around you."},
    "shield_bash": {"name": "Shield Bash", "class": "class.warrior", "cost": 25, "cd": 12.0, "cast": 0.0, "range": 55.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 0.8, "kind": "power"}, {"t": "status", "id": "stun", "dur": 1.5}], "desc": "Stun a foe."},
    "war_cry": {"name": "War Cry", "class": "class.warrior", "cost": 20, "cd": 18.0, "cast": 0.0, "range": 160.0, "target": "self",
        "effects": [{"t": "taunt", "radius": 160.0, "dur": 3.5}, {"t": "shield", "pct": 0.15}], "desc": "Enemies nearby attack you instead; gain a shield."},
    "charge": {"name": "Charge", "class": "class.warrior", "cost": 25, "cd": 14.0, "cast": 0.0, "range": 260.0, "target": "enemy",
        "effects": [{"t": "dash"}, {"t": "status", "id": "root", "dur": 1.5}, {"t": "damage", "mult": 1.0, "kind": "power"}], "desc": "Rush a distant foe and pin it in place."},
    "shield_wall": {"name": "Shield Wall", "class": "class.warrior", "cost": 40, "cd": 25.0, "cast": 0.0, "range": 0.0, "target": "self",
        "effects": [{"t": "shield", "pct": 0.45}], "desc": "A huge shield for a few hard hits."},
    "whirlwind": {"name": "Whirlwind", "class": "class.warrior", "cost": 60, "cd": 16.0, "cast": 0.0, "range": 95.0, "target": "self_aoe",
        "effects": [{"t": "damage", "mult": 2.0, "kind": "power"}, {"t": "status", "id": "bleed", "dur": 4.0, "mult": 0.15}], "desc": "Spin through everything nearby; wounds bleed."},
    "rallying_shout": {"name": "Rallying Shout", "class": "class.warrior", "cost": 50, "cd": 30.0, "cast": 0.0, "range": 0.0, "target": "self",
        "effects": [{"t": "allies", "radius": 180.0, "inner": [{"t": "shield", "pct": 0.2}, {"t": "cleanse"}]}], "desc": "Shield allies around you and shake off their ailments."},
    "earthshatter": {"name": "Earthshatter", "class": "class.warrior", "cost": 80, "cd": 35.0, "cast": 0.8, "range": 120.0, "target": "self_aoe",
        "effects": [{"t": "damage", "mult": 2.4, "kind": "power"}, {"t": "status", "id": "stun", "dur": 2.0}], "desc": "Slam the ground: damage and stun everything around."},
    # --- rogue (focus)
    "quick_slash": {"name": "Quick Slash", "class": "class.rogue", "cost": 25, "combo": 1, "cd": 6.0, "cast": 0.0, "range": 60.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 1.9, "kind": "power"}], "desc": "One heavy strike on a nearby enemy."},
    "poison_blade": {"name": "Poison Blade", "class": "class.rogue", "cost": 30, "combo": 1, "cd": 10.0, "cast": 0.0, "range": 60.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 0.8, "kind": "power"}, {"t": "status", "id": "poison", "dur": 6.0, "mult": 0.35}], "desc": "Coat the blade: strong poison over time (stacks)."},
    "shadow_step": {"name": "Shadow Step", "class": "class.rogue", "cost": 35, "combo": 1, "cd": 14.0, "cast": 0.0, "range": 280.0, "target": "enemy",
        "effects": [{"t": "dash"}, {"t": "damage", "mult": 1.2, "kind": "power"}], "desc": "Vanish and strike a distant enemy (great on archers)."},
    "backstab": {"name": "Backstab", "class": "class.rogue", "cost": 40, "combo": 2, "cd": 9.0, "cast": 0.0, "range": 60.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 2.2, "kind": "power", "bonus_if_busy": 1.6}], "desc": "Massive damage to a foe busy fighting someone else."},
    "smoke_bomb": {"name": "Smoke Bomb", "class": "class.rogue", "cost": 45, "cd": 22.0, "cast": 0.0, "range": 0.0, "target": "self",
        "effects": [{"t": "zone", "radius": 90.0, "dur": 5.0, "status": "weaken", "sdur": 1.0, "foes": true}], "desc": "Foes inside the smoke hit weaker."},
    "fan_of_knives": {"name": "Fan of Knives", "class": "class.rogue", "cost": 50, "cd": 14.0, "cast": 0.0, "range": 110.0, "target": "self_aoe",
        "effects": [{"t": "damage", "mult": 1.1, "kind": "power"}, {"t": "status", "id": "bleed", "dur": 4.0, "mult": 0.15}], "desc": "Knives in every direction; everything bleeds."},
    "kidney_shot": {"name": "Kidney Shot", "class": "class.rogue", "cost": 25, "finisher": true, "cd": 16.0, "cast": 0.0, "range": 60.0, "target": "enemy",
        "effects": [{"t": "status", "id": "stun", "dur": 2.0}], "desc": "Finisher: stun a foe (longer with more combo points)."},
    "eviscerate": {"name": "Eviscerate", "class": "class.rogue", "cost": 35, "finisher": true, "cd": 10.0, "cast": 0.0, "range": 60.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 2.2, "kind": "power"}], "desc": "Finisher: one brutal strike, stronger with every combo point."},
    "ambush": {"name": "Ambush", "class": "class.rogue", "cost": 30, "combo": 1, "cd": 14.0, "cast": 0.0, "range": 200.0, "target": "enemy",
        "effects": [{"t": "dash"}, {"t": "damage", "mult": 0.9, "kind": "power"}, {"t": "interrupt"}], "desc": "Leap on a foe and cut its cast short."},
    # --- archer (concentration)
    "rapid_shot": {"name": "Rapid Shot", "class": "class.archer", "cost": 25, "cd": 7.0, "cast": 0.0, "range": 220.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 1.8, "kind": "power"}], "desc": "Swift double shot from distance."},
    "snare_shot": {"name": "Snare Shot", "class": "class.archer", "cost": 30, "cd": 12.0, "cast": 0.0, "range": 220.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 0.6, "kind": "power"}, {"t": "status", "id": "root", "dur": 2.5}], "desc": "Pin a charging foe in place."},
    "volley": {"name": "Volley", "class": "class.archer", "cost": 40, "cd": 14.0, "cast": 0.5, "range": 240.0, "target": "target_aoe", "radius": 75.0,
        "effects": [{"t": "damage", "mult": 1.1, "kind": "power"}], "desc": "Arrows rain on a group (short aim)."},
    "hunters_mark": {"name": "Hunter's Mark", "class": "class.archer", "cost": 20, "cd": 15.0, "cast": 0.0, "range": 260.0, "target": "enemy",
        "effects": [{"t": "status", "id": "marked", "dur": 8.0}], "desc": "Reveals the target through the fog; the whole squad deals it 15% more damage."},
    "bear_trap": {"name": "Bear Trap", "class": "class.archer", "cost": 35, "cd": 20.0, "cast": 0.0, "range": 0.0, "target": "self",
        "effects": [{"t": "zone", "radius": 50.0, "dur": 15.0, "status": "root", "sdur": 2.5, "foes": true, "once": true}], "desc": "A trap at your feet roots the first foes that step in."},
    "piercing_shot": {"name": "Piercing Shot", "class": "class.archer", "cost": 45, "cd": 12.0, "cast": 0.4, "range": 260.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 2.6, "kind": "true"}], "desc": "Ignores armor."},
    "concussive_shot": {"name": "Concussive Shot", "class": "class.archer", "cost": 30, "cd": 14.0, "cast": 0.0, "range": 220.0, "target": "enemy",
        "effects": [{"t": "knockback", "dist": 60.0}, {"t": "status", "id": "slow", "dur": 3.0}], "desc": "Knock a foe back and slow it."},
    "rain_of_arrows": {"name": "Rain of Arrows", "class": "class.archer", "cost": 80, "cd": 30.0, "cast": 1.0, "range": 260.0, "target": "target_aoe", "radius": 120.0,
        "effects": [{"t": "damage", "mult": 2.2, "kind": "power"}, {"t": "status", "id": "slow", "dur": 3.0}], "desc": "A storm of arrows over a wide area."},
    "interrupt_shot": {"name": "Interrupting Shot", "class": "class.archer", "cost": 25, "cd": 12.0, "cast": 0.0, "range": 240.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 0.6, "kind": "power"}, {"t": "interrupt"}], "desc": "A quick arrow that cuts a foe's cast short."},
    # --- cleric (mana)
    "heal": {"name": "Heal", "class": "class.cleric", "cost": 20, "cd": 4.0, "cast": 0.6, "range": 200.0, "target": "ally_low",
        "effects": [{"t": "heal", "mult": 3.0}], "desc": "Heal the most wounded ally in range."},
    "smite": {"name": "Smite", "class": "class.cleric", "cost": 15, "cd": 7.0, "cast": 0.0, "range": 200.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 1.6, "kind": "magical"}], "desc": "Holy light burns a foe (magic)."},
    "holy_radiance": {"name": "Holy Radiance", "class": "class.cleric", "cost": 35, "cd": 16.0, "cast": 0.0, "range": 0.0, "target": "self",
        "effects": [{"t": "allies", "radius": 150.0, "inner": [{"t": "heal", "mult": 1.2}]}], "desc": "Heal every ally around you."},
    "blessing": {"name": "Blessing", "class": "class.cleric", "cost": 25, "cd": 14.0, "cast": 0.0, "range": 200.0, "target": "ally_low",
        "effects": [{"t": "shield", "pct": 0.3}], "desc": "Shield the most wounded ally."},
    "purify": {"name": "Purify", "class": "class.cleric", "cost": 15, "cd": 10.0, "cast": 0.0, "range": 200.0, "target": "ally_low",
        "effects": [{"t": "cleanse"}, {"t": "heal", "mult": 0.6}], "desc": "Remove poison, stun and other ailments."},
    "sanctuary": {"name": "Sanctuary", "class": "class.cleric", "cost": 50, "cd": 30.0, "cast": 0.8, "range": 0.0, "target": "self",
        "effects": [{"t": "zone", "radius": 110.0, "dur": 8.0, "status": "regen", "sdur": 1.0, "foes": false}], "desc": "Holy ground: allies inside regenerate."},
    "judgement": {"name": "Judgement", "class": "class.cleric", "cost": 30, "cd": 15.0, "cast": 0.0, "range": 200.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 1.2, "kind": "magical"}, {"t": "status", "id": "stun", "dur": 1.2}], "desc": "Stun a foe with holy force."},
    "mass_heal": {"name": "Mass Heal", "class": "class.cleric", "cost": 70, "cd": 35.0, "cast": 1.2, "range": 0.0, "target": "self",
        "effects": [{"t": "allies", "radius": 260.0, "inner": [{"t": "heal", "mult": 2.5}, {"t": "cleanse"}]}], "desc": "A long prayer that heals and cleanses the whole squad."},
    # --- mage (mana)
    "fire_burst": {"name": "Fire Burst", "class": "class.mage", "cost": 25, "cd": 9.0, "cast": 0.5, "range": 210.0, "target": "target_aoe", "radius": 80.0,
        "effects": [{"t": "damage", "mult": 1.5, "kind": "magical"}, {"t": "status", "id": "burn", "dur": 4.0, "mult": 0.15}], "desc": "Explosion around the target; it keeps burning."},
    "frost_bolt": {"name": "Frost Bolt", "class": "class.mage", "cost": 15, "cd": 5.0, "cast": 0.4, "range": 220.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 1.4, "kind": "magical"}, {"t": "status", "id": "slow", "dur": 3.0}], "desc": "A bolt of ice that slows."},
    "arcane_shield": {"name": "Arcane Shield", "class": "class.mage", "cost": 20, "cd": 18.0, "cast": 0.0, "range": 0.0, "target": "self",
        "effects": [{"t": "shield", "pct": 0.35}], "desc": "A barrier for the fragile caster."},
    "frost_nova": {"name": "Frost Nova", "class": "class.mage", "cost": 35, "cd": 18.0, "cast": 0.0, "range": 100.0, "target": "self_aoe",
        "effects": [{"t": "damage", "mult": 0.8, "kind": "magical"}, {"t": "status", "id": "frozen", "dur": 2.5}], "desc": "Freeze everything around you in place (a heavy blow shatters the ice)."},
    "blink": {"name": "Blink", "class": "class.mage", "cost": 15, "cd": 12.0, "cast": 0.0, "range": 0.0, "target": "self",
        "effects": [{"t": "blink", "dist": 140.0}], "desc": "Teleport away from danger."},
    "chain_burn": {"name": "Chain Burn", "class": "class.mage", "cost": 40, "cd": 14.0, "cast": 0.6, "range": 220.0, "target": "target_aoe", "radius": 140.0,
        "effects": [{"t": "status", "id": "burn", "dur": 6.0, "mult": 0.25}], "desc": "Set a whole group on fire."},
    "meteor": {"name": "Meteor", "class": "class.mage", "cost": 70, "cd": 30.0, "cast": 1.5, "range": 260.0, "target": "target_aoe", "radius": 110.0,
        "effects": [{"t": "damage", "mult": 3.2, "kind": "magical"}, {"t": "status", "id": "stun", "dur": 1.0}], "desc": "A long cast, a devastating impact."},
    "arcane_torrent": {"name": "Arcane Torrent", "class": "class.mage", "cost": 50, "cd": 16.0, "cast": 0.8, "range": 230.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 2.8, "kind": "magical"}], "desc": "A raw blast of arcane force."},
    "counterspell": {"name": "Counterspell", "class": "class.mage", "cost": 20, "cd": 14.0, "cast": 0.0, "range": 230.0, "target": "enemy",
        "effects": [{"t": "damage", "mult": 0.4, "kind": "magical"}, {"t": "interrupt"}], "desc": "Unravel a foe's spell while it is being cast."},
}


static func info(id: String) -> Dictionary:
    return SKILLS.get(id, {})


## True when a hero of this class may know the skill (its class kit, or a shared skill).
static func usable_by(id: String, class_id: String) -> bool:
    if not SKILLS.has(id):
        return false
    var kit: Dictionary = KITS.get(class_id, KITS["class.none"])
    return String(SKILLS[id]["class"]) in ["", class_id] or (kit["start"] as Array).has(id) or (kit["learn"] as Array).has(id)


## Every skill a book can teach to one of these classes (D-046), sorted for determinism.
static func book_pool(class_ids: Array) -> Array:
    var out: Array = []
    for c in class_ids:
        var kit: Dictionary = KITS.get(c, KITS["class.none"])
        for s in (kit["start"] as Array) + (kit["learn"] as Array):
            if not out.has(s):
                out.append(s)
    out.sort()
    return out


static func resource_of(class_id: String) -> String:
    return String(CLASS_RESOURCE.get(class_id, "none"))


## D-044 (superseded by D-142: new heroes start with no active; kept for old callers and the creator's
## preview): the class active a seed would have picked from the class pool (separate RNG,
## so the rest of the hero generation is untouched).
static func starter_for(class_id: String, hero_seed: int) -> String:
    var pool: Array = KITS.get(class_id, KITS["class.none"])["start"]
    var r := RandomNumberGenerator.new()
    r.seed = hero_seed ^ 0x51e117
    return String(pool[r.randi() % pool.size()])


## D-045 / D-090: up to CHOICE_OPTIONS (+ extra) class skills the hero does not know yet (deterministic
## per hero and level). extra = the bonus option of a skill tome (pista D's bonus_skill_choice).
static func level_choices(class_id: String, known: Array, level: int, hero_seed: int, extra: int = 0) -> Array:
    var pool: Array = []
    for s in KITS.get(class_id, KITS["class.none"])["learn"]:
        if not known.has(s) and not pool.has(s):
            pool.append(s)
    var r := RandomNumberGenerator.new()
    r.seed = hero_seed ^ (level * 7919)
    var out: Array = []
    while not pool.is_empty() and out.size() < CHOICE_OPTIONS + maxi(0, extra):
        out.append(pool.pop_at(r.randi() % pool.size()))
    return out


## D-142: the levels that bring a skill choice (2, 5 and 10: W, E and R).
static func choice_levels() -> Array:
    return CHOICE_LEVELS.duplicate()


## D-142: the F action of a class ({} = the common lift of D-082).
static func f_action(class_id: String) -> Dictionary:
    return F_ACTIONS.get(class_id, {})


static func is_finisher(id: String) -> bool:
    return bool(info(id).get("finisher", false))


## The cost a hero really pays (classes with no resource pay nothing).
static func cost_for(id: String, class_id: String) -> float:
    return 0.0 if resource_of(class_id) == "none" else float(info(id).get("cost", 0))
