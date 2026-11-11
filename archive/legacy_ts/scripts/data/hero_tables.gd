class_name HeroTables
extends RefCounted
## Static game data. Every entry has a stable id (e.g. "trait.brave") so save files,
## lore and translations can reference it later without touching any code.
## Add new classes / traits / passives / backgrounds here and nowhere else.

const MAX_STARS := 5
const STAT_KEYS := ["hp", "atk", "mag", "def", "spd"]
const STAT_NAMES := {"hp": "HP", "atk": "ATK", "mag": "MAG", "def": "DEF", "spd": "SPD"}

const STAR_COLORS := {
    1: Color(0.62, 0.65, 0.68),
    2: Color(0.37, 0.75, 0.42),
    3: Color(0.29, 0.64, 1.0),
    4: Color(0.70, 0.42, 1.0),
    5: Color(1.0, 0.78, 0.24),
}

## Per-star rules. "hat"/"facial"/"held" = chance of getting that sprite layer.
## "style_rolls" = how many times a style is rolled (best one wins), so higher
## stars tend to get the fancier (higher numbered) clothes and hair.
const STAR_DATA := {
    1: {"level_cap": 10, "mult": 1.00, "traits": 1, "passives": 1, "hat": 0.05, "facial": 0.10, "held": 0.10, "style_rolls": 1},
    2: {"level_cap": 20, "mult": 1.25, "traits": 2, "passives": 1, "hat": 0.15, "facial": 0.15, "held": 0.30, "style_rolls": 1},
    3: {"level_cap": 40, "mult": 1.60, "traits": 2, "passives": 2, "hat": 0.35, "facial": 0.20, "held": 0.60, "style_rolls": 2},
    4: {"level_cap": 60, "mult": 2.10, "traits": 3, "passives": 2, "hat": 0.60, "facial": 0.25, "held": 0.85, "style_rolls": 2},
    5: {"level_cap": 80, "mult": 2.80, "traits": 3, "passives": 3, "hat": 0.85, "facial": 0.30, "held": 1.00, "style_rolls": 3},
}

## Sprite layers that have style + color variants: files are "<folder>/<style>_<color>.png".
## Style 1 of most folders is an empty "none" image, so it is left out of the lists.
const LAYER_DEFS := {
    "rear_hair": {"folder": "Rear_Hair", "styles": [2, 3, 4, 5, 6, 7, 8]},
    "front_hair": {"folder": "Front_Hair", "styles": [2, 3, 4, 5, 6]},
    "facial_hair": {"folder": "Facial_Hair", "styles": [2, 3, 4]},
    "top": {"folder": "Top", "styles": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]},
    "bottom": {"folder": "Bottom", "styles": [1, 2, 3, 4, 5]},
    "hat": {"folder": "Hat", "styles": [2, 3, 4, 5]},
}
const HELD_STYLES := [2, 3, 4, 5, 6]

