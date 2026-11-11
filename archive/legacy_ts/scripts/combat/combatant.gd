class_name Combatant
extends Node2D
## Shared base of every unit in a mission (heroes and enemies): health, defences, the single
## damage path (CombatRules.resolve), status effects, downed/agony/rescue (heroes, D-036) and death.
## Subclasses add movement, AI, drawing and animation through the _on_* hooks.

signal died(unit)
signal went_down(unit)
signal revived(unit)

var base_max_hp: int = 1
var max_hp: int = 1
var hp: int = 1
var armor: int = 0
var mres: int = 0
var iframe_t: float = 0.0            # dash invulnerability left (CombatRules.DASH_IFRAMES)
var immune: bool = false             # Crimson Baron's altar shield (master prompt E): every hit does 0
signal immune_hit
var heal_block: bool = false         # floor modifier "no_heal" (master prompt D)
var no_death: bool = false           # D-080: the Master never dies; when they would, they are "lost" instead
var lost: bool = false               # D-080: the Master's agony ran out (or they were left behind): stays down
signal lost_down(c: Combatant)
var heal_mult: float = 1.0           # D-079: "no_heal" partly countered (heavy armour, Regeneration gift)
var poison_mult: float = 1.0         # D-079: "hazard" countered (antidote, Poison-proof gift): poison strength
var soft_in: float = 1.0             # D-079 soft block: damage taken x (PowerCalc.floor_effect, set once per floor)
var soft_out: float = 1.0            # D-079 soft block: damage dealt x
var surround_mult: float = 1.0       # D-084: damage taken x when surrounded (SandboxScreen._update_surrounded)
var dev_god: bool = false            # D-146 dev console /god: every hit does 0 (turning it off leaves nothing behind)
var dmg_mult: float = 1.0            # D-081: the Master leads, the others carry (MasterDefs.DAMAGE_MULT)
var resistances: Dictionary = {}    # P-29 hook (pending): element -> fraction resisted (0..1); no content yet
var crit_chance: float = 0.0
var status_resist: float = 0.0
var alive: bool = true            # can act (false while downed or dead)
var dead: bool = false            # permanent
var downed: bool = false
var can_be_downed: bool = false   # heroes only (D-036)
var agony: float = 0.0            # seconds left while downed
var killed_by: String = ""
var statuses: Dictionary = {}     # id -> {"t": seconds, "mag": float, "stacks": int, "src": Node2D}
var combat_rng := RandomNumberGenerator.new()
var _status_tick: float = 0.0
var _status_fx: Dictionary = {}   # status id -> looping aura node (CombatVFX.STATUS_FX), look only


func setup_combat(p_max_hp: int, p_armor: int, p_mres: int, p_crit: float, p_resist: float, seed_value: int) -> void:
    base_max_hp = maxi(1, p_max_hp)
    max_hp = base_max_hp
    hp = max_hp
    armor = p_armor
    mres = p_mres
    crit_chance = p_crit
    status_resist = p_resist
    combat_rng.seed = seed_value


# --- damage -----------------------------------------------------------------------------

