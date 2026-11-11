class_name PowerCalc
extends RefCounted
## Soft block of the tower (proposal D-079). Stateless: squad power by source, the power a floor expects,
## the combat multipliers when the squad falls short, the counters of the floor modifiers and the Risk
## shown at the tower gate. Numbers live in PowerDefs. Power is internal: the UI shows only floor_risk().


# --- required power ------------------------------------------------------------------------------------

## What one hero slot of the floor is expected to bring.
static func slot_required_power(floor_num: int) -> float:
    var f := maxi(1, floor_num)
    var arc := float((f - 1) / 10)
    return PowerDefs.POWER_BASE * pow(PowerDefs.POWER_GROWTH, float(f)) * (1.0 + PowerDefs.ARC_STEP * arc)


## What the whole squad of the floor is expected to bring (PR).
static func floor_required_power(floor_num: int) -> float:
    return slot_required_power(floor_num) * float(TowerExpedition.party_max(floor_num))


## Expected share of PR per source on this floor (PowerDefs.POWER_BUDGET, linear between rows).
static func budget(floor_num: int) -> Dictionary:
    var rows: Array = PowerDefs.POWER_BUDGET
    var out := {}
    for k in ["base", "gear", "consumables", "town"]:
        out[k] = _lerp_rows(rows, floor_num, k)
    return out


## Share of PR that base + gifts may cover in full (PowerDefs.GACHA_CAP).
static func gacha_cap_frac(floor_num: int) -> float:
    return _lerp_rows(PowerDefs.GACHA_CAP, floor_num, "frac")


static func _lerp_rows(rows: Array, floor_num: int, key: String) -> float:
    var f := float(floor_num)
    var first: Dictionary = rows[0]
    if f <= float(first["floor"]):
        return float(first[key])
    for i in range(1, rows.size()):
        var a: Dictionary = rows[i - 1]
        var b: Dictionary = rows[i]
        if f <= float(b["floor"]):
            var t := (f - float(a["floor"])) / maxf(1.0, float(b["floor"]) - float(a["floor"]))
            return lerpf(float(a[key]), float(b[key]), t)
    return float((rows[rows.size() - 1] as Dictionary)[key])


# --- squad power -----------------------------------------------------------------------------------------

static func stat_power(stats: Dictionary) -> float:
    var p := 0.0
    for k in PowerDefs.STAT_WEIGHTS:
        p += float(stats.get(k, 0.0)) * float(PowerDefs.STAT_WEIGHTS[k])
    return p


## A hero's power split by source: base (attributes = stats + level + stars), gear (equipment; also split
## into gear_off / gear_def for the hints), consumables (bag), town (passive building bonuses, town =
## building id -> level) and gacha_traits (summon gifts). "total" is their sum.
static func hero_power(hero: HeroData, town: Dictionary = {}) -> Dictionary:
    var bare := CombatRules.derive(hero.attributes(), hero.hero_class)
    var base := stat_power(bare)
    var gear := maxf(0.0, stat_power(hero.get_stats()) - base)
    var off_eq := {}
    for slot in hero.equipment:
        if PowerDefs.OFFENCE_SLOTS.has(String(slot)):
            off_eq[slot] = hero.equipment[slot]
    var gear_off := clampf(stat_power(ItemDefs.apply_equipment(bare, off_eq, hero.hero_class)) - base, 0.0, gear)
    var cons := 0.0
    for id in hero.bag:
        cons += float(PowerDefs.CONSUMABLE_FRAC.get(String(id), 0.0)) * float(mini(int(hero.bag[id]), PowerDefs.CONSUMABLE_MAX_EACH)) * base
    var gifts := 0.0
    for g in hero.innate:
        gifts += float((PowerDefs.GIFTS.get(String(g), {}) as Dictionary).get("power_frac", 0.0)) * base
    var parts := {"base": base, "gear": gear, "consumables": cons}
    var town_p := 0.0
    for bid in PowerDefs.TOWN_BONUS:
        var tb: Dictionary = PowerDefs.TOWN_BONUS[bid]
        town_p += float(tb["per_level"]) * float(int(town.get(bid, 0))) * float(parts.get(String(tb["of"]), 0.0))
    return {"base": base, "gear": gear, "gear_off": gear_off, "gear_def": gear - gear_off, "consumables": cons,
        "town": town_p, "gacha_traits": gifts, "total": base + gear + cons + town_p + gifts}


## Sum of hero_power() by source.
static func party_power(heroes: Array, town: Dictionary = {}) -> Dictionary:
    var out := {"base": 0.0, "gear": 0.0, "gear_off": 0.0, "gear_def": 0.0, "consumables": 0.0, "town": 0.0, "gacha_traits": 0.0, "total": 0.0}
    for h in heroes:
        var hp := hero_power(h as HeroData, town)
        for k in out:
            out[k] = float(out[k]) + float(hp[k])
    return out


