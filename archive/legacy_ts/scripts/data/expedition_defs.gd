class_name ExpeditionDefs
extends RefCounted
## Master prompt C (2026-10-31): offline expeditions. Heroes go back alone to floors already cleared
## and farm them while the player is away. Every number here (playtest starting values).

const UNLOCK_FLOOR := 5              # opens once floor 5 is cleared
const CHARGES_MAX := 3               # expeditions per day; portal upgrades raise it (+1 each)
const CHARGE_HOURS := 8.0            # one charge comes back every 8 real hours (3 a day)
const MINUTES_PER_FLOOR := 20.0      # real duration = floor x 20 min
const YIELD := 0.55                  # share of what playing the floor would give
const KILLS_PER_FLOOR := 10          # creature drops rolled as if this many fell
const MAX_HEROES := 5
## Offline gives the basics (owner: town materials come from the Wilds; no gold yet): T1 basics per
## floor level, then the floor's own drops (no key_ items, no first-clear rewards).
const BASICS_PER_FLOOR := {"herb": 1.0, "ore": 1.0, "hide": 0.6, "wood": 1.0}
const CAP_HOURS := 12.0              # an expedition left unclaimed longer gives nothing extra
## Optional rules, built but OFF by default.
const FLOOR_GAP := 0                 # > 0: only floors at least this far below the record
const RISK := false                  # true: a weak party brings less and comes back tired
const RISK_FATIGUE := 30
const STORAGE_LIMIT := 0             # > 0: max units an expedition can carry home
