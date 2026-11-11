class_name MasterBot
extends RefCounted
## D-082: a scripted player that, like a real one, drives ONLY the Master (right-click moves, Q attacks,
## W E R skills, Space dashes, holds F to lift a fallen ally) and leads the other four with pings
## (SandboxScreen.ping) and Commands (use_command). It never gives orders to the other heroes directly.
##   style "loco": attacks the nearest foe, pings "attack" at it without thinking, never retreats.
##   style "tactical": explores toward the goal, marks and pings the priority targets (casters, healers,
##   the leader, lookouts), uses Commands at good moments, warns of marked areas, retreats when hurt and
##   lifts the fallen.

const ENGAGE := 320.0
const PING_EVERY := {"loco": 1.0, "tactical": 2.5}
const REVIVE_GO := 420.0

var style: String = "tactical"
## D-083 simulator knobs (tools/sim configs "bot"). Defaults = the D-082 behaviour.
var engage: float = ENGAGE            # how close a visible foe must be to start fighting it
var ping_every: float = -1.0          # seconds between attack pings (-1 = PING_EVERY of the style)
var retreat_hp: float = 0.3           # tactical: the Master backs off below this share of health (0 = never)
var use_commands: bool = true         # Commands (focus, regroup, hold fast)
var use_skills: bool = true           # the Master's W E R
var revive: bool = true               # tactical: walks over and lifts the fallen (hold F)
var regroup_wait: float = 3.0         # D-084 tactical: waits up to this long for the squad before pulling a new group
var camp: bool = true                 # D-090 tactical: pings "Camp here" when the squad is worn out and it is safe
var camp_below: float = 0.55          # ...when the squad's health (or a caster's mana) is under this share
var _wait_t: float = 0.0
var _regroup_cd: float = 0.0
var stats := {"pings": 0, "commands": 0, "skills": 0, "revives": 0, "retreats": 0, "dashes": 0, "camps": 0, "loots": 0}
var loot: bool = true                 # pista D: walks to glowing bodies near the way and holds F
const LOOT_SEEK := 220.0
var _loot_t: float = 0.0              # time spent on the current body (gives up after LOOT_GIVE_UP s)
var _loot_target: LootBag = null
const LOOT_GIVE_UP := 6.0
var _ping_cd: float = 0.0
var _move_cd: float = 0.0
var _last_goal: Vector2 = Vector2.INF
var _pinged: Dictionary = {}          # foe -> already marked (tactical)
var _lifting: SandboxHero = null
var _lift_t: float = 0.0
var _given_up: Dictionary = {}        # fallen allies it could not reach in time (gives up after LIFT_GIVE_UP s)
const LIFT_GIVE_UP := 15.0
const RETREAT_EVERY := 4.0
var _retreat_cd: float = 0.0


func _init(p_style: String = "tactical") -> void:
    style = p_style


func tactical() -> bool:
    return style == "tactical"


## The hero the bot plays: the Master, or (a squad without one) the hero in slot 1.
func lead(sb: SandboxScreen) -> SandboxHero:
    if sb.master_hero != null:
        return sb.master_hero
    if sb.controlled() == null and not sb.heroes.is_empty() and sb.heroes[0].alive:
        sb.select_slot(0)
    return sb.controlled()