## The one way to hurt a unit. Returns the damage dealt (0 if absorbed, dead or downed).
func take_hit(info: DamageInfo) -> int:
    if dead:
        return 0
    if dev_god and not downed:
        return 0
    if downed:
        agony = maxf(0.0, agony - CombatRules.AGONY_HIT_PENALTY)
        return 0
    if iframe_t > 0.0:
        FloatingText.spawn(self, "Dodged!", FloatingText.COLORS["miss"], false, 0.8)
        return 0
    if immune:
        FloatingText.spawn(self, "0", Color(0.75, 0.75, 0.85), false, 0.8)
        immune_hit.emit()
        return 0
    var dmg := CombatRules.resolve(info, self)
    var blocked := false
    if statuses.has("shield"):
        var s: Dictionary = statuses["shield"]
        var absorbed := mini(dmg, int(s["mag"]))
        s["mag"] = float(s["mag"]) - absorbed
        dmg -= absorbed
        blocked = dmg <= 0 and absorbed > 0
        if float(s["mag"]) <= 0.0:
            statuses.erase("shield")
    if info.source != null and is_instance_valid(info.source) and info.source.get("enemy_name") != null:
        killed_by = str(info.source.get("enemy_name"))
    hp = maxi(0, hp - dmg)
    if dmg > 0 and info.source != null and is_instance_valid(info.source) and info.source.has_method("credit") and not can_be_downed:
        info.source.credit("damage", float(dmg))          # a hero hurt a creature
    if dmg > 0 and can_be_downed and has_method("credit"):
        call("credit", "tanked", float(dmg))               # a hero took a blow for the squad
    if dmg > 0 and info.source != null and is_instance_valid(info.source) and info.source.has_method("credit"):
        set_meta("last_hitter", info.source)
    # D-112 (pista C): white normal, orange crit, purple damage over time, grey block; big numbers
    # only for the Master and damage to the party (heals are green, in heal())
    if blocked:
        FloatingText.number(self, 0, "miss", false, "block")
    else:
        var nk := "dot" if info.tags.has("dot") else ("crit" if info.crit else ("party" if can_be_downed else "normal"))
        FloatingText.number(self, dmg, nk, can_be_downed or _master_involved(info))
    JuicePlayer.on_hit(self, info, dmg, blocked)      # D-110: presentation only
    _on_hit(info, dmg)
    if hp <= 0:
        if can_be_downed:
            go_down()
        else:
            die()
    return dmg


## Legacy entry point: already-mitigated damage, no crit (kept for older callers and tests).
func take_damage(amount: int, source: Node2D = null) -> void:
    var info := DamageInfo.make(float(amount), "true", source)
    take_hit(info)


func heal(amount: int) -> int:
    if not alive or heal_block:
        return 0
    var before := hp
    hp = mini(max_hp, hp + maxi(0, roundi(float(amount) * heal_mult)))
    if hp > before:
        FloatingText.number(self, hp - before, "heal", can_be_downed)
    return hp - before


# --- downed / rescue / death (D-036) --------------------------------------------------------

func go_down() -> void:
    if dead or downed:
        return
    downed = true
    alive = false
    hp = 0
    agony = CombatRules.AGONY_TIME
    statuses.clear()
    _sync_status_fx()
    _on_down()
    went_down.emit(self)


func revive(hp_fraction: float) -> void:
    if dead or lost or not downed:
        return
    downed = false
    alive = true
    apply_status("wounded", 99999.0)
    hp = maxi(1, roundi(float(max_hp) * hp_fraction))
    _on_revive()
    revived.emit(self)


func die() -> void:
    if dead or lost:
        return
    if no_death:                          # D-080: stays down (no memorial); the screen ends the expedition
        lost = true
        downed = true
        alive = false
        hp = 0
        agony = 0.0
        lost_down.emit(self)
        return
    dead = true
    downed = false
    alive = false
    hp = 0
    statuses.clear()
    _sync_status_fx()
    JuicePlayer.on_death(self)            # D-110: death "pop" (look only)
    _on_die()
    died.emit(self)


# --- status effects -------------------------------------------------------------------------

## duration is shortened by status resistance (TEM) unless the status says "no_resist".
func apply_status(id: String, duration: float, magnitude: float = 0.0, source: Node2D = null) -> void:
    if dead or not CombatRules.STATUS.has(id):
        return
    var def: Dictionary = CombatRules.STATUS[id]
    var t := duration if def.get("no_resist", false) else duration * (1.0 - status_resist)
    if id == "poison":
        magnitude *= poison_mult
    if statuses.has(id):
        var s: Dictionary = statuses[id]
        s["t"] = maxf(float(s["t"]), t)
        s["stacks"] = mini(int(s["stacks"]) + 1, int(def.get("stacks", 1)))
        s["mag"] = maxf(float(s["mag"]), magnitude) if id != "shield" else float(s["mag"]) + magnitude
    else:
        statuses[id] = {"t": t, "mag": magnitude, "stacks": 1, "src": source}
    _recalc_max_hp()
    _sync_status_fx()


func has_status(id: String) -> bool:
    return statuses.has(id)


func can_move() -> bool:
    return alive and not _blocked("move")


