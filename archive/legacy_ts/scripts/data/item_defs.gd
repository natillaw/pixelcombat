class_name ItemDefs
extends RefCounted
## Equipment as data (D-039 slots): rarities, base items, affixes, legendary/mythic uniques and sets.
## An item instance is a plain Dictionary made by ItemGen (saved inside the hero or the stash), so
## there is one inventory model and no dangling references. Numbers are tuning placeholders.

const SLOTS := ["main_hand", "off_hand", "head", "chest", "hands", "legs", "feet", "ring1", "ring2", "amulet", "special", "bag"]
const SLOT_NAMES := {"main_hand": "Main hand", "off_hand": "Off hand", "head": "Head", "chest": "Chest", "hands": "Hands",
    "legs": "Legs", "feet": "Feet", "ring1": "Ring", "ring2": "Ring", "amulet": "Amulet", "special": "Special", "bag": "Bag"}

## affixes = random properties; mult = base stat multiplier; quality = how strong the properties roll
## (x the affix range); unique = gets a unique power. D-122: a fixed base + 1-2 random properties by
## rarity (green 1, blue and up 2, stronger the rarer). D-123: grey junk is never worn, only salvaged.
const RARITIES := {
    "junk": {"name": "Junk", "affixes": 0, "mult": 0.6, "quality": 0.0, "color": Color(0.55, 0.55, 0.55), "weight": 0.0, "junk": true},
    "common": {"name": "Common", "affixes": 0, "mult": 1.0, "quality": 1.0, "color": Color(0.92, 0.92, 0.92), "weight": 60.0},
    "uncommon": {"name": "Uncommon", "affixes": 1, "mult": 1.1, "quality": 1.0, "color": Color(0.45, 0.9, 0.45), "weight": 28.0},
    "rare": {"name": "Rare", "affixes": 2, "mult": 1.2, "quality": 1.1, "color": Color(0.4, 0.6, 1.0), "weight": 9.0},
    "epic": {"name": "Epic", "affixes": 2, "mult": 1.35, "quality": 1.3, "color": Color(0.75, 0.4, 1.0), "weight": 2.5},
    "legendary": {"name": "Legendary", "affixes": 2, "mult": 1.5, "quality": 1.55, "color": Color(1.0, 0.6, 0.15), "weight": 0.45},
    "unique": {"name": "Unique", "affixes": 2, "mult": 1.6, "color": Color(1.0, 0.22, 0.22), "weight": 0.0, "unique": true},
    "mythic": {"name": "Mythic", "affixes": 3, "mult": 1.7, "color": Color(1.0, 0.25, 0.3), "weight": 0.0, "unique": true},   # old saves only
}
## D-077: common (white), uncommon (green), rare (blue), epic (purple), legendary (orange), unique (red).
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "unique", "mythic"]

