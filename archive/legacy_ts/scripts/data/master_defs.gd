class_name MasterDefs
extends RefCounted
## D-080: the Master, the player's own character. A HeroData with is_master = true, made once in the
## character creator (MasterCreator) and the only hero the player drives in an expedition. The other
## heroes of the party act on their own. Every number here is a tuning placeholder.

## Debug only: brings back 1-5 to switch the driven hero (D-053) when the squad has a Master.
const DEBUG_HERO_SWITCH := false

## Rank of a mid rarity summon (HeroTables.STAR_DATA): same stats, level cap and promotions as any 3-star.
const STARS := 3
const NAME_MAX := 16
## Background: fixed, shown as text (the Spanish lives in StringsEs).
const BACKGROUND_ID := "bg.old_master"
const BACKGROUND_TITLE := "Former Master"
const BACKGROUND_TEXT := "Once the circle answered only to you. You lost it all, and now you begin again."
## The Master leads, so Trust and Obedience are full (D-051 never refuses the Master).
const TRUST := 100
const OBEDIENCE := 100

## Races the creator offers. D-081: human only for now (a Master saved as an elf migrates to human).
const RACES := ["human"]
const BODIES := ["male", "female"]
const BEARDS := ["", "beard_trimmed"]          # male bodies only, like the summoned
## Classes the creator offers, with the role shown (tank / damage / support / scout).
const CLASSES := {
    "class.warrior": {"role": "Tank", "text": "Holds the front line and takes the blows meant for the others."},
    "class.rogue": {"role": "Scout", "text": "Fast and light: finds the way, strikes first and gets out."},
    "class.archer": {"role": "Damage", "text": "Fights from a distance and picks off what threatens the squad."},
    "class.mage": {"role": "Damage", "text": "Fragile, but its spells hit the hardest of all."},
    "class.cleric": {"role": "Support", "text": "Keeps the squad standing with healing and protection."},
    "class.commoner": {"role": "Damage", "text": "No training, no limits: a bit of everything, eager to learn."},
}

## Wounded Master (D-080): the Master never dies. If the agony runs out or the squad leaves without them,
## the expedition fails and the Master comes home with this disease (EconomyDefs.DISEASES).
const WOUND_DISEASE := "master_wounded"


# --- D-081: the Master leads, the others carry -------------------------------------------------------
## The Master's own damage (basic attacks and skills): below a high-rarity hero of the same level and class.
const DAMAGE_MULT := 0.85

## Leadership: Master only. raw = BASE + PER_LEVEL x (level - 1) + memory points. Its effect uses
## frac = raw / (raw + HALF) (diminishing returns: never reaches 1).
const LEADERSHIP_BASE := 5.0
const LEADERSHIP_PER_LEVEL := 1.0
const LEADERSHIP_HALF := 40.0
## What frac buys: the radius of commands and of the pings (px), an Obedience bonus for heroes in that
## radius, and a share of the Composure they would lose that is spared.
const RADIUS_BASE := 160.0
const RADIUS_EXTRA := 160.0
const OBEY_BONUS_MAX := 15.0
const COMPOSURE_GUARD_MAX := 0.4

## Commands (keys 1 2 3 by default: COMMAND_KEYS; the input actions are master_command_1..3). The radius is
## the Master's leadership_radius(). A hero answers only inside it and with enough Obedience
## (CombatRules.OBEY_MIN after the leadership and bond bonuses; never a random roll, D-016).
const COMMAND_KEYS := [KEY_1, KEY_2, KEY_3]
const COMMANDS := {
    "focus_fire": {"name": "Focus fire!", "desc": "Heroes in range attack the Master's target and deal +15% damage for 6 s.",
        "slot": 0, "unlock_level": 1, "cooldown": 60.0, "duration": 6.0, "status": "focused"},
    "regroup": {"name": "Regroup!", "desc": "Heroes in range fall back to the Master and take 20% less damage for 5 s.",
        "slot": 1, "unlock_level": 5, "cooldown": 45.0, "duration": 5.0, "status": "rallied"},
    "hold_fast": {"name": "Hold fast!", "desc": "Heroes in range stop panicking and steady themselves (+40 Composure).",
        "slot": 2, "unlock_level": 10, "cooldown": 90.0, "composure": 40},
}
const FOCUS_OUT_DMG := 1.15
const RALLY_IN_DMG := 0.8

## Panic (D-081, minimal): Composure (0-100) drops on these events; the Master never panics. Below
## PANIC_BELOW the hero panics for PANIC_TIME s: cannot act, runs to the Master (or the squad) and ignores
## orders. When it ends Composure is back to PANIC_RECOVER. Leadership and bond spare part of each loss.
const COMPOSURE_LOSS := {"ally_down": 15, "ally_died": 25, "master_down": 30, "low_hp": 20}
const LOW_HP_FRAC := 0.25
const PANIC_BELOW := 30
const PANIC_TIME := 6.0
const PANIC_RECOVER := 45

## Bond Master-hero (every other hero, 0-100; new and migrated heroes start at BOND_START).
const BOND_START := 30
const BOND_DELTA := {"floor_cleared": 4, "rescued_by_master": 8, "mvp": 5, "ally_died": -6, "left_behind": -15}
## Tiers by bond: lowest value, name, Obedience bonus, share of the "master_down" Composure loss spared,
## and whether the hero rushes to lift the fallen Master on its own.
const BOND_TIERS := [
    {"min": 0, "name": "Distrustful", "obey": -10, "guard": 0.0, "rescue": false},
    {"min": 25, "name": "Wary", "obey": 0, "guard": 0.1, "rescue": false},
    {"min": 50, "name": "Loyal", "obey": 5, "guard": 0.25, "rescue": false},
    {"min": 75, "name": "Devoted", "obey": 10, "guard": 0.4, "rescue": true},
]

## Barber / mirror in the Summoner's Hall: re-opens only the Looks tab. Free (there is no gold yet, D-070).
const BARBER_COST := {}
## Hardcore (chosen once in the creator): skull shown on the HUD and the title (CC0, Voxel Dungeon Pack).
const HARDCORE_ICON := "res://assets/packs/voxel-dungeon-pack-full/ui/elements/icon_skull.png"

