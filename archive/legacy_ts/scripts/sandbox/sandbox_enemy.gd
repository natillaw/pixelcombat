class_name SandboxEnemy
extends Combatant
## Placeholder enemy (T-010): perceives the nearest hero, chases, then winds up a telegraphed
## strike. The strike lands only on heroes still inside the marked circle when the wind-up ends,
## so the player can dodge by ordering a move.

enum State { IDLE, CHASE, WINDUP, RECOVER }
signal boss_phase(boss, phase)                 # #8: the boss reached EnemyDefs.BOSS_PHASES[phase]
var boss_phase_reached: int = -1

var enemy_name: String = "Grunt"
var atk: int = 12
var defense: int:                   # legacy alias of Combatant.armor
    get:
        return armor
var speed: float = 62.0
var perception: float = 230.0
var strike_range: float = 40.0
var strike_radius: float = 44.0
var windup_time: float = 0.7
var recover_time: float = 0.8
var state: State = State.IDLE
var strike_seq: int = 0              # increments at every wind-up (heroes roll once per strike, D-052)
var _pending_strike: float = -1.0    # D-054: a ranged strike in flight lands when this reaches 0
var _pending_heroes: Array = []
var _timer: float = 0.0
var _aim: Vector2 = Vector2.ZERO
var _shape: Dictionary = {"shape": "circle"}   # D-145 the current telegraph: circle / cone / line (+ reach)
var _from: Vector2 = Vector2.ZERO               # where the cone or line starts (the creature at wind-up)
var _later_calls: Array = []                     # D-145 skill effects that land when the projectile arrives
var _bar_lag: float = 1.0                        # D-145 health bar: white trail that drains after a hit
var _bar_wait: float = 0.0
var _flash: float = 0.0
var type_id: String = ""            # T-024: visual type (EnemySprites.IDS); stats unchanged for now
var _sprite: AnimatedSprite2D = null
var _path: Array[Vector2] = []
var _repath: float = 0.0
const REPATH_EVERY := 0.4
var _anim_lock: float = 0.0        # attack / hurt animation playing (look only)
var focus: SandboxHero = null       # hero it is currently going for (rogue Backstab reads it)
var taunted_by: SandboxHero = null  # Warrior War Cry: forced target while taunt_t > 0
var taunt_t: float = 0.0
# Body size (CombatRules.SIZE, game feel report): presence, knock-back resistance and how it moves.
var size_class: String = "standard"
var body_radius: float = 12.0
var mass: float = 1.0
var is_boss: bool = false
var velocity: Vector2 = Vector2.ZERO
var _accel: float = 0.10
var _turn: float = 16.0
var _cur_speed: float = 0.0
var _heading: Vector2 = Vector2.ZERO
const RUN_ANIM_SPEED := 62.0        # move speed at which the run cycle plays at its authored rate
# Role and encounter (EnemyDefs, D-056): how this creature fights and with whom.
var role: String = "melee"
var home: Vector2 = Vector2.INF     # guard post / patrol start (set when placed)
var group_mates: Array = []         # the rest of its encounter: one spotted or hurt = all alerted
var alerted: bool = false
var dormant: bool = false           # ambusher: hidden and still until a hero comes close or it is hurt
var patrol: Array[Vector2] = []     # patrol route (walked while nothing is perceived)
var _patrol_i: int = 0
var _support_cd: float = 0.0
var _back_cd: float = 0.0
var on_hit_status: Dictionary = {}
var _allies: Array = []             # living creatures (supports heal them), set each tick by the screen
## D-065 creature skills (EnemyDefs.SKILLS): cast like a hero's, with a visible wind-up that only an interrupt skill breaks (D-142).
var skills: Array = []
var skill_cd: Dictionary = {}       # skill id -> seconds left
var casting_skill: String = ""      # the WINDUP is this skill's cast ("" = a basic strike)
var _skill_ally: SandboxEnemy = null
var _skill_check: float = 0.0
var job: String = ""                # "scout" (raises the alarm) | "shaman" (keeps the boss alive) | "caller" | ""
var tactical: bool = false          # 2026-10-31: scores targets (backline, healer, isolated) instead of nearest
var call_t: float = -1.0            # caller: seconds until it howls (-1 = not counting)
var enrage_after: float = 0.0       # boss hard enrage (EnemyDefs.BOSS_ENRAGE_AFTER; 0 = none)
var fight_t: float = 0.0            # boss: seconds since it joined the fight
var hard_enraged: bool = false
var enrage_low: bool = false        # floor modifier "enrage": hits harder once under FloorMods.ENRAGE_BELOW
var enrage_atk: float = FloorMods.ENRAGE_ATK   # D-079: a countered "enrage" (Cold Blood, burst weapons) is milder
var _low_raged: bool = false
var _skill_hero: SandboxHero = null # target of a skill that follows a hero (Mark of Doom)
signal called_reinforcements(e)
var hero_list: Array = []           # every hero of the mission (live array, for lasting zones)
var _alarm_to: SandboxEnemy = null
## D-082 bandit AI by role (AiDefs.BANDIT_AI): brute | assassin | archer | caster | leader | support | "".
var ai_role: String = ""
var threat: Dictionary = {}         # D-090 aggro: hero -> threat (damage dealt to it, healing near it; warriors x2)
var arrows_in: int = 0              # D-090: heroes' arrows stuck in this creature (taken back from the body)
var detect_mult: float = 1.0        # D-090: a camp fire nearby makes it notice heroes from further away (screen)
var marked_by: Node2D = null        # D-090 Hunter's Eye: the archer whose mark keeps it visible in the fog
var _map: NavMap = null
var flee_t: float = 0.0             # running away (low health or broken morale)
var _flee_rolled: bool = false
var _leader_cd: float = 0.0
var horn_t: float = -1.0            # job "horn": seconds until it sounds (-1 = not counting, -2 = done)
var spotted_t: float = 0.0          # D-082 "enemy spotted" ping: visible to the whole squad for a while
signal horn_blown(e)


func _init() -> void:
    setup_combat(60, 3, 2, 0.05, 0.0, 1)


## D-083: set by SandboxScreen from the run seed and the spawn order, so the same expedition rolls the same
## dice (it used to mix in the instance id, which changes every run). 0 = spawned elsewhere (tests).
var spawn_seed: int = 0


func _ready() -> void:
    combat_rng.seed = hash(position) ^ (spawn_seed if spawn_seed != 0 else get_instance_id())


## T-024: swaps the placeholder circle for a Pixel Crawler mob. Falls back to the circle when
## the art is not installed (tests/headless without assets keep working).
func setup_type(id: String, floor_num: int = 0) -> void:
    type_id = id
    _apply_def(id, floor_num)
    if SimMode.on:
        # D-083 headless simulator: the size and name the art would give, without the art
        if _sprite == null:
            enemy_name = id.capitalize() if EnemySprites.is_voxel(id) or EnemySprites.has_processed(id) else enemy_name
            apply_size(CombatRules.size_class_of(id))
        return
    var f := EnemySprites.build_frames(id)
    if f == null or _sprite != null:
        return
    enemy_name = id.capitalize() if EnemySprites.is_voxel(id) or EnemySprites.has_processed(id) else enemy_name
    apply_size(CombatRules.size_class_of(id))
    _sprite = AnimatedSprite2D.new()
    _sprite.sprite_frames = f
    _sprite.centered = false
    _sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # lunge/slide tweens run in idle
    _sprite.scale = Vector2.ONE * EnemySprites.scale_for(id) * (SpriteComposer.LPC_WORLD_SCALE if BanditArt.has(id) else 1.0)
    add_child(_sprite)
    _sprite.play("idle")
    _fit("idle")