## One decision (call every few tenths of a second of game time). goal = where the mission wants the squad
## (relic, clue, exit...; INF = nothing). Returns the skills + commands used.
func think(sb: SandboxScreen, goal: Vector2, dt: float) -> int:
    _ping_cd -= dt
    _move_cd -= dt
    var m := lead(sb)
    sb.interact_held = false
    if m == null or not m.alive or sb.mission_state != SandboxScreen.Mission.ACTIVE:
        return 0
    var used := 0
    var foes: Array = sb.visible_enemies()
    var near: SandboxEnemy = _nearest(foes, m.position, engage)
    # survival of the Master: step out of a marked area (dash on timing)
    if tactical() and _dodge(sb, m, foes):        # D-084: the "loco" never steps out of a marked area
        return used
    if tactical():
        used += _tactical_calls(sb, m, foes, near)
        if revive and _revive(sb, m, foes):
            return used
        if near != null and float(m.hp) < float(m.max_hp) * retreat_hp and _ally_centre(sb, m) != Vector2.INF:   # alone: fight on (D-084)
            stats["retreats"] += 1
            _ping(sb, "danger", near.position)
            # D-084: fall back behind the squad (toward the healer), not just away from the foe
            var back := _ally_centre(sb, m)
            if back == Vector2.INF or back.distance_to(near.position) < m.position.distance_to(near.position):
                back = m.position + (m.position - near.position).normalized() * 160.0
            _move(sb, back, true)
            return used
        # D-084: a new, still idle group in sight and the squad strung out: gather first, then pull it
        _regroup_cd -= dt
        if near != null and not near.alerted and _wait_t < regroup_wait:
            var far := sb.heroes.filter(func(h): return h.alive and not h.downed and h != m and h.position.distance_to(m.position) > 260.0)
            if not far.is_empty():
                _wait_t += dt
                if _regroup_cd <= 0.0:
                    _regroup_cd = 3.0
                    _ping(sb, "regroup", m.position)
                m.stop()
                return used
        if near == null or near.alerted:
            _wait_t = 0.0
    if near != null:
        var key := _priority(foes, m.position, engage) if tactical() else near
        if key == null:
            key = near
        if _ping_cd <= 0.0:
            _ping_cd = ping_every if ping_every > 0.0 else float(PING_EVERY[style])
            _ping(sb, "attack", key.position, key)
        if use_commands and sb.use_command(0, key.position) > 0:         # focus fire whenever it is ready
            stats["commands"] += 1
            used += 1
        if m.position.distance_to(key.position) > m.attack_range() * 0.9:
            _move(sb, key.position, false)
        else:
            m.aimed_attack(key.position, sb.living_enemies(), sb.map)   # Q at the foe
        for i in (m.slots.size() if use_skills else 0):
            if m.skill_ready(i):
                sb.select_only([m])
                if sb.use_skill_selected(i, key.position) > 0:
                    stats["skills"] += 1
                    used += 1
        return used
    if sb.camp != null and is_instance_valid(sb.camp):
        m.stop()                                      # D-090: sits by the fire until the camp ends
        return used
    if loot and _loot(sb, m, dt):                     # pista D (D-121): a glowing body near the way: hold F on it
        return used
    if tactical() and camp and _worn_out(sb) and sb.camp_refusal(m.position) == "":
        _ping(sb, "camp", m.position)
        stats["camps"] += 1
        m.stop()
        return used
    for g in sb.nodes:                                # a gathering spot at the Master's feet: hold F
        if is_instance_valid(g) and not g.taken and g.position.distance_to(m.position) <= GatherNode.RANGE:
            sb.interact_held = true
            m.stop()
            return used
    if goal != Vector2.INF:
        _move(sb, goal, false)
        if tactical() and _ping_cd <= 0.0 and m.position.distance_to(goal) > 300.0:
            _ping_cd = 8.0
            _ping(sb, "explore", m.position + (goal - m.position).normalized() * 200.0)
    return used


## D-090: the squad needs a rest (average health, or a caster's mana, under camp_below).
func _worn_out(sb: SandboxScreen) -> bool:
    var hp := 0.0
    var n := 0
    for h in sb.heroes:
        if not h.alive:
            continue
        hp += float(h.hp) / float(maxi(1, h.max_hp))
        n += 1
        if h.res_kind == "mana" and h.res_max > 0.0 and h.res < h.res_max * camp_below * 0.6:
            return true
    return n > 0 and hp / float(n) < camp_below