## Core Classes (Commoner + 5 Fundamental Classes) and Professions for Lobby Base Building.
const CLASSES := {
    "class.none": {"name": "Novice", "reach": "melee",
        "desc": "No class yet. Grows into a fundamental class when promoted.",
        "base": {"hp": 75, "atk": 7, "mag": 5, "def": 4, "spd": 7}},
    "class.commoner": {"name": "Commoner", "reach": "melee",
        "desc": "An ordinary citizen turned adventurer. Very common, versatile, and eager to learn.",
        "base": {"hp": 85, "atk": 9, "mag": 5, "def": 6, "spd": 9}},
    "class.warrior": {"name": "Warrior", "reach": "melee",
        "desc": "Sturdy melee front-liner with solid defense.",
        "base": {"hp": 115, "atk": 13, "mag": 2, "def": 11, "spd": 7}},
    "class.rogue": {"name": "Rogue", "reach": "melee",
        "desc": "Swift and agile striker dealing rapid physical damage.",
        "base": {"hp": 85, "atk": 14, "mag": 3, "def": 5, "spd": 15}},
    "class.archer": {"name": "Archer", "reach": "ranged",
        "desc": "Backline marksman striking foes from afar.",
        "base": {"hp": 80, "atk": 12, "mag": 4, "def": 5, "spd": 12}},
    "class.cleric": {"name": "Cleric", "reach": "melee",
        "desc": "Holy protector providing vital support and healing.",
        "base": {"hp": 95, "atk": 8, "mag": 10, "def": 8, "spd": 8}},
    "class.mage": {"name": "Mage", "reach": "ranged",
        "desc": "Master of arcane destruction and elemental magic.",
        "base": {"hp": 70, "atk": 3, "mag": 17, "def": 4, "spd": 9}},
}
## D-035: attribute profile per class. attrs/growth order = ATTR_KEYS (FUE, AGI, VIT, INT, TEM).
## weapon/focus = flat physical/magic power of the class kit until real equipment exists (D-039);
## armor/mres = flat class defences; kind = damage type of the basic attack. Tuning placeholders.
## Task 03b: the ranger ("explorador") is now the archer. Old ids found in saves and simulator configs
## are read through canonical_class().
const CLASS_ALIASES := {"class.ranger": "class.archer", "class.explorador": "class.archer", "class.arquero": "class.archer"}


## The current class id for `id` (old aliases -> new id; anything else unchanged).
static func canonical_class(id: String) -> String:
    return String(CLASS_ALIASES.get(id, id))


const ATTR_KEYS := ["fue", "agi", "vit", "int", "tem"]
const ATTR_NAMES := {"fue": "FUE", "agi": "AGI", "vit": "VIT", "int": "INT", "tem": "TEM"}
## legacy stat key each attribute inherits its personal variance / trait modifier from
const ATTR_LEGACY := {"fue": "atk", "agi": "spd", "vit": "hp", "int": "mag", "tem": "def"}
const CLASS_COMBAT := {
    "class.none": {"attrs": [4, 4, 5, 3, 4], "growth": [0.5, 0.5, 0.5, 0.4, 0.4], "weapon": 2, "focus": 1, "armor": 1, "mres": 0, "kind": "physical"},
    "class.commoner": {"attrs": [5, 5, 6, 3, 5], "growth": [0.6, 0.6, 0.7, 0.3, 0.5], "weapon": 3, "focus": 1, "armor": 2, "mres": 0, "kind": "physical"},
    "class.warrior": {"attrs": [8, 4, 9, 2, 6], "growth": [1.0, 0.4, 1.1, 0.2, 0.6], "weapon": 6, "focus": 0, "armor": 6, "mres": 1, "kind": "physical"},
    "class.rogue": {"attrs": [6, 9, 5, 3, 4], "growth": [0.8, 1.1, 0.6, 0.3, 0.4], "weapon": 5, "focus": 0, "armor": 1, "mres": 0, "kind": "physical"},
    "class.archer": {"attrs": [6, 8, 5, 4, 5], "growth": [0.8, 1.0, 0.6, 0.4, 0.5], "weapon": 5, "focus": 1, "armor": 1, "mres": 1, "kind": "physical"},
    "class.cleric": {"attrs": [4, 4, 7, 7, 8], "growth": [0.4, 0.4, 0.8, 0.9, 1.0], "weapon": 2, "focus": 5, "armor": 3, "mres": 3, "kind": "magical"},
    "class.mage": {"attrs": [2, 5, 4, 10, 6], "growth": [0.2, 0.5, 0.5, 1.2, 0.7], "weapon": 1, "focus": 6, "armor": 0, "mres": 2, "kind": "magical"},
}

const BIRTH_CLASS_WEIGHTS := {
    "class.commoner": 35, "class.warrior": 15, "class.rogue": 15, "class.archer": 15, "class.cleric": 10, "class.mage": 10,
}
const PROMOTION_CLASS_POOL := []

