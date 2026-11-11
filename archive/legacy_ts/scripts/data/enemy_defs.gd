class_name EnemyDefs
extends RefCounted
## Creature stats and combat roles (D-056: difficulty from composition, not from inflated health).
## Numbers are tuning placeholders for early floors (heroes of 1-2 stars, level 1-5: ~100-130 HP and
## ~12 damage per second each). Body size (reach, wind-up, mass) comes from CombatRules.SIZE on top.
##
## Roles: swarm = fast and frail, comes in numbers; melee = standard fighter; brute = slow heavy hitter;
## guard = holds a spot (leash) with armour; ranged = strikes from afar and backs off; support = heals
## hurt allies and stays behind them. status = applied to heroes its strike hits ({id, dur, mag}).

## assassin (master prompt D/H) = melee that always hunts the backline (healers, casters) and leaps to it.
const ROLES := ["swarm", "melee", "brute", "guard", "ranged", "support", "assassin"]
const DEFAULT := {"hp": 60, "atk": 12, "armor": 3, "mres": 2, "speed": 62.0, "role": "melee"}

const TYPES := {
    # tower floors (Voxel Dungeon creatures, D-031 forest)
    "rat": {"hp": 28, "atk": 5, "armor": 0, "mres": 0, "speed": 88.0, "role": "swarm", "windup": 0.55, "recover": 0.5},
    "bat": {"hp": 22, "atk": 5, "armor": 0, "mres": 1, "speed": 100.0, "role": "swarm", "windup": 0.5, "recover": 0.5},
    "slime_green": {"hp": 55, "atk": 8, "armor": 2, "mres": 1, "speed": 48.0, "role": "melee", "windup": 0.8},
    "slime_blue": {"hp": 65, "atk": 9, "armor": 3, "mres": 4, "speed": 48.0, "role": "melee", "windup": 0.8,
        "status": {"id": "slow", "dur": 2.0, "mag": 0.0}},
    "mushroom_red": {"hp": 45, "atk": 4, "armor": 1, "mres": 3, "speed": 40.0, "role": "support", "skills": ["mend"]},
    "mushroom_blue": {"hp": 50, "atk": 4, "armor": 1, "mres": 5, "speed": 40.0, "role": "support", "skills": ["mend", "ward"]},
    "mushroom_purple": {"hp": 45, "atk": 7, "armor": 1, "mres": 3, "speed": 42.0, "role": "ranged",
        "status": {"id": "poison", "dur": 4.0, "mag": 2.0}, "skills": ["spore_cloud"]},
    "spider": {"hp": 40, "atk": 8, "armor": 1, "mres": 1, "speed": 70.0, "role": "ranged",
        "status": {"id": "poison", "dur": 3.0, "mag": 2.0}, "skills": ["aimed_shot"]},
    "goblin": {"hp": 60, "atk": 10, "armor": 2, "mres": 1, "speed": 70.0, "role": "melee"},
    "hobgoblin": {"hp": 110, "atk": 13, "armor": 6, "mres": 2, "speed": 58.0, "role": "guard", "skills": ["rally", "slam"]},
    "orc_brute": {"hp": 170, "atk": 18, "armor": 5, "mres": 2, "speed": 56.0, "role": "brute", "skills": ["slam"]},
    "golem": {"hp": 320, "atk": 24, "armor": 10, "mres": 6, "speed": 40.0, "role": "brute", "skills": ["slam"]},
    "orc_chieftain": {"hp": 150, "atk": 14, "armor": 6, "mres": 3, "speed": 60.0, "role": "brute", "skills": ["slam", "rally"]},
    "warlord": {"hp": 120, "atk": 13, "armor": 5, "mres": 3, "speed": 58.0, "role": "brute", "skills": ["slam", "rally"]},   # floor 5 boss (make_boss scales it)
    # master prompt H (2026-10-31): the bandit band, Tiny Pixel Fantasy layers (BanditArt). Same ash-brown
    # clothes for all, red scarf; told apart by silhouette and weapon.
    "bandido_maton": {"hp": 85, "atk": 14, "armor": 3, "mres": 1, "speed": 54.0, "role": "melee", "windup": 1.0, "recover": 0.9},
    "bandido_arquero": {"hp": 45, "atk": 9, "armor": 1, "mres": 1, "speed": 66.0, "role": "ranged", "skills": ["aimed_shot"]},
    "bandido_degollador": {"hp": 55, "atk": 12, "armor": 1, "mres": 1, "speed": 86.0, "role": "assassin", "windup": 0.55, "skills": ["leap"]},
    "bandido_bruto": {"hp": 150, "atk": 11, "armor": 8, "mres": 2, "speed": 48.0, "role": "guard", "skills": ["slam"]},
    "bandido_mago": {"hp": 40, "atk": 8, "armor": 0, "mres": 4, "speed": 56.0, "role": "ranged", "skills": ["fireball"]},
    "bandido_chaman": {"hp": 50, "atk": 4, "armor": 1, "mres": 4, "speed": 50.0, "role": "support", "skills": ["mend", "ward"]},
    "capitan_bandido": {"hp": 140, "atk": 15, "armor": 6, "mres": 3, "speed": 60.0, "role": "brute", "skills": ["slam", "rally"]},
    "totem_bandido": {"hp": 240, "atk": 0, "armor": 4, "mres": 4, "speed": 0.0, "role": "guard", "threat": 0},   # sabotage (FloorMods)
    "jefe_baron_carmesi": {"hp": 220, "atk": 18, "armor": 8, "mres": 5, "speed": 58.0, "role": "brute", "skills": ["slam"]},
    # training ground (Pixel Crawler mobs): the old shared numbers, with roles
    "orc": {"role": "melee"},
    "orc_rogue": {"role": "melee", "speed": 72.0},
    "orc_warrior": {"role": "guard", "armor": 5},
    "orc_shaman": {"role": "support"},
    "skeleton_base": {"role": "melee"},
    "skeleton_rogue": {"role": "melee", "speed": 72.0},
    "skeleton_warrior": {"role": "guard", "armor": 5},
    "skeleton_mage": {"role": "ranged"},
}

