class_name TowerExpedition
extends RefCounted
## The first ten tower floors (D-027): all unlocked for now and all in the forest biome (D-031).
## Sizes are in map cells; "enemies" is the spawn budget; "foes" are the creature types that can
## appear (voxel-dungeon creatures, see EnemySprites; roles in EnemyDefs). Numbers are tuning placeholders.
## D-056: sized for a 10-30 minute expedition the first time (fog, unknown layout). Playtest 2026-10-31:
## at 92x80..108x92 a blind first run took 4-8 min, so floors 1-5 grew ~30% per side (~1.7x the area) with
## creatures and gathering spots scaled to keep the same density; a replay that goes straight to the goal
## stays short (that is fine). Older saved floors keep the size they were generated with (D-026).
## D-066: tower floors have no gathering spots (the Wilds hold the town's materials) and each needs a
## Summoner's Hall level ("hall", floor_block()).
## D-065: creature strength grows gently (+10% per floor, EnemyDefs.floor_scale); difficulty comes from
## mechanics that ask for thought: telegraphed blows (1), healers behind the line (2), a slow relic carrier
## everything hunts (3), lookouts that raise the alarm (4), a boss with shamans, wards and phases (5).
## A floor may still set "scale" to override the curve.

const THEME_NAME := "Whispering Forest"

## Master prompt D (2026-10-31, owner): the bandit band holds floors 1-10 (BanditArt / EnemyDefs). Each floor
## sets its own squad size ("party", never above 5; 10-hero raids are backlog), its mission, a threat
## budget ("threat", spent by ProceduralMap on creatures by EnemyDefs.THREAT so roles mix) and, from
## floor 3, one modifier (FloorMods: fog, hazard, enrage, no_heal). Every 5th floor is a spike, the 10th
## a major boss. Floor 7 "sabotage": destroy the totems that raise the fallen (FloorMods).
const FLOORS := {
    1: {"name": "Floor 1: Forest Edge", "hall": 1, "difficulty": "Tutorial", "mission": "combat", "party": 1, "threat": 14, "width": 96, "height": 84,
        "foes": ["bandido_maton", "bandido_maton", "bandido_arquero"], "nodes": 0, "intro": "A lone scout against a few bandits on the forest edge."},
    2: {"name": "Floor 2: Mossy Trail", "hall": 1, "difficulty": "Easy", "mission": "exploration", "party": 2, "threat": 48, "lookouts": true, "width": 124, "height": 110,
        "foes": ["bandido_maton", "bandido_arquero", "bandido_bruto"], "nodes": 0, "intro": "Find the three old markers. A bandit elite patrols the trail."},
    3: {"name": "Floor 3: Mushroom Hollow", "hall": 2, "difficulty": "Normal", "mission": "defense", "party": 3, "threat": 56, "hold_time": 210.0, "wave_base": 3, "wave_growth": 0.5, "wave_cap": 8, "modifier": "fog", "width": 130, "height": 112,
        "foes": ["bandido_maton", "bandido_arquero", "bandido_degollador", "bandido_mago"], "nodes": 0, "intro": "Hold the shrine while the bandits come in waves. Mist hides them until they are close."},
    4: {"name": "Floor 4: Bandit Pass", "hall": 2, "difficulty": "Hard", "mission": "escape", "party": 2, "threat": 70, "time_limit": 900.0, "modifier": "hazard", "lookouts": true, "tactics": true, "width": 136, "height": 116,
        "foes": ["bandido_bruto", "bandido_maton", "bandido_arquero", "bandido_degollador", "bandido_chaman"], "nodes": 0, "intro": "Cross the pass to the far side. Fighting them all is losing."},
    5: {"name": "Floor 5: The Captain's Camp", "hall": 3, "difficulty": "Very Hard", "mission": "boss", "boss_name": "Bandit Captain", "party": 5, "threat": 72, "modifier": "enrage", "tactics": true, "shamans": 2, "width": 140, "height": 120,
        "foes": ["capitan_bandido", "bandido_bruto", "bandido_maton", "bandido_arquero", "bandido_mago", "bandido_degollador"], "nodes": 0, "intro": "The first great challenge: the Bandit Captain and the healers who keep him standing."},
    6: {"name": "Floor 6: Tangled Thicket", "hall": 3, "difficulty": "Hard", "mission": "rescue", "party": 3, "threat": 72, "modifier": "no_heal", "time_limit": 720.0, "tactics": true, "width": 146, "height": 124,
        "foes": ["bandido_bruto", "bandido_degollador", "bandido_arquero", "bandido_mago", "bandido_chaman"], "nodes": 0, "intro": "A villager is caged in the thicket. Six guards, and not much time."},
    7: {"name": "Floor 7: Raider Woods", "hall": 4, "difficulty": "Hard", "mission": "sabotage", "party": 4, "threat": 80, "modifier": "fog", "tactics": true, "width": 150, "height": 130,
        "foes": ["bandido_maton", "bandido_mago", "bandido_degollador", "bandido_chaman", "bandido_arquero"], "nodes": 0},
    8: {"name": "Floor 8: Stone Circle", "hall": 4, "difficulty": "Hard", "mission": "combat", "party": 1, "threat": 14, "modifier": "enrage", "tactics": true, "width": 64, "height": 56,
        "foes": ["bandido_bruto", "bandido_degollador"], "nodes": 0, "intro": "A duel: one hero against a bandit elite and its two cutthroats."},
    9: {"name": "Floor 9: Warband Clearing", "hall": 5, "difficulty": "Very Hard", "mission": "survival", "party": 5, "threat": 88, "survive_time": 300.0, "wave_base": 3, "wave_growth": 0.5, "wave_cap": 10, "modifier": "hazard", "tactics": true, "width": 160, "height": 138,
        "foes": ["bandido_bruto", "bandido_maton", "bandido_mago", "bandido_degollador", "bandido_chaman", "bandido_arquero"], "nodes": 0},
    10: {"name": "Floor 10: The Crimson Baron", "hall": 5, "difficulty": "Major Boss", "mission": "boss", "boss_name": "The Crimson Baron", "boss_hp_mult": 3.5, "atk_scale": 1.4, "shamans": 0, "party": 5, "threat": 56, "modifier": "enrage", "tactics": true, "altar": true, "width": 118, "height": 104,
        "foes": ["jefe_baron_carmesi", "bandido_bruto", "bandido_degollador", "bandido_mago", "bandido_chaman"], "nodes": 0, "intro": "The Crimson Baron cannot be hurt while his shield holds. The light comes from somewhere else."},
}