## Pista D: walks to the nearest body with loot (only if a pack has room or it holds materials) and
## holds F there; gives up on a body after LOOT_GIVE_UP s. Only when it is safe (SandboxScreen.loot_safe),
## and in defense/survival without moving (loot_holds_post). True while busy looting.
func _loot(sb: SandboxScreen, m: SandboxHero, dt: float) -> bool:
    # the same rule as the autonomous heroes: nothing alive nearby and not fighting; in defense and
    # survival only what lies at its feet (never off its post: the end-of-floor sweep takes the rest)
    if m.target != null or m.is_casting() or not sb.loot_safe(m.position):
        _loot_t = 0.0
        return false
    var seek := LootDefs.LOOT_RANGE * 0.8 if sb.loot_holds_post() else LOOT_SEEK
    var best: LootBag = null
    for b in sb.loot_bags:
        if is_instance_valid(b) and not b.is_empty() and b.visible_to_bot and b.position.distance_to(m.position) <= seek \
                and (best == null or b.position.distance_to(m.position) < best.position.distance_to(m.position)):
            best = b
    if best == null or (best.res.is_empty() and sb._pack_with_room(m, true) == null):
        _loot_t = 0.0
        return false
    if best != _loot_target:
        _loot_target = best
        _loot_t = 0.0
    _loot_t += dt
    if _loot_t > LOOT_GIVE_UP:
        best.visible_to_bot = false               # unreachable: leave it
        _loot_t = 0.0
        return false
    if best.position.distance_to(m.position) <= LootDefs.LOOT_RANGE * 0.8:
        sb.interact_held = true
        m.stop()
        if best.hold == 0.0:
            stats["loots"] += 1
    else:
        _move(sb, best.position, false)
    return true


## Retreat toward the exit like a player: X (the Master runs, the squad is pinged to come), then escape.
## The tactical player first lifts the fallen it can reach (holding F) and calls the squad together;
## it leaves a fallen ally behind only when nobody can reach them safely.
func retreat(sb: SandboxScreen) -> void:
    stats["retreats"] += 1
    var m := lead(sb)
    sb.interact_held = false
    if m == null or not m.alive:
        return
    if tactical():
        _dodge(sb, m, sb.visible_enemies())
        if revive and _revive(sb, m, sb.visible_enemies()):
            if _ping_cd <= 0.0:
                _ping_cd = 3.0
                _ping(sb, "regroup", m.position)
            return
    if sb.extract_block() == "":
        sb.interact_press()                           # F at the exit escapes
        sb.interact_release()
        if sb.mission_state == SandboxScreen.Mission.ACTIVE:
            sb.extract()
        return
    _retreat_cd -= 0.25
    if _retreat_cd <= 0.0:
        _retreat_cd = RETREAT_EVERY                   # X now and then, not every think (pings have an anti-spam)
        sb.squad_key(KEY_X)


func _tactical_calls(sb: SandboxScreen, m: SandboxHero, foes: Array, near: SandboxEnemy) -> int:
    var used := 0
    # mark the priority targets once ("enemy spotted": everybody sees it, DPS focus it)
    for e in foes:
        if not _pinged.has(e) and _is_priority(e) and e.position.distance_to(m.position) < 420.0:
            _pinged[e] = true
            _ping(sb, "spotted", e.position, e)
            break
    # a marked area over the squad: warn them
    for e in foes:
        if e.is_telegraphing() and e.telegraph_radius() >= 60.0:
            var caught := sb.heroes.filter(func(h): return h.alive and h != m and h.position.distance_to(e.aim_point()) <= e.telegraph_radius())
            if caught.size() >= 2:
                _ping(sb, "danger", e.aim_point())
                break
    # Commands: hold fast when someone panics; regroup when the squad is scattered in a fight
    if not use_commands:
        return used
    if sb.heroes.any(func(h): return h.alive and h.has_status("panicked")) and sb.use_command(2) > 0:
        stats["commands"] += 1
        used += 1
    if near != null:
        var far := sb.heroes.filter(func(h): return h.alive and h != m and h.position.distance_to(m.position) > 260.0)
        if far.size() >= 2 and sb.use_command(1) > 0:
            stats["commands"] += 1
            used += 1
    return used


func _is_priority(e: SandboxEnemy) -> bool:
    return e.ai_role in ["caster", "leader", "support"] or e.job == "scout" or e.job == "caller" or e.job == "horn" \
        or e.skills.has("mend") or e.skills.has("ward")


