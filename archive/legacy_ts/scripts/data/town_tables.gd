class_name TownTables
extends RefCounted
## The town (D-030): every building, where it stands on the fixed town map, what it costs and what
## it opens. Levels live in Game.town_buildings (0 = not built yet). Costs are TUNING PLACEHOLDERS.

const EXPERT_MULT := 2
const LIBRARY_BASE_COST := 80     # materials to transcribe a skill book at Library level 1 (D-046)
const LIBRARY_DISCOUNT := 10      # per extra Library level
const MAP_W := 44
const MAP_H := 26

## plot = Rect2i(cell x, cell y, w, h) on the town map; the door is the bottom-centre cell.
## open = screen opened from the building ("" = info panel only). start = level in a new game.
## jobs = recipes the building can run (EconomyDefs.RECIPES); slots = worker places at level 1 (+1 every
## 2 levels); hall = Summoner's Hall level needed to build it; beds = sleeping places per level (dorms).
## Every building's level is capped by the Summoner's Hall level (CoC-style central progression).
## experts = past-life professions shown as a hint; the real effect comes from ProfessionDefs (D-049).
## props = drawn in front of the building: "caz:<Tiles path>" (Caz base pack) or "voxel:<id>" (voxel dungeon).
## look = house built from Caz pieces: roof "thatch"|"tile", wall "plaster"|"stone"|"timber", tint on the roof.
const BUILDINGS := {
    "town_hall": {"name": "Summoner's Hall", "plot": Rect2i(14, 2, 6, 3), "start": 1, "max": 5, "cost": 60,
        "open": "hq", "roof": Color(0.95, 0.80, 0.45), "props": ["voxel:banner", "voxel:banner", "caz:ExteriorFeatures/ExteriorFeatures_2_1"], "look": {"roof": "tile", "wall": "stone", "tint": Color(1, 1, 1)},
        "slots": 0, "hall": 0, "desc": "Heart of the order. Its level caps every other building and opens new ones; assign work here."},
    "summon_circle": {"name": "Summoning Circle", "plot": Rect2i(3, 3, 4, 3), "start": 1, "max": 1, "cost": 0,
        "open": "summon", "roof": Color(0.70, 0.55, 1.0), "props": ["voxel:altar", "voxel:crystal_deco"], "look": {"roof": "thatch", "wall": "plaster", "tint": Color(0.85, 0.75, 1.0)},
        "desc": "Call new heroes into the order."},
    "barracks": {"name": "Barracks", "plot": Rect2i(26, 3, 5, 3), "start": 0, "max": 1, "cost": 10,
        "open": "roster", "roof": Color(0.75, 0.75, 0.80), "props": ["caz:OutsideFeatures/OutsideFeatures_31_1", "caz:OutsideFeatures/OutsideFeatures_31_2", "caz:OutsideFeatures/OutsideFeatures_32_1"], "look": {"roof": "tile", "wall": "stone", "tint": Color(0.85, 0.85, 0.9)},
        "desc": "Your heroes: stats, personality, training and promotion."},
    "war_room": {"name": "War Room", "plot": Rect2i(26, 8, 4, 2), "start": 0, "max": 1, "cost": 10,
        "open": "party", "roof": Color(0.80, 0.45, 0.40), "props": ["caz:OutsideFeatures/OutsideFeatures_24_1", "voxel:table"], "look": {"roof": "tile", "wall": "timber", "tint": Color(1, 1, 1)},
        "desc": "Choose the five heroes of the squad."},
    "tower_gate": {"name": "Tower Gate", "plot": Rect2i(15, 15, 4, 3), "start": 1, "max": 1, "cost": 0,
        "open": "tower", "roof": Color(0.45, 0.45, 0.55), "props": ["voxel:brazier", "voxel:brazier"], "look": {"roof": "tile", "wall": "stone", "tint": Color(0.6, 0.6, 0.7)},
        "desc": "Lead the squad into the tower (D-027)."},
    "memorial": {"name": "Memorial", "plot": Rect2i(3, 15, 3, 2), "start": 0, "max": 1, "cost": 10,
        "open": "memorial", "roof": Color(0.55, 0.55, 0.60), "props": ["caz:OutsideFeatures/OutsideFeatures_11_1", "caz:OutsideFeatures/OutsideFeatures_11_2", "caz:OutsideFeatures/OutsideFeatures_11_1"], "look": {"roof": "tile", "wall": "stone", "tint": Color(0.7, 0.7, 0.75)},
        "desc": "The names of the fallen, kept forever."},
    "dorm_1": {"name": "Dormitory", "plot": Rect2i(3, 9, 4, 2), "start": 1, "max": 5, "cost": 40,
        "open": "", "roof": Color(0.60, 0.75, 0.95), "props": ["caz:ExteriorFeatures/ExteriorFeatures_6_1"], "look": {"roof": "thatch", "wall": "plaster", "tint": Color(1, 1, 1)},
        "beds": [0, 5, 7, 9, 11, 13], "hall": 0, "desc": "Beds for heroes. Every hero needs one; better dorms rest better."},
    "dorm_2": {"name": "Dormitory", "plot": Rect2i(9, 9, 4, 2), "start": 1, "max": 5, "cost": 40,
        "open": "", "roof": Color(0.60, 0.75, 0.95), "props": ["caz:ExteriorFeatures/ExteriorFeatures_6_1"], "look": {"roof": "thatch", "wall": "plaster", "tint": Color(1, 1, 1)},
        "beds": [0, 5, 7, 9, 11, 13], "hall": 0, "desc": "Beds for heroes. Every hero needs one; better dorms rest better."},
    "kitchen": {"name": "Kitchen", "plot": Rect2i(21, 11, 3, 2), "start": 0, "max": 5, "cost": 30,
        "open": "", "roof": Color(0.95, 0.65, 0.35), "props": ["caz:OutsideFeatures/OutsideFeatures_22_2", "caz:ExteriorFeatures/ExteriorFeatures_6_1"], "look": {"roof": "thatch", "wall": "timber", "tint": Color(1, 1, 1)}, "experts": ["occupation.chef", "occupation.farmer", "occupation.fisher", "occupation.hunter"],
        "jobs": ["cook_meal"], "slots": 2, "hall": 0, "desc": "Cooks turn grain into the meals the whole town eats."},
    "infirmary": {"name": "Hospital", "plot": Rect2i(26, 12, 4, 2), "start": 0, "max": 5, "cost": 40,
        "open": "", "roof": Color(0.92, 0.92, 0.95), "props": ["caz:ExteriorFeatures/ExteriorFeatures_5_1", "caz:OutsideFeatures/OutsideFeatures_12_1"], "look": {"roof": "tile", "wall": "plaster", "tint": Color(1, 0.95, 0.95)}, "experts": ["occupation.medic", "occupation.priest", "occupation.alchemist"],
        "jobs": ["treat"], "slots": 1, "hall": 1, "sick_beds": [0, 2, 3, 4, 5, 6], "desc": "Beds for the sick. A doctor with medicine cures diseases; without one, only rest."},
    "blacksmith": {"name": "Blacksmith", "plot": Rect2i(9, 3, 4, 2), "start": 0, "max": 5, "cost": 40,
        "open": "", "roof": Color(0.55, 0.30, 0.25), "props": ["caz:OutsideFeatures/OutsideFeatures_6_1", "voxel:weaponrack"], "look": {"roof": "tile", "wall": "stone", "tint": Color(0.65, 0.6, 0.6)},
        "jobs": ["smelt_iron", "forge_weapon", "forge_armor", "forge_fine_weapon", "forge_fine_armor"], "slots": 1, "hall": 0, "desc": "Blacksmiths smelt ore into ingots and forge weapons and armor; quality follows smith and forge level."},
    "workshop": {"name": "Workshop", "plot": Rect2i(21, 3, 3, 2), "start": 0, "max": 5, "cost": 30,
        "open": "", "roof": Color(0.70, 0.55, 0.35), "props": ["caz:OutsideFeatures/OutsideFeatures_4_1", "caz:OutsideFeatures/OutsideFeatures_6_1"], "look": {"roof": "thatch", "wall": "timber", "tint": Color(0.9, 0.85, 0.75)}, "experts": ["occupation.lumberjack", "occupation.miner", "occupation.mason", "occupation.builder", "occupation.engineer", "occupation.blacksmith"],
        "jobs": ["make_materials"], "slots": 2, "hall": 0, "desc": "Carpenters shape wood and stone into building materials."},
    "jeweler": {"name": "Jeweller", "plot": Rect2i(3, 21, 3, 2), "start": 0, "max": 5, "cost": 50,
        "open": "", "roof": Color(0.45, 0.35, 0.6), "props": [], "look": {"roof": "tile", "wall": "stone", "tint": Color(0.8, 0.75, 0.9)},
        "jobs": [], "slots": 1, "hall": 0, "desc": "Jewellers cut gems and set rings, amulets and trinkets (D-077)."},
    "alchemy": {"name": "Alchemy Lab", "plot": Rect2i(9, 15, 4, 2), "start": 0, "max": 5, "cost": 60,
        "open": "", "roof": Color(0.45, 0.85, 0.65), "props": ["voxel:crystal_deco", "caz:OutsideFeatures/OutsideFeatures_12_1"], "look": {"roof": "thatch", "wall": "plaster", "tint": Color(0.8, 1.0, 0.8)},
        "jobs": ["brew_medicine", "brew_potion", "brew_antidote", "brew_elixir_strength", "brew_elixir_speed", "brew_elixir_defense", "brew_potion_major"], "slots": 1, "hall": 1, "desc": "Alchemists brew medicine, healing potions and antidotes from herbs."},
    "common": {"name": "Tavern", "plot": Rect2i(21, 15, 4, 2), "start": 0, "max": 5, "cost": 30,
        "open": "", "experts": ["occupation.entertainer", "occupation.merchant"], "roof": Color(0.85, 0.55, 0.30), "props": ["caz:ExteriorFeatures/ExteriorFeatures_3_2", "caz:ExteriorFeatures/ExteriorFeatures_6_1"], "look": {"roof": "tile", "wall": "timber", "tint": Color(1, 0.9, 0.8)},
        "jobs": ["serve"], "slots": 1, "hall": 1, "desc": "Stressed heroes unwind and talk here; friendships and quarrels happen. A tavern keeper helps."},
    "library": {"name": "Library", "plot": Rect2i(27, 16, 4, 2), "start": 0, "max": 5, "cost": 70,
        "open": "", "experts": ["occupation.scholar", "occupation.priest"], "roof": Color(0.55, 0.45, 0.80), "props": ["voxel:table", "caz:OutsideFeatures/OutsideFeatures_24_1"], "look": {"roof": "tile", "wall": "stone", "tint": Color(0.85, 0.8, 1.0)},
        "slots": 1, "hall": 2, "desc": "Transcribe skill books for materials (cheaper each level). Heroes read them to learn actives."},
    "farm": {"name": "Farm", "plot": Rect2i(35, 2, 5, 3), "start": 0, "max": 5, "cost": 40, "jobs": ["grow_grain", "grow_herbs"], "slots": 2, "hall": 0,
        "open": "", "experts": ["occupation.farmer"], "roof": Color(0.85, 0.75, 0.35), "props": ["caz:OutsideFeatures/OutsideFeatures_22_2"], "look": {"roof": "thatch", "wall": "timber", "tint": Color(1, 0.95, 0.8)},
        "desc": "Farmers grow grain (food) and herbs (medicine)."},
    "lumber_camp": {"name": "Lumber Camp", "plot": Rect2i(35, 9, 4, 2), "start": 0, "max": 5, "cost": 40, "jobs": ["fell_wood"], "slots": 2, "hall": 0,
        "open": "", "experts": ["occupation.lumberjack"], "roof": Color(0.55, 0.40, 0.25), "props": ["caz:OutsideFeatures/OutsideFeatures_4_1"], "look": {"roof": "thatch", "wall": "timber", "tint": Color(0.85, 0.75, 0.6)},
        "desc": "Lumberjacks fell trees for wood."},
    "mine": {"name": "Mine", "plot": Rect2i(35, 16, 4, 2), "start": 0, "max": 5, "cost": 50, "jobs": ["dig_stone", "dig_ore"], "slots": 2, "hall": 0,
        "open": "", "experts": ["occupation.miner"], "roof": Color(0.45, 0.42, 0.40), "props": ["voxel:brazier"], "look": {"roof": "tile", "wall": "stone", "tint": Color(0.6, 0.6, 0.6)},
        "desc": "Miners dig stone and iron ore."},
    "warehouse": {"name": "Warehouse", "plot": Rect2i(30, 9, 3, 2), "start": 0, "max": 5, "cost": 50, "slots": 0, "hall": 0,
        "open": "", "roof": Color(0.65, 0.50, 0.35), "props": ["caz:OutsideFeatures/OutsideFeatures_6_1"], "look": {"roof": "tile", "wall": "timber", "tint": Color(0.9, 0.85, 0.75)},
        "desc": "Storage for every resource and the equipment stash. Each level holds more."},
    "dorm_3": {"name": "Dormitory", "plot": Rect2i(35, 21, 4, 2), "start": 0, "max": 5, "cost": 60, "beds": [0, 5, 7, 9, 11, 13], "hall": 1,
        "open": "", "roof": Color(0.60, 0.75, 0.95), "props": ["caz:ExteriorFeatures/ExteriorFeatures_6_1"], "look": {"roof": "thatch", "wall": "plaster", "tint": Color(1, 1, 1)},
        "desc": "Beds for heroes. Every hero needs one; better dorms rest better."},
    "dorm_4": {"name": "Dormitory", "plot": Rect2i(9, 21, 4, 2), "start": 0, "max": 5, "cost": 80, "beds": [0, 5, 7, 9, 11, 13], "hall": 2,
        "open": "", "roof": Color(0.60, 0.75, 0.95), "props": ["caz:ExteriorFeatures/ExteriorFeatures_6_1"], "look": {"roof": "thatch", "wall": "plaster", "tint": Color(1, 1, 1)},
        "desc": "Beds for heroes. Every hero needs one; better dorms rest better."},
    "training_grounds": {"name": "Training Grounds", "plot": Rect2i(21, 20, 4, 2), "start": 0, "max": 5, "cost": 60, "slots": 0, "hall": 1,
        "open": "", "roof": Color(0.80, 0.60, 0.40), "props": ["caz:OutsideFeatures/OutsideFeatures_31_1", "voxel:weaponrack"], "look": {"roof": "thatch", "wall": "timber", "tint": Color(1, 0.9, 0.8)},
        "desc": "Heroes of 2 stars or more learn one more skill of their class here (a choice, not all of them). Class wings come later."},
    "ascension": {"name": "Sanctuary of Ascension", "plot": Rect2i(27, 20, 4, 2), "start": 0, "max": 5, "cost": 60, "slots": 0, "hall": 1,
        "open": "", "roof": Color(0.95, 0.90, 0.60), "props": ["voxel:altar", "voxel:crystal_deco"], "look": {"roof": "tile", "wall": "stone", "tint": Color(1, 0.95, 0.75)},
        "desc": "A hero at the top level of its star rank can attempt to ascend (promotion) with tower materials. Luck matters; failures make the next try likelier."},
}


