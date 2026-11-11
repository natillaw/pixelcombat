class_name AltarDefs
extends RefCounted
## Master prompt E (2026-10-31): the Crimson Baron (floor 10) and his altar. Every number here.
## The Baron is immune to all damage while his shield holds. CHANNEL_HEROES heroes standing on an altar
## channel for CHANNEL_TIME s (any hit on a channeler breaks it) and the shield falls for VULN_TIME s,
## then it comes back. Phases by the Baron's health:
##   above PHASE2_AT: one altar
##   PHASE2_AT..PHASE3_AT: a second altar on the far side; BOTH_REQUIRED = both must be channeled
##   below PHASE3_AT: the altar moves after every vulnerable window

const CHANNEL_HEROES := 2
const CHANNEL_TIME := 8.0
const VULN_TIME := 25.0
const RADIUS := 46.0                 # standing on the altar
const PHASE2_AT := 0.66
const PHASE3_AT := 0.33
const BOTH_REQUIRED := true          # phase 2: both altars (false = either one)
const ALTAR_MIN_CELLS := 12          # an altar is this far (cells) from the Baron at least
const ALTAR_MAX_CELLS := 30
## The Baron sends adds to the altar while someone channels (and now and then anyway).
const ADDS_EVERY := 18.0
const ADDS := 2
const ADD_TYPES := ["bandido_degollador", "bandido_maton"]
## When the shield falls the Baron strikes towards the altar (an area there) every SLAM_EVERY s.
const SLAM_EVERY := 6.0               # the wave's area and damage: EnemyDefs.SKILLS["crimson_wave"]
## Subtle hints (no tutorial): a faint thread of light from the Baron to the altar, seen only within
## THREAD_SEEN px of either; a pulsing shield on "0" hits in the altar's rhythm (PULSE_HZ); a fallen
## adventurer with a hand on the altar; one line from a hero (once per attempt).
const THREAD_SEEN := 300.0
const PULSE_HZ := 1.2
const HERO_LINES := {
    "default": "That light isn't coming from him...",
    "trait.curious": "The stone over there is glowing with him. Look!",
    "trait.cautious": "Nothing touches him. Something else keeps him whole.",
    "trait.brave": "Then we break whatever shields him!",
}