## Stats and role from EnemyDefs, scaled a little per floor (more health and damage deeper).
var _floor: int = 0


func _apply_def(id: String, floor_num: int) -> void:
    _floor = floor_num
    var d := EnemyDefs.info(id)
    var k := EnemyDefs.floor_scale(floor_num)
    setup_combat(roundi(float(d["hp"]) * k), int(d["armor"]), int(d["mres"]), crit_chance, status_resist, int(combat_rng.seed))
    atk = roundi(float(d["atk"]) * EnemyDefs.floor_atk_scale(floor_num))
    speed = float(d["speed"])
    role = String(d["role"])
    windup_time = float(d.get("windup", windup_time))
    recover_time = float(d.get("recover", recover_time))
    on_hit_status = d.get("status", {})
    ai_role = String(AiDefs.BANDIT_AI.get(id, ""))
    skills.clear()
    for sid in d.get("skills", []):
        var skill_floor := floor_num if floor_num >= 0 else DungeonDefs.skill_floor(-floor_num)   # D-066 Wilds tiers
        if EnemyDefs.SKILLS.has(sid) and skill_floor >= int(EnemyDefs.SKILLS[sid].get("min_floor", 1)):
            skills.append(String(sid))
    if role == "ranged":
        strike_range = EnemyDefs.RANGED_RANGE
        strike_radius = EnemyDefs.RANGED_RADIUS
    elif role == "support":
        strike_range = 34.0


## D-066: deeper rooms of the Wilds hold stronger creatures (health and damage times k).
func scale_stats(k: float) -> void:
    if is_equal_approx(k, 1.0):
        return
    base_max_hp = roundi(float(base_max_hp) * k)
    max_hp = roundi(float(max_hp) * k)
    hp = max_hp
    atk = roundi(float(atk) * k)


## Wakes this creature and its whole encounter (spotted a hero, or one of them was hurt).
## noise (D-084): the fight also wakes idle creatures of other groups within AiDefs.NOISE_RADIUS (no chain).
func alert(noise: bool = true) -> void:
    if alerted and not dormant:
        return
    alerted = true
    dormant = false
    visible = true
    for m in group_mates:
        if is_instance_valid(m) and m != self and m.alive and not m.alerted:
            m.alert(noise)
    if noise:
        for o in _allies:
            if is_instance_valid(o) and o != self and o.alive and not o.alerted and not o.dormant and not group_mates.has(o) \
                    and o.position.distance_to(position) <= AiDefs.NOISE_RADIUS:
                o.alert(false)


## Size class from the measured art (CombatRules.SIZE): bigger creatures reach further, telegraph
## longer, resist knock-back and accelerate/turn slower. Standard leaves every number as it was.
func apply_size(cls: String) -> void:
    var d: Dictionary = CombatRules.SIZE.get(cls, CombatRules.SIZE["standard"])
    size_class = cls
    body_radius = float(d["body"])
    mass = float(d["mass"])
    strike_range *= float(d["reach"])
    strike_radius *= float(d["reach"])
    windup_time *= float(d["windup"])
    _accel = float(d["accel"])
    _turn = float(d["turn"])


## <= 0 when a click at `p` lands on this creature: distance to a vertical capsule from its feet to
## its head, minus a margin that never goes below the old 26 px click radius.
func pick_distance(p: Vector2) -> float:
    var top := position + Vector2(0, -maxf(14.0, _art_height() - 10.0))
    var bottom := position + Vector2(0, -8)
    var q := Geometry2D.get_closest_point_to_segment(p, top, bottom)
    return q.distance_to(p) - maxf(26.0, body_radius * 1.4)


func is_heavy() -> bool:
    return is_boss or size_class == "large" or size_class == "huge"


func _fit(anim: String) -> void:
    var sz := _sprite.sprite_frames.get_frame_texture(anim, 0).get_size()
    _sprite.offset = Vector2(-sz.x * 0.5, -sz.y)         # feet at the node origin


func _play(anim: String) -> void:
    if _sprite == null or _anim_lock > 0.0 or _sprite.animation == anim:
        return
    _sprite.speed_scale = 1.0
    _sprite.play(anim)
    _fit(anim)


## Plays a one-shot creature animation lasting `duration` seconds (stretched to fit), if it has one.
func _play_once(anim: String, duration: float) -> void:
    if _sprite == null or not _sprite.sprite_frames.has_animation(anim):
        return
    var n := _sprite.sprite_frames.get_frame_count(anim)
    var natural := float(n) / maxf(1.0, _sprite.sprite_frames.get_animation_speed(anim))
    _sprite.speed_scale = natural / maxf(0.05, duration)
    _sprite.stop()
    _sprite.play(anim)
    _fit(anim)
    _anim_lock = duration


func _look_at_x(x: float) -> void:
    if _sprite != null and absf(x - position.x) > 1.0:
        _sprite.flip_h = x < position.x                 # the art faces right


func _update_sprite() -> void:
    if _sprite == null:
        return
    _play("run" if state == State.CHASE else "idle")
    if state == State.WINDUP:
        _look_at_x(_aim.x)
    var k := 1.0 - clampf(_timer / windup_time, 0.0, 1.0)
    if _flash > 0.0:
        _sprite.modulate = Color(2.5, 2.5, 2.5)
    elif state == State.WINDUP:
        _sprite.modulate = Color(1.0, 1.0 - 0.45 * k, 1.0 - 0.45 * k)
    else:
        _sprite.modulate = Color.WHITE


func _do_lunge() -> void:
    if _sprite == null or not _sprite.is_inside_tree():
        return
    var t := _sprite.create_tween()
    t.tween_property(_sprite, "position", (_aim - position).normalized() * 8.0, 0.08)
    t.tween_property(_sprite, "position", Vector2.ZERO, 0.15)


## Floor 10 boss (D-014 principles; numbers are tuning placeholders): much tougher, bigger strike,
## longer and clearer wind-up so the player can read and dodge it.
func make_boss(boss_name: String = "Orc Chieftain") -> void:
    enemy_name = boss_name
    base_max_hp *= int(TowerExpedition.get_floor_config(_floor).get("boss_hp_mult", EnemyDefs.BOSS_HP_MULT)) if _floor > 0 else EnemyDefs.BOSS_HP_MULT
    max_hp = base_max_hp
    hp = max_hp
    atk = roundi(float(atk) * 1.6)
    armor += 4
    strike_radius *= 1.5
    strike_range *= 1.3
    windup_time = 1.1 * float(CombatRules.SIZE[size_class]["windup"])
    is_boss = true
    if type_id == BanditArt.BARON_ID:
        _add_aura()
    for sid in EnemyDefs.BOSS_SKILLS.get(type_id, []):
        if not skills.has(sid):
            skills.append(String(sid))
    mass *= CombatRules.BOSS_MASS_MULT
    body_radius *= 1.5
    if _sprite != null:
        _sprite.scale *= 1.5


