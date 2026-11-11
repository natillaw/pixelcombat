class_name ItemLibrary
extends RefCounted
## D-077 item library (owner, 2026-10-31), every number in this one file:
##   - TIERS by material, 10 floors each (only tier 1 is reachable today).
##   - Crafted lines: the blacksmith (metal weapons and armour), the workshop's woodworker (bows,
##     staves, wands) and the jeweller (rings, amulets, trinkets). Clean names ("Copper Mail Shirt"),
##     predictable stats, one affix chosen from 3, at most rare, and a tier SET for armour.
##   - Drops: themed by the enemy that dropped them (THEMES), random affixes up to legendary. A drop
##     and a crafted piece never share a name: drops carry the theme ("Cutthroat's Dagger").
##   - Cursed affixes: 15% of non-common pieces carry one, always with a good affix made stronger.
##   - Requirements: hero level by tier and a light class rule (a mage never wields a greataxe).
##   - Uniques (red): secret objectives only, 1-2% per completion, one per account forever.
## Potions and other consumables are alchemy-only (EconomyDefs recipes), never dropped.

const TIERS := {
    1: {"name": "Copper & Iron", "floors": [1, 10], "metal": "copper", "metal2": "iron", "wood": "Pine", "gem": "Quartz", "leather": "Rawhide", "cloth": "Linen", "min_level": 1, "ilvl": 5},
    2: {"name": "Steel", "floors": [11, 20], "metal": "steel", "wood": "Oak", "gem": "Amethyst", "leather": "Tanned", "cloth": "Wool", "min_level": 10, "ilvl": 15},
    3: {"name": "Silver & Mithril", "floors": [21, 30], "metal": "silver", "wood": "Yew", "gem": "Sapphire", "leather": "Hardened", "cloth": "Silk", "min_level": 20, "ilvl": 25},
    4: {"name": "Runic Gold", "floors": [31, 40], "metal": "gold", "wood": "Ironwood", "gem": "Ruby", "leather": "Wyrmhide", "cloth": "Runeweave", "min_level": 30, "ilvl": 35},
    5: {"name": "Obsidian & Draconic", "floors": [41, 50], "metal": "gold", "wood": "Elderwood", "gem": "Dragonstone", "leather": "Dragonhide", "cloth": "Starweave", "min_level": 40, "ilvl": 45},
}
const METAL_NAMES := {"copper": "Copper", "iron": "Iron", "steel": "Steel", "silver": "Mithril", "gold": "Runic"}

## Who makes what. cost = materials per tier step (x tier); time = work-hours. The line key is the building;
## D-126: the tanner and the tailor have no building yet (the town is pista B): until TownTables has one
## they work at "fallback".
const LINES := {
    "blacksmith": {"prof": "blacksmith", "bases": ["sword", "greataxe", "dagger", "mace", "shield", "kite_shield", "bronze_shield", "helm", "mail", "gloves", "greaves"],
        "cost": {"ingot": 3, "materials": 4}, "cost_t1": {"ore": 3, "materials": 3}, "time": 6.0, "name": "metal"},
    "workshop": {"prof": "carpenter", "bases": ["bow", "recurve", "longbow", "crossbow", "staff", "wand"], "cost": {"wood": 6, "materials": 3}, "time": 5.0, "name": "wood"},
    "jeweler": {"prof": "jeweler", "bases": ["ring", "ruby_band", "sapphire_band", "iron_band", "amulet", "heart_pendant", "sun_pendant", "swift_chain",
        "charm", "blood_rune", "bulwark_rune", "shadow_rune", "hawk_rune", "mana_rune", "mercy_rune", "thorn_rune", "lucky_clover"], "cost": {"ingot": 1, "materials": 2, "essence": 1}, "time": 6.0, "name": "gem"},
    "tannery": {"prof": "leatherworker", "fallback": "workshop", "bases": ["leather_cap", "leather_vest", "leather_pants", "boots", "satchel", "backpack"],
        "cost": {"hide": 4, "materials": 2}, "time": 5.0, "name": "leather"},
    "tailor": {"prof": "tailor", "fallback": "workshop", "bases": ["hood", "robe", "cloth_pants", "sandals"],
        "cost": {"silk": 2, "herb": 2, "materials": 1}, "time": 5.0, "name": "cloth"},
}
const CRAFT_MAX_RARITY := "rare"
const CRAFT_AFFIX_CHOICES := 3
## Smith sets (plate armour) per tier: pieces bonus at 2 / 3 / 4 pieces.
const SET_PIECES := ["helm", "mail", "gloves", "greaves"]
const SET_BONUS := {2: {"def": 2}, 3: {"hp_pct": 0.06}, 4: {"def": 4, "mres": 3, "hp_pct": 0.06}}
const SET_NAMES := {1: "Coppervein", 2: "Steelguard", 3: "Moonsilver", 4: "Runeforged", 5: "Dragonscale"}