## kind: "weapon" | "armor" | "jewel". slot: where it goes ("ring" fits ring1/ring2). two_handed fills
## both hands. classes = trained users (others get NOVICE_EFF of its stats). stats grow per item level.
const NOVICE_EFF := 0.75
const PER_ILVL := 0.12
const BASES := {
    "sword": {"name": "Sword", "kind": "weapon", "slot": "main_hand", "stats": {"atk": 6}, "classes": ["class.warrior", "class.rogue", "class.commoner"]},
    "greataxe": {"name": "Greataxe", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"atk": 11}, "classes": ["class.warrior"]},
    "dagger": {"name": "Dagger", "kind": "weapon", "slot": "main_hand", "stats": {"atk": 4, "crit": 0.04}, "classes": ["class.rogue"]},
    "mace": {"name": "Mace", "kind": "weapon", "slot": "main_hand", "stats": {"atk": 5, "mag": 2}, "classes": ["class.cleric", "class.warrior"]},
    "bow": {"name": "Longbow", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"atk": 8}, "classes": ["class.archer"], "visual_base": "bow"},
    # D-127: the bows D-082 reserved for items (interval_pct < 0 = slower shots)
    "recurve": {"name": "Recurve bow", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"atk": 8, "crit": 0.03}, "classes": ["class.archer"], "visual_base": "bow"},
    "longbow": {"name": "Great bow", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"atk": 11, "interval_pct": -0.08}, "classes": ["class.archer"], "visual_base": "bow"},
    "crossbow": {"name": "Crossbow", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"atk": 13, "interval_pct": -0.15}, "classes": ["class.archer"], "visual_base": "bow"},
    "staff": {"name": "Staff", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"mag": 9}, "classes": ["class.mage", "class.cleric"]},
    "wand": {"name": "Wand", "kind": "weapon", "slot": "main_hand", "stats": {"mag": 5}, "classes": ["class.mage"]},
    "shield": {"name": "Shield", "kind": "armor", "slot": "off_hand", "stats": {"def": 4}, "classes": ["class.warrior", "class.cleric", "class.commoner"],
        "block": {"chance": 0.12, "reduce": 0.5, "arc_deg": 120.0}},
    "kite_shield": {"name": "Kite shield", "kind": "armor", "slot": "off_hand", "stats": {"def": 6}, "classes": ["class.warrior", "class.cleric"],
        "block": {"chance": 0.15, "reduce": 0.5, "arc_deg": 120.0}},
    "bronze_shield": {"name": "Bronze shield", "kind": "armor", "slot": "off_hand", "stats": {"def": 5, "hp": 6}, "classes": ["class.warrior", "class.cleric"],
        "block": {"chance": 0.12, "reduce": 0.6, "arc_deg": 140.0}},
    # D-126 armour by class: "armor" = plate (blacksmith: warriors), leather (tanner: rogues and archers),
    # cloth (tailor: mages and clerics). ItemLibrary.ARMOR_BY_CLASS says who wears what.
    "helm": {"name": "Helm", "kind": "armor", "slot": "head", "stats": {"def": 2}, "classes": [], "armor": "plate"},
    "hood": {"name": "Hood", "kind": "armor", "slot": "head", "stats": {"mres": 2}, "classes": [], "armor": "cloth"},
    "mail": {"name": "Mail shirt", "kind": "armor", "slot": "chest", "stats": {"def": 4, "hp": 10}, "classes": [], "armor": "plate"},
    "robe": {"name": "Robe", "kind": "armor", "slot": "chest", "stats": {"mres": 4, "mag": 1}, "classes": [], "armor": "cloth"},
    "gloves": {"name": "Gauntlets", "kind": "armor", "slot": "hands", "stats": {"def": 1, "atk": 1}, "classes": [], "armor": "plate"},
    "greaves": {"name": "Greaves", "kind": "armor", "slot": "legs", "stats": {"def": 2}, "classes": [], "armor": "plate"},
    "boots": {"name": "Boots", "kind": "armor", "slot": "feet", "stats": {"def": 1, "move": 4.0}, "classes": [], "armor": "leather"},
    "leather_cap": {"name": "Leather cap", "kind": "armor", "slot": "head", "stats": {"def": 1, "crit": 0.01}, "classes": [], "armor": "leather"},
    "leather_vest": {"name": "Leather armour", "kind": "armor", "slot": "chest", "stats": {"def": 3, "hp": 6}, "classes": [], "armor": "leather"},
    "leather_pants": {"name": "Leather trousers", "kind": "armor", "slot": "legs", "stats": {"def": 1, "move": 2.0}, "classes": [], "armor": "leather"},
    "cloth_pants": {"name": "Woven trousers", "kind": "armor", "slot": "legs", "stats": {"mres": 2}, "classes": [], "armor": "cloth"},
    "sandals": {"name": "Sandals", "kind": "armor", "slot": "feet", "stats": {"mres": 1, "move": 3.0}, "classes": [], "armor": "cloth"},
    # D-124 bags: more backpack slots in the tower (stat "pack"); only the tanner makes them.
    "satchel": {"name": "Satchel", "kind": "bag", "slot": "bag", "stats": {"pack": 2}, "classes": [], "no_drop": true},
    "backpack": {"name": "Backpack", "kind": "bag", "slot": "bag", "stats": {"pack": 4}, "classes": [], "no_drop": true},
    "ring": {"name": "Ring", "kind": "jewel", "slot": "ring", "stats": {"crit": 0.02}, "classes": []},
    "amulet": {"name": "Amulet", "kind": "jewel", "slot": "amulet", "stats": {"mres": 2, "status_resist": 0.03}, "classes": []},
    "charm": {"name": "Trinket", "kind": "jewel", "slot": "special", "stats": {"hp": 8}, "classes": []},
    # owner 2026-11-02: jeweller variety. Each base has its own main stat; affixes add the random part.
    "ruby_band": {"name": "Ruby band", "kind": "jewel", "slot": "ring", "stats": {"atk": 2}, "classes": []},
    "sapphire_band": {"name": "Sapphire band", "kind": "jewel", "slot": "ring", "stats": {"mag": 2}, "classes": []},
    "iron_band": {"name": "Iron band", "kind": "jewel", "slot": "ring", "stats": {"def": 2}, "classes": []},
    "heart_pendant": {"name": "Heart pendant", "kind": "jewel", "slot": "amulet", "stats": {"hp": 12}, "classes": []},
    "sun_pendant": {"name": "Sun pendant", "kind": "jewel", "slot": "amulet", "stats": {"atk": 1, "mag": 1, "crit": 0.01}, "classes": []},
    "swift_chain": {"name": "Swift chain", "kind": "jewel", "slot": "amulet", "stats": {"move": 5.0, "interval_pct": 0.03}, "classes": []},
    # owner 2026-11-02: trinkets with a chance-based passive ("proc", see TRINKET_PROCS). The passive only
    # works for the classes listed (others get the stats at NOVICE_EFF and no passive).
    "blood_rune": {"name": "Blood rune", "kind": "jewel", "slot": "special", "stats": {"hp": 6}, "classes": ["class.warrior"],
        "proc": {"type": "leech_strike", "chance": 0.05, "frac": 1.0}},
    "bulwark_rune": {"name": "Bulwark rune", "kind": "jewel", "slot": "special", "stats": {"def": 1}, "classes": ["class.warrior"],
        "proc": {"type": "shield_on_hurt", "chance": 0.08, "pct": 0.15, "dur": 6.0}},
    "shadow_rune": {"name": "Shadow rune", "kind": "jewel", "slot": "special", "stats": {"crit": 0.01}, "classes": ["class.rogue"],
        "proc": {"type": "echo_strike", "chance": 0.10, "frac": 0.6}},
    "hawk_rune": {"name": "Hawk rune", "kind": "jewel", "slot": "special", "stats": {"atk": 1}, "classes": ["class.archer"],
        "proc": {"type": "mark_on_hit", "chance": 0.10, "dur": 4.0}},
    "mana_rune": {"name": "Mana rune", "kind": "jewel", "slot": "special", "stats": {"mag": 1}, "classes": ["class.mage"],
        "proc": {"type": "cd_reduce", "chance": 0.10, "secs": 2.0}},
    "mercy_rune": {"name": "Mercy rune", "kind": "jewel", "slot": "special", "stats": {"mres": 1}, "classes": ["class.cleric"],
        "proc": {"type": "mend_ally", "chance": 0.08, "pct": 0.12}},
    "thorn_rune": {"name": "Thorn rune", "kind": "jewel", "slot": "special", "stats": {"def": 1}, "classes": [],
        "proc": {"type": "stun_on_hurt", "chance": 0.08, "dur": 1.0}},
    "lucky_clover": {"name": "Lucky clover", "kind": "jewel", "slot": "special", "stats": {"hp": 4}, "classes": [],
        "proc": {"type": "regen_on_hurt", "chance": 0.06, "pct": 0.03, "dur": 5.0}},
    # D-082b starter kit (white, never looted or crafted: "starter"). Clothes have no stats; weapons the minimum.
    "plain_shirt": {"name": "Plain shirt", "kind": "armor", "slot": "chest", "stats": {}, "classes": [], "starter": true},
    "plain_pants": {"name": "Plain trousers", "kind": "armor", "slot": "legs", "stats": {}, "classes": [], "starter": true},
    "plain_shoes": {"name": "Plain shoes", "kind": "armor", "slot": "feet", "stats": {}, "classes": [], "starter": true},
    "plain_sword": {"name": "Simple sword", "kind": "weapon", "slot": "main_hand", "stats": {"atk": 1}, "classes": ["class.warrior"], "starter": true, "visual_base": "sword"},
    "plain_shield": {"name": "Round wooden shield", "kind": "armor", "slot": "off_hand", "stats": {"def": 1}, "classes": ["class.warrior"], "starter": true,
        "block": {"chance": 0.1, "reduce": 0.5, "arc_deg": 120.0}},
    "plain_dagger": {"name": "Simple dagger", "kind": "weapon", "slot": "main_hand", "stats": {"atk": 1}, "classes": ["class.rogue"], "starter": true, "visual_base": "dagger"},
    "plain_offhand_dagger": {"name": "Simple off-hand dagger", "kind": "weapon", "slot": "off_hand", "stats": {}, "classes": ["class.rogue"], "starter": true, "visual_base": "dagger"},
    "plain_bow": {"name": "Simple bow", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"atk": 1}, "classes": ["class.archer"], "starter": true, "visual_base": "bow"},
    "plain_staff": {"name": "Simple staff", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"mag": 1}, "classes": ["class.mage", "class.cleric"], "starter": true, "visual_base": "staff"},
    "plain_club": {"name": "Club", "kind": "weapon", "slot": "main_hand", "stats": {"atk": 1}, "classes": [], "starter": true, "visual_base": "mace"},
}
## D-082b: what every hero (and the Master) wears and carries when they join: real white items.
const STARTER_OUTFIT := {"chest": "plain_shirt", "legs": "plain_pants", "feet": "plain_shoes"}
const STARTER_WEAPONS := {
    "class.warrior": {"main_hand": "plain_sword", "off_hand": "plain_shield"},
    "class.rogue": {"main_hand": "plain_dagger", "off_hand": "plain_offhand_dagger"},
    "class.archer": {"main_hand": "plain_bow"},
    "class.mage": {"main_hand": "plain_staff"},
    "class.cleric": {"main_hand": "plain_staff"},
    "class.commoner": {"main_hand": "plain_club"},
}