## D-066 (cambiado por Nathaniel 2026-10-31): the town no longer gates a floor. Every floor opened by
## tower progress (D-031: 1-10) can be entered; "hall" is only the suggested Summoner's Hall level. The
## difficulty is the content (enemies hit hard enough that crafted gear is the expected answer).
static func floor_block(_floor_num: int, _hall_level: int = 0) -> String:
    return ""


## Advisory text when the town is below a floor's suggested Hall level ("" if it is not).
static func floor_advice(floor_num: int, hall_level: int) -> String:
    if floor_num <= 0:
        return ""
    var need := int(get_floor_config(floor_num).get("hall", 1))
    return "" if hall_level >= need else "suggested: Summoner's Hall %d (now %d). Without town gear this floor is very hard" % [need, hall_level]


const SLICE_FLOORS := 5                # vertical slice: floors 1-5 are the polished, playable ones


## How many heroes may enter (master prompt D; the party keeps its 5 slots, the first N go in).
static func party_max(floor_num: int) -> int:
    return clampi(int(get_floor_config(floor_num).get("party", 5)), 1, 5)


## D-082b: the one answer to "who goes in" (the tower gate, the dialog before entering and the expedition
## screen all read it, so what the floor says and what is deployed always match). party = the heroes of the
## party in slot order (the Master first). size = what the floor takes, have = party heroes, goes = how
## many are deployed (the first ones), short / extra = fewer / more than the floor takes.
static func squad_report(floor_num: int, party: Array) -> Dictionary:
    var size := party_max(floor_num) if floor_num != 0 else 5
    var have := party.size()
    return {"size": size, "have": have, "goes": mini(size, have), "short": have < size, "extra": have > size}


static func get_floor_config(floor_num: int) -> Dictionary:
    if floor_num < 0:
        return DungeonDefs.config(-floor_num)     # D-066: negative = a tier of the repeatable Wilds
    var f := clampi(floor_num, 1, 10)
    return FLOORS[f]


## Creature type for the i-th spawn of a floor (the boss floor puts the chieftain first).
static func foe_for(floor_num: int, i: int) -> String:
    var foes: Array = get_floor_config(floor_num)["foes"]
    return String(foes[i % foes.size()])
