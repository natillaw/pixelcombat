class_name SummonConfig
extends RefCounted
## Data-driven summon banners (spec: SUMMONS_AND_HERO_GENERATION sec 3 + 10).
## Every number here is a TUNING PLACEHOLDER. Change it here, never inside game logic.
## Rates are percentages and must sum to 100 (validate() checks it, Game refuses a bad banner).

const DEFAULT_BANNER := "standard"
## Overhaul LPC (D-F): hero races and their weights. D-082: no more elves among the summoned (the Master
## lost them in D-081); elves already in a save keep their look (it is saved, D-004).
const RACE_WEIGHTS := {"human": 100}
## The ten free summons of a new account: early-game odds (1-star common, 2-star sometimes, 3-star very
## rare), no 4-5 stars. Viability and a guaranteed builder are enforced by Game.starter_summons().
const STARTER_BANNER := "starter"
const STARTER_COUNT := 10
const STARTER_MIN_FIGHTERS := 4      # at least this many combat classes among the ten
const LOG_CAP := 200
## Playtest 2026-10-31 (#10): 2000 gems at 10 per summon were 200 summons, so beds were the only limit and
## a summon + sacrifice loop with one free bed gave five 5-star heroes and endless materials. Gems now
## buy a handful of summons; the tower pays more of them (Game.complete_floor).
const START_GEMS := 300   # how many past summons are kept in the save (reproducibility log)

const BANNERS := {
    "standard": {
        "name": "Standard Summon",
        "version": 1,
        "currency": "gems",
        "rates": [50.0, 30.0, 14.0, 5.0, 1.0],   # 1-star .. 5-star
        "pity4": 10,        # 4-star or better guaranteed within this many pulls
        "pity5": 80,        # 5-star guaranteed within this many pulls
        "cost_single": 100,
        "multi_count": 10,
        "cost_multi": 900,
    },
    "starter": {
        "name": "First Summoning",
        "version": 1,
        "currency": "gems",
        "rates": [72.0, 26.0, 2.0, 0.0, 0.0],
        "pity4": 9999,      # no pity on the free summons (they never touch the account's pity either)
        "pity5": 9999,
        "cost_single": 0,
        "multi_count": 10,
        "cost_multi": 0,
    },
}

## Used only when two heroes would show the same display name (spec: disambiguate with callsigns).
const CALLSIGNS := [
    "Ember", "Fox", "Wren", "Ash", "Hawk", "Moth", "Cinder", "Thorn", "Raven", "Sparrow",
    "Flint", "Briar", "Lark", "Slate", "Marrow", "Dusk", "Fable", "Rook", "Sable", "Tarn",
]


static func get_banner(id: String) -> Dictionary:
    if not BANNERS.has(id):
        return {}
    return (BANNERS[id] as Dictionary).duplicate(true)


static func default_banner() -> Dictionary:
    return get_banner(DEFAULT_BANNER)


## Returns a list of problems (empty = valid).
static func validate(b: Dictionary) -> Array:
    var errs: Array = []
    for key in ["rates", "pity4", "pity5", "cost_single", "multi_count", "cost_multi"]:
        if not b.has(key):
            errs.append("missing key: %s" % key)
    if not errs.is_empty():
        return errs
    var rates: Array = b["rates"]
    if rates.size() != HeroTables.MAX_STARS:
        errs.append("rates needs %d entries" % HeroTables.MAX_STARS)
    var total := 0.0
    for r in rates:
        if float(r) < 0.0:
            errs.append("negative rate")
        total += float(r)
    if absf(total - 100.0) > 0.001:
        errs.append("rates sum to %s, must be 100" % total)
    if int(b["pity4"]) < 1 or int(b["pity5"]) < int(b["pity4"]):
        errs.append("pity values invalid (need 1 <= pity4 <= pity5)")
    if int(b["cost_single"]) < 0 or int(b["cost_multi"]) < 0 or int(b["multi_count"]) < 2:
        errs.append("costs/multi_count invalid")
    return errs


static func cost_for(b: Dictionary, count: int) -> int:
    if count == int(b["multi_count"]):
        return int(b["cost_multi"])
    return int(b["cost_single"]) * count


static func rates_text(b: Dictionary) -> String:
    var parts: Array = []
    var rates: Array = b["rates"]
    for i in rates.size():
        parts.append("%d-star %s%%" % [i + 1, _fmt(float(rates[i]))])
    return "   |   ".join(parts)


static func _fmt(v: float) -> String:
    return str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))


## Deterministic callsign pick that skips any display name already in use.
static func callsign_for(hero_seed: int, base_name: String, taken: Dictionary) -> String:
    var start: int = absi(hero_seed) % CALLSIGNS.size()
    for i in CALLSIGNS.size():
        var c: String = CALLSIGNS[(start + i) % CALLSIGNS.size()]
        if not taken.has("%s \"%s\"" % [base_name, c]):
            return c
    var n := 2
    while taken.has("%s \"No. %d\"" % [base_name, n]):
        n += 1
    return "No. %d" % n
