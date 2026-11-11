class_name MasterRules
extends RefCounted
## D-081: stateless rules of the Master as a leader: Leadership, the bond of every hero with the Master,
## which commands are unlocked and the memories. Numbers live in MasterDefs / MasterMemories.


# --- Leadership ------------------------------------------------------------------------------------

## Raw Leadership of the Master (0 for anyone else): grows with level and memory points.
static func leadership(m: HeroData) -> float:
    if m == null or not m.is_master:
        return 0.0
    return MasterDefs.LEADERSHIP_BASE + MasterDefs.LEADERSHIP_PER_LEVEL * float(m.level - 1) + float(m.leadership_points)


## 0..1 with diminishing returns: what the radius, Obedience and Composure bonuses scale with.
static func leadership_frac(m: HeroData) -> float:
    var raw := leadership(m)
    return raw / (raw + MasterDefs.LEADERSHIP_HALF)


## Reach of commands (and of the pings, when they exist) around the Master, in px.
static func leadership_radius(m: HeroData) -> float:
    return MasterDefs.RADIUS_BASE + MasterDefs.RADIUS_EXTRA * leadership_frac(m)


## Obedience bonus for a hero inside the Master's radius.
static func obey_bonus(m: HeroData) -> int:
    return roundi(MasterDefs.OBEY_BONUS_MAX * leadership_frac(m))


## Share of a Composure loss spared to a hero inside the Master's radius.
static func composure_guard(m: HeroData) -> float:
    return MasterDefs.COMPOSURE_GUARD_MAX * leadership_frac(m)


# --- bond Master-hero --------------------------------------------------------------------------------

static func bond_tier(bond: int) -> Dictionary:
    var out: Dictionary = MasterDefs.BOND_TIERS[0]
    for t in MasterDefs.BOND_TIERS:
        if bond >= int(t["min"]):
            out = t
    return out


## Applies a MasterDefs.BOND_DELTA event to a hero (never the Master). Logged as an event (D-016 style:
## deterministic). Returns the change applied.
static func bond_event(h: HeroData, why: String) -> int:
    if h == null or h.is_master or not MasterDefs.BOND_DELTA.has(why):
        return 0
    var before := h.bond_master
    h.bond_master = clampi(h.bond_master + int(MasterDefs.BOND_DELTA[why]), 0, 100)
    if h.bond_master != before:
        h.add_event("bond_master", {"why": why, "bond": h.bond_master})
    return h.bond_master - before


## Obedience a hero shows right now: its own, its bond tier and (inside the radius) the Master's Leadership.
static func effective_obedience(h: HeroData, m: HeroData, in_radius: bool) -> int:
    if h == null:
        return 100
    if h.is_master:
        return h.obedience
    var v := h.obedience + int(bond_tier(h.bond_master)["obey"])
    if in_radius and m != null:
        v += obey_bonus(m)
    return v


## Composure a hero loses on an event (MasterDefs.COMPOSURE_LOSS), after the Master's Leadership (inside the
## radius) and, for "master_down", the bond.
static func composure_loss(h: HeroData, m: HeroData, why: String, in_radius: bool) -> int:
    var loss := float(MasterDefs.COMPOSURE_LOSS.get(why, 0))
    if in_radius and m != null:
        loss *= 1.0 - composure_guard(m)
    if why == "master_down":
        loss *= 1.0 - float(bond_tier(h.bond_master)["guard"])
    return roundi(loss)


# --- commands and memories ------------------------------------------------------------------------------

## Command ids the Master can use, by level and memories, in slot order.
static func commands(m: HeroData) -> Array:
    var out: Array = []
    if m == null or not m.is_master:
        return out
    for id in MasterDefs.COMMANDS:
        var c: Dictionary = MasterDefs.COMMANDS[id]
        if m.level >= int(c.get("unlock_level", 999)) or m.memory_commands().has(id):
            out.append(String(id))
    out.sort_custom(func(a, b): return int(MasterDefs.COMMANDS[a]["slot"]) < int(MasterDefs.COMMANDS[b]["slot"]))
    return out


## Unlocks the memory of a tenth floor once and applies its reward. Returns it, or {} if there is none
## for that floor or it was already unlocked.
static func unlock_memory(m: HeroData, floor_num: int) -> Dictionary:
    var mem := MasterMemories.for_floor(floor_num)
    if m == null or not m.is_master or mem.is_empty() or m.master_memories.has(String(mem["id"])):
        return {}
    m.master_memories.append(String(mem["id"]))
    var r: Dictionary = mem["reward"]
    m.leadership_points += int(r.get("leadership", 0))
    var p := String(r.get("passive", ""))
    if HeroTables.PASSIVES.has(p) and not m.passives.has(p):
        m.passives.append(p)
    m.add_memory("master_memory", String(mem["title"]), "", 4)
    return mem
