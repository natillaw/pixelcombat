class_name PowerDefs
extends RefCounted
## Soft block of the tower (proposal D-079, 2026-11-01): the tower never locks a floor, but every floor
## expects a level of preparation (town gear, consumables, buildings, a good summon). Below it the squad
## takes more damage and deals less. The player never sees power numbers: only "Risk: N%" with a band and
## at most 3 qualitative hints (PowerCalc.floor_risk). Every number here is a TUNING PLACEHOLDER, fitted
## with tools/sim_power_curve.gd (criteria in that script).
##
## D-065 still holds: creatures grow +10%/floor (EnemyDefs.floor_scale) and nothing here rescales them.
## The required power PR measures what a floor EXPECTS from the squad; the soft block only acts on the
## squad's own damage when it falls short.

## Debug only: show the raw numbers (PR, squad power by source) next to the Risk. Never on for players.
const DEBUG_SHOW_NUMBERS := false

# --- required power per floor ------------------------------------------------------------------------
## PR(f) = POWER_BASE x POWER_GROWTH^f x (1 + ARC_STEP x arc(f)), arc = (f - 1) / 10 (integer: one step per
## arc of ten floors). PR is per hero slot; a floor asks for PR x its squad size (TowerExpedition.party_max).
const POWER_BASE := 70.0
const POWER_GROWTH := 1.026
const ARC_STEP := 0.15

# --- how a hero's stats become power ---------------------------------------------------------------
## Same weights as HeroData.power() plus the stats it ignored (mres, crit). A stat missing on a hero is 0.
const STAT_WEIGHTS := {"hp": 0.1, "atk": 1.5, "mag": 1.5, "def": 1.0, "mres": 0.5, "spd": 1.0, "crit": 50.0}
## Gear slots that count as offence for the hints ("your weapons are worn"); the rest is defence.
const OFFENCE_SLOTS := ["main_hand"]

## Consumables carried in the hero's bag (HeroData.bag): power as a fraction of the hero's base power,
## per unit, counting at most CONSUMABLE_MAX_EACH of each id. Ids without an entry give nothing.
const CONSUMABLE_FRAC := {
    "potion": 0.04, "con_potion_major": 0.07, "antidote": 0.02,
    "elixir_strength": 0.05, "elixir_speed": 0.04, "elixir_defense": 0.05,
}
const CONSUMABLE_MAX_EACH := 3

## Passive town bonuses (building id -> {"of": source it multiplies, "per_level": fraction per level}).
## A hero gets per_level x level x (its power from that source). Buildings missing from the save give 0.
## TODO: these are the only "passive" building effects in combat; none of them exists as a stat yet, the
## soft block is where they act (they lower the ratio, so the squad's damage penalty shrinks).
const TOWN_BONUS := {
    "blacksmith": {"of": "gear", "per_level": 0.07},          # upkeep and sharpening of the gear
    "training_grounds": {"of": "base", "per_level": 0.03},
    "kitchen": {"of": "base", "per_level": 0.015},            # well fed before the climb
    "infirmary": {"of": "base", "per_level": 0.015},
    "alchemy": {"of": "consumables", "per_level": 0.15},      # better brews
}

## Expected share of PR covered by each source, by floor (linear between rows). Used to calibrate and to
## pick the hints ("what is missing most is gear").
const POWER_BUDGET := [
    {"floor": 1, "base": 1.00, "gear": 0.00, "consumables": 0.00, "town": 0.00},
    {"floor": 10, "base": 0.70, "gear": 0.25, "consumables": 0.05, "town": 0.00},
    {"floor": 30, "base": 0.45, "gear": 0.35, "consumables": 0.10, "town": 0.10},
    {"floor": 60, "base": 0.30, "gear": 0.40, "consumables": 0.15, "town": 0.15},
    {"floor": 100, "base": 0.20, "gear": 0.40, "consumables": 0.20, "town": 0.20},
]

# --- the summon's ceiling ------------------------------------------------------------------------------
## base + gacha_traits count in full only up to GACHA_CAP_FRAC x PR (by floor, linear between rows);
## above it the extra counts GACHA_OVER_CAP. A bare 5-star squad cannot replace the town.
const GACHA_CAP := [{"floor": 1, "frac": 1.0}, {"floor": 5, "frac": 1.0}, {"floor": 100, "frac": 0.55}]
const GACHA_OVER_CAP := 0.25

# --- effect in combat (computed once when the squad enters, SandboxScreen.soft_block) -------------------
## ratio = PR / squad power. Below 1 nothing changes (no bonus for coming over-prepared).
## damage taken x clamp(ratio, 1, RATIO_MAX) ^ DMG_TAKEN_EXP; damage dealt x clamp(1 / ratio, RATIO_MIN, 1) ^ DMG_DEALT_EXP.
const DMG_TAKEN_EXP := 1.5
const DMG_DEALT_EXP := 1.2
const RATIO_MAX := 2.0
const RATIO_MIN := 0.5