static func ids() -> Array:
    return BUILDINGS.keys()


static var _info_cache := {}


## A building's data; its jobs include the item library's recipes made there (D-077).
static func info(id: String) -> Dictionary:
    if not BUILDINGS.has(id):
        return {}
    if not _info_cache.has(id):
        var d: Dictionary = (BUILDINGS[id] as Dictionary).duplicate()
        var jobs: Array = (d.get("jobs", []) as Array).duplicate()
        for rid in ItemLibrary.recipes():
            if String(ItemLibrary.recipes()[rid]["building"]) == id:
                jobs.append(rid)
        d["jobs"] = jobs
        _info_cache[id] = d
    return _info_cache[id]


static func start_levels() -> Dictionary:
    var out := {}
    for id in BUILDINGS:
        out[id] = int(BUILDINGS[id]["start"])
    return out


## Materials needed to go from `level` to `level + 1` (building from 0 costs the base price).
static func upgrade_cost(id: String, level: int) -> int:
    return int(info(id).get("cost", 0)) * (level + 1)


static func door_cell(id: String) -> Vector2i:
    var p: Rect2i = info(id)["plot"]
    return Vector2i(p.position.x + p.size.x / 2, p.end.y)


## Plot with the player's layout applied (D-050: moved buildings keep their size).
static func plot_at(id: String, layout: Dictionary) -> Rect2i:
    var p: Rect2i = info(id)["plot"]
    if layout.has(id):
        p.position = layout[id]
    return p