const PROFESSIONS := {
    "occupation.farmer": {"name": "Farmer", "desc": "Worked the soil. Produces food ingredients in the lobby.", "bonus": "provisions", "action": "Pitchfork Thrust"},
    "occupation.chef": {"name": "Chef", "desc": "Prepared gourmet dishes. Converts ingredients into meal buffs.", "bonus": "cooking", "action": "Frying Pan Bash"},
    "occupation.blacksmith": {"name": "Blacksmith", "desc": "Forged weapons and armor. Crafts and repairs equipment.", "bonus": "smithy", "action": "Hammer Strike"},
    "occupation.lumberjack": {"name": "Lumberjack", "desc": "Felled timber in deep forests. Produces wood resources.", "bonus": "wood", "action": "Axe Chop"},
    "occupation.miner": {"name": "Miner", "desc": "Excavated tunnels. Yields ore and stone crystals.", "bonus": "ore", "action": "Pickaxe Swing"},
    "occupation.builder": {"name": "Builder / Carpenter", "desc": "Constructed dwellings. Improves building upgrades.", "bonus": "construction", "action": "Hammer Bonk"},
    "occupation.medic": {"name": "Medic / Apothecary", "desc": "Tended to the sick. Treats wounded characters and produces medicine.", "bonus": "healing", "action": "Bottle Throw"},
    "occupation.merchant": {"name": "Merchant", "desc": "Traded wares on roads. Improves trading access and town prices.", "bonus": "economy", "action": "Walking Stick Strike"},
    "occupation.guard": {"name": "Guard / Watchman", "desc": "Kept the peace. Contributes to settlement defense.", "bonus": "defense", "action": "Spear Thrust"},
    "occupation.hunter": {"name": "Hunter", "desc": "Tracked wild beasts. Produces meat, hides, and materials.", "bonus": "gathering", "action": "Basic Bow Shot"},
    "occupation.tailor": {"name": "Tailor / Leatherworker", "desc": "Stitched garments. Produces clothing and light armor.", "bonus": "clothing", "action": "Scissors Slash"},
    "occupation.engineer": {"name": "Engineer", "desc": "Built mechanical wonders. Supports traps and defenses.", "bonus": "traps", "action": "Wrench Strike"},
    "occupation.scout": {"name": "Scout", "desc": "Mapped unknown lands. Provides exploration intelligence.", "bonus": "intelligence", "action": "Dagger Stab"},
    "occupation.scholar": {"name": "Scholar", "desc": "Studied ancient tomes. Supports research and enemy lore.", "bonus": "research", "action": "Book Bash"},
    "occupation.alchemist": {"name": "Alchemist", "desc": "Brewed potions. Produces alchemical reagents and elixirs.", "bonus": "alchemy", "action": "Weak Potion Throw"},
    "occupation.priest": {"name": "Priest", "desc": "Offered prayers. Supports settlement morale and spiritual recovery.", "bonus": "morale", "action": "Staff Strike"},
    "occupation.fisher": {"name": "Fisher", "desc": "Casted nets at dawn. Provides fish and river catches.", "bonus": "fish", "action": "Fishing Rod Whack"},
    "occupation.stablehand": {"name": "Stablehand", "desc": "Tended to mounts and beasts of burden.", "bonus": "mounts", "action": "Pitchfork Jab"},
    "occupation.mason": {"name": "Mason", "desc": "Cut solid stone blocks. Supports stonework and fortifications.", "bonus": "stone", "action": "Chisel Strike"},
    "occupation.entertainer": {"name": "Entertainer", "desc": "Sang and performed. Boosts settlement morale and spirits.", "bonus": "morale", "action": "Instrument Bash"},
}

