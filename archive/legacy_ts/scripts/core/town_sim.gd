class_name TownSim
extends RefCounted
## The town simulation (HQ Phase 1, D-047..D-049). Pure logic on the game state `g` (the Game
## autoload or a test instance): it never needs a scene, so the town keeps living while the player
## is in the tower. One step = one town hour. Order per hour: hospital admissions -> each hero
## picks an activity -> needs -> production -> construction -> treatment -> illness course ->
## tavern -> (daily) contagion. Deterministic: the hour's RNG comes from the town seed and clock.

## Advances `hours` town hours. `deployed` = hero ids away in the tower (keep their bed, do nothing).
## Returns a report: {"hours", "produced": {res: n}, "events": [String]}.
## Beta safety net (2026-11-01): permadeath stays, but the account never gets stuck. Every morning,
## while fewer than RECRUIT_BELOW heroes live, a 1-star wanderer joins the town for free.
const RECRUIT_BELOW := 5


static func _recruit(g: Object, report: Dictionary) -> void:
    if (g.heroes as Dictionary).size() >= RECRUIT_BELOW or not g.has_method("recruit_wanderer"):
        return
    var name: String = g.recruit_wanderer()
    if name != "":
        (report["events"] as Array).append("%s, a wanderer, joined the town" % name)


## Apprentices (TownTables.SPECIALIST_ONLY): an hour beside a master teaches them; they make nothing
## until they learn the trade. Returns the workers who actually produce this hour.
static func _apprentices(g: Object, bid: String, workers: Array, report: Dictionary) -> Array:
    if not TownTables.SPECIALIST_ONLY.has(bid):
        return workers
    var prof := String(g.workplace_prof(bid))
    var best := 0
    for w in workers:
        best = maxi(best, (w as HeroData).prof_level(prof))
    var master := best >= TownTables.MASTER_MIN_LVL
    var out: Array = []
    var rng := RandomNumberGenerator.new()
    rng.seed = int(g.town_seed) ^ (int(g.town_clock) * 7919) ^ hash(bid)
    var pname := String(ProfessionDefs.info(prof)["name"]).to_lower()
    for w in workers:
        var h: HeroData = w
        if h.knows_prof(prof):
            out.append(h)
            continue
        if not master:
            continue
        # AptitudeDefs: progress (0..1) = base x tier x master x roll; daily surprises; incompatible quits
        var tier := AptitudeDefs.tier(h, prof)
        var p: Dictionary = h.apprenticeship.get(prof, {}) if h.apprenticeship.get(prof) is Dictionary else {}
        var hours := float(p.get("hours", 0.0)) + 1.0
        var prog := float(p.get("progress", 0.0))
        prog += AptitudeDefs.BASE_PER_HOUR * float(AptitudeDefs.TIER_MULT[tier]) * (1.0 + AptitudeDefs.MASTER_PER_LVL * float(best - 1)) * rng.randf_range(0.7, 1.3)
        if int(hours) % 24 == 0:
            if rng.randf() < float(AptitudeDefs.BREAKTHROUGH.get(tier, 0.0)):
                prog += AptitudeDefs.BREAKTHROUGH_GAIN
                (report["events"] as Array).append("%s had a breakthrough at the %s" % [h.display_name(), TownTables.info(bid)["name"]])
            elif rng.randf() < float(AptitudeDefs.FRUSTRATION.get(tier, 0.0)):
                prog = maxf(0.0, prog - AptitudeDefs.FRUSTRATION_LOSS)
                (report["events"] as Array).append("%s is frustrated at the %s" % [h.display_name(), TownTables.info(bid)["name"]])
        if hours >= AptitudeDefs.REVEAL_HOURS and not h.aptitude_known.has(prof):
            h.aptitude_known[prof] = tier                # the master's opinion
        if tier == "incompatible" and hours >= AptitudeDefs.INCOMPATIBLE_HOURS:
            h.apprenticeship.erase(prof)
            h.aptitude_known[prof] = tier
            h.hq_assignment = ""
            (report["events"] as Array).append("%s has no talent for this: leaves the %s apprenticeship" % [h.display_name(), pname])
            continue
        if prog >= 1.0 and h.learn_prof(prof) == "":
            h.apprenticeship.erase(prof)
            var lvl := int(AptitudeDefs.GRAD_LEVEL.get(tier, 0)) + (1 if rng.randf() < AptitudeDefs.GRAD_BONUS_CHANCE else 0)
            h.professions[prof]["lvl"] = lvl
            (report["events"] as Array).append("%s finished the apprenticeship: now a %s (level %d)" % [h.display_name(), pname, lvl])
            continue
        h.apprenticeship[prof] = {"hours": hours, "progress": prog}
    return out