# --- risk (the only thing the player sees) ----------------------------------------------------------
## Logistic on the ratio: risk = 100 / (1 + exp(-RISK_K x (ratio - RISK_MID))).
## ratio 0.8 ~ 17%, 1.0 ~ 35%, 1.25 ~ 65%, 1.6 ~ 91%.
const RISK_K := 4.95
const RISK_MID := 1.125
## Fewer heroes than the floor lets in: + this per empty place (on top of the lower squad power).
const RISK_PER_MISSING := 6.0
## Mission type extras.
const MISSION_RISK := {"boss": 8.0}
const RISK_MIN := 1
const RISK_MAX := 99
## Bands: upper bound (inclusive) -> id. Names and colours for the gate.
const BANDS := [{"max": 25, "id": "low"}, {"max": 50, "id": "medium"}, {"max": 75, "id": "high"}, {"max": 100, "id": "extreme"}]
const BAND_NAMES := {"low": "Low", "medium": "Moderate", "high": "High", "extreme": "Extreme"}
const BAND_COLORS := {"low": Color(0.45, 0.9, 0.45), "medium": Color(1.0, 0.88, 0.35), "high": Color(1.0, 0.6, 0.2), "extreme": Color(1.0, 0.3, 0.25)}
const MAX_HINTS := 3
## A source only becomes a hint when it misses at least this share of PR.
const HINT_MIN_DEFICIT := 0.04

# --- mechanical walls: floor modifiers (FloorMods) and their counters ------------------------------------
## Per hero, coverage is 1 when the hero carries the counter (bag item, equipped base, weapon affix) or has
## the gift; a gift also covers every other hero at GIFT_GROUP_COVER. Effect left = 1 - reduction x coverage.
## risk = the modifier's "risk" x (1 - average coverage of the squad).
## "todo": counters the economy does not have yet (never invented here; see the D-079 summary).
const COUNTERS := {
    "fog": {"bag": [], "bases": [], "affixes": [], "gifts": ["innate.owl_eyes"], "reduction": 0.6, "risk": 8.0,
        "todo": "lantern or torch (craftable): no such item exists yet"},
    "hazard": {"bag": ["antidote"], "bases": [], "affixes": [], "gifts": ["innate.poison_ward"], "reduction": 0.6, "risk": 8.0,
        "todo": ""},
    "enrage": {"bag": [], "bases": [], "affixes": ["swift"], "gifts": ["innate.cold_blood"], "reduction": 0.6, "risk": 7.0,
        "todo": "weapon affix 'damage to wounded foes': does not exist yet (swift = burst stands in)"},
    "no_heal": {"bag": [], "bases": ["mail", "shield"], "affixes": [], "gifts": ["innate.regeneration"], "reduction": 0.6, "risk": 8.0,
        "todo": "rations / food with regeneration before the floor: no such consumable yet"},
}
## Only the main hand is checked for the "affixes" counters (a burst weapon).
const COUNTER_AFFIX_SLOTS := ["main_hand"]
const GIFT_GROUP_COVER := 0.5

# --- summon gifts (innate traits rolled at the summon, HeroGenerator v5) ------------------------------
## "combat" gifts stand in for a counter (cover = how much of it on the hero itself; group cover is
## GIFT_GROUP_COVER x cover) and add power_frac x base power. "trade" gifts add aptitude points to one
## trade (AptitudeDefs.score). Old heroes keep [] (never rerolled, D-004).
const GIFTS := {
    "innate.owl_eyes": {"name": "Owl Eyes", "kind": "combat", "counter": "fog", "cover": 1.0, "power_frac": 0.05,
        "desc": "Sees through mist."},
    "innate.poison_ward": {"name": "Poison-proof", "kind": "combat", "counter": "hazard", "cover": 1.0, "power_frac": 0.05,
        "desc": "Poison barely takes hold."},
    "innate.cold_blood": {"name": "Cold Blood", "kind": "combat", "counter": "enrage", "cover": 1.0, "power_frac": 0.05,
        "desc": "Keeps calm against enraged foes."},
    "innate.regeneration": {"name": "Regeneration", "kind": "combat", "counter": "no_heal", "cover": 0.5, "power_frac": 0.05,
        "desc": "Wounds close a little even where nothing heals."},
    "innate.born_smith": {"name": "Born Smith", "kind": "trade", "prof": "blacksmith", "aptitude": 1.5, "desc": "A natural at the forge."},
    "innate.keen_nose": {"name": "Keen Nose", "kind": "trade", "prof": "alchemist", "aptitude": 1.5, "desc": "A natural at brewing."},
    "innate.good_palate": {"name": "Good Palate", "kind": "trade", "prof": "cook", "aptitude": 1.5, "desc": "A natural cook."},
    "innate.steady_hand": {"name": "Steady Hand", "kind": "trade", "prof": "jeweler", "aptitude": 1.5, "desc": "A natural jeweller."},
}
## Chance of one combat gift by stars; a 5-star may roll a second one (GIFT_SECOND_5).
const GIFT_CHANCE := {1: 0.03, 2: 0.06, 3: 0.12, 4: 0.25, 5: 0.45}
const GIFT_SECOND_5 := 0.08
## Chance of one trade gift by stars (a good pull also helps the town).
const TRADE_GIFT_CHANCE := {1: 0.04, 2: 0.07, 3: 0.12, 4: 0.20, 5: 0.32}