## slot -> base of the starter kit of a class.
static func starter_kit(class_id: String) -> Dictionary:
    var out: Dictionary = STARTER_OUTFIT.duplicate()
    out.merge(STARTER_WEAPONS.get(class_id, {}))
    return out
## Trinket passives (BASES "proc"): what each type does, for tooltips. %d = chance in percent.
const TRINKET_PROCS := {
    "leech_strike": "%d%% on hit: heal for the full damage of that hit",
    "shield_on_hurt": "%d%% when hit: a shield of 15%% max HP",
    "echo_strike": "%d%% on hit: the blow echoes for 60%% more damage",
    "mark_on_hit": "%d%% on hit: marks the target (+25%% damage taken)",
    "cd_reduce": "%d%% on hit: skill cooldowns -2 s",
    "mend_ally": "%d%% on hit: heals the most hurt ally 12%% of max HP",
    "stun_on_hurt": "%d%% when hit in melee: stuns the attacker 1 s",
    "regen_on_hurt": "%d%% when hit: regenerate 3%% max HP per second for 5 s",
}


## Tooltip line of a trinket passive ("" for items without one); the class that can use it.
static func proc_text(base_id: String) -> String:
    var b: Dictionary = BASES.get(base_id, {})
    if not b.has("proc"):
        return ""
    var p: Dictionary = b["proc"]
    var txt := String(TranslationServer.translate(String(TRINKET_PROCS.get(String(p["type"]), "%d%%")))) % roundi(float(p["chance"]) * 100.0)
    var cls: Array = b.get("classes", [])
    if not cls.is_empty():
        txt += " (%s)" % ", ".join(cls.map(func(c): return String(TranslationServer.translate(String(HeroTables.CLASSES.get(c, {}).get("name", c))))))
    return txt


