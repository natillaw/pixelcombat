class_name LootDefs
extends RefCounted
## Master prompt A (2026-10-31): loot of tower floors 1-10, in ONE table so it can be rebalanced here.
## Owner's answer on the prompt: floors drop only a few materials (rare ones), procedural gear (already
## Game.complete_floor) and rare things; the town's basic materials stay in the Wilds (D-066). Gems stay
## the summon currency. Prompt IDs mapped to the repo's where they clash (kept the repo id):
##   cur_mana_shard -> gems · mat_wild_herb -> herb · mat_old_bone -> bone · mat_worn_leather -> hide
##   mat_copper_ore -> ore · mat_weak_essence -> essence · key_guardian_core -> core
##   con_potion_minor -> potion. New ids keep the prompt's names (mat_*, key_*, con_*).
## Tiers: T1 floors 1-4, T2 floors 5-9, T3 floor 10.

## Per floor. drops = per creature killed {id: [chance, min, max]}; chest = mission chest (always
## something); boss = the miniboss/boss {id: [chance, min, max]}; first = only on the first clear.
## "first_chance" overrides a boss chance on the first clear (legendary fragment 2% -> 10%).
const FLOORS := {
    1: {"drops": {"essence": [0.04, 1, 1]}, "chest": {"essence": [2, 2]}},   # owner 2026-11-02: potions only from alchemy (no potions in chests)
    2: {"drops": {"essence": [0.04, 1, 1]}, "chest": {"essence": [2, 2]}},
    3: {"drops": {"essence": [0.05, 1, 1]}, "chest": {"essence": [2, 2]}},
    4: {"drops": {"essence": [0.06, 1, 1], "mat_enchanted_cloth": [0.03, 1, 1]}, "chest": {"essence": [2, 2], "mat_enchanted_cloth": [1, 1]}},
    5: {"drops": {"mat_enchanted_cloth": [0.12, 1, 1], "essence": [0.05, 1, 1]}, "chest": {"mat_enchanted_cloth": [3, 3], "essence": [2, 2]},
        "boss": {"core": [1.0, 1, 2]}, "first": {"key_floor5_seal": 1}},
    6: {"drops": {"mat_iron_ore": [0.15, 1, 1], "mat_enchanted_cloth": [0.05, 1, 1]}, "chest": {"mat_iron_ore": [4, 4]}},
    7: {"drops": {"mat_resonant_crystal": [0.10, 1, 1], "mat_iron_ore": [0.05, 1, 1]}, "chest": {"mat_resonant_crystal": [2, 2]}},
    8: {"drops": {"mat_moon_flower": [0.12, 1, 1], "mat_resonant_crystal": [0.03, 1, 1]}, "chest": {"mat_moon_flower": [3, 3]}},
    9: {"drops": {"mat_rune_plate": [0.08, 1, 1], "mat_moon_flower": [0.05, 1, 1]}, "chest": {"mat_rune_plate": [2, 2], "essence": [3, 3]}},
    10: {"drops": {"mat_rune_plate": [0.06, 1, 1]}, "chest": {"essence": [5, 5]},
        "boss": {"key_guardian_heart": [1.0, 1, 1], "key_legendary_fragment": [0.02, 1, 1]}, "first_chance": {"key_legendary_fragment": 0.10}},
}
## A replay's chest pays this fraction (at least 1 of each line): repeating is predictable but smaller.
const REPLAY_CHEST := 0.4

## New items: tier, stack cap and use. Their display names live in EconomyDefs.RESOURCES (cat "tower")
## like every other resource; the greater-potion recipe is in EconomyDefs.RECIPES. No sell prices: the
## owner kept gems and there is no gold yet.
const ITEMS := {
    "mat_enchanted_cloth": {"tier": 2, "stack": 99, "desc": "Accessories with a minor passive."},
    "mat_iron_ore": {"tier": 2, "stack": 99, "desc": "T2 gear."},
    "mat_resonant_crystal": {"tier": 2, "stack": 50, "desc": "Synthesis catalyst; enchanting T2."},
    "mat_moon_flower": {"tier": 2, "stack": 99, "desc": "Greater potions."},
    "mat_rune_plate": {"tier": 2, "stack": 50, "desc": "Portal upgrades."},
    "key_floor5_seal": {"tier": 2, "stack": 1, "desc": "Portal shortcut to floor 5 (never used up)."},
    "key_guardian_heart": {"tier": 3, "stack": 10, "desc": "Promotion 2★→3★ or an epic weapon."},
    "key_legendary_fragment": {"tier": 3, "stack": 10, "desc": "10 = a guaranteed Rare+ summon."},
    "con_potion_major": {"tier": 2, "stack": 20, "desc": "Heals 60% of a hero."},
}

# --- pista D (D-120..D-129): loot on the body, backpacks, greed, consumables and books -------------