static func advance(g: Object, hours: int, deployed: Array = []) -> Dictionary:
    var report := {"hours": hours, "produced": {}, "events": []}
    for i in hours:
        _hour(g, deployed, report)
    return report


static func _hour(g: Object, deployed: Array, report: Dictionary) -> void:
    var clock: int = g.town_clock
    var hour := clock % 24
    var night := hour >= EconomyDefs.NIGHT_START or hour < EconomyDefs.NIGHT_END
    var rng := RandomNumberGenerator.new()
    rng.seed = int(g.town_seed) ^ (clock * 2654435761)
    # a problem stays visible until its building runs again; buildings nobody works at drop theirs
    for bid in (g.town_problems as Dictionary).keys():
        if bid != "infirmary" and (g.workers_at(bid) as Array).is_empty():
            g.town_problems.erase(bid)
    _admit_patients(g, deployed)
    if hour == 7:
        _recruit(g, report)
    var at_work := {}           # building id -> [HeroData]
    var builders: Array = []
    var social: Array = []
    for id in g.heroes:
        var h: HeroData = g.heroes[id]
        if deployed.has(id):
            h.activity_state = "deployed"
            continue
        var a := _choose(g, h, night)
        h.activity_state = a
        match a:
            "working":
                if h.hq_assignment == "construction":
                    builders.append(h)
                else:
                    if not at_work.has(h.hq_assignment):
                        at_work[h.hq_assignment] = []
                    (at_work[h.hq_assignment] as Array).append(h)
            "socializing":
                social.append(h)
            "eating":
                g.hq_outputs["food"] = int(g.hq_outputs.get("food", 0)) - 1
        _needs(g, h, a)
    for bid in at_work:
        at_work[bid] = _apprentices(g, String(bid), at_work[bid], report)
    for bid in at_work:
        if bid != "infirmary" and bid != "common":
            _work_building(g, String(bid), at_work[bid], rng, report)
    _build(g, builders, report)
    _treat(g, at_work.get("infirmary", []), report)
    _illness_course(g, report)
    _socialize(g, social, at_work.get("common", []), rng, report)
    if hour == 0:
        _contagion(g, deployed, rng, report)
    if hour == 8:
        _hints(g, report)
    g.town_clock = clock + 1


# --- activities --------------------------------------------------------------------------------

static func _choose(g: Object, h: HeroData, night: bool) -> String:
    if (g.patients as Array).has(h.id):
        return "in_treatment"
    if h.fatigue >= EconomyDefs.FATIGUE_SLEEP or (night and h.fatigue > 0):
        return "sleeping"
    if h.hunger >= EconomyDefs.HUNGER_EAT and int(g.hq_outputs.get("food", 0)) > 0:
        return "eating"
    if h.stress >= EconomyDefs.STRESS_SOCIAL and g.building_level("common") > 0:
        return "socializing"
    if g.can_work_now(h):
        return "working"
    return "idle"


static func _needs(g: Object, h: HeroData, a: String) -> void:
    var d: Array = EconomyDefs.NEED_DELTA.get(a, [0, 0, 0])
    var hunger_d := int(d[0])
    var fatigue_d := float(d[1])
    var stress_d := int(d[2])
    if a == "sleeping":
        if h.bed == "":
            fatigue_d = EconomyDefs.ROUGH_SLEEP_FATIGUE
            stress_d += EconomyDefs.ROUGH_SLEEP_STRESS
        else:
            fatigue_d *= 0.8 + 0.1 * float(g.building_level(h.bed))     # better dorms rest better
    h.hunger = clampi(h.hunger + hunger_d, 0, 100)
    h.fatigue = clampi(h.fatigue + roundi(fatigue_d), 0, 100)
    if h.hunger >= 100:
        stress_d += EconomyDefs.STARVING_STRESS
    h.stress = clampi(h.stress + stress_d, 0, 100)
    if h.fatigue >= 100:
        h.exhausted_hours += 1
        if h.exhausted_hours >= EconomyDefs.EXHAUSTION_HOURS and h.catch_disease("exhaustion", "overwork"):
            g.log_town("%s collapsed from exhaustion." % h.hero_name)
    else:
        h.exhausted_hours = 0


