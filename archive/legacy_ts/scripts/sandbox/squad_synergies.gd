class_name SquadSynergies
extends RefCounted
## D-090: the synergies that depend on where the whole squad stands (SynergyDefs). SandboxScreen calls
## update() a few times a second: bushes (stealth), Shared Sight, bonds (rivals / mentor / friends /
## incompatible), Trap Sense, Hunter's Eye.

const EVERY := 0.25


static func update(heroes: Array, foes: Array, bushes: BushField, fog: FogMap, map: NavMap) -> void:
    var standing: Array = heroes.filter(func(h): return is_instance_valid(h) and h.alive)
    for h in standing:
        h.in_bush = bushes != null and bushes.has_at(h.position)
        h.synergy_vision = 0
        h.syn_out = 1.0
        h.syn_in = 1.0
        h.syn_crit = 0.0
    for i in standing.size():
        var a: SandboxHero = standing[i]
        for j in range(i + 1, standing.size()):
            var b: SandboxHero = standing[j]
            var d := a.position.distance_to(b.position)
            _pair_scouts(a, b, d, foes, map)
            _pair_bond(a, b, d)
    if fog != null and map != null:
        for e in foes:
            if e.alive and e.marked_by != null and is_instance_valid(e.marked_by) and e.has_status("marked") \
                    and not fog.is_visible(map.cell_of(e.position)) and e.spotted_t > 0.0 and not e.get_meta("mark_fog_noted", false):
                (e.marked_by as SandboxHero).synergy("mark_fog")     # seen through the fog thanks to the mark
                e.set_meta("mark_fog_noted", true)                     # once per creature


static func _pair_scouts(a: SandboxHero, b: SandboxHero, d: float, foes: Array, _map: NavMap) -> void:
    if a.hero == null or b.hero == null:
        return
    var ca := a.hero.hero_class
    var cb := b.hero.hero_class
    if SynergyDefs.SCOUT_CLASSES.has(ca) and SynergyDefs.SCOUT_CLASSES.has(cb) and d <= float(SynergyDefs.param("shared_sight", "radius", 220.0)):
        var v := int(SynergyDefs.param("shared_sight", "vision", 1))
        a.synergy_vision = v
        b.synergy_vision = v
        _note_once(a, "shared_sight")
    if ((ca == "class.rogue" and cb == "class.archer") or (ca == "class.archer" and cb == "class.rogue")) \
            and d <= float(SynergyDefs.param("trap_sense", "radius", 200.0)):
        var reveal := float(SynergyDefs.param("trap_sense", "reveal", 200.0))
        for e in foes:
            if e.alive and e.dormant and not e.get_meta("trap_sensed", false) \
                    and (e.position.distance_to(a.position) <= reveal or e.position.distance_to(b.position) <= reveal):
                e.set_meta("trap_sensed", true)
                e.spotted_t = maxf(e.spotted_t, AiDefs.SPOTTED_TIME)    # the screen shows spotted foes in the fog
                FloatingText.spawn(e, "ambush?", Color(1.0, 0.75, 0.3), false, 1.6)
                a.synergy("trap_sense")


## Bonds apply both ways while the two are within the synergy's radius.
static func _pair_bond(a: SandboxHero, b: SandboxHero, d: float) -> void:
    if a.hero == null or b.hero == null:
        return
    var kind := SynergyDefs.bond_between(a.hero, b.hero)
    match kind:
        "rivals":
            if d <= float(SynergyDefs.param("rivals", "radius", 200.0)) and (a.in_combat() or b.in_combat()):
                var m := float(SynergyDefs.param("rivals", "out_dmg", 1.08))
                a.syn_out *= m
                b.syn_out *= m
                _note_once(a, "rivals")
        "friends":
            if d <= float(SynergyDefs.param("friends", "radius", 200.0)) and (a.in_combat() or b.in_combat()):
                var m2 := float(SynergyDefs.param("friends", "in_dmg", 0.92))
                a.syn_in *= m2
                b.syn_in *= m2
                _note_once(a, "friends")
        "incompatible":
            if d <= float(SynergyDefs.param("incompatible", "radius", 120.0)):
                a.set_meta("clash_t", float(a.get_meta("clash_t", 0.0)) + EVERY)
                if float(a.get_meta("clash_t")) >= 1.0 / maxf(0.01, float(SynergyDefs.param("incompatible", "composure_per_s", 1.0))):
                    a.set_meta("clash_t", 0.0)
                    if not a.hero.is_master:
                        a.hero.set_composure(a.hero.composure - 1)
                    if not b.hero.is_master:
                        b.hero.set_composure(b.hero.composure - 1)
                    _note_once(a, "incompatible")
    if d <= float(SynergyDefs.param("mentor", "radius", 200.0)):
        var c := float(SynergyDefs.param("mentor", "crit", 0.05))
        if SynergyDefs.is_mentor(a.hero, b.hero) and b.in_combat():
            b.syn_crit += c
            _note_once(b, "mentor")
        elif SynergyDefs.is_mentor(b.hero, a.hero) and a.in_combat():
            a.syn_crit += c
            _note_once(a, "mentor")


## Lasting synergies are announced (and counted) once per hero per floor, not every update.
static func _note_once(h: SandboxHero, id: String) -> void:
    var key := "syn_noted_" + id
    if h.has_meta(key):
        return
    h.set_meta(key, true)
    h.synergy(id)