## Drops: resource -> [chance, min, max], rolled when the creature dies (kept by the expedition ledger).
const DROPS := {
    "rat": {"hide": [0.6, 1, 1], "fang": [0.4, 1, 1]},
    "bat": {"hide": [0.5, 1, 1], "fang": [0.3, 1, 1]},
    "slime_green": {"gel": [0.8, 1, 2]},
    "slime_blue": {"gel": [0.9, 1, 2]},
    "mushroom_red": {"spore": [0.8, 1, 2], "herb": [0.5, 1, 1]},
    "mushroom_blue": {"spore": [0.8, 1, 2], "herb": [0.5, 1, 1]},
    "mushroom_purple": {"spore": [0.9, 1, 2], "venom": [0.3, 1, 1]},
    "spider": {"silk": [0.8, 1, 2], "venom": [0.5, 1, 1]},
    "goblin": {"fang": [0.4, 1, 1], "bone": [0.5, 1, 1], "ore": [0.3, 1, 2]},
    "hobgoblin": {"bone": [0.8, 1, 2], "hide": [0.5, 1, 2], "ingot": [0.2, 1, 1]},
    "orc_brute": {"bone": [0.9, 1, 2], "hide": [0.7, 1, 2]},
    "golem": {"core": [0.6, 1, 1], "stone": [1.0, 2, 4], "ore": [0.8, 1, 3]},
    "orc_chieftain": {"core": [1.0, 1, 1], "bone": [1.0, 2, 3]},
    "warlord": {"hide": [1.0, 3, 5], "bone": [1.0, 2, 3], "core": [0.5, 1, 1]},
}
## D-066: in the tower creatures leave no parts (those are hunted in the Wilds); since the master prompt
## (2026-10-31) tower drops are per floor in LootDefs.
const XP_PER_HP := 0.2            # experience a creature is worth (its max HP x this)


const RANGED_RANGE := 150.0       # ranged strike distance (the marked circle is at the hero's feet)
const RANGED_RADIUS := 30.0       # a ranged strike hits a small circle: one hero, dodgeable by moving
const BACK_OFF := 70.0            # ranged and support creatures step back when a hero is this close
const SUPPORT_HEAL := 0.2         # fraction of the patient's max HP
const SUPPORT_EVERY := 5.0        # seconds between heals
const SUPPORT_REACH := 170.0
const GUARD_LEASH := 160.0        # a guard never follows further than this from its post
const AMBUSH_WAKE := 90.0         # an ambusher stays hidden and still until a hero is this close
const ALERT_PERCEPTION := 1.6     # an alerted group sees further (one of them was attacked or spotted you)
const FLOOR_SCALE := 0.10         # +10% health per floor above the first (D-065: difficulty comes from mechanics)
## 2026-10-31: damage climbs faster than health (enemies hit hard, they are not sponges): +FLOOR_ATK_SCALE
## per floor above the first. Without crafted armour floor 5+ hits are brutal.
const FLOOR_ATK_SCALE := 0.22
## D-082b: minimum content of a floor (ProceduralMap.ensure_density): at least ENCOUNTER_MIN encounters or
## ENCOUNTER_MIN_SHARE of the rooms past the entrance, no room further than ENCOUNTER_MAX_GAP px (straight
## line) from a group; fillers are FILLER_SIZE creatures of the floor.
const ENCOUNTER_MIN := 6
const ENCOUNTER_MIN_SHARE := 0.6
const ENCOUNTER_MAX_GAP := 900.0
const FILLER_SIZE := [1, 2]