func can_act() -> bool:
    return alive and not _blocked("act")


func move_mult() -> float:
    var m := 1.0
    for id in statuses:
        m *= float(CombatRules.STATUS[id].get("move", 1.0))
    return m


func outgoing_mult() -> float:
    var m := 1.0
    for id in statuses:
        m *= float(CombatRules.STATUS[id].get("out_dmg", 1.0))
    return m


func incoming_mult() -> float:
    var m := 1.0
    for id in statuses:
        m *= float(CombatRules.STATUS[id].get("in_dmg", 1.0))
    return m


## Removes every harmful status (poison, stun, slow...). Returns how many were removed.
func cleanse() -> int:
    var gone: Array = []
    for id in statuses:
        if CombatRules.STATUS[id].get("debuff", false):
            gone.append(id)
    for id in gone:
        statuses.erase(id)
    if not gone.is_empty():
        _recalc_max_hp()
    return gone.size()


func _blocked(what: String) -> bool:
    for id in statuses:
        if (CombatRules.STATUS[id].get("blocks", []) as Array).has(what):
            return true
    return false


func _recalc_max_hp() -> void:
    var m := 1.0
    for id in statuses:
        m *= float(CombatRules.STATUS[id].get("max_hp", 1.0))
    max_hp = maxi(1, roundi(float(base_max_hp) * m))
    hp = mini(hp, max_hp)


## Keeps one looping aura per active status (fire while burning, a bubble while shielded...).
func _sync_status_fx() -> void:
    for id in _status_fx.keys():
        if not statuses.has(id):
            if is_instance_valid(_status_fx[id]):
                (_status_fx[id] as Node).queue_free()
            _status_fx.erase(id)
    for id in statuses:
        if not _status_fx.has(id) and CombatVFX.STATUS_FX.has(id):
            var d: Array = CombatVFX.STATUS_FX[id]
            var fx := CombatVFX.attach(self, String(d[0]), d[1], float(d[2]))
            if fx != null:
                _status_fx[id] = fx


## Call every simulation step: status durations, damage over time, agony countdown.
func tick_combat(delta: float) -> void:
    iframe_t = maxf(0.0, iframe_t - delta)
    _sync_status_fx()
    if dead:
        return
    if downed:
        if lost:
            return
        agony -= delta
        if agony <= 0.0:
            die()
        return
    _status_tick += delta
    var ticks := 0
    while _status_tick >= CombatRules.STATUS_TICK:
        _status_tick -= CombatRules.STATUS_TICK
        ticks += 1
    var expired: Array = []
    var dots: Array = []                  # applied after the loop: a lethal tick clears `statuses`
    var hots := 0.0
    for id in statuses:
        var s: Dictionary = statuses[id]
        s["t"] = float(s["t"]) - delta
        var dot := String(CombatRules.STATUS[id].get("dot", ""))
        if dot != "" and ticks > 0:
            var src: Node2D = s["src"] if is_instance_valid(s["src"]) else null
            var di := DamageInfo.make(float(s["mag"]) * float(s["stacks"]) * CombatRules.STATUS_TICK * ticks, dot, src)
            di.tags.append("dot")                 # D-112: shown purple (look only)
            dots.append(di)
        if CombatRules.STATUS[id].get("hot", false) and ticks > 0:
            hots += float(s["mag"]) * CombatRules.STATUS_TICK * ticks
        if float(s["t"]) <= 0.0:
            expired.append(id)
    for id in expired:
        statuses.erase(id)
    if not expired.is_empty():
        _recalc_max_hp()
    if hots > 0.0:
        heal(roundi(hots))
    for d in dots:
        if alive:
            take_hit(d)


# --- hooks for subclasses ---------------------------------------------------------------------

func _on_hit(_info: DamageInfo, _dmg: int) -> void:
    pass


func _on_down() -> void:
    pass


func _on_revive() -> void:
    pass


func _on_die() -> void:
    pass


## D-112: the Master dealt or took this hit (their numbers are the big ones).
func _master_involved(info: DamageInfo) -> bool:
    if no_death:
        return true
    return info.source != null and is_instance_valid(info.source) and info.source.get("no_death") == true