## Owner's choice (A+B): the Crimson Baron is drawn x2 and also wears a pulsing crimson aura.
func _add_aura() -> void:
    var g := Gradient.new()
    g.set_color(0, Color(0.95, 0.12, 0.1, 0.55))
    g.set_color(1, Color(0.6, 0.0, 0.0, 0.0))
    var tex := GradientTexture2D.new()
    tex.gradient = g
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = 96
    tex.height = 96
    var aura := Sprite2D.new()
    aura.texture = tex
    aura.scale = Vector2(1.6, 0.9)
    aura.position = Vector2(0, -6)
    aura.z_index = -1
    aura.name = "BaronAura"
    add_child(aura)
    var tw := aura.create_tween().set_loops()
    tw.tween_property(aura, "modulate:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE)
    tw.tween_property(aura, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


func aim_point() -> Vector2:
    return _aim


func windup_left() -> float:
    return _timer if state == State.WINDUP else 0.0


func is_telegraphing() -> bool:
    return state == State.WINDUP


## D-142: only the interrupt skills (SkillDefs.INTERRUPTERS, effect "interrupt") break a wind-up; a stun
## pauses it and a knock-back no longer breaks it. Also used when the creature flees. True if one broke.
func interrupt() -> bool:
    if state != State.WINDUP:
        return false
    if casting_skill != "":
        FloatingText.spawn(self, "%s broken" % String(EnemyDefs.SKILLS[casting_skill]["name"]), Color(1.0, 0.85, 0.4), false)
        casting_skill = ""
    state = State.RECOVER
    _timer = recover_time
    _anim_lock = 0.0
    _play_once("hurt", 0.4)
    FloatingText.spawn(self, "interrupted", Color(1.0, 0.85, 0.4), false)
    return true


## D-090: forces the target for `duration` and puts the taunter first in the threat table.
func taunt(by: SandboxHero, duration: float) -> void:
    taunted_by = by
    taunt_t = maxf(taunt_t, duration)
    var top := 0.0
    for h in threat:
        top = maxf(top, float(threat[h]))
    threat[by] = maxf(float(threat.get(by, 0.0)), top * AiDefs.TAUNT_TOP + 1.0)
    focus = by


## heroes = every hero that is not permanently dead (downed ones can still be hit by a strike).
func tick(delta: float, heroes: Array, map: NavMap) -> void:
    _map = map
    tick_combat(delta)
    if not alive:
        return
    if job == "totem":                     # sabotage: a totem never moves nor strikes (the screen revives)
        queue_redraw()
        return
    _repath = maxf(0.0, _repath - delta)
    _tick_later(delta)
    _tick_bar(delta)
    taunt_t = maxf(0.0, taunt_t - delta)
    _support_cd = maxf(0.0, _support_cd - delta)
    _skill_check = maxf(0.0, _skill_check - delta)
    for sid in skill_cd:
        skill_cd[sid] = maxf(0.0, float(skill_cd[sid]) - delta)
    _back_cd = maxf(0.0, _back_cd - delta)
    spotted_t = maxf(0.0, spotted_t - delta)
    _tick_threat(delta)
    if ai_role == "leader" and alerted:
        _leader_tick(delta)
    if job == "horn" and alerted and not dormant:
        _horn_tick(delta)
    if is_boss and alerted and enrage_after > 0.0 and not hard_enraged:
        fight_t += delta
        if fight_t >= enrage_after:
            hard_enraged = true
            atk = roundi(float(atk) * EnemyDefs.BOSS_ENRAGE_ATK)
            windup_time *= EnemyDefs.BOSS_ENRAGE_WINDUP
            FloatingText.spawn(self, "ENRAGED!", Color(1.0, 0.2, 0.15), false, 2.0)
    if job == "caller" and alerted and not dormant:
        if call_t == -1.0:
            call_t = EnemyDefs.CALLER_DELAY
        elif call_t > 0.0:
            call_t -= delta
            if call_t <= 0.0:
                call_t = -2.0                 # once
                called_reinforcements.emit(self)
                FloatingText.spawn(self, "Howl!", Color(1.0, 0.45, 0.35), false, 1.2)
    if _pending_strike >= 0.0:
        _pending_strike -= delta
        if _pending_strike < 0.0:
            _land_strike(_pending_heroes)
    if _flash > 0.0:
        _flash = maxf(0.0, _flash - delta)
    _anim_lock = maxf(0.0, _anim_lock - delta)
    if not can_act():                     # D-142: a stun pauses the wind-up, it no longer breaks it
        _update_sprite()
        queue_redraw()
        return
    match state:
        State.WINDUP:
            _timer -= delta
            if casting_skill != "" and bool(EnemyDefs.SKILLS[casting_skill].get("follow", false)) \
                    and _skill_hero != null and is_instance_valid(_skill_hero) and _skill_hero.alive:
                _aim = _skill_hero.position
            if _timer <= 0.0:
                if casting_skill != "":
                    _resolve_skill(heroes)
                else:
                    _strike(heroes)
                state = State.RECOVER
                _timer = recover_time
        State.RECOVER:
            _timer -= delta
            if _timer <= 0.0:
                state = State.IDLE
        _:
            if dormant:
                for h in heroes:                  # ambush: still and hidden until a hero walks in
                    if h.alive and position.distance_to(h.position) <= EnemyDefs.AMBUSH_WAKE:
                        alert()
                        FloatingText.spawn(self, "ambush!", Color(1.0, 0.45, 0.35), true)
                        break
                if dormant:
                    _update_sprite()
                    return
            if flee_t > 0.0:
                flee_t -= delta
                _flee_step(heroes, delta, map)     # D-082: running away, no fighting
                _update_sprite()
                queue_redraw()
                return
            var t := _nearest_hero(heroes)
            if t != null and not alerted:
                alert()                           # it saw you: so does its group
            if t != null and role == "guard" and home != Vector2.INF and t.position.distance_to(home) > EnemyDefs.GUARD_LEASH:
                t = null                          # a guard does not leave its post
            focus = t
            if job == "scout" and alerted and _scout_tick(delta, map):
                pass                              # running to raise the alarm: no fighting on the way
            elif _try_skill(heroes, t):
                pass                              # started a cast (wind-up visible, an interrupt breaks it)
            elif t == null:
                state = State.IDLE
                _wander(delta, map)
            elif (role == "ranged" or role == "support") and position.distance_to(t.position) < keep_distance() and _back_cd <= 0.0:
                _back_cd = AiDefs.CASTER_BACK_CD if ai_role == "caster" else 2.0   # keep its distance, not every tick
                var away := position + (position - t.position).normalized() * 90.0
                if not map.is_blocked(away):
                    _path = map.find_path(position, away)
                    _repath = 1.0
                state = State.CHASE
            elif state == State.CHASE and not _path.is_empty() and _repath > 0.6 and (role == "ranged" or role == "support"):
                _step_toward(_path[_path.size() - 1], delta, map)     # finishing the step back
            elif role == "support" and position.distance_to(t.position) > strike_range:
                state = State.IDLE                # healers stay behind the fight
            elif ai_role == "archer" and position.distance_to(t.position) <= strike_range \
                    and not map.has_line_of_sight(position + Vector2(0, -12), t.position + Vector2(0, -12)):
                state = State.CHASE                   # D-082: no clear shot: walk to a spot that has one
                _step_toward(_los_spot(t, map), delta, map)
            elif position.distance_to(t.position) <= strike_range and (role != "ranged" or map.has_line_of_sight(position + Vector2(0, -12), t.position + Vector2(0, -12))):
                state = State.WINDUP
                strike_seq += 1
                _cur_speed = 0.0
                velocity = Vector2.ZERO
                _timer = windup_time
                _play_once("attack", windup_time + 0.15)    # the blow lands when the wind-up ends
                _aim = t.position
                _set_telegraph(EnemyDefs.strike_shape(role, ai_role, String(_strike_fx().get("proj", ""))),
                    position.distance_to(_aim) + strike_radius)
            else:
                state = State.CHASE
                _step_toward(t.position, delta, map)
    _update_sprite()
    queue_redraw()


## Follows a cached path, recomputed every REPATH_EVERY seconds (not every frame: performance).
func _step_toward(goal: Vector2, delta: float, map: NavMap) -> void:
    if not can_move():
        return
    if _repath <= 0.0 or _path.is_empty():
        _repath = REPATH_EVERY
        _path = map.find_path(position, goal)
    if _path.is_empty():
        return
    var to: Vector2 = _path[0] - position
    if to.length() < 4.0:
        _path.remove_at(0)
        return
    _look_at_x(_path[0].x)
    # weight: speed builds up over the size's accel time and the heading turns at a limited rate
    # (a golem swings round, a rat darts); top speed itself is unchanged.
    var want := to.normalized()
    if _heading == Vector2.ZERO:
        _heading = want
    var ang := _heading.angle_to(want)
    _heading = _heading.rotated(clampf(ang, -_turn * delta, _turn * delta))
    var top := speed * move_mult()
    _cur_speed = move_toward(_cur_speed, top, top / maxf(0.01, _accel) * delta)
    var np := position + _heading * _cur_speed * delta
    if not map.can_step(position, np):
        _heading = want                              # never let the turn rate push it into a wall
        np = position + want * _cur_speed * delta
    if map.can_step(position, np):
        velocity = (np - position) / maxf(0.0001, delta)
        position = np
        if _sprite != null and _anim_lock <= 0.0:
            _sprite.speed_scale = clampf(_cur_speed / RUN_ANIM_SPEED, 0.6, 1.4)


## Nothing perceived: patrols walk their route, guards drift back to their post, the rest stay put.
func _wander(delta: float, map: NavMap) -> void:
    if not patrol.is_empty():
        var goal: Vector2 = patrol[_patrol_i % patrol.size()]
        if position.distance_to(goal) < 20.0:
            _patrol_i += 1
        else:
            state = State.CHASE
            _step_toward(goal, delta * 0.6, map)         # patrols walk, they do not run
    elif home != Vector2.INF and position.distance_to(home) > 40.0 and (role == "guard" or alerted):
        state = State.CHASE
        _step_toward(home, delta, map)


func _nearest_hero(heroes: Array) -> SandboxHero:
    if taunt_t > 0.0 and taunted_by != null and is_instance_valid(taunted_by) and taunted_by.alive:
        return taunted_by
    var reach0 := perception * (EnemyDefs.ALERT_PERCEPTION if alerted else 1.0)
    match ai_role:
        "brute", "", "leader", "caster", "support":   # D-090: they follow the threat table
            var top := threat_target(reach0)
            if top != null:
                return top
        "archer":                             # D-090: whoever it has a clear shot at, nearest first
            var shot: SandboxHero = null
            for h in heroes:
                if h.alive and _notices(h, reach0) and position.distance_to(h.position) <= strike_range * AiDefs.ARCHER_PICK_RANGE \
                        and (_map == null or _map.has_line_of_sight(position + Vector2(0, -12), h.position + Vector2(0, -12))) \
                        and (shot == null or position.distance_to(h.position) < position.distance_to(shot.position)):
                    shot = h
            if shot != null:
                return shot
        "assassin":                           # D-082: the cleric or the mage first, from further away
            var prey: SandboxHero = null
            for h in heroes:
                if h.alive and h.hero != null and AiDefs.ASSASSIN_PREY.has(h.hero.hero_class) \
                        and _notices(h, reach0 * AiDefs.ASSASSIN_REACH) \
                        and (prey == null or position.distance_to(h.position) < position.distance_to(prey.position)):
                    prey = h
            if prey != null:
                return prey
    # D-065 relic: the carrier draws every creature that notices it, from much further away
    for h in heroes:
        if h.alive and h.carrying and position.distance_to(h.position) <= perception * EnemyDefs.CARRIER_HUNT:
            return h
    var best: SandboxHero = null
    var reach := perception * (EnemyDefs.ALERT_PERCEPTION if alerted else 1.0)
    var best_d := INF
    var k := float(EnemyDefs.FOCUS_ROLE_MULT.get(role, 1.0)) if tactical or role == "assassin" else 0.0
    for h in heroes:
        if not h.alive:
            continue                          # downed heroes are not chased (no executions, D-036)
        var d: float = position.distance_to(h.position)
        if not _notices(h, reach):
            continue                          # D-090: stealth, bushes, trees in the way
        if k > 0.0:
            d -= k * _focus_bonus(h, heroes)
            if h == focus:
                d -= EnemyDefs.FOCUS_STICKY
        if d < best_d:
            best_d = d
            best = h
    return best


# --- D-082 bandit roles ------------------------------------------------------------------------------

## D-090: does this creature notice the hero within `reach`? reach x (1 - the hero's stealth), never below
## CombatRules.DETECT_MIN of it, x detect_mult (a camp fire). Before the fight it also needs a clear line of
## sight (trees and walls hide the hero); once fighting, a hero it already hates is never lost by stealth.
func _notices(h: SandboxHero, reach: float) -> bool:
    var d := position.distance_to(h.position)
    if threat.has(h) and d < reach:
        return true
    if d >= h.detect_range(reach) * detect_mult:
        return false
    if not alerted and _map != null and not _map.has_line_of_sight(position + Vector2(0, -12), h.position + Vector2(0, -12)):
        return false
    return true


## D-090 aggro: threat from a hero (damage dealt, healing near the fight), x the class multiplier.
func add_threat(h: Node, amount: float) -> void:
    if h == null or not is_instance_valid(h) or amount <= 0.0:
        return
    var cls: String = String(h.hero.hero_class) if h is SandboxHero and h.hero != null else ""
    threat[h] = float(threat.get(h, 0.0)) + amount * AiDefs.THREAT_PER_DAMAGE * float(AiDefs.THREAT_CLASS_MULT.get(cls.trim_prefix("class."), 1.0))


## D-090 for the UI: the hero this creature is going for (taunter first, else its focus; null = nobody).
func attention() -> SandboxHero:
    if taunt_t > 0.0 and taunted_by != null and is_instance_valid(taunted_by) and taunted_by.alive:
        return taunted_by
    if focus != null and is_instance_valid(focus) and focus.alive and alerted:
        return focus
    return null


func threat_of(h: Node) -> float:
    return float(threat.get(h, 0.0))


## [[hero, threat], ...] highest first (UI, tests).
func threat_ranking() -> Array:
    var out: Array = []
    for h in threat:
        if is_instance_valid(h) and h.alive:
            out.append([h, float(threat[h])])
    out.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
    return out


func _tick_threat(delta: float) -> void:
    if threat.is_empty():
        return
    for h in threat.keys():
        if not is_instance_valid(h) or not h.alive:
            threat.erase(h)
            continue
        threat[h] = float(threat[h]) * (1.0 - AiDefs.THREAT_DECAY * delta)


## The standing hero with the most threat within `reach` (null when nobody has hurt it yet).
func threat_target(reach: float) -> SandboxHero:
    var best: SandboxHero = null
    var best_v := 0.5
    for h in threat:
        if is_instance_valid(h) and h.alive and position.distance_to(h.position) <= reach and float(threat[h]) > best_v:
            best_v = float(threat[h])
            best = h
    # D-090: keeps its current target until another hero passes it by THREAT_SWITCH
    if best != null and focus != null and focus != best and threat.has(focus) and is_instance_valid(focus) and focus.alive \
            and position.distance_to(focus.position) <= reach and best_v < float(threat[focus]) * AiDefs.THREAT_SWITCH:
        return focus
    return best


## Distance a ranged / support creature keeps from the nearest hero (archers more, casters when pressed).
func keep_distance() -> float:
    match ai_role:
        "archer":
            return AiDefs.ARCHER_KEEP
        "caster":
            return AiDefs.CASTER_PRESSED
    return EnemyDefs.BACK_OFF


## Archer: a nearby spot (around the target, at strike range) with a clear line to it. Tried in a fixed
## order (deterministic); the target itself when none is found.
func _los_spot(t: SandboxHero, map: NavMap) -> Vector2:
    var base := (position - t.position).angle()
    var r := clampf(position.distance_to(t.position), AiDefs.ARCHER_KEEP, strike_range * 0.9)
    for i in AiDefs.ARCHER_LOS_TRIES:
        var a := base + (float((i + 1) >> 1) * 0.5 * (1.0 if i % 2 == 0 else -1.0))
        var p := t.position + Vector2.RIGHT.rotated(a) * r
        if not map.is_blocked(p) and map.has_line_of_sight(p + Vector2(0, -12), t.position + Vector2(0, -12)):
            return p
    return t.position


## Leader: every LEADER_EVERY s the bandits around it are inspired (+15 % damage for a while).
func _leader_tick(delta: float) -> void:
    _leader_cd -= delta
    if _leader_cd > 0.0:
        return
    _leader_cd = AiDefs.LEADER_EVERY
    var n := 0
    for a in _allies:
        if is_instance_valid(a) and a.alive and a != self and a.ai_role != "" and a.position.distance_to(position) <= AiDefs.LEADER_RADIUS:
            a.apply_status("inspired", AiDefs.LEADER_BUFF_TIME, 0.0, self)
            n += 1
    if n > 0:
        apply_status("inspired", AiDefs.LEADER_BUFF_TIME, 0.0, self)
        FloatingText.spawn(self, "Hold the line!", Color(1.0, 0.6, 0.3), false, 1.0)


## Horn: once alerted (or badly hurt) it sounds a horn: every sleeping creature nearby wakes and comes.
func _horn_tick(delta: float) -> void:
    if horn_t == -2.0:
        return
    if horn_t == -1.0:
        horn_t = AiDefs.HORN_DELAY
    horn_t -= delta
    if horn_t > 0.0 and float(hp) > float(max_hp) * AiDefs.HORN_HP:
        return
    horn_t = -2.0
    var woke := 0
    for a in _allies:
        if is_instance_valid(a) and a.alive and not a.alerted and a.position.distance_to(position) <= AiDefs.HORN_RADIUS:
            a.alert()
            woke += 1
    FloatingText.spawn(self, "Horn!", Color(1.0, 0.45, 0.35), true, 1.4)
    horn_blown.emit(self)


## Low health: rolls once (seeded) to run away for a while.
func _check_flee() -> void:
    if _flee_rolled or ai_role == "" or is_boss or not alive or float(hp) > float(max_hp) * AiDefs.FLEE_HP:
        return
    _flee_rolled = true
    if combat_rng.randf() < AiDefs.FLEE_CHANCE:
        start_flee()


## Morale (D-082): the leader died nearby; this bandit rolls (seeded) to run.
func morale_check() -> bool:
    if not alive or is_boss or ai_role == "" or ai_role == "leader":
        return false
    if combat_rng.randf() < AiDefs.MORALE_FLEE:
        start_flee()
        return true
    return false


func start_flee() -> void:
    if state == State.WINDUP:
        interrupt()
    casting_skill = ""
    flee_t = AiDefs.FLEE_TIME
    FloatingText.spawn(self, "flees!", Color(0.9, 0.9, 0.6), false, 1.2)


func _flee_step(heroes: Array, delta: float, map: NavMap) -> void:
    var near: SandboxHero = null
    for h in heroes:
        if h.alive and (near == null or position.distance_to(h.position) < position.distance_to(near.position)):
            near = h
    state = State.CHASE
    if near == null:
        return
    var away := position + (position - near.position).normalized() * 120.0
    if map.is_blocked(away):
        away = map.nearest_walkable(away)
    _step_toward(away, delta * 1.1, map)


## Tactical targeting: how much more a hero is worth than its distance says (EnemyDefs.FOCUS_*).
func _focus_bonus(h: SandboxHero, heroes: Array) -> float:
    var b := 0.0
    var cls := String(h.hero.hero_class) if h.hero != null else ""
    if cls == "class.cleric":
        b += EnemyDefs.FOCUS_HEALER
    elif h.is_ranged():
        b += EnemyDefs.FOCUS_BACKLINE
    var alone := true
    for o in heroes:
        if o != h and o.alive and o.position.distance_to(h.position) < EnemyDefs.ISOLATION_RADIUS:
            alone = false
            break
    if alone:
        b += EnemyDefs.FOCUS_ISOLATED
    b += EnemyDefs.FOCUS_LOW_HP * (1.0 - float(h.hp) / float(maxi(1, h.max_hp)))
    return b


# --- D-065 skills ----------------------------------------------------------------------------------

## Starts a skill when one is ready and has a use now. Checked a few times a second, not every tick.
func _try_skill(heroes: Array, t: SandboxHero) -> bool:
    if skills.is_empty() or _skill_check > 0.0:
        return false
    _skill_check = 0.25
    for sid in skills:
        if float(skill_cd.get(sid, 0.0)) > 0.0:
            continue
        var sk: Dictionary = EnemyDefs.SKILLS[sid]
        var reach := float(sk["range"])
        var aim := Vector2.INF
        _skill_ally = null
        match String(sk["target"]):
            "ally_low":
                var best_k := float(sk.get("below", 0.75))
                for a in _allies:
                    if is_instance_valid(a) and a.alive and a.position.distance_to(position) <= reach:
                        var k := float(a.hp) / float(maxi(1, a.max_hp))
                        if k < best_k:
                            best_k = k
                            _skill_ally = a
            "ally_key":
                if t == null and not alerted:
                    continue
                var best_hp := -1
                for a in _allies:
                    if is_instance_valid(a) and a.alive and a != self and a.position.distance_to(position) <= reach and not a.has_status("shield"):
                        var w: int = a.max_hp * (10 if a.is_boss else 1)
                        if w > best_hp:
                            best_hp = w
                            _skill_ally = a
            "allies":
                if t == null:
                    continue
                var n := 0
                for a in _allies:
                    if is_instance_valid(a) and a.alive and a != self and a.position.distance_to(position) <= reach:
                        n += 1
                if n >= 1:
                    aim = position
            "self_area":
                if t != null and position.distance_to(t.position) <= reach:
                    aim = position
            "far_hero":
                var far_d := -1.0
                for h in heroes:
                    var dd: float = position.distance_to(h.position)
                    if h.alive and dd <= reach and dd > far_d:
                        far_d = dd
                        aim = h.position
                if t == null:
                    aim = Vector2.INF
            "doom_hero":
                _skill_hero = null
                if t != null:
                    var pool: Array = heroes.filter(func(h): return h.alive and h != focus and position.distance_to(h.position) <= reach)
                    if not pool.is_empty():
                        _skill_hero = pool[combat_rng.randi() % pool.size()]
                        aim = _skill_hero.position
            "self_heal":
                if t != null and float(hp) / float(maxi(1, max_hp)) < float(sk.get("below", 0.8)):
                    aim = position
            "hero_area":
                if t != null and position.distance_to(t.position) <= reach:
                    aim = t.position
                    if tactical:
                        aim = _blob_aim(heroes, reach, aim)
        if _skill_ally == null and aim == Vector2.INF:
            continue
        casting_skill = sid
        skill_cd[sid] = float(sk["cd"])
        _aim = aim if aim != Vector2.INF else _skill_ally.position
        _set_telegraph(sk.get("shape", {"shape": "circle"}), float(sk.get("radius", 0.0)))
        state = State.WINDUP
        strike_seq += 1
        _cur_speed = 0.0
        velocity = Vector2.ZERO
        _timer = float(sk["cast"])
        _play_once("attack", _timer + 0.15)
        FloatingText.spawn(self, String(sk["name"]) + "!", Color(1.0, 0.7, 0.35), false, 1.0)
        return true
    return false


## Anti-blob: aim an area skill at the hero with the most squad-mates around it (ties keep `fallback`).
func _blob_aim(heroes: Array, reach: float, fallback: Vector2) -> Vector2:
    var best := fallback
    var best_n := 1
    for h in heroes:
        if not h.alive or position.distance_to(h.position) > reach:
            continue
        var n := 0
        for o in heroes:
            if o.alive and o.position.distance_to(h.position) <= EnemyDefs.BLOB_RADIUS:
                n += 1
        if n > best_n:
            best_n = n
            best = h.position
    return best


## Master prompt E: the Baron strikes an area away from himself (towards the altar) right now; it is
## telegraphed like a skill (a wind-up the players can see) through a one-off skill entry.
func force_area(at: Vector2, sid: String = "crimson_wave") -> void:
    if not alive or state == State.WINDUP:
        return
    casting_skill = sid
    _aim = at
    state = State.WINDUP
    _timer = float(EnemyDefs.SKILLS[sid]["cast"])
    strike_seq += 1
    FloatingText.spawn(self, "Crimson Wave!", Color(1.0, 0.3, 0.25), false, 1.0)


## The radius of the area the current wind-up marks (a skill's own, or the basic strike's).
func telegraph_radius() -> float:
    if casting_skill != "":
        return float(EnemyDefs.SKILLS[casting_skill].get("radius", 0.0))
    return strike_radius


## D-145: "circle" | "cone" | "line" of the current (or last) wind-up.
func telegraph_shape() -> String:
    return String(_shape.get("shape", "circle"))


func _set_telegraph(shape: Dictionary, reach: float) -> void:
    _shape = shape.duplicate()
    _shape["reach"] = reach
    _from = position


## D-145: true when `p` stands inside the area the current wind-up marks (what the blow will hit).
func in_telegraph(p: Vector2) -> bool:
    return _in_shape(p, _shape, _from, _aim, telegraph_radius())


static func _in_shape(p: Vector2, shape: Dictionary, from: Vector2, at: Vector2, radius: float) -> bool:
    var reach := float(shape.get("reach", radius))
    var dir := at - from
    if dir.length() < 1.0:
        dir = Vector2.RIGHT
    match String(shape.get("shape", "circle")):
        "cone":
            var d := p - from
            if d.length() > reach:
                return false
            return d.length() < 14.0 or absf(dir.angle_to(d)) <= deg_to_rad(float(shape.get("angle", 90.0)) * 0.5)
        "line":
            var end := from + dir.normalized() * maxf(reach, dir.length())
            var q := Geometry2D.get_closest_point_to_segment(p, from, end)
            return q.distance_to(p) <= float(shape.get("width", 18.0)) * 0.5 + 6.0     # + a hero's half body
        _:
            return p.distance_to(at) <= radius


func _tick_later(delta: float) -> void:
    if _later_calls.is_empty():
        return
    var due: Array = []
    for c in _later_calls:
        c["t"] = float(c["t"]) - delta
        if float(c["t"]) <= 0.0:
            due.append(c)
    for c in due:
        _later_calls.erase(c)
        (c["f"] as Callable).call()


## Health bar juice (D-111 style): the bar drops at once, the white part waits BAR_WAIT s and drains.
const BAR_WAIT := 0.3
const BAR_DRAIN := 0.9
func _tick_bar(delta: float) -> void:
    var frac := float(hp) / float(maxi(1, max_hp))
    if frac >= _bar_lag:
        _bar_lag = frac
    elif _bar_wait > 0.0:
        _bar_wait -= delta
    else:
        _bar_lag = move_toward(_bar_lag, frac, BAR_DRAIN * delta)


## Middle of the marked area (where a cone or line blow shows its impact).
func _shape_centre(shape: Dictionary, from: Vector2, at: Vector2) -> Vector2:
    var reach := float(shape.get("reach", 0.0))
    match String(shape.get("shape", "circle")):
        "cone", "line":
            return from + (at - from).normalized() * reach * 0.55 if from.distance_to(at) > 1.0 else at
    return at


func _resolve_skill(heroes: Array) -> void:
    var sid := casting_skill
    casting_skill = ""
    var sk: Dictionary = EnemyDefs.SKILLS[sid]
    var parent := get_parent()
    if sk.has("heal_pct") and _skill_ally != null and is_instance_valid(_skill_ally) and _skill_ally.alive:
        _skill_ally.heal(roundi(float(_skill_ally.max_hp) * float(sk["heal_pct"])))
        CombatVFX.play(parent, _skill_ally.position + Vector2(0, -14), "heal_toxic", 1.0)
    if sk.has("shield_pct") and _skill_ally != null and is_instance_valid(_skill_ally) and _skill_ally.alive:
        _skill_ally.apply_status("shield", 10.0, float(_skill_ally.max_hp) * float(sk["shield_pct"]), self)
    if String(sk["target"]) == "allies":
        for a in _allies:
            if is_instance_valid(a) and a.alive and a.position.distance_to(position) <= float(sk["range"]):
                var st: Dictionary = sk["status"]
                a.apply_status(String(st["id"]), float(st["dur"]), float(st["mag"]), self)
        CombatFeel.shake(self, "small")
    if bool(sk.get("dash", false)):
        position = _aim + (position - _aim).normalized() * 18.0   # lands next to its prey
    if sk.has("heal_self_pct"):
        heal(roundi(float(max_hp) * float(sk["heal_self_pct"])))
        CombatVFX.play(parent, position + Vector2(0, -14), "heal_toxic", 1.4)
    if String(sk["target"]) in ["hero_area", "self_area", "far_hero", "doom_hero"]:
        # D-145: the skill shows itself when the wind-up ends (a fireball flies, an arrow along the line, a
        # meteor from the sky) and its damage lands on arrival, on whoever is still in the marked shape.
        var look: Dictionary = sk.get("look", {})
        var shp := _shape.duplicate()
        var from := _from
        var at := _aim
        var travel := 0.0
        if look.has("proj") and parent != null:
            var start := at + Vector2(-160, -420) if bool(look.get("sky", false)) else position + Vector2(0, -20)
            var spd := float(look.get("speed", 650.0 if bool(look.get("sky", false)) else 800.0))
            var end := at + Vector2(0, -12) if String(shp.get("shape", "circle")) != "line" else from + (at - from).normalized() * float(shp.get("reach", 0.0))
            CombatVFX.projectile(parent, start, end, String(look["proj"]), "", spd, float(look.get("scale", 1.0)), 1.0)
            travel = start.distance_to(end) / spd
        var land := func(): _land_skill(sid, sk, shp, from, at, heroes, hero_list)
        if travel > 0.02:
            _later_calls.append({"t": travel, "f": land})
        else:
            land.call()
    _do_lunge()


## D-145: where a creature skill lands: damage + status on everyone inside its shape, its look and juice.
func _land_skill(sid: String, sk: Dictionary, shp: Dictionary, from: Vector2, at: Vector2, heroes: Array, all_heroes: Array) -> void:
    var parent := get_parent()
    var r := float(sk["radius"])
    var look: Dictionary = sk.get("look", {})
    if sk.has("dmg_mult"):
        var caught := heroes.filter(func(h): return is_instance_valid(h) and not h.dead and _in_shape(h.position, shp, from, at, r))
        var blob := EnemyDefs.BLOB_MULT if caught.size() >= EnemyDefs.BLOB_COUNT else 1.0
        for h in caught:
            var own := float(sk.get("target_mult", 1.0)) if h == _skill_hero else 1.0
            var hit := DamageInfo.make(float(atk) * float(sk["dmg_mult"]) * EnemyDefs.TELEGRAPH_MULT * blob * own, EnemyDefs.TELEGRAPH_KIND, self, crit_chance, combat_rng)
            hit.element = String(sk.get("element", ""))
            hit.tags.append("eskill." + sid)                  # its own juice profile (JuiceDefs.ENEMY)
            h.take_hit(hit)
            if sk.has("status") and h.alive:
                var st2: Dictionary = sk["status"]
                h.apply_status(String(st2["id"]), float(st2["dur"]), float(st2["mag"]), self)
        CombatFeel.shake(self, "medium" if r >= 90.0 else "small", at - from)
    if parent != null:
        var centre := _shape_centre(shp, from, at)
        if String(shp.get("shape", "circle")) == "circle":
            CombatVFX.area_burst(parent, at, r, String(look.get("hit", "slam" if r >= 60.0 else "spark")))
        else:
            for i in 3:                                       # along the cone / line
                var k := 0.3 + 0.35 * float(i)
                CombatVFX.play(parent, from + (centre - from) * k * 1.8, String(look.get("hit", "slash_heavy")), 1.0, at.x < from.x)
        if look.has("extra"):
            CombatVFX.play(parent, centre, String(look["extra"]), clampf(r / 60.0, 0.8, 2.5))
    if sk.has("zone") and parent != null:
        var z: Dictionary = sk["zone"]
        CombatZone.spawn(parent, at, r, float(z["life"]), String(z["status"]), float(z["dur"]), float(z["mag"]),
            all_heroes if not all_heroes.is_empty() else heroes, self)


## Lookout (D-065): once it has seen the squad it does not fight; it runs to the nearest creature that
## has not been alerted yet and raises the alarm there (its whole group joins). Kill it before it arrives.
func _scout_tick(delta: float, map: NavMap) -> bool:
    if _alarm_to == null or not is_instance_valid(_alarm_to) or not _alarm_to.alive or _alarm_to.alerted:
        _alarm_to = null
        var best_d := 1400.0
        for a in _allies:
            if is_instance_valid(a) and a.alive and not a.alerted and not group_mates.has(a):
                var d: float = a.position.distance_to(position)
                if d < best_d:
                    best_d = d
                    _alarm_to = a
        if _alarm_to == null:
            job = ""                              # nobody left to warn: fights like the others
            return false
        FloatingText.spawn(self, "!", Color(1.0, 0.3, 0.2), true, 1.2)
    if position.distance_to(_alarm_to.position) <= EnemyDefs.SCOUT_ALARM_RADIUS:
        _alarm_to.alert()
        FloatingText.spawn(_alarm_to, "ALARM!", Color(1.0, 0.3, 0.2), true, 1.6)
        _alarm_to = null
        job = ""
        return false
    state = State.CHASE
    _step_toward(_alarm_to.position, delta * EnemyDefs.SCOUT_FLEE_SPEED, map)
    return true


## D-065: a stun breaks a boss's shield (the shamans' Ward): control is how a squad gets through it.
func apply_status(id: String, duration: float, magnitude: float = 0.0, source: Node2D = null) -> void:
    if id == "stun" and is_boss and statuses.has("shield") and alive:
        statuses.erase("shield")
        FloatingText.spawn(self, "shield broken!", Color(0.6, 0.85, 1.0), true)
    super.apply_status(id, duration, magnitude, source)


## Look of the basic strike per creature (CombatVFX.ENEMY_FX): claws, slime splashes, spores, slams, spells.
func _strike_fx() -> Dictionary:
    var fx := CombatVFX.enemy_fx(type_id)
    if role == "ranged" and not fx.has("proj"):
        fx = {"proj": "orb", "hit": String(fx.get("hit", "spark_small"))}    # a ranged strike always flies
    return fx


func _strike(heroes: Array) -> void:
    _do_lunge()
    var fx := _strike_fx()
    var sc := strike_radius / 44.0
    var at := _aim + Vector2(0, -12)
    if telegraph_shape() == "line" and fx.has("proj"):
        at = _from + (_aim - _from).normalized() * float(_shape.get("reach", 0.0)) + Vector2(0, -12)   # flies the whole line
    elif telegraph_shape() == "cone" and get_parent() != null:
        CombatVFX.play(get_parent(), _shape_centre(_shape, _from, _aim) + Vector2(0, -10), "crescent", sc, _aim.x < position.x)
    if fx.has("proj"):
        var from := position + Vector2(0, -20)
        CombatVFX.projectile(get_parent(), from, at, String(fx["proj"]), String(fx["hit"]), STRIKE_PROJECTILE_SPEED, 1.0, sc)
        _pending_strike = from.distance_to(at) / STRIKE_PROJECTILE_SPEED      # D-054: lands on arrival
        _pending_heroes = heroes
    else:
        CombatVFX.play(get_parent(), at, String(fx.get("hit", "claw")), sc, _aim.x < position.x)
        _land_strike(heroes)
    if fx.has("extra"):
        CombatVFX.play(get_parent(), _aim, String(fx["extra"]), sc)


const STRIKE_PROJECTILE_SPEED := 900.0


## Everyone still inside the marked circle when the blow (or the projectile) lands is hit.
func _land_strike(heroes: Array) -> void:
    for h in heroes:
        if is_instance_valid(h) and not h.dead and _in_shape(h.position, _shape, _from, _aim, strike_radius):
            var dmg_info := DamageInfo.make(float(atk) * (EnemyDefs.HEAVY_MULT if windup_time >= EnemyDefs.HEAVY_WINDUP else 1.0), "physical", self, crit_chance, combat_rng)
            var proj := String(_strike_fx().get("proj", ""))
            if proj != "":
                dmg_info.tags.append("eskill.basic_" + proj)     # D-145 juice of the shot (JuiceDefs.ENEMY)
            h.take_hit(dmg_info)
            if not on_hit_status.is_empty() and h.alive:
                h.apply_status(String(on_hit_status["id"]), float(on_hit_status["dur"]), float(on_hit_status.get("mag", 0.0)), self)
    if is_boss:
        CombatFeel.shake(self, "medium", _aim - position)
        CombatFeel.freeze(_sprite, "boss")
    elif is_heavy():
        CombatFeel.shake(self, "small", _aim - position)


## Light blows only flash a heavy creature; a blow worth STAGGER_PCT of its health makes it flinch.
const STAGGER_PCT := 0.06


func _on_hit(info: DamageInfo, dmg: int) -> void:
    _flash = 0.12
    _bar_wait = BAR_WAIT
    alert()                                       # hurting one wakes its whole encounter
    if info != null and info.source is SandboxHero:
        if info.has_meta("aoe") and taunt_t > 0.0 and taunted_by != null and info.source != taunted_by:
            (info.source as SandboxHero).synergy("taunt_aoe")    # D-090 Safe Sweep: no threat while taunted
        else:
            add_threat(info.source, float(dmg))
    _check_flee()
    if is_boss and hp > 0:
        _check_boss_phase()
    if enrage_low and not _low_raged and hp > 0 and float(hp) < float(max_hp) * FloorMods.ENRAGE_BELOW:
        _low_raged = true
        atk = roundi(float(atk) * enrage_atk)
        FloatingText.spawn(self, "Enraged!", Color(1.0, 0.3, 0.2), false, 1.2)
    var flinch := not is_heavy() or float(dmg) >= float(max_hp) * STAGGER_PCT * (2.0 if is_boss else 1.0)
    if dmg > 0 and state != State.WINDUP and hp > 0 and flinch:
        _play_once("hurt", 0.3)


func _check_boss_phase() -> void:
    var frac := float(hp) / float(maxi(1, max_hp))
    for i in EnemyDefs.BOSS_PHASES.size():
        var ph: Dictionary = EnemyDefs.BOSS_PHASES[i]
        if i > boss_phase_reached and frac <= float(ph["at"]):
            boss_phase_reached = i
            if ph.has("enrage_atk"):
                atk = roundi(float(atk) * float(ph["enrage_atk"]))
                windup_time *= float(ph["enrage_windup"])
                FloatingText.spawn(self, "ENRAGED!", Color(1.0, 0.3, 0.2), true)
            else:
                FloatingText.spawn(self, "To me, warband!", Color(1.0, 0.55, 0.3), true)
            boss_phase.emit(self, i)


func _on_die() -> void:
    if is_heavy() and is_inside_tree():
        CombatVFX.play(get_parent(), position, "dust_puff", body_radius / 14.0)
        CombatFeel.shake(self, "medium" if is_boss else "small")
    EnemySprites.spawn_death(self, _sprite)
    visible = false


func _draw() -> void:
    if not alive:
        return
    var body := Color(0.85, 0.30, 0.30) if _flash <= 0.0 else Color.WHITE
    # contact shadow sized to the body: tells size and where the creature really stands
    draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
    draw_circle(Vector2.ZERO, body_radius * 1.25, Color(0, 0, 0, 0.3))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    var bar_y := -34.0
    var bar_w := 30.0
    if _sprite == null:
        draw_circle(Vector2(0, -12), 12.0, body)
    else:
        bar_y = -minf(_art_height() + 8.0, 150.0)          # above the head, whatever the size
        bar_w = clampf(body_radius * 2.6, 26.0, 70.0)
    var frac := float(hp) / float(maxi(1, max_hp))
    draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, 4), Color(0.1, 0.1, 0.1, 0.8))
    draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * maxf(_bar_lag, frac), 4), Color(1.0, 0.95, 0.85, 0.9))   # D-145 white trail
    draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * frac, 4), Color(1.0, 1.0, 1.0) if _flash > 0.0 else Color(0.9, 0.35, 0.35))
    # D-090 attention: who it goes for (that hero's number, in its star colour); a taunt shows a red ring
    var att := attention()
    if att != null and att.hero != null:
        var col := att.hero.star_color()
        if taunt_t > 0.0:
            draw_arc(Vector2(bar_w * 0.5 + 6.0, bar_y + 1.0), 6.0, 0.0, TAU, 16, Color(1.0, 0.3, 0.25), 2.0)
        draw_string(ThemeDB.fallback_font, Vector2(bar_w * 0.5 + 2.5, bar_y + 5.0), str(att.slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
    if has_status("marked") and marked_by != null:
        draw_arc(Vector2(0, -12), body_radius + 6.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.7, 0.8), 1.5)   # Hunter's Eye
    if state == State.WINDUP:
        # telegraph = the real strike area; the inner disc fills it as the blow approaches (lands when full)
        var total := windup_time if casting_skill == "" else float(EnemyDefs.SKILLS[casting_skill]["cast"])
        var k := 1.0 - clampf(_timer / maxf(0.01, total), 0.0, 1.0)
        var r := telegraph_radius()
        if r <= 0.0:
            # a help spell (heal, ward, rally): a ring on the caster fills up; interrupt it before it closes
            draw_arc(Vector2(0, -6), body_radius + 10.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(0.4, 1.0, 0.6), 3.0)
        elif telegraph_shape() == "cone":
            _draw_cone(k)
        elif telegraph_shape() == "line":
            _draw_line_tele(k)
        else:
            draw_set_transform(_aim - position, 0.0, Vector2(1.0, 0.55))
            draw_circle(Vector2.ZERO, r, Color(1.0, 0.2, 0.2, 0.10 + 0.12 * k))
            draw_circle(Vector2.ZERO, r * k, Color(1.0, 0.25, 0.2, 0.25))
            draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.3, 0.3), 3.0 if is_heavy() or casting_skill != "" else 2.0)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## D-145 cone telegraph: the wedge, a fill that grows outwards as the blow approaches, and its edge.