## --- tactical targeting (2026-10-31: the Wilds and late floors punish mistakes) ---------------------
## A "tactical" creature (DungeonDefs / floor "tactics") does not just go for the nearest hero: it scores
## every hero it perceives = distance - bonuses. Healers and ranged heroes (the backline) and heroes
## standing alone are worth chasing; frontline roles (guard, brute) stay on the nearest and body-block.
## FOCUS_ROLE_MULT scales the bonuses per creature role (swarm = flankers, ranged = picks off casters).
const FOCUS_BACKLINE := 90.0      # px of "closeness" a ranged hero is worth
const FOCUS_HEALER := 130.0       # a cleric is worth more: kill the healer
const FOCUS_ISOLATED := 120.0     # a hero with no ally within ISOLATION_RADIUS
const FOCUS_LOW_HP := 60.0        # x (1 - hp fraction): finish the hurt
const ISOLATION_RADIUS := 130.0
const FOCUS_ROLE_MULT := {"assassin": 3.0, "swarm": 1.5, "melee": 0.8, "ranged": 1.2, "support": 0.0, "guard": 0.0, "brute": 0.3}
const FOCUS_STICKY := 40.0        # the current focus keeps this bonus (no target ping-pong)
## A pack's "caller" (job) howls for reinforcements: if it is still alive CALLER_DELAY s after its group
## is alerted, CALLER_ADDS creatures of the area join next to it (once). Kill it first.
const CALLER_DELAY := 6.0
const CALLER_ADDS := 3
## Anti-blob: a "blob" is BLOB_COUNT+ heroes within BLOB_RADIUS of a creature's area skill target; area
## skills (hero_area) aimed at a blob deal BLOB_MULT more.
const BLOB_RADIUS := 80.0
const BLOB_COUNT := 3
const BLOB_MULT := 2.0
## 2026-10-31 (owner: "a lo loco no debe tener chance"): what is telegraphed must be lethal, so reading
## and dodging is the skill. Every creature skill that hits an area multiplies its dmg_mult by
## TELEGRAPH_MULT; a slow basic strike (wind-up >= HEAVY_WINDUP, a readable blow) hits HEAVY_MULT harder.
const TELEGRAPH_MULT := 1.6        # D-084: was 1.35 (avoidable hits hurt more: dodging pays)
const HEAVY_WINDUP := 0.9
const HEAVY_MULT := 1.9            # D-084: was 1.6
## Telegraphed area hits pierce armour (gear does not replace dodging): damage kind of creature area skills.
const TELEGRAPH_KIND := "true"

