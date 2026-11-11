class_name ExpeditionResults
extends RefCounted
## Pure rules for the end of an expedition (no state): experience per hero and the MVP.
## heroes = [{"hero": HeroData, "alive": bool, "contrib": {category: amount}}]; outcome = "success" |
## "escaped" | "failed"; kill_xp = worth of the creatures killed (EnemyDefs.XP_PER_HP x max HP, summed).
## Returns {"mvp": HeroData or null, "mvp_reason": String, "xp": {hero id: int}, "scores": {hero id: float}}.


static func contribution_scores(heroes: Array) -> Dictionary:
    var totals := {}
    for e in heroes:
        for k in (e["contrib"] as Dictionary):
            totals[k] = float(totals.get(k, 0.0)) + float(e["contrib"][k])
    var out := {}
    for e in heroes:
        var s := 0.0
        for k in ProgressionDefs.CONTRIB_WEIGHTS:
            var t := float(totals.get(k, 0.0))
            if t > 0.0:
                s += float(ProgressionDefs.CONTRIB_WEIGHTS[k]) * float((e["contrib"] as Dictionary).get(k, 0.0)) / t
        out[(e["hero"] as HeroData).id] = s
    return out


## The category where this hero's share of the squad total was largest (for "why the MVP").
static func best_category(entry: Dictionary, heroes: Array) -> String:
    var best := ""
    var best_share := 0.0
    for k in ProgressionDefs.CONTRIB_WEIGHTS:
        var t := 0.0
        for e in heroes:
            t += float((e["contrib"] as Dictionary).get(k, 0.0))
        if t <= 0.0:
            continue
        var share := float((entry["contrib"] as Dictionary).get(k, 0.0)) / t * float(ProgressionDefs.CONTRIB_WEIGHTS[k])
        if share > best_share:
            best_share = share
            best = k
    return best


## The cap of a normal run at this hero level, as a fraction of its next level (data: ProgressionDefs).
static func normal_cap_frac(level: int) -> float:
    return maxf(ProgressionDefs.NORMAL_CAP_MIN, ProgressionDefs.NORMAL_CAP_FRAC - ProgressionDefs.NORMAL_CAP_DECAY * float(level - 1))


## How much a hero over the floor's expected level still earns (1.0 at or below it).
static func overlevel_mult(level: int, floor_num: int) -> float:
    var over := float(level) - (1.0 + float(floor_num) * ProgressionDefs.LEVELS_PER_FLOOR)
    return 1.0 if over <= 0.0 else maxf(ProgressionDefs.OVERLEVEL_MIN, 1.0 - ProgressionDefs.OVERLEVEL_DECAY * over)


## floor_num <= 0 = the Wilds (creature XP only, WILDS_XP_MULT). secret_done = the run's secret objective
## was completed (SECRET_MULT for every survivor). mvp_bonus = what the MVP multiplier added.
static func compute(heroes: Array, outcome: String, floor_num: int, kill_xp: int, secret_done: bool = false) -> Dictionary:
    var res := {"mvp": null, "mvp_reason": "", "xp": {}, "scores": {}}
    var alive: Array = heroes.filter(func(e): return bool(e["alive"]))
    if alive.is_empty() or outcome == "failed":
        return res
    var scores := contribution_scores(alive)
    res["scores"] = scores
    var total_score := 0.0
    for id in scores:
        total_score += float(scores[id])
    var wilds := floor_num <= 0
    var success := outcome == "success" and not wilds
    var kill := float(kill_xp) * ProgressionDefs.KILL_XP_MULT
    var n := float(alive.size())
    var mvp_e: Dictionary = {}
    if success:
        for e in alive:
            if mvp_e.is_empty() or float(scores[(e["hero"] as HeroData).id]) > float(scores[(mvp_e["hero"] as HeroData).id]):
                mvp_e = e
    for e in alive:
        var h: HeroData = e["hero"]
        var share := 1.0 / n
        if total_score > 0.0:
            share = ProgressionDefs.SHARE_FLAT / n + (1.0 - ProgressionDefs.SHARE_FLAT) * float(scores[h.id]) / total_score
        var need := float(h.xp_to_next())
        var complete := need * ProgressionDefs.COMPLETE_FRAC if success else 0.0
        var base := minf(complete + kill * share, need * normal_cap_frac(h.level))
        base *= overlevel_mult(h.level, maxi(1, floor_num)) * (ProgressionDefs.WILDS_XP_MULT if wilds else 1.0)
        var mult := 1.0
        if success and secret_done:
            mult *= ProgressionDefs.SECRET_MULT
        if not mvp_e.is_empty() and mvp_e == e:
            mult *= ProgressionDefs.MVP_MULT
        var total := minf(base * mult, need * ProgressionDefs.BONUS_CAP_FRAC)
        res["xp"][h.id] = roundi(total)
        if not mvp_e.is_empty() and mvp_e == e:
            res["mvp_bonus"] = roundi(total - minf(base * mult / ProgressionDefs.MVP_MULT, total))
    if not mvp_e.is_empty():
        res["mvp"] = mvp_e["hero"]
        res["mvp_reason"] = String(ProgressionDefs.CONTRIB_LABELS.get(best_category(mvp_e, alive), "did a bit of everything"))
    return res
