class_name GatherDefs
extends RefCounted
## D-117 (pista C): gathering spots as data. A spot has CHARGES (3-6, fixed by its position); each work
## cycle of CYCLE seconds gives one charge: its share of what the spot holds (the spot's total yield is
## unchanged, only spread over time). Empty spots disappear.
## Synergy "two on one ore" (pista A's SynergyDefs, read only if it exists): a second hero on the same
## spot speeds it up, with a chance per cycle to break it (the remaining charges are lost).

const CHARGES := [3, 6]
const CYCLE := 5.0                       # seconds per charge
const SWING := 0.7                       # seconds between work "hits" (look only: chips, leaves)
const FADE := 0.4                        # seconds an empty spot takes to disappear
const SYNERGY_ID := "gather_pair"           # pista A's "Two on a Vein" (SynergyDefs.SYNERGIES)
## Used only when SynergyDefs has the synergy but no numbers for it.
const SYNERGY_FALLBACK := {"speed": 1.6, "break_chance": 0.15}
## Work look by kind: particle colour and the hero's verb (tooltip/label).
const WORK := {
    "ore": {"chip": Color(0.62, 0.62, 0.7), "verb": "Mining"},
    "stone": {"chip": Color(0.62, 0.6, 0.58), "verb": "Mining"},
    "wood": {"chip": Color(0.7, 0.5, 0.3), "verb": "Chopping"},
    "herb": {"chip": Color(0.45, 0.85, 0.4), "verb": "Picking herbs"},
    "cache": {"chip": Color(0.95, 0.8, 0.35), "verb": "Opening the cache"},
}