## D-120 creature loot. Before, tower creatures only rolled FLOORS "drops" (4-6% of a material) and all
## the gear came at the end of a cleared floor, straight into the stash: in play, enemies dropped nothing.
## Now each body may carry equipment (chance by rank: "elite" = a leader, a shaman or a caller), and
## everything stays on the body until a hero loots it. ITEM_RARITY_BONUS feeds ItemGen.roll_rarity.
## D-142 (owner, 2026-11-02): gear on 3% of normal creatures and 20% of elites (was 10% / 35%).
const CREATURE_ITEM_CHANCE := {"normal": 0.03, "elite": 0.20, "boss": 1.0}
## D-142: a floor's boss ALWAYS carries these pieces too, on top of its normal loot (floor -> [{base, rarity}]).
## Floor 10: an epic (purple) axe.
const BOSS_GUARANTEED := {10: [{"base": "greataxe", "rarity": "epic"}]}
const CREATURE_ITEMS := {"normal": 1, "elite": 1, "boss": 2}
const ITEM_RARITY_BONUS := {"normal": 0.0, "elite": 1.0, "boss": 3.0}
const JUNK_CHANCE := 0.35            # D-123: of the items a normal creature drops, this share is grey junk
## D-121 looting: a body with loot glows; holding F LOOT_HOLD s within LOOT_RANGE opens the loot window.
## Autonomous heroes standing next to a body with nothing to fight loot it on their own (AUTO_LOOT_*).
const LOOT_HOLD := 1.0
const LOOT_RANGE := 44.0
const AUTO_LOOT_RANGE := 40.0
const AUTO_LOOT_TIME := 1.2
## A won floor can end on the spot (the boss falls): the squad still sweeps the bodies around them.
const END_SWEEP := 260.0
## AI looting (MasterBot and the autonomous heroes; the player decides for themself): only with no living
## creature within LOOT_SAFE_RADIUS and not fighting; in HOLD_MISSIONS nobody walks off their post to loot
## (they loot what lies at their feet in a lull, and the end-of-floor sweep collects the rest).
const LOOT_SAFE_RADIUS := 320.0
const HOLD_MISSIONS := ["defense", "survival"]

## D-124 backpacks: items found in a run go into the looter's pack (PACK_SLOTS + the bag's "pack").
## Leaving the tower (success or escape) moves every pack into the Master's stash; a fallen hero drops
## their pack where they fell (anyone may pick it up); a pack left on the floor at the end is lost.
const PACK_SLOTS := 4
## D-123 salvage of junk (and of any stash piece): materials by item kind, x (1 + rarity rank).
const SALVAGE := {"weapon": {"ingot": 1}, "armor": {"ingot": 1}, "jewel": {"materials": 1}, "bag": {"hide": 1}}   # as before D-123
const SALVAGE_JUNK := {"weapon": {"ore": 2}, "armor": {"hide": 1, "materials": 1}, "jewel": {"materials": 1}, "bag": {"hide": 1}}

## D-125 the greedy trait (trait.greedy): the squad loots more (+loot_bonus per greedy hero, up to
## max_bonus, on item chance), greedy heroes reach for bodies from further away, but every item in a
## greedy hero's pack may be kept back on the way home (keep_chance). The Master notices each time with
## `discover` chance and can then confiscate (trust/obedience below) or punish by synthesis in the Hall.
const GREEDY := {"trait": "trait.greedy", "loot_bonus": 0.25, "max_bonus": 0.5, "loot_range_mult": 2.0,
    "keep_chance": 0.25, "discover": 0.4, "confiscate_trust": -8, "confiscate_obedience": 4}

## Owner 2026-11-02: healing potions are a town product (alchemy only) with a long per-hero cooldown.
## Heroes drink on their own below HEAL_POTION_AT; the Master only when the player presses POTION_KEY
## (the headless bot presses it for the Master at the same threshold).
const HEAL_POTION_CD := 300.0          # seconds between two healing potions of one hero (5 min)
const HEAL_POTION_AT := 0.25           # fraction of max HP under which a hero drinks
const HEAL_POTION := 0.4               # healing potion: fraction of max HP
const HEAL_POTION_MAJOR := 0.6         # greater potion
const POTION_KEY := KEY_D

## D-128 what a hero may carry in the bag (HeroData.bag), with what it does. "meal": eaten when the
## expedition starts, a buff for the whole run (fractions of max HP / attack / magic). camp_kit and arrows
## are for pista A (camp, ammunition): carried and kept until that system reads them.
const CONSUMABLES := {
    "potion": {}, "antidote": {}, "con_potion_major": {}, "elixir_strength": {}, "elixir_speed": {}, "elixir_defense": {},
    "meal_stew": {"meal": {"hp_pct": 0.10}, "desc": "+10% max HP for the whole expedition."},
    "meal_roast": {"meal": {"atk_pct": 0.08, "mag_pct": 0.08}, "desc": "+8% attack and magic for the whole expedition."},
    "meal_broth": {"meal": {"def_pct": 0.12, "mres_pct": 0.12}, "desc": "+12% armour and magic resistance for the whole expedition."},
    "meal_feast": {"meal": {"hp_pct": 0.08, "atk_pct": 0.05, "mag_pct": 0.05, "def_pct": 0.05}, "desc": "+8% max HP, +5% attack, magic and armour for the whole expedition."},
    "camp_kit": {"desc": "Set up a camp in the tower (rest point)."},
    "arrows": {"desc": "A quiver of arrows for archers."},
}

## D-129 books (rare tower drops; held in town storage until used from the inventory):
##   book_xp     one whole level for a hero;
##   book_skill  one extra skill choice (HeroData.bonus_skill_choice, read by pista A);
##   book_trade  +1 level in a profession (pista B points it at villagers; today: a hero's profession);
##   book_plan   a master plan: unlocks a building or upgrade (pista B: Game.apply_master_plan); kept until then.
const BOOKS := ["book_xp", "book_skill", "book_trade", "book_plan"]
const BOOK_WEIGHTS := {"book_xp": 50.0, "book_skill": 25.0, "book_trade": 15.0, "book_plan": 10.0}
const BOOK_CHANCE := {"normal": 0.0, "elite": 0.03, "boss": 0.30}
