class_name ProfessionDefs
extends RefCounted
## Town professions (D-049): every hero knows at most MAX_KNOWN professions, each with a level
## (0 = apprentice .. MAX_LEVEL) and experience. The past-life occupation becomes the first one, at
## PAST_LIFE_LEVEL and with "passion" (faster learning). Numbers are tuning placeholders.

const MAX_KNOWN := 2              # D-049: main + secondary
const MAX_LEVEL := 10
const PAST_LIFE_LEVEL := 2
const PASSION_XP := 1.5           # experience multiplier on the past-life profession
const APPRENTICE_EFF := 0.3       # level-0 efficiency

## attr = attribute that helps (+2% efficiency per point above 5).
const PROFESSIONS := {
    "builder": {"name": "Builder", "family": "craft", "attr": "fue", "desc": "Raises and upgrades buildings (D-048)."},
    "blacksmith": {"name": "Blacksmith", "family": "craft", "attr": "fue", "desc": "Smelts ore and forges weapons and armor."},
    "woodworker": {"name": "Woodworker", "family": "craft", "attr": "agi", "desc": "Carves bows, staves and wands (D-077)."},
    "jeweler": {"name": "Jeweller", "family": "craft", "attr": "int", "desc": "Sets rings, amulets and trinkets (D-077)."},
    "carpenter": {"name": "Carpenter", "family": "craft", "attr": "agi", "desc": "Turns wood and stone into building materials."},
    "miner": {"name": "Miner", "family": "gather", "attr": "fue", "desc": "Digs ore and stone."},
    "lumberjack": {"name": "Lumberjack", "family": "gather", "attr": "fue", "desc": "Fells trees for wood."},
    "farmer": {"name": "Farmer", "family": "gather", "attr": "vit", "desc": "Grows grain and herbs."},
    "cook": {"name": "Cook", "family": "service", "attr": "tem", "desc": "Turns grain into meals."},
    "alchemist": {"name": "Alchemist", "family": "medicine", "attr": "int", "desc": "Brews medicine, potions and antidotes."},
    "doctor": {"name": "Doctor", "family": "medicine", "attr": "int", "desc": "Treats diseases and wounds in the hospital."},
    "scholar": {"name": "Scholar", "family": "knowledge", "attr": "int", "desc": "Working in the Library makes skill-book transcription cheaper."},
    "tavernkeeper": {"name": "Tavern keeper", "family": "service", "attr": "tem", "desc": "Makes the tavern more relaxing."},
    # D-126: armour by class. Their own buildings come with the town (pista B); until then they work in
    # the workshop (ItemLibrary.LINES "fallback").
    "leatherworker": {"name": "Leatherworker", "family": "craft", "attr": "agi", "desc": "Tans hides into leather armour for rogues and archers, bags and camp kits."},
    "tailor": {"name": "Tailor", "family": "craft", "attr": "int", "desc": "Weaves robes, hoods and trousers for mages and clerics."},
}

## D-128 plain recipes of the professions (same format as EconomyDefs.RECIPES; "line" = the
## ItemLibrary line whose building runs it). Consumables for the other tracks: meals with a buff for the
## whole expedition (LootDefs.CONSUMABLES), the camp kit (pista A's camp) and quivers of arrows.
const RECIPES := {
    # owner 2026-11-02: expedition meals are the kitchen's (blvl = kitchen level needed): no kitchen, no buffs
    "cook_stew": {"name": "Cook hearty stew", "building": "kitchen", "prof": "cook", "min": 1, "blvl": 1, "work": 3.0, "in": {"grain": 2, "herb": 1}, "out": {"meal_stew": 2}},
    "cook_roast": {"name": "Cook spiced roast", "building": "kitchen", "prof": "cook", "min": 2, "blvl": 2, "work": 3.0, "in": {"grain": 1, "herb": 2, "fang": 1}, "out": {"meal_roast": 2}},
    "cook_broth": {"name": "Cook bone broth", "building": "kitchen", "prof": "cook", "min": 2, "blvl": 3, "work": 4.0, "in": {"grain": 1, "herb": 2, "bone": 2}, "out": {"meal_broth": 2}},
    "cook_feast": {"name": "Cook a hunter's feast", "building": "kitchen", "prof": "cook", "min": 3, "blvl": 4, "work": 6.0, "in": {"grain": 3, "herb": 2, "hide": 1, "fang": 1}, "out": {"meal_feast": 2}},
    "make_camp_kit": {"name": "Make a camp kit", "line": "tannery", "prof": "leatherworker", "min": 1, "work": 4.0, "in": {"hide": 2, "wood": 2}, "out": {"camp_kit": 1}},
    "fletch_arrows": {"name": "Fletch arrows", "line": "workshop", "prof": "carpenter", "min": 0, "work": 2.0, "in": {"wood": 2, "ore": 1}, "out": {"arrows": 2}},
}

## Past-life occupation (HeroTables.PROFESSIONS) -> town profession it starts with.
const FROM_PAST_LIFE := {
    "occupation.builder": "builder", "occupation.mason": "builder", "occupation.engineer": "builder",
    "occupation.blacksmith": "blacksmith", "occupation.lumberjack": "lumberjack", "occupation.miner": "miner",
    "occupation.farmer": "farmer", "occupation.stablehand": "farmer", "occupation.chef": "cook",
    "occupation.fisher": "cook", "occupation.hunter": "leatherworker", "occupation.alchemist": "alchemist",   # D-126: hunter -> leatherworker
    "occupation.medic": "doctor", "occupation.priest": "doctor", "occupation.scholar": "scholar",
    "occupation.entertainer": "tavernkeeper", "occupation.merchant": "tavernkeeper", "occupation.tailor": "tailor",   # D-126: tailor -> tailor
    "occupation.guard": "builder", "occupation.scout": "lumberjack",
}


static func info(id: String) -> Dictionary:
    return PROFESSIONS.get(id, {})


static func xp_to_next(level: int) -> int:
    return 10 + 6 * level


## Work done per hour by a worker of this level (before health/fatigue).
static func efficiency(level: int) -> float:
    return APPRENTICE_EFF if level <= 0 else 0.5 + 0.1 * float(level)
