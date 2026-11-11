class_name AptitudeDefs
extends RefCounted
## Owner 2026-11-01: not every hero can learn every trade. Each hero has a hidden aptitude per
## profession, fixed from birth: weighted base attributes (class base x the hero's own variance, so it
## never changes with level) + traits + a seeded roll. Tiers: incompatible / clumsy / normal / talented
## / prodigy. An apprenticeship (TownTables.SPECIALIST_ONLY) progresses every hour by
## BASE_PER_HOUR x tier x master x rand(0.7, 1.3); daily breakthroughs and frustrations; an incompatible
## apprentice gives up after INCOMPATIBLE_HOURS. The tier shows as "???" until the master has watched
## the apprentice for REVEAL_HOURS. All numbers here.

const TIERS := ["incompatible", "clumsy", "normal", "talented", "prodigy"]
const TIER_NAMES := {"incompatible": "Incompatible", "clumsy": "Clumsy", "normal": "Normal", "talented": "Talented", "prodigy": "Prodigy"}
const TIER_MULT := {"incompatible": 0.0, "clumsy": 0.5, "normal": 1.0, "talented": 1.5, "prodigy": 2.0}
## Score thresholds (score = weighted base attribute 1..10 + traits + roll -2.5..2.5).
const TIER_AT := [3.4, 5.0, 7.1, 8.4]          # measured percentiles: ~10% / 25% / 35% / 20% / 10%
const ROLL := 2.5
## Which base attributes a trade leans on (others: ProfessionDefs attr with weight 1).
const STATS := {
    "blacksmith": {"fue": 0.6, "vit": 0.4},
    "alchemist": {"int": 0.8, "tem": 0.2},
    "cook": {"agi": 0.5, "tem": 0.5},
    "jeweler": {"int": 0.5, "agi": 0.5},
}
## Traits nudge every trade (all) or one (prof id): points added to the score.
const TRAITS := {
    "trait.curious": {"all": 0.8}, "trait.lazy": {"all": -1.0}, "trait.stoic": {"blacksmith": 1.0},
    "trait.hot_headed": {"blacksmith": 0.6, "alchemist": -0.8}, "trait.cautious": {"alchemist": 1.0, "jeweler": 0.6},
    "trait.reckless": {"alchemist": -1.0, "jeweler": -0.6},
}
const BASE_PER_HOUR := 1.0 / 48.0               # a normal apprentice with a level-1 master: ~48 work hours
const MASTER_PER_LVL := 0.1                    # +10% speed per master level above 1
const BREAKTHROUGH := {"prodigy": 0.10, "talented": 0.06, "normal": 0.03}   # daily: +25% progress
const BREAKTHROUGH_GAIN := 0.25
const FRUSTRATION := {"clumsy": 0.08}          # daily: -10% progress
const FRUSTRATION_LOSS := 0.10
const INCOMPATIBLE_HOURS := 8                  # then "no talent for this" and they leave the post
const REVEAL_HOURS := 6                        # the master's opinion shows the tier
## Graduation: starting profession level by tier (+1 with GRAD_BONUS_CHANCE).
const GRAD_LEVEL := {"clumsy": 0, "normal": 0, "talented": 1, "prodigy": 2}
const GRAD_BONUS_CHANCE := 0.15


## The hero's fixed aptitude score for a trade (deterministic from its seed).
static func score(h: HeroData, prof: String) -> float:
    var base: Dictionary = HeroTables.CLASS_COMBAT.get(h.hero_class, HeroTables.CLASS_COMBAT["class.none"])
    var weights: Dictionary = STATS.get(prof, {String(ProfessionDefs.info(prof).get("attr", "fue")): 1.0})
    var s := 0.0
    for k in weights:
        var i := HeroTables.ATTR_KEYS.find(k)
        var v := float(base["attrs"][i]) if i >= 0 else 5.0
        if i >= 0:
            v *= float(h.variance.get(HeroTables.ATTR_LEGACY[k], 1.0))
        s += float(weights[k]) * v
    for t in h.traits:
        var m: Dictionary = TRAITS.get(String(t), {})
        s += float(m.get("all", 0.0)) + float(m.get(prof, 0.0))
    for g in h.innate:                       # D-079 trade gifts (a good summon also helps the town)
        var gd: Dictionary = PowerDefs.GIFTS.get(String(g), {})
        if String(gd.get("prof", "")) == prof:
            s += float(gd.get("aptitude", 0.0))
    var rng := RandomNumberGenerator.new()
    rng.seed = h.hero_seed ^ hash("aptitude:" + prof)
    return s + rng.randf_range(-ROLL, ROLL)


static func tier(h: HeroData, prof: String) -> String:
    var sc := score(h, prof)
    var t := 0
    while t < TIER_AT.size() and sc >= float(TIER_AT[t]):
        t += 1
    return String(TIERS[t])