## D-126: which armour weights a class wears (future subclasses add their own line). Classes not listed
## (and items with no "armor", like shields, jewels and the starter clothes) have no armour rule.
const ARMOR_BY_CLASS := {
    "class.warrior": ["plate", "leather"],
    "class.rogue": ["leather"],
    "class.archer": ["leather"],
    "class.mage": ["cloth"],
    "class.cleric": ["cloth"],
    "class.commoner": ["leather", "cloth"],
}
const ARMOR_NAMES := {"plate": "plate", "leather": "leather", "cloth": "cloth"}

## Drop themes: which bases an enemy family drops and how they are named.
const THEMES := {
    "bandit": {"bases": ["dagger", "sword", "bow", "recurve", "crossbow", "leather_cap", "leather_vest", "leather_pants", "boots", "hood", "ring", "shadow_rune", "thorn_rune", "sun_pendant", "swift_chain"],
        "names": ["Cutthroat's", "Brigand's", "Bandit's", "Highwayman's"]},
    "orc": {"bases": ["greataxe", "mace", "mail", "helm", "shield", "kite_shield", "bronze_shield", "gloves", "amulet", "blood_rune", "bulwark_rune", "ruby_band", "iron_band"], "names": ["Tribal", "Orcish", "Warchief's", "Bonecrusher"]},
    "undead": {"bases": ["sword", "staff", "robe", "cloth_pants", "sandals", "helm", "charm", "mana_rune", "mercy_rune", "sapphire_band"], "names": ["Grave", "Bone", "Hollow", "Wight's"]},
    "beast": {"bases": ["boots", "leather_cap", "leather_vest", "hood", "charm", "longbow", "lucky_clover", "hawk_rune", "heart_pendant"], "names": ["Hide", "Fang", "Pelt", "Wild"]},
}
static func theme_of(enemy_id: String) -> String:
    if enemy_id.begins_with("bandido") or enemy_id.begins_with("capitan") or enemy_id.begins_with("jefe_baron"):
        return "bandit"
    if enemy_id.begins_with("orc") or enemy_id.contains("goblin") or enemy_id == "warlord":
        return "orc"
    if enemy_id.begins_with("skeleton") or enemy_id.contains("zombie"):
        return "undead"
    return "beast"


## Cursed (bad) affixes: rolled on 15% of non-common pieces, always with a good one x CURSE_BOOST.
const CURSE_CHANCE := 0.15
const CURSE_BOOST := 1.5
const CURSES := {
    "brittle": {"name": "Brittle", "stat": "def", "min": -3.0, "max": -1.0},
    "frail": {"name": "of Frailty", "stat": "hp", "min": -12.0, "max": -6.0},
    "sluggish": {"name": "Sluggish", "stat": "move", "min": -8.0, "max": -4.0},
    "clumsy": {"name": "Clumsy", "stat": "crit", "min": -0.04, "max": -0.02},
    "dull": {"name": "Dull", "stat": "atk", "min": -3.0, "max": -1.0},
    "unwarded": {"name": "Unwarded", "stat": "mres", "min": -3.0, "max": -1.0},
}

## Light class rules: these classes cannot equip these bases at all (everything else may, at
## NOVICE_EFF if the class is not trained with it).
const FORBIDDEN := {"greataxe": ["class.mage", "class.cleric"], "staff": ["class.warrior"], "wand": ["class.warrior"],
    "bow": [], "shield": ["class.mage", "class.archer"]}

## Uniques (secret objectives): chance per completed secret; once per account.
const UNIQUE_CHANCE := 0.02


static func tier_of_ilvl(ilvl: int) -> int:
    for t in TIERS:
        if ilvl <= int(TIERS[t]["floors"][1]):
            return int(t)
    return 5


static func tier_of_floor(floor_num: int) -> int:
    return clampi(1 + (maxi(1, floor_num) - 1) / 10, 1, 5)


## Level needed to equip an item.
static func min_level(item: Dictionary) -> int:
    return int(TIERS[tier_of_ilvl(int(item.get("ilvl", 1)))]["min_level"])