# --- production ---------------------------------------------------------------------------------

static func _work_building(g: Object, bid: String, hs: Array, rng: RandomNumberGenerator, report: Dictionary) -> void:
    var level: int = g.building_level(bid)
    var rid: String = g.job_of(bid)
    if level <= 0 or rid == "":
        return
    var r: Dictionary = EconomyDefs.recipe(rid)
    var prof := String(r["prof"])
    g.town_problems.erase(bid)
    var eff := 0.0
    var best := 0
    for h in hs:
        var hd := h as HeroData
        if hd.prof_level(prof) < int(r["min"]):
            continue
        # better buildings work faster; friends at the same bench help, rivals get in the way
        eff += hd.work_efficiency(prof) * (1.0 + 0.1 * float(level - 1)) * _teamwork(hd, hs)
        best = maxi(best, hd.prof_level(prof))
        hd.add_prof_xp(prof, 1.0)
    if int(g.town_clock) % 24 == 12:
        _coworkers_bond(hs)
    if eff <= 0.0:
        g.town_problems[bid] = "nobody qualified (needs %s level %d)" % [ProfessionDefs.info(prof)["name"], int(r["min"])]
        return
    var batch: Dictionary = g.town_batches.get(bid, {})
    var guard := 0
    while guard < 4:
        guard += 1
        if batch.is_empty():
            var why: String = g.start_batch(bid, rid)
            if why != "":
                g.town_problems[bid] = why
                break
            batch = g.town_batches[bid]
        batch["progress"] = float(batch["progress"]) + eff
        eff = 0.0
        var rr: Dictionary = EconomyDefs.recipe(String(batch["recipe"]))
        if float(batch["progress"]) < float(rr["work"]):
            break
        eff = float(batch["progress"]) - float(rr["work"])         # leftover work carries on
        g.finish_batch(bid, best, rng, report)
        batch = {}
        if eff <= 0.0:
            break


const FRIEND_BONUS := 0.1
const RIVAL_MALUS := 0.15


static func _teamwork(h: HeroData, team: Array) -> float:
    var m := 1.0
    for o in team:
        if o == h:
            continue
        var st := String(h.get_relationship((o as HeroData).id)["status"])
        if st == "friend" or st == "trusted_ally":
            m += FRIEND_BONUS
        elif st == "hostile":
            m -= RIVAL_MALUS
    return maxf(0.5, m)


## Once a day (noon) people working side by side get to know each other a little.
static func _coworkers_bond(team: Array) -> void:
    for a in team:
        for b in team:
            if a != b:
                (a as HeroData).update_relationship((b as HeroData).id, 1, "coworker")


static func _build(g: Object, builders: Array, report: Dictionary) -> void:
    var projects: Array = g.construction
    if projects.is_empty() or builders.is_empty():
        return
    for i in builders.size():
        var h := builders[i] as HeroData
        var p: Dictionary = projects[mini(i, projects.size() - 1)]   # one builder per project; extras help the first
        p["work_left"] = float(p["work_left"]) - h.work_efficiency("builder")
        h.add_prof_xp("builder", 1.0)
    var done: Array = []
    for p in projects:
        if float(p["work_left"]) <= 0.0:
            done.append(p)
    for p in done:
        projects.erase(p)
        g.complete_construction(String(p["bid"]), int(p["to"]))
        (report["events"] as Array).append("%s reached level %d." % [TownTables.info(String(p["bid"]))["name"], int(p["to"])])


# --- health -------------------------------------------------------------------------------------