## The old forge recipes (forge_weapon / forge_armor): the blacksmith only makes metal (D-126).
const CRAFTABLE := {"weapon": ["sword", "greataxe", "dagger", "mace"],
    "armor": ["shield", "kite_shield", "helm", "mail", "gloves", "greaves"]}

## group = only one affix of a group per item; kinds = item kinds it can roll on.
const AFFIXES := {
    "mighty": {"name": "Mighty", "stat": "atk", "min": 2.0, "max": 4.0, "group": "atk", "kinds": ["weapon", "jewel", "armor"]},
    "arcane": {"name": "Arcane", "stat": "mag", "min": 2.0, "max": 4.0, "group": "mag", "kinds": ["weapon", "jewel", "armor"]},
    "keen": {"name": "Keen", "stat": "crit", "min": 0.02, "max": 0.05, "group": "crit", "kinds": ["weapon", "jewel"]},
    "swift": {"name": "Swift", "stat": "interval_pct", "min": 0.04, "max": 0.08, "group": "speed", "kinds": ["weapon", "jewel"]},
    "sturdy": {"name": "Sturdy", "stat": "def", "min": 1.0, "max": 3.0, "group": "def", "kinds": ["armor", "jewel"]},
    "warded": {"name": "Warded", "stat": "mres", "min": 1.0, "max": 3.0, "group": "mres", "kinds": ["armor", "jewel"]},
    "vital": {"name": "of Vitality", "stat": "hp", "min": 6.0, "max": 14.0, "group": "hp", "kinds": ["armor", "jewel"]},
    "resolute": {"name": "of Resolve", "stat": "status_resist", "min": 0.03, "max": 0.07, "group": "resist", "kinds": ["armor", "jewel"]},
    "fleet": {"name": "Fleet", "stat": "move", "min": 4.0, "max": 9.0, "group": "move", "kinds": ["armor", "jewel"]},
    "vampiric": {"name": "Vampiric", "stat": "lifesteal", "min": 0.03, "max": 0.06, "group": "leech", "kinds": ["weapon", "jewel"]},
    "thorned": {"name": "Thorned", "stat": "thorns", "min": 0.08, "max": 0.15, "group": "thorns", "kinds": ["armor"]},
}
## Grows with item level (flat stats only; percentages stay in range).
const SCALING_STATS := ["atk", "mag", "def", "mres", "hp"]