## --- creature classes and skills (D-065) -------------------------------------------------------------
## Roles work as classes: swarm (skirmisher), melee (fighter), brute, guard (defender), ranged (archer),
## support (healer / shaman), plus two jobs given by the floor: scout (lookout: flees to raise the alarm)
## and the boss's shamans. A creature casts a skill like a hero: a visible wind-up (a ring on the caster
## for help spells, the marked area for attacks) that only an interrupt skill breaks (D-142); cooldown per skill.
## min_floor: the skill appears from that floor (floor 1 teaches the basics without enemy healers).
## Targets: ally_low = the most hurt creature in range (heals); ally_key = the boss if near, else the
## strongest creature (wards); allies = every creature around the caster; hero_area = an area at a hero
## (marked on the ground: step out of it).
const SKILLS := {
    "mend": {"name": "Mend", "cast": 1.5, "cd": 5.0, "range": 200.0, "target": "ally_low", "below": 0.75, "min_floor": 2,
        "heal_pct": 0.4, "desc": "Heals the most hurt creature. Kill or stun the healer."},
    "ward": {"name": "Ward", "cast": 1.1, "cd": 11.0, "range": 220.0, "target": "ally_key", "min_floor": 3,
        "shield_pct": 0.22, "desc": "Shields an ally (the boss first)."},
    "rally": {"name": "Rally", "cast": 1.2, "cd": 16.0, "range": 230.0, "target": "allies", "min_floor": 4,
        "status": {"id": "empowered", "dur": 8.0, "mag": 0.0}, "desc": "Nearby creatures hit 30% harder for a while."},
    "slam": {"name": "Slam", "cast": 1.4, "cd": 9.0, "range": 140.0, "target": "hero_area", "radius": 150.0, "min_floor": 1,
        "shape": {"shape": "cone", "angle": 120.0}, "look": {"hit": "slam", "extra": "shockwave"},
        "dmg_mult": 1.8, "status": {"id": "stun", "dur": 1.0, "mag": 0.0}, "desc": "A huge frontal blow: get out of the cone."},
    "spore_cloud": {"name": "Spore Cloud", "cast": 1.0, "cd": 12.0, "range": 190.0, "target": "hero_area", "radius": 75.0, "min_floor": 3,
        "zone": {"status": "poison", "life": 6.0, "dur": 2.0, "mag": 3.0}, "look": {"proj": "venom", "hit": "poison_cloud"}, "desc": "Leaves a poison cloud: do not stand in it."},
    "aimed_shot": {"name": "Aimed Shot", "cast": 1.7, "cd": 8.0, "range": 230.0, "target": "hero_area", "radius": 250.0, "min_floor": 3,
        "shape": {"shape": "line", "width": 26.0}, "look": {"proj": "arrow", "hit": "spark", "speed": 1100.0},
        "dmg_mult": 2.4, "desc": "A long aim along a line: step out of it, or interrupt the archer."},
    "fireball": {"name": "Fireball", "cast": 1.3, "cd": 7.0, "range": 230.0, "target": "hero_area", "radius": 60.0, "min_floor": 1,
        "dmg_mult": 2.0, "element": "fire", "look": {"proj": "fireball", "hit": "explosion_big", "extra": "fire_impact"}, "desc": "A ball of fire on a group of heroes: do not bunch up."},
    "leap": {"name": "Leap", "cast": 0.7, "cd": 9.0, "range": 320.0, "target": "far_hero", "radius": 34.0, "min_floor": 1,
        "dmg_mult": 1.6, "dash": true, "look": {"hit": "slam", "extra": "dust"}, "desc": "Jumps onto the furthest hero (the backline): guard your healer."},
    # --- boss mechanics (2026-10-31, raid style: each one asks the player for a specific answer) -------
    "whirlwind": {"name": "Whirlwind", "cast": 1.8, "cd": 13.0, "range": 125.0, "target": "self_area", "radius": 125.0, "min_floor": 1,
        "dmg_mult": 2.2, "look": {"hit": "crescent", "extra": "shockwave"}, "desc": "Spins around itself: every melee hero must run out of the circle."},
    "meteor": {"name": "Meteor", "cast": 2.2, "cd": 11.0, "range": 460.0, "target": "far_hero", "radius": 70.0, "min_floor": 1,
        "dmg_mult": 2.6, "look": {"proj": "fireball", "sky": true, "scale": 3.0, "hit": "explosion_big", "extra": "fire_impact"}, "desc": "Falls on the hero furthest away (the backline): move, and do not stack behind."},
    "doom": {"name": "Mark of Doom", "cast": 4.0, "cd": 17.0, "range": 460.0, "target": "doom_hero", "radius": 90.0, "min_floor": 1,
        "follow": true, "dmg_mult": 3.0, "target_mult": 0.5, "look": {"hit": "arcane_burst", "extra": "shockwave"}, "desc": "Marks a hero (not the tank); it explodes on everyone near that hero: the marked one must leave the group."},
    "crimson_wave": {"name": "Crimson Wave", "cast": 1.6, "cd": 0.0, "range": 9999.0, "target": "hero_area", "radius": 80.0, "min_floor": 99,
        "dmg_mult": 1.8, "look": {"hit": "shockwave", "extra": "blood"}, "desc": "The unshielded Baron strikes at his altar (AltarDefs): hold him, or leave the altar."},
    "blood_ritual": {"name": "Blood Ritual", "cast": 3.0, "cd": 18.0, "range": 0.0, "target": "self_heal", "below": 0.8, "min_floor": 1,
        "heal_self_pct": 0.12, "desc": "Heals itself a lot: interrupt it."},
}
## D-145 telegraph shapes of the basic strike: "circle" (at the target), "cone" (a wedge in front of the
## creature, angle in degrees, reach = distance to the target + strike radius), "line" (from the creature
## through the target, width px, length = strike range + LINE_EXTRA). Picked by role (strike_shape); a
## skill's own "shape" wins (its "radius" is then the cone's reach or the line's length).
## Casters (fire/frost/arcane bolts) hit a circle at the target; archers and spitters a line; brutes and
## guards a cone; the rest a small circle.
const STRIKE_SHAPES := {"brute": {"shape": "cone", "angle": 100.0}, "guard": {"shape": "cone", "angle": 80.0},
    "line": {"shape": "line", "width": 18.0}, "circle": {"shape": "circle"}}