## "" if the hero may equip the item, else why not.
static func equip_block(h: HeroData, item: Dictionary) -> String:
    if ItemDefs.is_junk(item):
        return "junk: salvage it for materials"
    if (FORBIDDEN.get(String(item.get("base", "")), []) as Array).has(h.hero_class):
        return "%s cannot use a %s" % [HeroTables.CLASSES[h.hero_class]["name"], String(ItemDefs.BASES[String(item["base"])]["name"]).to_lower()]
    var weight := armor_of(item)
    if weight != "" and ARMOR_BY_CLASS.has(h.hero_class) and not (ARMOR_BY_CLASS[h.hero_class] as Array).has(weight):
        return "%s cannot wear %s armour" % [HeroTables.CLASSES[h.hero_class]["name"], ARMOR_NAMES.get(weight, weight)]
    if h.level < min_level(item):
        return "needs level %d" % min_level(item)
    return ""


## D-126: "plate" | "leather" | "cloth" | "" (no armour rule).
static func armor_of(item: Dictionary) -> String:
    return String(ItemDefs.BASES.get(String(item.get("base", "")), {}).get("armor", ""))


## D-124: bags are one recipe each (tier 1), the bigger one needs a better tanner and twice the leather.
const BAG_RECIPES := {"satchel": {"min": 1, "cost_mult": 1}, "backpack": {"min": 3, "cost_mult": 2}}


## The building a line works in today (its own, or its fallback until the town builds it).
static func line_building(line: String) -> String:
    var fb := String(LINES[line].get("fallback", ""))
    return line if fb == "" or TownTables.BUILDINGS.has(line) else fb


## The crafted recipe id for a base at a tier.
static func recipe_id(line: String, base: String, tier: int) -> String:
    return "craft_%s_%s_t%d" % [line, base, tier]


## Display name of a crafted piece ("Copper Mail Shirt", "Pine Longbow", "Quartz Ring").
static func crafted_name(line: String, base: String, tier: int) -> String:
    var t: Dictionary = TIERS[tier]
    var word := ""
    match String(LINES[line]["name"]):
        "metal":
            word = String(METAL_NAMES.get(String(t["metal"]), "Iron"))
        "wood":
            word = String(t["wood"])
        "leather", "cloth":
            word = String(t[String(LINES[line]["name"])])
        _:
            word = String(t["gem"])
    if BAG_RECIPES.has(base):
        return String(ItemDefs.BASES[base]["name"])
    return "%s %s" % [word, ItemDefs.BASES[base]["name"]]


## Every crafted recipe of the library, EconomyDefs.RECIPES format plus "base", "tier", "line". Also
## the professions' plain recipes (ProfessionDefs.RECIPES: meals, camp kits, arrows), so each building
## lists them as jobs (TownTables.info).
static var _recipes: Dictionary = {}
static func recipes() -> Dictionary:
    if not _recipes.is_empty():
        return _recipes
    for line in LINES:
        var l: Dictionary = LINES[line]
        for tier in TIERS:
            for base in l["bases"]:
                var bag: Dictionary = BAG_RECIPES.get(base, {})
                if not bag.is_empty() and int(tier) != 1:
                    continue
                var cost: Dictionary = (l.get("cost_t1", l["cost"]) if int(tier) == 1 else l["cost"]).duplicate()
                for k in cost:
                    cost[k] = int(cost[k]) * int(tier) * int(bag.get("cost_mult", 1))
                if int(tier) >= 2:
                    cost["mat_iron_ore"] = 2 * (int(tier) - 1)
                var kind := String(ItemDefs.BASES[base]["kind"])
                _recipes[recipe_id(line, base, int(tier))] = {"name": crafted_name(line, base, int(tier)), "building": line_building(line),
                    "prof": String(l["prof"]), "min": int(bag.get("min", (int(tier) - 1) * 4 + (0 if kind == "jewel" else 1))), "work": float(l["time"]) + float(tier),
                    "in": cost, "out": {}, "craft": base, "tier": int(tier), "line": line,
                    "category": "Weapons" if kind == "weapon" else ("Jewellery" if kind == "jewel" else ("Bags" if kind == "bag" else "Armour"))}
    for rid in ProfessionDefs.RECIPES:
        var r: Dictionary = (ProfessionDefs.RECIPES[rid] as Dictionary).duplicate(true)
        if r.has("line"):
            r["building"] = line_building(String(r["line"]))
        _recipes[rid] = r
    return _recipes
