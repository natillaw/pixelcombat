class_name DungeonDefs
extends RefCounted
## D-066: the repeatable farming dungeon outside the tower (the "Wilds"). It is where the town's
## materials come from: building materials, wood, stone, ore, herbs and creature parts. The tower no
## longer has gathering spots; it drops equipment and rare things the Wilds never give.
##   - A new procedural map every time (it is never saved, unlike tower floors, D-026).
##   - Its tier follows the tower: tier 1 while the squad climbs floors 1-10, tier 2 once floor 10 is
##     cleared, and so on (tier(): 1 + highest cleared floor / 10). Each tier is another biome with its
##     own creatures and loot.
##   - No mission: the squad goes as deep as it dares and leaves by the entrance (X). The further from
##     the entrance, the richer the spots and caches and the harder the creatures. A wiped squad loses
##     everything it carried; fallen heroes die for good (D-011).
## Every number here is a tuning placeholder. Configs use the same keys as TowerExpedition floors so the
## map generator and the mission screen read both alike (TowerExpedition.get_floor_config(-tier)).

const HOURS_PER_RUN := 12            # a run in the Wilds moves the town half a day (the tower: a whole one)

## 2026-10-31: the Wilds fight smart (EnemyDefs tactical targeting, anti-blob area aim, callers) and
## their packs are built by role so they complement each other: PACK = the role of each slot in order
## (a tank first, then ranged damage and a healer, then fillers). Roles missing from a tier's foes fall
## back to any foe of the tier.
const TACTICS := true
const PACK := ["guard", "ranged", "support", "melee", "ranged", "swarm", "melee"]

const TIERS := {
    1: {"name": "The Overgrown Wilds", "short": "Wilds", "difficulty": "Varies by depth", "mission": "farm", "width": 112, "height": 96,
        "enemies": 42, "foes": ["slime_green", "rat", "bat", "spider", "mushroom_red", "goblin", "hobgoblin"],
        "nodes": 22, "node_mix": {"wood": 4, "stone": 3, "ore": 3, "herb": 3}, "caches": 3,
        "intro": "Wild woods beside the town, never the same twice. Timber, stone, ore, herbs and creature parts: everything the town needs. The deeper you go, the richer and the deadlier."},
    2: {"name": "The Ashen Quarries", "short": "Quarries", "difficulty": "Varies by depth", "mission": "farm", "width": 120, "height": 104,
        "enemies": 48, "foes": ["hobgoblin", "orc_brute", "goblin", "mushroom_purple", "spider", "golem"],
        "nodes": 24, "node_mix": {"stone": 4, "ore": 5, "wood": 2, "herb": 2}, "caches": 4,
        "intro": "Burnt quarries opened by the climb past floor 10: richer ore and stone, harder creatures."},
}

## Depth (the map's room zones, from the entrance to the far "heart"): creature strength and how much a
## gathering spot or a cache holds.
const ZONE_STRENGTH := {"entrance": 1.0, "explore": 1.1, "danger": 1.5, "objective": 2.2}
## Creature skills follow EnemyDefs.SKILLS "min_floor": in the Wilds a tier counts as this tower floor
## (tier 1 has healers, wards and aimed shots like floors 3-4; tier 2 everything).
const TIER_SKILL_FLOOR := {1: 4, 2: 10}
const ZONE_RICHNESS := {"entrance": 0.8, "explore": 1.0, "danger": 1.6, "objective": 2.4}
## A cache is a hidden stockpile in the deep rooms: shaped building materials, ready to use.
const CACHE := {"materials": [10, 18], "ingot": [0, 1]}
## Tier multiplier on top (tier 2 creatures and spots are stronger and richer).
const TIER_STRENGTH := {1: 1.0, 2: 1.9}
## 2026-10-31: Wilds creatures hit like a floor 4 (tier 1) / floor 10 (tier 2) on top of depth: farming is
## not free; a careless squad loses heroes in the deep rooms.
const TIER_ATK := {1: 1.4, 2: 2.8}   # beta: tier 1 is where fresh heroes farm; depth still scales
const TIER_RICHNESS := {1: 1.0, 2: 1.6}


static func tier_for(highest_cleared_floor: int) -> int:
    return clampi(1 + highest_cleared_floor / 10, 1, TIERS.size())


static func config(tier: int) -> Dictionary:
    var t := clampi(tier, 1, TIERS.size())
    var c: Dictionary = (TIERS[t] as Dictionary).duplicate(true)
    c["scale"] = float(TIER_STRENGTH.get(t, 1.0))
    c["tier"] = t
    c["pack"] = PACK
    return c


static func skill_floor(tier: int) -> int:
    return int(TIER_SKILL_FLOOR.get(clampi(tier, 1, TIERS.size()), 4))


static func zone_strength(zone: String) -> float:
    return float(ZONE_STRENGTH.get(zone, 1.0))


static func zone_richness(zone: String, tier: int) -> float:
    return float(ZONE_RICHNESS.get(zone, 1.0)) * float(TIER_RICHNESS.get(tier, 1.0))