## Uniques: a fixed base with a power that changes how the hero fights. Mythic = the same power
## strengthened (power x MYTHIC_POWER) plus one more affix (RARITIES).
const MYTHIC_POWER := 1.5
const UNIQUES := {
    "emberbrand": {"name": "Emberbrand", "base": "sword", "power": {"on_hit_status": "burn", "chance": 0.35, "dur": 3.0, "mult": 0.12},
        "desc": "Hits may set the target on fire."},
    "gravewhisper": {"name": "Gravewhisper", "base": "dagger", "power": {"kill_heal": 0.15},
        "desc": "Each kill heals 15% of max HP."},
    "frostweave": {"name": "Frostweave", "base": "staff", "power": {"on_hit_status": "slow", "chance": 0.5, "dur": 2.0, "mult": 0.0},
        "desc": "Basic attacks may slow the target."},
    "bramblehide": {"name": "Bramblehide", "base": "mail", "power": {"thorns": 0.25},
        "desc": "Melee attackers take 25% of the damage back."},
    "wayfarer": {"name": "Wayfarer's Stride", "base": "boots", "power": {"slow_immune": 1.0, "move": 10.0},
        "desc": "Cannot be slowed; moves faster."},
}

## Sets: bonuses at 2 and 3 pieces that change play, not only numbers.
const SETS := {
    "warden": {"name": "Warden's Vigil", "pieces": {"helm": "Warden's Helm", "mail": "Warden's Hauberk", "shield": "Warden's Bulwark"},
        "bonus": {2: {"hp_pct": 0.1}, 3: {"shield_mult": 1.5}},
        "desc": "2: +10% max HP. 3: every shield the hero gives or gets is 50% stronger."},
    "nightstalker": {"name": "Nightstalker", "pieces": {"dagger": "Nightstalker Fang", "gloves": "Nightstalker Grips", "boots": "Nightstalker Treads"},
        "bonus": {2: {"crit": 0.05}, 3: {"busy_bonus": 0.3}},
        "desc": "2: +5% crit. 3: +30% damage to foes busy fighting someone else (basic attacks and skills)."},
}


static func rarity_color(r: String) -> Color:
    return RARITIES.get(r, RARITIES["common"])["color"]


## D-060: 8 slots are open now (they match the Dragon Regalia frames); hands, ring2 and special exist
## in the data and saves but stay locked until opened (nothing is generated or equipped for them).
const ACTIVE_SLOTS := ["main_hand", "off_hand", "head", "chest", "hands", "legs", "feet", "ring1", "amulet", "special", "bag"]   # D-077: + hands, trinket; D-124: + bag


static func slot_open(slot: String) -> bool:
    return ACTIVE_SLOTS.has(slot)


## True when a base goes into an open slot (loot and crafting only make these for now).
static func base_open(base_id: String) -> bool:
    return not slots_for(base_id).is_empty() and not bool(BASES[base_id].get("starter", false))   # D-082b: the kit is never loot