static func door_at(id: String, layout: Dictionary) -> Vector2i:
    var p := plot_at(id, layout)
    return Vector2i(p.position.x + p.size.x / 2, p.end.y)


## The town a save started with before the vertical slice (everything basic built). Old-save migrations
## use it as the historical start levels (they must not change when the new-account start changes);
## the debug menu ("Full town") and production tests use it too. A new account starts nearly empty.
const PRE_SLICE_TOWN := ["town_hall", "summon_circle", "barracks", "war_room", "tower_gate", "memorial", "dorm_1",
    "dorm_2", "kitchen", "infirmary", "blacksmith", "workshop", "common", "farm", "lumber_camp", "mine", "warehouse"]


## Start level a building had before the vertical slice (for old-save migrations).
static func pre_slice_start(id: String) -> int:
    return 1 if PRE_SLICE_TOWN.has(id) else 0


## Free placement (owner, 2026-10-31): a new building may go anywhere in the town as long as it stays
## within NEAR_CELLS of another building (it is a village, not scattered huts).
const NEAR_CELLS := 3
## Owner 2026-11-01: only a smith works the forge as a worker. Others can learn the trade as an
## APPRENTICE: only while a master (knows the profession at MASTER_MIN_LVL+) works there, an apprentice
## makes nothing and learns it after APPRENTICE_HOURS of work beside the master. Add building ids here
## to make them specialist-only too.
const SPECIALIST_ONLY := ["blacksmith"]
const MASTER_MIN_LVL := 1
const APPRENTICE_HOURS := 48
const APPRENTICE_SLOTS := 1             # apprentices per building, on top of its worker places