## The squad's power as the floor counts it: base + gifts above the summon ceiling count GACHA_OVER_CAP.
static func effective_power(pp: Dictionary, floor_num: int) -> float:
    var cap := gacha_cap_frac(floor_num) * floor_required_power(floor_num)
    var summon := float(pp["base"]) + float(pp["gacha_traits"])
    var counted := minf(summon, cap) + PowerDefs.GACHA_OVER_CAP * maxf(0.0, summon - cap)
    return counted + float(pp["gear"]) + float(pp["consumables"]) + float(pp["town"])


## PR / squad power (INF for an empty squad).
static func ratio(floor_num: int, heroes: Array, town: Dictionary = {}) -> float:
    var pg := effective_power(party_power(heroes, town), floor_num)
    return INF if pg <= 0.0 else floor_required_power(floor_num) / pg


## The soft block itself: damage multipliers for the squad (never a bonus when ratio <= 1).
static func combat_mults(r: float) -> Dictionary:
    var taken := pow(clampf(r, 1.0, PowerDefs.RATIO_MAX), PowerDefs.DMG_TAKEN_EXP)
    var dealt := pow(clampf(1.0 / maxf(r, 0.0001), PowerDefs.RATIO_MIN, 1.0), PowerDefs.DMG_DEALT_EXP)
    return {"taken": taken, "dealt": dealt}


# --- counters of the floor modifiers ---------------------------------------------------------------------

## The modifier of a floor (only floors that exist in TowerExpedition.FLOORS have one).
static func floor_modifier(floor_num: int) -> String:
    return String((TowerExpedition.FLOORS.get(floor_num, {}) as Dictionary).get("modifier", ""))


## True when the hero itself carries the town's counter (bag item, equipped base, weapon affix).
static func has_item_counter(hero: HeroData, mod: String) -> bool:
    var c: Dictionary = PowerDefs.COUNTERS.get(mod, {})
    for id in c.get("bag", []):
        if int(hero.bag.get(String(id), 0)) > 0:
            return true
    for slot in hero.equipment:
        var it: Dictionary = hero.equipment[slot]
        if (c.get("bases", []) as Array).has(String(it.get("base", ""))):
            return true
        if PowerDefs.COUNTER_AFFIX_SLOTS.has(String(slot)):
            for a in it.get("affixes", []):
                if (c.get("affixes", []) as Array).has(String((a as Dictionary).get("id", ""))):
                    return true
    return false


## How much a hero's own gifts cover a modifier (0..1).
static func gift_cover(hero: HeroData, mod: String) -> float:
    var best := 0.0
    for g in hero.innate:
        var gd: Dictionary = PowerDefs.GIFTS.get(String(g), {})
        if String(gd.get("counter", "")) == mod:
            best = maxf(best, float(gd.get("cover", 1.0)))
    return best


## Coverage of each hero (same order) against a modifier: 1 with the item counter, the gift's cover for
## its owner, GIFT_GROUP_COVER x that cover for the others.
static func coverage(heroes: Array, mod: String) -> Array:
    var group := 0.0
    for h in heroes:
        group = maxf(group, PowerDefs.GIFT_GROUP_COVER * gift_cover(h as HeroData, mod))
    var out: Array = []
    for h in heroes:
        var c := 1.0 if has_item_counter(h as HeroData, mod) else maxf(gift_cover(h as HeroData, mod), group)
        out.append(c)
    return out


## Everything the expedition needs when the squad enters a floor (computed once, SandboxScreen):
## ratio, damage multipliers, the modifier and, per hero, how strong it still is (1 = in full).
static func floor_effect(floor_num: int, heroes: Array, town: Dictionary = {}) -> Dictionary:
    var r := ratio(floor_num, heroes, town)
    var out := combat_mults(r)
    out["ratio"] = r
    var mod := floor_modifier(floor_num)
    out["modifier"] = mod
    var strength: Array = []
    var red := float((PowerDefs.COUNTERS.get(mod, {}) as Dictionary).get("reduction", 0.0))
    for c in coverage(heroes, mod):
        strength.append(1.0 - red * float(c))
    out["strength"] = strength
    return out


# --- risk ----------------------------------------------------------------------------------------------------

static func band_of(risk: int) -> String:
    for b in PowerDefs.BANDS:
        if risk <= int(b["max"]):
            return String(b["id"])
    return "extreme"


static func band_name(band: String) -> String:
    return String(PowerDefs.BAND_NAMES.get(band, band))


static func band_color(band: String) -> Color:
    return PowerDefs.BAND_COLORS.get(band, Color.WHITE)