static func _admit_patients(g: Object, deployed: Array) -> void:
    var patients: Array = g.patients
    for id in patients.duplicate():
        if not g.heroes.has(id) or (g.heroes[id] as HeroData).diseases.is_empty():
            patients.erase(id)
            if g.heroes.has(id):
                g.log_town("%s left the hospital, cured." % (g.heroes[id] as HeroData).hero_name)
    var beds: int = TownTables.info("infirmary").get("sick_beds", [0])[clampi(g.building_level("infirmary"), 0, 5)]
    if patients.size() >= beds:
        return
    var waiting: Array = []
    for id in g.heroes:
        var h: HeroData = g.heroes[id]
        if not h.diseases.is_empty() and not patients.has(id) and not deployed.has(id):
            waiting.append(h)
    # the most serious cases first (prioritised care), then summon order
    waiting.sort_custom(func(a, b): return _severity(a) > _severity(b))
    for h in waiting:
        if patients.size() >= beds:
            break
        patients.append(h.id)


static func _severity(h: HeroData) -> int:
    var s := 0
    for d in h.diseases:
        s += int(EconomyDefs.DISEASES[String(d["id"])]["severity"])
    return s


## Doctors treat up to 2 patients each per hour, using the disease's medicine every 24 treated hours.
static func _treat(g: Object, staff: Array, report: Dictionary) -> void:
    var doctors: Array = staff.filter(func(h): return (h as HeroData).knows_prof("doctor"))
    if (g.patients as Array).is_empty():
        g.town_problems.erase("infirmary")
    if doctors.is_empty():
        if not (g.patients as Array).is_empty() and g.building_level("infirmary") > 0:
            g.town_problems["infirmary"] = "no doctor on duty: patients only rest"
        return
    var capacity := doctors.size() * 2
    var eff := 0.0
    for d in doctors:
        eff += (d as HeroData).work_efficiency("doctor")
        (d as HeroData).add_prof_xp("doctor", 1.0)
    eff /= float(doctors.size())
    g.town_problems.erase("infirmary")
    for id in g.patients:
        if capacity <= 0:
            break
        var h: HeroData = g.heroes[id]
        for dz in h.diseases:
            var def: Dictionary = EconomyDefs.DISEASES[String(dz["id"])]
            var med := String(def["medicine"])
            var treated := int(dz.get("treated", 0))
            if med != "" and treated % 24 == 0:
                if int(g.hq_outputs.get(med, 0)) <= 0:
                    g.town_problems["infirmary"] = "out of %s" % EconomyDefs.RESOURCES[med]["name"].to_lower()
                    continue
                g.hq_outputs[med] = int(g.hq_outputs[med]) - 1
            dz["treated"] = treated + 1
            dz["hours"] = float(dz["hours"]) - float(def["treat_rate"]) * eff
            capacity -= 1
            break


static func _illness_course(g: Object, report: Dictionary) -> void:
    for id in g.heroes:
        var h: HeroData = g.heroes[id]
        if h.diseases.is_empty():
            continue
        var resting := h.activity_state in ["sleeping", "in_treatment"]
        var cured: Array = []
        for dz in h.diseases:
            var def: Dictionary = EconomyDefs.DISEASES[String(dz["id"])]
            if def["natural"] and (String(dz["id"]) != "exhaustion" or resting):
                dz["hours"] = float(dz["hours"]) - (1.5 if resting else 1.0)
            if float(dz["hours"]) <= 0.0:
                cured.append(dz)
        for dz in cured:
            h.diseases.erase(dz)
            h.add_memory("recovered", "Recovered from %s." % EconomyDefs.DISEASES[String(dz["id"])]["name"], "", 1)
            (report["events"] as Array).append("%s recovered from %s." % [h.hero_name, EconomyDefs.DISEASES[String(dz["id"])]["name"]])