## Cells no building may cover: the plaza and its well.
const PLAZA := Rect2i(15, 9, 5, 3)


## Worker places of a building at a level.
static func worker_slots(id: String, level: int) -> int:
    var base := int(info(id).get("slots", 0))
    return 0 if base <= 0 or level <= 0 else base + (level - 1) / 2


static func beds_at(id: String, level: int) -> int:
    var b: Array = info(id).get("beds", [])
    return 0 if b.is_empty() else int(b[clampi(level, 0, b.size() - 1)])


static func is_dorm(id: String) -> bool:
    return info(id).has("beds")


static func is_expert(building_id: String, profession: String) -> bool:
    return (info(building_id).get("experts", []) as Array).has(profession)


## Buildings where this profession is an expert (for the hero panel).
## #16 of the playtest: "experts" holds the old past-life occupation ids ("occupation.chef") while the
## town works with profession ids ("cook"), so asking with a profession found nothing. Both work now:
## an occupation is turned into its profession, and a building counts when one of its jobs needs it.
static func best_workplaces(profession: String) -> Array:
    var prof := String(ProfessionDefs.FROM_PAST_LIFE.get(profession, profession))
    return ids().filter(func(id): return is_expert(id, profession) or _uses_prof(id, prof))


static func _uses_prof(id: String, prof: String) -> bool:
    if id == "library":
        return prof == "scholar"
    for rid in info(id).get("jobs", []):
        if String(EconomyDefs.recipe(rid).get("prof", "")) == prof:
            return true
    return false
