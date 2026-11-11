class_name ProgressionDefs
extends RefCounted
## Hero progression of the vertical slice (data, tuning placeholders): expedition experience and MVP,
## ascension (promotion) at the Sanctuary of Ascension, and skill training at the Training Grounds.

# --- expedition experience (ExpeditionResults) ---------------------------------------------------
## 2026-10-31 (Nathaniel): slower levelling. XP is measured against the hero's own next level
## (HeroData.xp_to_next), so a normal floor clear never fills a whole level.
## Completion XP for every surviving hero = COMPLETE_FRAC x xp_to_next (success only).
const COMPLETE_FRAC := 0.35
## Creature worth (EnemyDefs.XP_PER_HP x max HP, summed) is multiplied by this before it is shared.
const KILL_XP_MULT := 0.35
## A normal run (completion + creatures) is capped at NORMAL_CAP_FRAC x xp_to_next: ~55% at level 1,
## shrinking by NORMAL_CAP_DECAY per level down to NORMAL_CAP_MIN as the curve climbs.
const NORMAL_CAP_FRAC := 0.55
const NORMAL_CAP_DECAY := 0.01
const NORMAL_CAP_MIN := 0.25
## A hero above a floor's expected level (1 + floor x LEVELS_PER_FLOOR) earns OVERLEVEL_DECAY less per
## level over it (never below OVERLEVEL_MIN): replaying low floors is not a farm.
const LEVELS_PER_FLOOR := 1.0
const OVERLEVEL_DECAY := 0.2
const OVERLEVEL_MIN := 0.1
## The Wilds pay only creature XP, times this (no completion, no MVP): they are for materials.
const WILDS_XP_MULT := 0.7          # beta: farming the Wilds must level fresh recruits (still < a floor)
## The creatures' worth is shared by the survivors: SHARE_FLAT of it equally, the rest by contribution.
## An escape keeps this part (no completion, no MVP).
const SHARE_FLAT := 0.6
## Special cases are multiplicative and bounded: the MVP (top contributor) and a completed secret
## objective each multiply that hero's run XP; the total never exceeds BONUS_CAP_FRAC x xp_to_next.
## MVP + secret on a normal clear ≈ 0.55 x 1.4 x 1.4 ≈ 1.08 levels.
const MVP_MULT := 1.4
const SECRET_MULT := 1.4
const BONUS_CAP_FRAC := 1.15
## Contribution weights (each category normalised by the squad total, so a healer can top a fighter).
const CONTRIB_WEIGHTS := {"damage": 1.0, "kills": 0.6, "healing": 1.0, "shield": 0.6, "rescues": 0.8,
    "explored": 0.7, "objective": 1.0, "gathered": 0.4, "tanked": 0.5}
const CONTRIB_LABELS := {"damage": "dealt the most damage", "kills": "struck the final blows", "healing": "kept the squad alive",
    "shield": "shielded the squad", "rescues": "carried the fallen back", "explored": "scouted the way",
    "objective": "carried the mission", "gathered": "gathered for the town", "tanked": "took the blows for the others"}

# --- floor completion ------------------------------------------------------------------------------
## D-066: tower floors no longer pay town materials (the Wilds do, DungeonDefs). A first clear pays gems,
## stones, gear (Game.complete_floor) and the tower-only rarities: starsteel (TOWER_STARSTEEL_BASE + floor/2)
## and spirit essence (1 + floor/3). The old FLOOR_MATERIALS_* (D-064) are gone.
const TOWER_STARSTEEL_BASE := 1
## Master prompt B pacing (2026-10-31): about one summon (100 gems) every ~2 runs. A first clear pays
## FIRST_GEMS_BASE + FIRST_GEMS_PER_FLOOR x floor (~1 summon while climbing); a replay pays
## REPLAY_GEMS_BASE + REPLAY_GEMS_PER_FLOOR x floor (~half a summon at floor 10): small but predictable.
const FIRST_GEMS_BASE := 60
const FIRST_GEMS_PER_FLOOR := 15
const REPLAY_GEMS_BASE := 30
const REPLAY_GEMS_PER_FLOOR := 2

# --- ascension (promotion) -----------------------------------------------------------------------
## Materials per target star (tower drops make the player explore and hunt specific creatures).
const ASCENSION_COST := {
    2: {"materials": 30, "hide": 4, "gel": 3, "silk": 2},
    3: {"materials": 80, "bone": 6, "spore": 4, "venom": 3, "ingot": 2, "essence": 2},
    4: {"materials": 160, "core": 2, "bone": 10, "silk": 6, "ingot": 6, "essence": 4, "starsteel": 2},
    5: {"materials": 300, "core": 5, "venom": 10, "ingot": 12, "essence": 8, "starsteel": 5},
}
const ASCENSION_BASE := 0.5          # base chance
const ASCENSION_PER_LUCK := 0.03     # luck 1..10
const ASCENSION_PER_SANCTUARY := 0.04  # per sanctuary level above 1
const ASCENSION_PITY_STEP := 0.15    # each failure adds this to the next try
const ASCENSION_PITY_HARD := 3       # after this many failures in a row the next try cannot fail
const ASCENSION_FAIL_KEEP := 0.5     # a failure gives back this fraction of the tower materials (never the hero's level)

# --- training (Training Grounds) ------------------------------------------------------------------
## A hero of 2+ stars may train (stars - 1) extra class skills; each time it chooses 1 of up to 3.
const TRAIN_MIN_STARS := 2
const TRAIN_OPTIONS := 3
const TRAIN_COST := {"materials": 25, "ingot": 1}


# --- synthesis and sacrifice (D-061; provisional numbers, G-21 / G-22) --------------------------------
const SYNTH_EFFICIENCY := 0.30        # share of the sources' total experience the target receives
const SYNTH_SAME_CLASS := 0.40        # ... when the source is of the target's class
const SYNTH_MAX_SOURCES := 3
const SYNTH_ATTR_BONUS := 1           # +1 permanent to the source's best attribute (same class only)
## Sacrifice: materials by stars, plus a class flavour.
const SACRIFICE := {
    1: {"materials": 15, "hide": 1},
    2: {"materials": 35, "bone": 2, "silk": 1},
    3: {"materials": 70, "bone": 3, "core": 1},
    4: {"materials": 120, "core": 2, "venom": 3},
    5: {"materials": 200, "core": 3, "ingot": 5},
}
const SACRIFICE_CLASS := {"class.warrior": {"bone": 1}, "class.rogue": {"venom": 1}, "class.archer": {"silk": 1},
    "class.mage": {"spore": 2}, "class.cleric": {"herb": 2}, "class.commoner": {"materials": 5}, "class.none": {"materials": 5}}