## Traits: personality. "mods" multiply stats, "passive" is the combat passive it can grant.
## D-080: no trait is free. Every trait has a downside (a mod below 1 or negative loyalty); the seven
## that had none got a -3% (placeholder) and tests/test_master.gd keeps it that way.
const TRAITS := {
    "trait.brave": {"name": "Brave", "desc": "Faces danger head-on.", "mods": {"atk": 1.05, "def": 0.97}, "passive": "passive.vanguard", "loyalty": 5},
    "trait.cautious": {"name": "Cautious", "desc": "Never takes a step without looking first.", "mods": {"def": 1.06, "spd": 0.97}, "passive": "passive.evasive", "loyalty": 0},
    "trait.greedy": {"name": "Greedy", "desc": "Always eyeing the loot.", "mods": {"spd": 1.04}, "passive": "passive.fortune", "loyalty": -8},
    "trait.loyal": {"name": "Loyal", "desc": "Sticks with the party to the end.", "mods": {"hp": 1.05, "atk": 0.97}, "passive": "passive.bodyguard", "loyalty": 15},
    "trait.arrogant": {"name": "Arrogant", "desc": "Believes they are the best in the room.", "mods": {"atk": 1.06, "def": 0.97}, "passive": "passive.showoff", "loyalty": -10},
    "trait.kind": {"name": "Kind", "desc": "Cannot leave anyone behind.", "mods": {"hp": 1.04, "atk": 0.97}, "passive": "passive.field_medic", "loyalty": 10},
    "trait.reckless": {"name": "Reckless", "desc": "Acts first, thinks later.", "mods": {"atk": 1.08, "def": 0.94}, "passive": "passive.berserk", "loyalty": -3},
    "trait.stoic": {"name": "Stoic", "desc": "Shows no fear and little emotion.", "mods": {"def": 1.04, "spd": 0.97}, "passive": "passive.resolute", "loyalty": 3},
    "trait.curious": {"name": "Curious", "desc": "Always poking at things.", "mods": {"mag": 1.06, "def": 0.97}, "passive": "passive.analyst", "loyalty": 0},
    "trait.lazy": {"name": "Lazy", "desc": "Does exactly what is needed, no more.", "mods": {"hp": 1.05, "spd": 0.95}, "passive": "passive.second_wind", "loyalty": -5},
    "trait.cunning": {"name": "Cunning", "desc": "Always has a trick up their sleeve.", "mods": {"spd": 1.05}, "passive": "passive.opportunist", "loyalty": -2},
    "trait.honorable": {"name": "Honorable", "desc": "Fights fair, keeps promises.", "mods": {"atk": 1.03, "def": 1.03, "spd": 0.97}, "passive": "passive.duelist", "loyalty": 12},
    "trait.hot_headed": {"name": "Hot-headed", "desc": "Quick to anger, quicker to move.", "mods": {"spd": 1.07, "def": 0.96}, "passive": "passive.first_strike", "loyalty": -4},
    "trait.cheerful": {"name": "Cheerful", "desc": "Keeps morale up no matter what.", "mods": {"hp": 1.03, "def": 0.97}, "passive": "passive.inspiring", "loyalty": 8},
    "trait.gloomy": {"name": "Gloomy", "desc": "Expects the worst, is rarely surprised.", "mods": {"def": 1.05}, "passive": "passive.pessimist", "loyalty": -3},
    "trait.stubborn": {"name": "Stubborn", "desc": "Refuses to go down.", "mods": {"hp": 1.06, "spd": 0.96}, "passive": "passive.iron_will", "loyalty": 2},
}
## Pairs of traits that never appear on the same hero.
const TRAIT_CONFLICTS := [
    ["trait.brave", "trait.cautious"], ["trait.kind", "trait.arrogant"],
    ["trait.cheerful", "trait.gloomy"], ["trait.lazy", "trait.reckless"],
    ["trait.honorable", "trait.cunning"], ["trait.loyal", "trait.greedy"],
]