const LINE_EXTRA := 24.0
const MAGIC_PROJ := ["fireball", "frost_shard", "arcane_bolt", "orb"]


static func strike_shape(role: String, ai_role: String, proj: String) -> Dictionary:
    if ai_role == "caster" or MAGIC_PROJ.has(proj):
        return STRIKE_SHAPES["circle"]
    if role == "ranged" or ai_role == "archer":
        return STRIKE_SHAPES["line"]
    if role == "brute" or ai_role == "brute":
        return STRIKE_SHAPES["brute"]
    if role == "guard":
        return STRIKE_SHAPES["guard"]
    return STRIKE_SHAPES["circle"]


## Bosses get these on top of their own skills (make_boss). Each floor boss teaches a few mechanics.
const BOSS_SKILLS := {"warlord": ["whirlwind", "meteor", "blood_ritual"],
    "capitan_bandido": ["whirlwind", "blood_ritual"], "jefe_baron_carmesi": ["whirlwind"],   # the altar is his fight (AltarDefs)
    "orc_chieftain": ["whirlwind", "meteor", "doom", "blood_ritual"]}
## A boss lives long enough to cycle its mechanics (whirlwind, meteor, doom, ritual): its health is
## BOSS_HP_MULT x its type's (it was 8; a 30 s fight never showed them). The enrage keeps it a DPS check.
const BOSS_HP_MULT := 11
## Hard enrage (a DPS check): this many seconds after the boss joins the fight it hits BOSS_ENRAGE_ATK
## times harder and winds up faster. A squad that cannot kill it in time (no gear, no focus) is wiped.
const BOSS_ENRAGE_AFTER := {5: 100.0, 10: 420.0}   # floor 10: the altar is the check; the enrage only ends a stalled fight
const BOSS_ENRAGE_ATK := 3.0
const BOSS_ENRAGE_WINDUP := 0.6
const SCOUT_ALARM_RADIUS := 140.0  # a fleeing lookout raises the alarm on reaching this close to another group
const SCOUT_FLEE_SPEED := 1.25     # lookouts run faster than they walk
const BOSS_SHAMANS := 2            # floor bosses come with shamans that heal and ward them
const CARRIER_HUNT := 2.0          # creatures notice the relic carrier this many times further away

## #8 of the playtest: a boss used to be a big bag of health; a squad could run straight to it and win
## in a minute. Now it fights in phases: at each health threshold it calls its warband (every creature
## within CALL_RADIUS is alerted and `adds` new ones of the floor join next to it); the last phase also
## enrages it (faster wind-up and harder blows).
const BOSS_PHASES := [
    {"at": 0.6, "adds": 2, "call_radius": 650.0},
    {"at": 0.3, "adds": 3, "call_radius": 900.0, "enrage_atk": 1.25, "enrage_windup": 0.8},
]


## Health and damage multiplier of a floor's creatures: the floor's "scale" (TowerExpedition) or, when it
## has none, 1 + FLOOR_SCALE per floor above the first. D-065: kept gentle on purpose; the challenge of a
## floor is its mechanics (healers, lookouts, the relic carrier, the boss's shamans), not inflated numbers.
static func floor_scale(floor_num: int) -> float:
    if floor_num <= 0:
        return 1.0
    var cfg := TowerExpedition.get_floor_config(floor_num)
    return float(cfg.get("scale", 1.0 + FLOOR_SCALE * float(maxi(0, floor_num - 1))))


static func floor_atk_scale(floor_num: int) -> float:
    if floor_num < 0:
        return float(DungeonDefs.TIER_ATK.get(-floor_num, 1.0))
    if floor_num == 0:
        return 1.0
    var cfg := TowerExpedition.get_floor_config(floor_num)
    return float(cfg.get("atk_scale", 1.0 + FLOOR_ATK_SCALE * float(maxi(0, floor_num - 1))))


## Master prompt D: what a creature costs from a floor's threat budget, by role (a type may override).
const THREAT := {"swarm": 1, "melee": 1, "ranged": 2, "support": 2, "assassin": 2, "guard": 3, "brute": 3}


static func threat_of(id: String) -> int:
    var d := info(id)
    return int(d.get("threat", THREAT.get(String(d["role"]), 1)))


static func info(id: String) -> Dictionary:
    var d := DEFAULT.duplicate()
    d.merge(TYPES.get(id, {}), true)
    return d


static func role_of(id: String) -> String:
    return String(info(id)["role"])