## D-124: a base that can come out of a corpse (bags are only made by the tanner).
static func base_droppable(base_id: String) -> bool:
    return base_open(base_id) and not bool(BASES[base_id].get("no_drop", false))


## D-123: grey junk is never worn, only salvaged.
static func is_junk(item: Dictionary) -> bool:
    return String(item.get("rarity", "")) == "junk"


## Which open equipment slots a base can go in.
static func slots_for(base_id: String) -> Array:
    var s := String(BASES[base_id]["slot"])
    var all: Array = ["ring1", "ring2"] if s == "ring" else [s]
    return all.filter(func(x): return ACTIVE_SLOTS.has(x))


static func item_label(item: Dictionary) -> String:
    return "%s (%s, ilvl %d)" % [item.get("name", "?"), RARITIES.get(String(item.get("rarity", "common")), {}).get("name", ""), int(item.get("ilvl", 1))]


## Adds the equipment to derived stats (D-039). Weapons out of the class training give NOVICE_EFF.
## Also collects combat powers in stats["mods"]: "procs" (on-hit statuses), thorns, lifesteal,
## kill_heal, slow_immune and set bonuses (shield_mult, busy_bonus).
static func apply_equipment(stats: Dictionary, equipment: Dictionary, class_id: String) -> Dictionary:
    var out := stats.duplicate()
    var mods := {}
    var interval_pct := 0.0
    var hp_pct := 0.0
    var set_count := {}
    for slot in equipment:
        var it: Dictionary = equipment[slot]
        var base: Dictionary = BASES.get(String(it.get("base", "")), {})
        if base.is_empty():
            continue
        var classes: Array = base.get("classes", [])
        var eff := 1.0 if classes.is_empty() or classes.has(class_id) else NOVICE_EFF
        var all: Dictionary = (it.get("stats", {}) as Dictionary).duplicate()
        for a in it.get("affixes", []):
            all[String(a["stat"])] = float(all.get(String(a["stat"]), 0.0)) + float(a["value"])
        if base.has("block") and class_id == "class.warrior":   # D-082b: shields block for warriors only (for now)
            mods["block"] = base["block"]
        if base.has("proc") and eff >= 1.0:              # trinket passives: only for their classes
            if not mods.has("trinket_procs"):
                mods["trinket_procs"] = []
            (mods["trinket_procs"] as Array).append(base["proc"])
        var power: Dictionary = it.get("power", {})
        if power.has("on_hit_status"):
            if not mods.has("procs"):
                mods["procs"] = []
            (mods["procs"] as Array).append(power)
        for k in power:
            match String(k):
                "move":
                    all["move"] = float(all.get("move", 0.0)) + float(power[k])
                "kill_heal", "thorns", "slow_immune":
                    mods[k] = float(mods.get(k, 0.0)) + float(power[k])
        for k in all:
            var v := float(all[k]) * eff
            match k:
                "atk", "mag", "def", "mres", "hp":
                    out[k] = int(out.get(k, 0)) + roundi(v)
                "crit", "status_resist":
                    out[k] = clampf(float(out.get(k, 0.0)) + v, 0.0, 0.6)
                "move":
                    out["move"] = float(out.get("move", 70.0)) + v
                "interval_pct":
                    interval_pct += v
                "lifesteal", "thorns":
                    mods[k] = float(mods.get(k, 0.0)) + v
        var st := String(it.get("set", ""))
        if st != "":
            set_count[st] = int(set_count.get(st, 0)) + 1
    for st in set_count:
        var bonus: Dictionary = SETS[st]["bonus"] if SETS.has(st) else ItemLibrary.SET_BONUS
        for need in bonus:
            if int(set_count[st]) >= int(need):
                for k in bonus[need]:
                    match k:
                        "hp_pct":
                            hp_pct += float(bonus[need][k])
                        "crit":
                            out["crit"] = clampf(float(out.get("crit", 0.0)) + float(bonus[need][k]), 0.0, 0.6)
                        "def", "mres", "atk", "mag", "hp":
                            out[k] = int(out.get(k, 0)) + int(bonus[need][k])
                        _:
                            mods[k] = bonus[need][k]
    out["hp"] = roundi(float(out.get("hp", 1)) * (1.0 + hp_pct))
    out["interval"] = clampf(float(out.get("interval", 1.0)) * (1.0 - interval_pct), 0.6, 1.6)
    out["mods"] = mods
    return out