func _draw_cone(k: float) -> void:
    var o := _from - position
    var reach := float(_shape.get("reach", 60.0))
    var half := deg_to_rad(float(_shape.get("angle", 90.0)) * 0.5)
    var a0 := (_aim - _from).angle() if _aim.distance_to(_from) > 1.0 else 0.0
    var heavy := is_heavy() or casting_skill != ""
    for pass_i in 2:
        var rr := reach if pass_i == 0 else reach * k
        if rr < 2.0:
            continue
        var pts := PackedVector2Array([o])
        for i in 17:
            var a := a0 - half + 2.0 * half * float(i) / 16.0
            pts.append(o + Vector2(cos(a), sin(a) * 0.55) * rr)
        draw_colored_polygon(pts, Color(1.0, 0.2, 0.2, 0.10 + 0.12 * k) if pass_i == 0 else Color(1.0, 0.25, 0.2, 0.25))
        if pass_i == 0:
            pts.append(o)
            draw_polyline(pts, Color(1.0, 0.3, 0.3), 3.0 if heavy else 2.0)


## D-145 line telegraph: a lane from the creature through the target that fills from the creature.
func _draw_line_tele(k: float) -> void:
    var reach := float(_shape.get("reach", 60.0))
    var w := float(_shape.get("width", 18.0))
    var dir := (_aim - _from).normalized() if _aim.distance_to(_from) > 1.0 else Vector2.RIGHT
    var lane := maxf(reach, _aim.distance_to(_from))
    draw_set_transform(_from - position, dir.angle(), Vector2.ONE)
    draw_rect(Rect2(0, -w * 0.5, lane, w), Color(1.0, 0.2, 0.2, 0.10 + 0.12 * k))
    draw_rect(Rect2(0, -w * 0.5, lane * k, w), Color(1.0, 0.25, 0.2, 0.25))
    draw_rect(Rect2(0, -w * 0.5, lane, w), Color(1.0, 0.3, 0.3), false, 3.0 if is_heavy() or casting_skill != "" else 2.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Height of the creature on screen (opaque frame height x scale), for the health bar.
func _art_height() -> float:
    if _sprite == null or _sprite.sprite_frames == null:
        return 26.0
    return float(EnemySprites.art_height(type_id)) * _sprite.scale.y