## Combat passives. "effect" is data the battle system will read in the next drop.
const PASSIVES := {
    "passive.vanguard": {"name": "Vanguard", "desc": "+10% DEF while in the front row.", "effect": {"type": "stat_mult", "stat": "def", "value": 1.10, "when": "front_row"}},
    "passive.evasive": {"name": "Evasive", "desc": "8% chance to dodge an attack.", "effect": {"type": "dodge", "value": 0.08}},
    "passive.fortune": {"name": "Fortune Seeker", "desc": "+15% rewards from victories.", "effect": {"type": "reward_mult", "value": 1.15}},
    "passive.bodyguard": {"name": "Bodyguard", "desc": "Sometimes takes a hit meant for a wounded ally.", "effect": {"type": "intercept", "value": 0.20}},
    "passive.showoff": {"name": "Showoff", "desc": "+15% damage while at full HP.", "effect": {"type": "damage_mult", "value": 1.15, "when": "full_hp"}},
    "passive.field_medic": {"name": "Field Medic", "desc": "Heals the weakest ally for 3% max HP each turn.", "effect": {"type": "turn_heal", "value": 0.03}},
    "passive.berserk": {"name": "Berserk", "desc": "+25% ATK below 40% HP.", "effect": {"type": "stat_mult", "stat": "atk", "value": 1.25, "when": "low_hp"}},
    "passive.resolute": {"name": "Resolute", "desc": "Ignores the first stun each battle.", "effect": {"type": "status_immunity", "status": "stun", "charges": 1}},
    "passive.analyst": {"name": "Analyst", "desc": "+10% damage to enemies with a debuff.", "effect": {"type": "damage_mult", "value": 1.10, "when": "target_debuffed"}},
    "passive.second_wind": {"name": "Second Wind", "desc": "Once per battle, heals 30% HP when dropping below 25%.", "effect": {"type": "heal_once", "value": 0.30, "threshold": 0.25}},
    "passive.opportunist": {"name": "Opportunist", "desc": "+20% damage to enemies with a debuff.", "effect": {"type": "damage_mult", "value": 1.20, "when": "target_debuffed"}},
    "passive.duelist": {"name": "Duelist", "desc": "+20% damage against enemies in the same row.", "effect": {"type": "damage_mult", "value": 1.20, "when": "same_row"}},
    "passive.first_strike": {"name": "First Strike", "desc": "+25% SPD on the first turn of a battle.", "effect": {"type": "stat_mult", "stat": "spd", "value": 1.25, "when": "first_turn"}},
    "passive.inspiring": {"name": "Inspiring", "desc": "Allies deal +3% damage.", "effect": {"type": "aura_damage", "value": 1.03}},
    "passive.pessimist": {"name": "Pessimist", "desc": "Takes 15% less damage from critical hits.", "effect": {"type": "crit_reduction", "value": 0.15}},
    "passive.iron_will": {"name": "Iron Will", "desc": "Takes 10% less damage below 50% HP.", "effect": {"type": "damage_taken_mult", "value": 0.90, "when": "half_hp"}},
}

## Backgrounds. {name} is replaced with the hero's name. Neutral wording on purpose.
const BACKGROUNDS := [
    {"id": "bg.farmhand", "title": "Farmhand", "text": "{name} grew up working fields at the edge of a quiet village, until the fields stopped growing anything."},
    {"id": "bg.deserter", "title": "Deserter", "text": "{name} once wore a soldier's colors and walked away from a battle nobody talks about."},
    {"id": "bg.noble_exile", "title": "Exiled Noble", "text": "{name} was born into a great house and cast out of it. The reason changes every time it is told."},
    {"id": "bg.street_urchin", "title": "Street Urchin", "text": "{name} learned to survive on rooftops and in back alleys, trusting no one for free."},
    {"id": "bg.acolyte", "title": "Temple Acolyte", "text": "{name} spent years sweeping temple floors and memorizing prayers, then left with more questions than answers."},
    {"id": "bg.mercenary", "title": "Sellsword", "text": "{name} fights for coin and has never once regretted it. Mostly."},
    {"id": "bg.scholar", "title": "Failed Scholar", "text": "{name} was expelled from an academy for asking the wrong question to the wrong teacher."},
    {"id": "bg.hunter", "title": "Wilderness Hunter", "text": "{name} tracked beasts through the deep forests, and now something is tracking them back."},
    {"id": "bg.sailor", "title": "Former Sailor", "text": "{name} lost a ship, a crew, and a map to the same storm."},
    {"id": "bg.performer", "title": "Traveling Performer", "text": "{name} juggled, sang and swindled across a dozen towns before the show ran out of luck."},
    {"id": "bg.apprentice", "title": "Smith's Apprentice", "text": "{name} worked a forge until the master vanished one night, leaving only a half-finished blade."},
    {"id": "bg.wanderer", "title": "Cursed Wanderer", "text": "{name} carries a mark nobody can explain and keeps moving so it cannot catch up."},
]