func _priority(foes: Array, from: Vector2, reach: float = ENGAGE) -> SandboxEnemy:
    var best: SandboxEnemy = null
    var best_s := INF
    for e in foes:
        if not e.alive or e.position.distance_to(from) > reach * 1.3:
            continue
        var s: float = e.position.distance_to(from) - (250.0 if _is_priority(e) else 0.0)
        if s < best_s:
            best_s = s
            best = e
    return best


## A fallen ally close by with no foe on top of it: ping "help", walk there and hold F until they are up.
func _revive(sb: SandboxScreen, m: SandboxHero, foes: Array) -> bool:
    if _lifting != null and (not is_instance_valid(_lifting) or not _lifting.downed or _lifting.dead):
        if is_instance_valid(_lifting) and not _lifting.downed and not _lifting.dead:
            stats["revives"] += 1
        _lifting = null
    if _lifting != null:
        _lift_t += 0.25
        if _lift_t > LIFT_GIVE_UP:
            _given_up[_lifting] = true            # could not get to them in time: carry on
            _lifting = null
    if _lifting == null:
        _lift_t = 0.0
        for d in sb.heroes:
            if d.downed and not d.dead and not d.lost and not _given_up.has(d) and d.position.distance_to(m.position) < REVIVE_GO \
                    and _nearest(foes, d.position, 90.0) == null and not sb.heroes.any(func(x): return x.rescue_target == d and x != m):
                _lifting = d
                _ping(sb, "help", d.position)
                break
    if _lifting == null:
        return false
    if m.position.distance_to(_lifting.position) > AiDefs.REVIVE_PROMPT_RANGE * 0.8:
        _move(sb, _lifting.position, false)
    else:
        sb.interact_held = true                      # hold F
    return true


func _dodge(sb: SandboxScreen, m: SandboxHero, foes: Array) -> bool:
    for e in foes:
        if not e.is_telegraphing():
            continue
        var r: float = e.telegraph_radius()
        if r <= 0.0 or m.position.distance_to(e.aim_point()) > r + 6.0:
            continue
        var away: Vector2 = (m.position - e.aim_point()).normalized() if m.position.distance_to(e.aim_point()) > 1.0 else Vector2.RIGHT
        if e.windup_left() < 0.4 and m.dash(away):
            stats["dashes"] += 1
            return true
        _move(sb, e.aim_point() + away * (r + 40.0), true)
        return true
    return false


func _ping(sb: SandboxScreen, kind: String, at: Vector2, foe: SandboxEnemy = null) -> void:
    sb.ping(kind, at, foe)
    stats["pings"] += 1


## Right-click for the Master (it re-paths only when the goal moved or now and then, like a player).
func _move(sb: SandboxScreen, to: Vector2, urgent: bool) -> void:
    var m := lead(sb)
    if m == null:
        return
    if not urgent and _move_cd > 0.0 and _last_goal != Vector2.INF and _last_goal.distance_to(to) < 40.0 and not m.path.is_empty():
        return
    _move_cd = 0.6
    _last_goal = to
    sb.select_only([m])
    sb.order_context(sb.map.nearest_walkable(to))


static func _nearest(foes: Array, from: Vector2, radius: float) -> SandboxEnemy:
    var best: SandboxEnemy = null
    for e in foes:
        if e.alive and e.position.distance_to(from) < radius and (best == null or e.position.distance_to(from) < best.position.distance_to(from)):
            best = e
    return best


