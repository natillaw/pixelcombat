class_name OfflineExpeditions
extends RefCounted
## Master prompt C: rules of the offline expeditions over Game's state (numbers in ExpeditionDefs).
## Time is passed in (unix seconds) so tests and the economy simulator can drive it.


static func charges_max(g) -> int:
    return ExpeditionDefs.CHARGES_MAX + int(g.portal_upgrades.get("charges", 0))


## Recharges by real time (one charge every CHARGE_HOURS) up to the maximum.
static func refresh_charges(g, now: float) -> void:
    if g.exp_charge_t <= 0.0:
        g.exp_charge_t = now
    var per := ExpeditionDefs.CHARGE_HOURS * 3600.0
    while g.exp_charges < charges_max(g) and now - g.exp_charge_t >= per:
        g.exp_charges += 1
        g.exp_charge_t += per
    if g.exp_charges >= charges_max(g):
        g.exp_charge_t = now


static func block(g, floor_num: int, ids: Array, now: float) -> String:
    refresh_charges(g, now)
    if int(g.tower_cleared.get(str(ExpeditionDefs.UNLOCK_FLOOR), 0)) <= 0:
        return "opens after clearing floor %d" % ExpeditionDefs.UNLOCK_FLOOR
    if int(g.tower_cleared.get(str(floor_num), 0)) <= 0:
        return "only floors already cleared"
    if ExpeditionDefs.FLOOR_GAP > 0 and floor_num > g.highest_cleared() - ExpeditionDefs.FLOOR_GAP:
        return "too close to the record floor"
    if g.exp_charges <= 0:
        return "no expedition charges left today"
    if ids.is_empty() or ids.size() > mini(ExpeditionDefs.MAX_HEROES, TowerExpedition.party_max(floor_num)):
        return "pick 1-%d heroes" % mini(ExpeditionDefs.MAX_HEROES, TowerExpedition.party_max(floor_num))
    for id in ids:
        if not g.heroes.has(id):
            return "unknown hero"
        var h: HeroData = g.heroes[id]
        if h.is_master:
            return "the Master does not go on offline expeditions"
        if h.hq_assignment == "expedition":
            return "%s is already away" % h.display_name()
    return ""


static func start(g, floor_num: int, ids: Array, now: float) -> String:
    var why := block(g, floor_num, ids, now)
    if why != "":
        return why
    g.exp_charges -= 1
    for id in ids:
        var h: HeroData = g.heroes[id]
        h.hq_assignment = "expedition"           # cannot work in the town meanwhile
    g.expeditions.append({"floor": floor_num, "heroes": ids.duplicate(), "start": now,
        "end": now + float(floor_num) * ExpeditionDefs.MINUTES_PER_FLOOR * 60.0})
    return ""


## What an expedition brings back (no key_ items, no first-clear rewards). Seeded per expedition.
static func loot(floor_num: int, seed_v: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    var raw := {}
    for k in ExpeditionDefs.KILLS_PER_FLOOR:
        var d := LootService.enemy_drops(floor_num, false, false, rng)
        for id in d:
            raw[id] = int(raw.get(id, 0)) + int(d[id])
    var c := LootService.chest(floor_num, false, rng)
    for id in c:
        raw[id] = int(raw.get(id, 0)) + int(c[id])
    var out := {}
    for id in raw:
        if String(id).begins_with("key_"):
            continue
        var n := floori(float(raw[id]) * ExpeditionDefs.YIELD + rng.randf())
        if n > 0:
            out[id] = n
    for id in ExpeditionDefs.BASICS_PER_FLOOR:
        var n := roundi(float(ExpeditionDefs.BASICS_PER_FLOOR[id]) * float(floor_num) * ExpeditionDefs.YIELD * 2.0)
        if n > 0:
            out[id] = int(out.get(id, 0)) + n
    if ExpeditionDefs.STORAGE_LIMIT > 0:
        var total := 0
        for id in out.keys():
            var take := mini(int(out[id]), ExpeditionDefs.STORAGE_LIMIT - total)
            total += take
            if take <= 0:
                out.erase(id)
            else:
                out[id] = take
    return out


## Brings home every finished expedition; returns [{floor, heroes, loot}].
static func claim(g, now: float) -> Array:
    var done: Array = []
    var keep: Array = []
    for e in g.expeditions:
        if now < float(e["end"]):
            keep.append(e)
            continue
        var got := loot(int(e["floor"]), hash("%d:%d" % [int(e["floor"]), int(e["start"])]))
        for id in got:
            g.hq_outputs[id] = mini(g.storage_cap(), int(g.hq_outputs.get(id, 0)) + int(got[id]))
        for id in e["heroes"]:
            if g.heroes.has(id):
                var h: HeroData = g.heroes[id]
                h.hq_assignment = ""
                if ExpeditionDefs.RISK:
                    h.fatigue = clampi(h.fatigue + ExpeditionDefs.RISK_FATIGUE, 0, 100)
        done.append({"floor": int(e["floor"]), "heroes": e["heroes"], "loot": got})
    g.expeditions = keep
    return done