static func _contagion(g: Object, deployed: Array, rng: RandomNumberGenerator, report: Dictionary) -> void:
    var sick: Array = []
    for id in g.heroes:
        var h: HeroData = g.heroes[id]
        for dz in h.diseases:
            if float(EconomyDefs.DISEASES[String(dz["id"])]["contagion"]) > 0.0 and h.bed != "":
                sick.append([h, String(dz["id"])])
    for pair in sick:
        var src: HeroData = pair[0]
        for id in g.heroes:
            var mate: HeroData = g.heroes[id]
            if mate == src or mate.bed != src.bed or deployed.has(id):
                continue
            if rng.randf() < float(EconomyDefs.DISEASES[pair[1]]["contagion"]) and mate.catch_disease(pair[1], "caught from " + src.hero_name):
                (report["events"] as Array).append("%s caught %s from %s." % [mate.hero_name, EconomyDefs.DISEASES[pair[1]]["name"], src.hero_name])


# --- tavern ---------------------------------------------------------------------------------------

const QUARRELSOME := ["trait.hot_headed", "trait.arrogant", "trait.stubborn", "trait.greedy"]
const SOCIABLE := ["trait.cheerful", "trait.kind", "trait.loyal"]


## Heroes at the tavern pair up (summon order). Two quarrelsome natures may argue (deterministic roll
## per hour); otherwise they bond. A tavern keeper and a better tavern relax them more.
static func _socialize(g: Object, social: Array, staff: Array, rng: RandomNumberGenerator, report: Dictionary) -> void:
    if social.is_empty():
        return
    var keeper := staff.any(func(h): return (h as HeroData).knows_prof("tavernkeeper"))
    for k in staff:
        if (k as HeroData).knows_prof("tavernkeeper"):
            (k as HeroData).add_prof_xp("tavernkeeper", 1.0)
    var relax: int = 2 * int(g.building_level("common")) + (5 if keeper else 0)
    for h in social:
        (h as HeroData).stress = clampi((h as HeroData).stress - relax, 0, 100)
    var i := 0
    while i + 1 < social.size():
        var a: HeroData = social[i]
        var b: HeroData = social[i + 1]
        i += 2
        var qa := a.traits.any(func(t): return QUARRELSOME.has(t))
        var qb := b.traits.any(func(t): return QUARRELSOME.has(t))
        var before: String = a.get_relationship(b.id)["status"]
        if qa and qb and rng.randf() < (0.3 if keeper else 0.5):
            a.update_relationship(b.id, -4, "argument")
            b.update_relationship(a.id, -4, "argument")
            a.stress = clampi(a.stress + 8, 0, 100)
            b.stress = clampi(b.stress + 8, 0, 100)
            if a.get_relationship(b.id)["status"] != before:
                a.add_memory("quarrel", "Fell out with %s at the tavern." % b.hero_name, b.id, 2)
                b.add_memory("quarrel", "Fell out with %s at the tavern." % a.hero_name, a.id, 2)
            g.log_town("%s and %s argued at the tavern." % [a.hero_name, b.hero_name])
        else:
            var bond := 1 if qa and qb else 3 + (1 if a.traits.any(func(t): return SOCIABLE.has(t)) else 0)
            a.update_relationship(b.id, bond, "tavern")
            b.update_relationship(a.id, bond, "tavern")
            if a.get_relationship(b.id)["status"] != before:
                a.add_memory("bond", "Grew closer to %s over a meal at the tavern." % b.hero_name, b.id, 2)
                b.add_memory("bond", "Grew closer to %s over a meal at the tavern." % a.hero_name, a.id, 2)
                (report["events"] as Array).append("%s and %s are now %s." % [a.hero_name, b.hero_name, a.get_relationship(b.id)["status"]])


## #12 of the playtest: what the tower brings home must have a visible use. Once a morning, if raw wood
## and stone pile up and nothing turns them into building materials, the town log says what would.
const RAW_PILE := 40


static func _hints(g: Object, report: Dictionary) -> void:
    var raw := int(g.hq_outputs.get("wood", 0)) + int(g.hq_outputs.get("stone", 0))
    if raw >= RAW_PILE and int(g.building_level("workshop")) == 0:
        (report["events"] as Array).append("Wood and stone are piling up (%d): a Workshop turns them into building materials." % raw)
    elif raw >= RAW_PILE and (g.workers_at("workshop") as Array).is_empty():
        (report["events"] as Array).append("Wood and stone are piling up (%d): put someone to work at the Workshop." % raw)