## Where the mission wants the squad, with full knowledge of the floor (a replay: the player already knows
## it). Shared by tests/playthrough_bot.gd and the simulator (tools/sim). INF = nothing to head for.
static func mission_goal(sb: SandboxScreen, c: Vector2, skip_targets: Array = []) -> Vector2:
    var goal := Vector2.INF
    match sb.mission_type:
        "sabotage":
            for t in sb.totems:
                if t.alive and (goal == Vector2.INF or t.position.distance_to(c) < goal.distance_to(c)):
                    goal = t.position
            return goal
        "escape":
            return sb.map.center_of(sb.map.relic_cell)
        "defense":
            return sb.shrine.position if sb.shrine != null else goal
        "combat":
            var best_d := INF
            for e in sb.living_enemies():
                if skip_targets.has(e):
                    continue
                var d: float = e.position.distance_to(c)
                if d < best_d:
                    best_d = d
                    goal = e.position
        "exploration":
            var best_d := INF
            for cl in sb.clues:
                if cl.visible and cl.position.distance_to(c) < best_d:
                    best_d = cl.position.distance_to(c)
                    goal = cl.position
        "retrieval", "rescue":
            goal = sb.relic.position if sb.carrier == null else sb.map.center_of(sb.map.extract_cell)
        "boss":
            if sb.boss != null:
                goal = sb.boss.position
        "farm":
            var best_d := INF
            for g in sb.nodes:
                if is_instance_valid(g) and not g.taken and g.position.distance_to(c) < best_d:
                    best_d = g.position.distance_to(c)
                    goal = g.position
    return goal


static func _ally_centre(sb: SandboxScreen, m: SandboxHero) -> Vector2:
    var c := Vector2.ZERO
    var n := 0
    for h in sb.heroes:
        if h != m and h.alive and not h.downed:
            c += h.position
            n += 1
    return c / float(n) if n > 0 else Vector2.INF


## D-084: the goal as a first-time player knows it (only what the squad has seen); INF = explore
## (SandboxScreen._fog_frontier). seen = foes the squad has spotted at least once.
static func known_goal(sb: SandboxScreen, c: Vector2, skip_targets: Array, seen: Dictionary, dead_ends: Dictionary = {}) -> Vector2:
    var known := func(p: Vector2) -> bool: return sb.fog.is_explored(sb.map.cell_of(p))
    var goal := Vector2.INF
    match sb.mission_type:
        "combat", "boss":
            var best_d := INF
            for e in sb.living_enemies():
                if skip_targets.has(e) or not (seen.has(e) or sb.revealed_enemies().has(e)):
                    continue
                if sb.mission_type == "boss" and e != sb.boss and sb.boss != null and seen.has(sb.boss):
                    continue
                var d: float = e.position.distance_to(c)
                if d < best_d:
                    best_d = d
                    goal = e.position
        "exploration":
            var best_d := INF
            for cl in sb.clues:
                if cl.visible and known.call(cl.position) and cl.position.distance_to(c) < best_d:
                    best_d = cl.position.distance_to(c)
                    goal = cl.position
        "retrieval", "rescue":
            if sb.carrier != null:
                goal = sb.map.center_of(sb.map.extract_cell)
            elif known.call(sb.relic.position):
                goal = sb.relic.position
        "sabotage":
            for t in sb.totems:
                if t.alive and known.call(t.position) and (goal == Vector2.INF or t.position.distance_to(c) < goal.distance_to(c)):
                    goal = t.position
        "escape":
            if known.call(sb.map.center_of(sb.map.relic_cell)):
                goal = sb.map.center_of(sb.map.relic_cell)
        "defense":
            if sb.shrine != null and known.call(sb.shrine.position):
                goal = sb.shrine.position
    if goal == Vector2.INF and not ["survival"].has(sb.mission_type):
        goal = frontier(sb, sb.map.cell_of(c), dead_ends)
    return goal


## Nearest explored walkable cell next to never-seen fog, skipping dead ends (frontiers the squad reached
## without revealing anything). Only what the squad has seen is used: the bot never knows the way.
static func frontier(sb: SandboxScreen, from: Vector2i, dead_ends: Dictionary) -> Vector2:
    var seen_c := {from: true}
    var queue: Array[Vector2i] = [from]
    var head := 0
    while head < queue.size():
        var cc: Vector2i = queue[head]
        head += 1
        for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var n: Vector2i = cc + d
            if seen_c.has(n) or sb.map.is_blocked_cell(n):
                continue
            seen_c[n] = true
            if not sb.fog.is_explored(n):
                if not dead_ends.has(cc):
                    return sb.map.center_of(cc)
                continue
            queue.append(n)
    return Vector2.INF