const NAME_START := ["Al", "Bren", "Cael", "Dar", "El", "Fen", "Gar", "Hal", "Is", "Jor", "Kel", "Lys", "Mor", "Nyx", "Or", "Pyr", "Quin", "Rhe", "Sol", "Tam", "Ul", "Vex", "Wyn", "Yor", "Zel"]
const NAME_END := ["a", "an", "ar", "ek", "en", "eth", "in", "ira", "is", "on", "or", "us", "yn", "ia"]
const FAMILY_NAMES := ["Ashford", "Blackmoor", "Coldwater", "Dunmere", "Emberfall", "Frostwick", "Greymane", "Hollowell", "Ironvale", "Jadewood", "Kestrel", "Lowmarsh", "Mistral", "Northwind", "Oakheart", "Pinecrest", "Quillfeather", "Ravenscar", "Stonebrook", "Thornfield", "Underhill", "Valemont", "Whitlock", "Yarrow"]
const EPITHETS_4 := ["the Bold", "the Swift", "the Unyielding", "the Sharp-Eyed", "the Resolute", "of the Ember", "the Wayfarer", "the Silent", "the Fearless", "of the Frost"]
const EPITHETS_5 := ["the Radiant", "Dawnbringer", "the Undying", "Stormcaller", "the Legend", "Worldwalker", "the Starborn", "Oathkeeper", "the Eternal", "Skybreaker"]

## Obedience (command discipline) modifier per trait. Separate from Trust on purpose
## (spec sec 7): the trait "loyalty" field above is the TRUST modifier. Placeholders.
## Expedition temperament (D-056 autonomy): how far a trait pushes the hero toward risk. The sum over the
## hero's traits (clamped -3..3) sets how far it strays from the driven hero, how far it chases, and when
## it falls back hurt. Curious heroes (and scout classes) explore the fog nearby when nothing happens.
const AGGRESSION := {
    "trait.brave": 1, "trait.reckless": 2, "trait.hot_headed": 1, "trait.arrogant": 1,
    "trait.cautious": -2, "trait.gloomy": -1, "trait.lazy": -1, "trait.loyal": -1,
}
const EXPLORER_TRAITS := ["trait.curious"]
const LEASH_BASE := 150.0
const LEASH_PER_AGGRESSION := 50.0
const CHASE_PER_AGGRESSION := 30.0
const FALLBACK_HP := 0.35              # falls back below this HP fraction (cautious earlier, reckless later)
const FALLBACK_PER_AGGRESSION := 0.08


const OBEDIENCE_MODS := {
    "trait.brave": 3, "trait.cautious": 5, "trait.greedy": -6, "trait.loyal": 8,
    "trait.arrogant": -10, "trait.kind": 2, "trait.reckless": -8, "trait.stoic": 6,
    "trait.curious": -2, "trait.lazy": -6, "trait.cunning": -4, "trait.honorable": 10,
    "trait.hot_headed": -9, "trait.cheerful": 1, "trait.gloomy": 0, "trait.stubborn": -7,
}
