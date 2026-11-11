class_name SynergyDefs
extends RefCounted
## D-090: synergies as data. Each one has a type (combo, formation, bond, explore, camp, gather), a name,
## a description (shown in the codex once discovered; "???" before) and its own numbers. The rules that
## use them live next to the code they change (SandboxHero, SandboxEnemy, SandboxScreen, CampSite); the
## "gather" one is only DEFINED here: its effect belongs to gather_node (pista C).
## The first time a synergy fires the squad sees "Synergy discovered!" and Game.synergy_codex keeps it.
## Every value is a tuning placeholder.

const TYPES := ["combo", "formation", "bond", "explore", "camp", "gather"]
const TYPE_NAMES := {"combo": "Combos", "formation": "Formation", "bond": "Personality and bonds",
    "explore": "Exploration", "camp": "Camp", "gather": "Gathering"}

const SYNERGIES := {
    # --- combos
    "stun_crit": {"type": "combo", "name": "Opening", "desc": "A rogue's blow on a stunned foe is always a critical hit."},
    "shatter": {"type": "combo", "name": "Shatter", "mult": 1.5,
        "desc": "A physical blow on a frozen foe shatters the ice: x1.5 damage, and the foe is free again."},
    "taunt_aoe": {"type": "combo", "name": "Safe Sweep",
        "desc": "While a foe is taunted, area damage from the other heroes draws no threat from it."},
    "mark_fog": {"type": "combo", "name": "Hunter's Eye",
        "desc": "A foe marked by an archer is revealed through the fog, and the whole squad deals it 15% more damage."},
    # --- formation: flanking, back to back and the shield wall were removed (owner, 2026-11-02)
    # --- personality / bonds (relationship levels: HeroData.relationships)
    "rivals": {"type": "bond", "name": "Rivals", "rel_min": -60, "rel_max": -26, "radius": 200.0, "out_dmg": 1.08,
        "desc": "Rivals near each other try to outdo one another: +8% damage."},
    "mentor": {"type": "bond", "name": "Mentor and Apprentice", "levels": 8, "rel_min": 21, "radius": 200.0, "crit": 0.05,
        "desc": "An apprentice near a friend 8+ levels higher fights better: +5% critical chance."},
    "friends": {"type": "bond", "name": "Friends", "rel_min": 51, "radius": 200.0, "in_dmg": 0.92,
        "desc": "Close friends near each other take 8% less damage."},
    "incompatible": {"type": "bond", "name": "Incompatible", "rel_max": -61, "radius": 120.0, "composure_per_s": 1.0,
        "desc": "Heroes who cannot stand each other (or whose characters clash) lose Composure when close."},
    # --- exploration
    "shared_sight": {"type": "explore", "name": "Shared Sight", "radius": 220.0, "vision": 1,
        "desc": "Two scouts (rogue, archer) near each other share what they see: +1 sight each."},
    "trap_sense": {"type": "explore", "name": "Trap Sense", "radius": 200.0, "reveal": 200.0,
        "desc": "A rogue and an archer together spot hidden ambushers before walking into them."},
    # --- camp (CampSite)
    "cook": {"type": "camp", "name": "Camp Cook", "profession": "occupation.chef", "dur_mult": 2.0,
        "desc": "A hero who was a chef cooks for everyone at the camp: the meal lasts twice as long."},
    "bard": {"type": "camp", "name": "Campfire Song", "profession": "occupation.entertainer", "composure": 20,
        "desc": "A hero who was an entertainer plays at the fire: everyone recovers Composure and takes less damage for a while."},
    # --- gathering (effect: pista C, gather_node)
    "gather_pair": {"type": "gather", "name": "Two on a Vein", "mult": 1.5,
        "desc": "Two heroes working the same node gather faster."},
}
## Character clashes that count as "incompatible" whatever the relationship.
const CLASHING_TRAITS := [["trait.reckless", "trait.cautious"], ["trait.honorable", "trait.cunning"], ["trait.cheerful", "trait.gloomy"]]
const SCOUT_CLASSES := ["class.archer", "class.rogue"]
const DISCOVER_COLOR := Color(1.0, 0.85, 0.35)


static func info(id: String) -> Dictionary:
    return SYNERGIES.get(id, {})


static func param(id: String, key: String, fallback: Variant = 0.0) -> Variant:
    return info(id).get(key, fallback)


## Ids of one type, in definition order (the codex lists them like this).
static func of_type(t: String) -> Array:
    var out: Array = []
    for id in SYNERGIES:
        if String(SYNERGIES[id]["type"]) == t:
            out.append(id)
    return out


## Shown name: the real one when discovered, "???" otherwise.
static func shown_name(id: String, codex: Dictionary) -> String:
    return String(info(id).get("name", id)) if codex.has(id) else "???"


static func shown_desc(id: String, codex: Dictionary) -> String:
    return String(info(id).get("desc", "")) if codex.has(id) else "Not discovered yet."


## Relationship level of a with b (0 when they never met).
static func rel_level(a: HeroData, b: HeroData) -> int:
    if a == null or b == null:
        return 0
    return int(a.get_relationship(b.id).get("level", 0))


static func clash(a: HeroData, b: HeroData) -> bool:
    if a == null or b == null:
        return false
    for pair in CLASHING_TRAITS:
        if (a.traits.has(pair[0]) and b.traits.has(pair[1])) or (a.traits.has(pair[1]) and b.traits.has(pair[0])):
            return true
    return false


## The bond synergy between two heroes ("" = none). Worst first: incompatible wins over the rest.
static func bond_between(a: HeroData, b: HeroData) -> String:
    var lv := mini(rel_level(a, b), rel_level(b, a))
    var best := maxi(rel_level(a, b), rel_level(b, a))
    if clash(a, b) or lv <= int(param("incompatible", "rel_max", -61)):
        return "incompatible"
    if lv >= int(param("rivals", "rel_min", -60)) and lv <= int(param("rivals", "rel_max", -26)):
        return "rivals"
    if best >= int(param("friends", "rel_min", 51)):
        return "friends"
    return ""


## True when `apprentice` has a mentor in `mentor` (friend and many levels above).
static func is_mentor(mentor: HeroData, apprentice: HeroData) -> bool:
    if mentor == null or apprentice == null:
        return false
    return mentor.level - apprentice.level >= int(param("mentor", "levels", 8)) \
        and maxi(rel_level(mentor, apprentice), rel_level(apprentice, mentor)) >= int(param("mentor", "rel_min", 21))


## Records a synergy. Returns true the FIRST time (the caller shows "Synergy discovered!").
static func discover(id: String) -> bool:
    if not SYNERGIES.has(id):
        return false
    var g: Node = _game()
    if g == null:
        return false
    var codex: Dictionary = g.get("synergy_codex")
    if codex.has(id):
        return false
    codex[id] = true
    return true


static func codex() -> Dictionary:
    var g: Node = _game()
    return g.get("synergy_codex") if g != null and g.get("synergy_codex") is Dictionary else {}


static func _game() -> Node:
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null or tree.root == null:
        return null
    var g := tree.root.get_node_or_null("Game")
    return g if g != null and g.get("synergy_codex") != null else null