## The Risk of entering a floor with these heroes (only the first party_max go in). inventory = the town
## storage (resource id -> amount), town = building id -> level.
## { "risk": 1..99 (100 only for an empty squad), "band": low|medium|high|extreme, "hints": [<= 3 texts] }
## With PowerDefs.DEBUG_SHOW_NUMBERS a "debug" text with the raw numbers is added.
static func floor_risk(floor_num: int, heroes: Array, inventory: Dictionary = {}, town: Dictionary = {}) -> Dictionary:
    var cap := TowerExpedition.party_max(floor_num)
    var squad: Array = heroes.slice(0, cap)
    if squad.is_empty():
        return {"risk": 100, "band": "extreme", "hints": ["Nobody is ready to go in"]}
    var pp := party_power(squad, town)
    var pr := floor_required_power(floor_num)
    var pg := effective_power(pp, floor_num)
    var r := pr / maxf(pg, 0.001)
    var risk := 100.0 / (1.0 + exp(-PowerDefs.RISK_K * (r - PowerDefs.RISK_MID)))
    var cands: Array = []                 # [score, text]
    var mod := floor_modifier(floor_num)
    if mod != "":
        var cov := coverage(squad, mod)
        var avg := 0.0
        for c in cov:
            avg += float(c)
        avg /= float(cov.size())
        var c_def: Dictionary = PowerDefs.COUNTERS[mod]
        risk += float(c_def["risk"]) * (1.0 - avg)
        if avg < 1.0:
            cands.append([2.0 * float(c_def["risk"]) / 100.0 * (1.0 - avg), _counter_hint(mod, avg, inventory)])
    var missing := cap - squad.size()
    if missing > 0:
        risk += PowerDefs.RISK_PER_MISSING * float(missing)
        cands.append([PowerDefs.RISK_PER_MISSING * float(missing) / 100.0, "Fewer heroes than this floor lets in"])
    var mission := String((TowerExpedition.FLOORS.get(floor_num, {}) as Dictionary).get("mission", ""))
    risk += float(PowerDefs.MISSION_RISK.get(mission, 0.0))
    # what is missing most against the floor's budget
    var b := budget(floor_num)
    var summon := minf(float(pp["base"]) + float(pp["gacha_traits"]), gacha_cap_frac(floor_num) * pr)
    var short := {"base": float(b["base"]) - summon / pr, "consumables": float(b["consumables"]) - float(pp["consumables"]) / pr,
        "town": float(b["town"]) - float(pp["town"]) / pr}
    var gear_need := float(b["gear"]) * 0.5
    short["gear_off"] = gear_need - float(pp["gear_off"]) / pr
    short["gear_def"] = gear_need - float(pp["gear_def"]) / pr
    var carries := squad.any(func(h): return not (h as HeroData).bag.is_empty())
    for k in short:
        if float(short[k]) >= PowerDefs.HINT_MIN_DEFICIT and r > 0.85:
            cands.append([float(short[k]), _source_hint(String(k), carries)])
    cands.sort_custom(func(a, c): return float(a[0]) > float(c[0]))
    var hints: Array = []
    for c in cands:
        if hints.size() >= PowerDefs.MAX_HINTS:
            break
        if not hints.has(c[1]):
            hints.append(String(c[1]))
    var n := clampi(roundi(risk), PowerDefs.RISK_MIN, PowerDefs.RISK_MAX)
    var out := {"risk": n, "band": band_of(n), "hints": hints}
    if PowerDefs.DEBUG_SHOW_NUMBERS:
        out["debug"] = "PR %d / PG %d (base %d, gear %d, cons %d, town %d, gifts %d) ratio %.2f" % [roundi(pr), roundi(pg),
            roundi(float(pp["base"])), roundi(float(pp["gear"])), roundi(float(pp["consumables"])), roundi(float(pp["town"])),
            roundi(float(pp["gacha_traits"])), r]
    return out


static func _source_hint(k: String, carries: bool) -> String:
    match k:
        "base":
            return "Your heroes are too green for this floor"
        "gear_off":
            return "Your weapons are worn out"
        "gear_def":
            return "Your armour will not hold against these blows"
        "consumables":
            return "Pack more potions and elixirs" if carries else "Nobody carries potions or elixirs"
        _:
            return "The town could prepare them better"


static func _counter_hint(mod: String, avg: float, inventory: Dictionary) -> String:
    var bag: Array = (PowerDefs.COUNTERS[mod] as Dictionary).get("bag", [])
    for id in bag:
        if int(inventory.get(String(id), 0)) > 0 and avg <= 0.0:
            return "Antidotes sit in storage: nobody carries one" if String(id) == "antidote" else "The counter sits in storage: nobody carries it"
    match mod:
        "fog":
            return "Only some of them see in this mist" if avg > 0.0 else "A good summon could see in this mist"
        "hazard":
            return "No antidotes on a poisoned floor"
        "enrage":
            return "Nothing to finish enraged foes quickly"
        _:
            return "Nothing heals here, and your armour is light"
