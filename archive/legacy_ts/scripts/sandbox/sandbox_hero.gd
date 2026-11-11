class_name SandboxHero
extends Combatant
## One deployed hero in a mission: animated sprite, movement, autonomous basic attacks, skills (SkillDefs) and
## direct orders. Health, damage, statuses, downed/agony and death live in Combatant (D-035..D-037).
## Orders are always obeyed (D-016: no random refusal); the order state decides what autonomy may do.

const ARRIVE_EPS := 1.0
const REPATH_EVERY := 0.4
# Movement feel (game feel report): full speed in ACCEL_TIME (no perceptible input lag), a short ease-in
# over the last ARRIVE_EASE pixels, idle only after IDLE_GRACE without a path (no idle/walk flicker
# between repaths), and a facing that changes axis only when the new axis clearly dominates.
const ACCEL_TIME := 0.07
const ARRIVE_EASE := 10.0
const IDLE_GRACE := 0.12
const FACING_HYSTERESIS := 1.3
const WALK_ANIM_SPEED := 85.0       # move speed at which the walk cycle plays at its authored rate
const ATTACK_LEAD := 0.12           # the attack pose starts this early so the blow lands on the damage

var hero: HeroData
var dev_fly: bool = false            # D-146 dev console /fly: moves in a straight line through walls
var vision_mod: int = 0
var art_scale: float = 1.0           # LPC heroes are drawn at half size (SpriteComposer.LPC_WORLD_SCALE)
var dash_cd: float = 0.0             # CombatRules.DASH_*
var dash_t: float = 0.0
var _dash_end: Vector2 = Vector2.ZERO
var _ghost_t: float = 0.0
var dashes: int = 0                  # stat (bots, tests)              # floor modifier "fog" (master prompt D)
var slot: int = 0                 # 0-4 -> key 1-5
var selected: bool = false : set = _set_selected
var path: Array[Vector2] = []
var facing: String = "down"
var speed: float = 90.0
var stats: Dictionary = {}        # derived combat stats (CombatRules.derive)
var _sprite: AnimatedSprite2D
var _anim_lock: float = 0.0          # T-023: blocks idle/walk from overriding an attack/cast pose
var velocity: Vector2 = Vector2.ZERO # last step's real velocity (camera look-ahead, debug overlay)
var _cur_speed: float = 0.0
var _idle_t: float = 0.0
var _prerolled: bool = false         # attack pose already started for the coming blow
## Authority (D-053): "ai" = autonomy decides; "player" = the player drives this hero directly, so
## autonomy never moves it on its own (no dodging, kiting or chasing beyond reach).
var controller: String = "ai"
## What this hero did this expedition (ExpeditionResults / MVP): damage, kills, healing, shield,
## rescues, explored, objective, gathered, tanked.
var contrib: Dictionary = {}
var low_hp_shaken: bool = false       # D-081: Composure already lost for this low-health spell
var was_panicked: bool = false
var anchor: SandboxHero = null       # hero the player drives: autonomous ones stay around it (set by the screen)
var rally_point: Vector2 = Vector2.INF   # squad centre (set by the screen): where a hurt hero falls back to
var explore_goal: Vector2 = Vector2.INF  # fog frontier picked by the screen for an idle explorer
var _fallback_cd: float = 0.0
const ANCHOR_LEASH := 150.0
var _dodge_seen: Dictionary = {}     # enemy instance id -> strike number already rolled for (D-052)
var _kite_cd: float = 0.0
var _pending: Array = []             # [{"t": seconds, "f": Callable}]: hits in flight (D-054)
var _side: String = "right"          # last horizontal facing (up/down attacks reuse it)
var chatter_text: String = ""
var chatter_timer: float = 0.0
## D-082 layered autonomy (AiDefs): 1 survival > 2 orders (pings, Commands) > 3 role > 4 personality.
## The hero re-decides every AiDefs.decide_interval(Composure) seconds, not every frame.
var role: String = "support"              # AiDefs.ROLE_BY_CLASS
var persona: Dictionary = {}              # AiDefs.personality(traits)
var ai_layer: String = ""                 # layer that made the last decision (debug overlay, tests)
var decisions: int = 0                    # how many times it decided (tests: not every frame)
var _think_t: float = 0.0
var order_left: float = 0.0               # a ping order ends after this many seconds (0 = no limit)
var focus_hint: SandboxEnemy = null       # the squad's focus (pinged / spotted), set by the screen
var defend_point: Vector2 = Vector2.INF   # "defend this area" ping
var revive_prompt: bool = false           # the Master stands next to this downed hero: "Hold F" (screen)
var _last_foes: Array = []                # what it saw last tick (its shots hit these)
var _shots: Array = []                    # ArrowShot in flight (D-082 real projectiles)
var _draw_t: float = -1.0                 # bow drawn: releases in this many seconds (-1 = not drawing)
var _draw_target: SandboxEnemy = null
var _draw_point: Vector2 = Vector2.INF    # player-aimed shot: released toward this point
var basic_attacks: int = 0                # stats (tests): basic attacks started / blows landed
var blows: int = 0
var shots_fired: int = 0
var shots_hit: int = 0
var blocks: int = 0                       # D-082b: blows the shield blocked

## Order state (D-040, D-082): "auto" | "move" | "attack" | "attack_move" | "hold" | "follow" | "retreat" | "rescue" | "defend".
var order: String = "auto"
var order_point: Vector2 = Vector2.ZERO     # attack-move destination / hold spot
var follow_leader: SandboxHero = null
var _dodge_t: float = 0.0
const KITE_DISTANCE := 70.0
const FOLLOW_DISTANCE := 90.0
const FOLLOW_LEASH := 170.0
const ORDER_LABELS := {"auto": "Auto", "move": "Moving", "attack": "Attacking", "attack_move": "Attack-moving",
	"hold": "Holding", "follow": "Following", "retreat": "Retreating", "rescue": "Rescuing", "defend": "Defending"}
var auto_path: bool = false         # true while walking toward a target on its own
var target: SandboxEnemy = null
var rescue_target: SandboxHero = null
var then_retreat: Vector2 = Vector2.INF
var squad: Array = []                     # every hero of the mission (set by the screen): allies for skills
## D-065: an autonomous hero uses its skills on its own (heal a hurt ally, break a creature's cast,
## draw blows off a fragile ally, shield, attack). T toggles it; a driven hero never auto-casts.
var auto_skills: bool = true
const AUTO_HEAL_BELOW := 0.6              # heals an ally under this fraction of its health
const CARRY_MOVE := 0.6                   # the relic carrier walks slower and cannot fight   # #14: a retreat that first picks up a fallen ally on the way out
var rescue_progress: float = 0.0
var _repath: float = 0.0
var _last_delta: float = 0.0
var _cooldown: float = 0.0
var _flash: float = 0.0
var carrying: bool = false          # holds the mission relic (T-011)
# Active skills (Phase 3): class resource (D-041), W/E/R slots (D-059), casting (D-042).
const CAST_BREAK_CD := 2.0          # cooldown left after a cast is broken by control
const SHIELD_TIME := 10.0
const REGEN_PER_MAG := 0.4          # Sanctuary heals this much per second per point of magic power
var res_kind: String = "stamina"
var res: float = 0.0
var res_max: float = 100.0
var slots: Array = []               # skill ids, keys W E R (D-059; Q = basic attack)
var combo: int = 0                  # D-090: rogue combo points (SkillDefs.COMBO_MAX), spent by finishers
var arrows: int = -1                # D-090: arrows left in the quiver (-1 = no bow: nothing to count)
var combat_t: float = 0.0           # D-090: seconds left "in combat" (SkillDefs.COMBAT_LINGER): resource regen/decay
var in_bush: bool = false           # D-090: standing in a bush (set by the screen): + stealth, half see-through
var synergy_vision: int = 0         # D-090 Shared Sight (set by the screen)
var syn_out: float = 1.0            # D-090 bond synergies (set by the screen): rivals = more damage dealt
var syn_in: float = 1.0             # friends = less damage taken
var syn_crit: float = 0.0           # mentor = more critical chance
var _arrow_corpses: Array = []      # creatures carrying this hero's arrows (recoverable once they are dead)
var _still_t: float = 0.0
var _syn_shown: Dictionary = {}     # synergy id -> seconds before its name floats again over this hero
var _cur_combo: int = 0             # combo points of the finisher being resolved
var _cur_aoe: bool = false          # the skill being resolved hits an area (Safe Sweep)
var cds: Dictionary = {}            # skill id -> seconds until ready
var casting: String = ""            # skill being cast ("" = none)
var cast_left: float = 0.0
var cast_target: Combatant = null
var cast_point: Vector2 = Vector2.ZERO
var last_refusal: String = ""       # why the last skill request was refused (shown to the player)
var _cast_enemies: Array = []
var _cast_allies: Array = []
var _map: NavMap = null
var _firing: String = ""            # id of the skill being resolved (for its look)
var _cast_fx: Node2D = null         # cast circle under the hero while casting
var _aim: Vector2 = Vector2.INF     # where the player aimed the skill being started (INF = autonomy picks)
# Equipment powers (ItemDefs.apply_equipment "mods") and carried consumables (HeroData.bag).
var item_mods: Dictionary = {}
var was_downed: bool = false        # for the expedition's after-effects (Game.after_expedition)
var was_poisoned: bool = false
var _potion_cd: float = 0.0
const POTION_CD := 8.0               # shared pause after any consumable (antidotes, elixirs)
var heal_potion_cd: float = 0.0      # owner 2026-11-02: LootDefs.HEAL_POTION_CD between healing potions
var _fx: float = 0.0                # skill visual timer
var _fx_to: Vector2 = Vector2.ZERO
var _fx_radius: float = 0.0


func say(text: String, duration: float = 4.0) -> void:
	chatter_text = StringsEs.tx(text)          # hero lines are English keys; Spanish by default (StringsEs)
	chatter_timer = duration
	queue_redraw()


func _init(h: HeroData = null, slot_index: int = 0) -> void:
	hero = h
	slot = slot_index


func _ready() -> void:
	if hero == null:
		return
	stats = hero.get_stats()
	speed = float(stats["move"])
	setup_combat(int(stats["hp"]), int(stats["def"]), int(stats["mres"]), float(stats["crit"]), float(stats["status_resist"]), hero.hero_seed)
	can_be_downed = true
	item_mods = stats.get("mods", {})
	_setup_skills()
	role = AiDefs.role_of(hero.hero_class)
	persona = AiDefs.personality(hero.traits)
	if SimMode.run_seed != 0:
		combat_rng.seed = hash([hero.hero_seed, SimMode.run_seed, slot])   # D-083: each simulated run rolls its own dice
	_think_t = combat_rng.randf() * AiDefs.DECIDE_JITTER * 3.0     # five heroes never think on the same tick
	if SimMode.on:
		art_scale = SpriteComposer.world_scale(hero)
		return                                   # D-083 headless simulator: no sprite
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SpriteComposer.build_frames(hero)
	_sprite.offset = SpriteComposer.feet_offset(hero)   # feet at the node origin (LPC 64 px / TPF 48 px)
	art_scale = SpriteComposer.world_scale(hero)
	_sprite.scale = Vector2.ONE * art_scale
	_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # pose tweens run in idle
	add_child(_sprite)
	_play("idle_down")


## Sight radius in cells for the fog of war (CombatRules.VISION_CELLS; scouts see further).
## D-090: class base (CombatRules.CLASS_VISION) + perception + items + floor modifier + Shared Sight.
func vision_cells() -> int:
	if downed:
		return CombatRules.DOWNED_VISION
	if hero == null:
		return CombatRules.VISION_CELLS + vision_mod
	var base := int(CombatRules.CLASS_VISION.get(hero.hero_class, CombatRules.VISION_CELLS))
	return base + perception() + int(item_mods.get("vision", 0)) + vision_mod + synergy_vision


## D-090: (INT + TEM) / PERCEPTION_DIV cells (+ items' "perception"), capped.
func perception() -> int:
	if hero == null:
		return 0
	var a: Dictionary = hero.attributes()
	var p := roundi(float(int(a.get("int", 0)) + int(a.get("tem", 0))) / float(CombatRules.PERCEPTION_DIV))
	return clampi(p + int(item_mods.get("perception", 0)), 0, CombatRules.PERCEPTION_MAX)


## D-090: how hard the hero is to notice (0..STEALTH_MAX): class + items + a bush.
func stealth() -> float:
	if hero == null:
		return 0.0
	var st := float(CombatRules.CLASS_STEALTH.get(hero.hero_class, 0.0)) + float(item_mods.get("stealth", 0.0))
	if in_bush:
		st += CombatRules.BUSH_STEALTH
	return clampf(st, 0.0, CombatRules.STEALTH_MAX)


## D-090: the distance at which a creature with this perception notices the hero.
func detect_range(enemy_perception: float) -> float:
	return enemy_perception * maxf(CombatRules.DETECT_MIN, 1.0 - stealth())


func credit(kind: String, amount: float) -> void:
	if amount > 0.0:
		contrib[kind] = float(contrib.get(kind, 0.0)) + amount


func is_controlled() -> bool:
	return controller == "player"


## D-051: deterministic, never a roll.
func obeys() -> bool:
	if has_status("panicked"):
		return false                             # D-081: a panicking hero hears nobody (deterministic)
	return hero == null or effective_obedience() >= CombatRules.OBEY_MIN


## D-081: Obedience after the bond tier and, inside the Master's radius, the Master's Leadership.
func effective_obedience() -> int:
	var m := squad_master()
	return MasterRules.effective_obedience(hero, m.hero if m != null else null, in_master_radius())


## The Master of this squad (D-080), or null.
func squad_master() -> SandboxHero:
	for o in squad:
		if is_instance_valid(o) and o.hero != null and o.hero.is_master:
			return o
	return null


## Inside the radius of a standing Master (commands, Leadership bonuses; the pings will use it too).
func in_master_radius() -> bool:
	var m := squad_master()
	return m != null and m != self and m.alive and position.distance_to(m.position) <= MasterRules.leadership_radius(m.hero)


## D-081 panic: runs to the Master (or the squad) and does nothing else until it passes.
func _panic_tick(map: NavMap) -> void:
	target = null
	var m := squad_master()
	var to: Vector2 = m.position if m != null and m.alive and m != self else rally_point
	if to == Vector2.INF or position.distance_to(to) < 40.0:
		path.clear()
		return
	if path.is_empty() or _repath <= 0.0:
		_repath = REPATH_EVERY
		path = map.find_path(position, to)


## Something that lands later (a projectile in flight); runs on the simulation clock, so it is
## deterministic and pauses with the mission.
func _later(seconds: float, f: Callable) -> void:
	if seconds <= 0.02:
		f.call()
		return
	_pending.append({"t": seconds, "f": f})


func _tick_pending(delta: float) -> void:
	if _pending.is_empty():
		return
	var due: Array = []
	for p in _pending:
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0.0:
			due.append(p)
	for p in due:
		_pending.erase(p)
		(p["f"] as Callable).call()


func is_moving() -> bool:
	return not path.is_empty()


func power() -> int:
	return int(stats["mag"]) if String(stats.get("kind", "physical")) == "magical" else int(stats["atk"])


# --- orders (never randomly refused, D-016) -----------------------------------------------------

func order_move(waypoints: Array[Vector2]) -> void:
	if casting != "":
		interrupt_cast("cast cancelled")
	path = waypoints.duplicate()
	if dev_fly and not path.is_empty():
		var last: Vector2 = path[path.size() - 1]   # D-146 /fly: straight line, walls ignored
		path.clear()
		path.append(last)
	auto_path = false
	target = null
	rescue_target = null
	rescue_progress = 0.0
	order = "move"


## Attack a specific enemy until it dies or another order arrives (chases it, no perception limit).
func order_attack(enemy: SandboxEnemy) -> void:
	target = enemy
	rescue_target = null
	rescue_progress = 0.0
	path.clear()
	auto_path = true
	order = "attack"
	_repath = 0.0


## Go to a downed ally and carry them back to their feet (D-036).
func order_rescue(ally: SandboxHero) -> void:
	rescue_target = ally
	rescue_progress = 0.0
	target = null
	path.clear()
	auto_path = false
	order = "rescue"
	_repath = 0.0


## Walk to a point, fighting anything met on the way, then go back to Auto.
func order_attack_move(point: Vector2, map: NavMap) -> bool:
	_clear_orders()
	order = "attack_move"
	order_point = point
	path = map.find_path(position, point)
	return not path.is_empty()


## Stay here: fight only what comes into range, never chase.
func order_hold() -> void:
	_clear_orders()
	order = "hold"
	order_point = position


## Stay close to another hero, fight near them, never wander off.
func order_follow(leader: SandboxHero) -> void:
	_clear_orders()
	order = "follow"
	follow_leader = leader


## Run to the extraction point without stopping to fight (then hold there).
func order_retreat(point: Vector2, map: NavMap) -> bool:
	_clear_orders()
	order = "retreat"
	path = map.find_path(position, point)
	return not path.is_empty()


func order_label() -> String:
	return String(ORDER_LABELS.get(order, order))


func _clear_orders() -> void:
	path.clear()
	auto_path = false
	target = null
	rescue_target = null
	rescue_progress = 0.0
	follow_leader = null
	then_retreat = Vector2.INF
	_repath = 0.0


func stop() -> void:
	_clear_orders()
	order = "auto"


# --- simulation --------------------------------------------------------------------------------

func tick(delta: float) -> void:
	_last_delta = delta
	tick_combat(delta)
	_tick_pending(delta)
	_tick_shots(delta)
	if order_left > 0.0:
		order_left -= delta
		if order_left <= 0.0:
			order_left = 0.0
			if order != "auto" and order != "rescue":
				stop()                               # D-082: a ping order ends; the hero decides again
	if not alive:
		if downed:
			queue_redraw()
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	for sid in cds:
		cds[sid] = maxf(0.0, float(cds[sid]) - delta)
	combat_t = maxf(0.0, combat_t - delta)
	if target != null and is_instance_valid(target) and target.alive:
		combat_t = SkillDefs.COMBAT_LINGER
	_still_t = _still_t + delta if path.is_empty() else 0.0
	for sid in _syn_shown:
		_syn_shown[sid] = float(_syn_shown[sid]) - delta
	if _sprite != null:
		_sprite.modulate.a = 0.55 if in_bush else 1.0   # D-090: half see-through inside a bush
	_tick_resource(delta)
	_use_consumables(delta)
	_pick_up_arrows()
	_repath = maxf(0.0, _repath - delta)
	_dodge_t = maxf(0.0, _dodge_t - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	if dash_t > 0.0:
		_dash_step(delta)
	_kite_cd = maxf(0.0, _kite_cd - delta)
	_fallback_cd = maxf(0.0, _fallback_cd - delta)
	if chatter_timer > 0.0:
		chatter_timer = maxf(0.0, chatter_timer - delta)
	if _fx > 0.0:
		_fx = maxf(0.0, _fx - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if casting != "":
		_tick_cast(delta)
		return
	if _draw_t >= 0.0:
		_draw_t -= delta
		if not can_act():
			_draw_t = -1.0                           # a stun breaks the draw
		elif _draw_t < 0.0:
			_release_shot()
		return                                       # standing still while the bow is drawn
	_walk(delta)


## Follows the path. The leftover of a step carries on to the next waypoint (no speed dip at every
## corner); speed ramps up in ACCEL_TIME and eases in on the last few pixels.
func _walk(delta: float) -> void:
	var before := position
	if path.is_empty() or not can_move():
		_cur_speed = 0.0
		velocity = Vector2.ZERO
		_idle_t += delta
		if _idle_t >= IDLE_GRACE or not can_move():
			_set_walk_rate(1.0)
			_play("idle_" + facing)
		return
	_idle_t = 0.0
	var top := speed * move_mult()
	_cur_speed = move_toward(_cur_speed, top, top / ACCEL_TIME * delta)
	var budget := _cur_speed * delta
	while budget > 0.0 and not path.is_empty():
		var next_wp: Vector2 = path[0]
		var to := next_wp - position
		var dist := to.length()
		if path.size() == 1 and dist < ARRIVE_EASE:
			budget = minf(budget, maxf(top * 0.35 * delta, dist * 0.5))
		if dist <= budget + ARRIVE_EPS:
			position = next_wp
			path.remove_at(0)
			budget -= dist
		else:
			var dir := to / dist
			position += dir * budget
			_face(dir)
			budget = 0.0
	velocity = (position - before) / maxf(0.0001, delta)
	_set_walk_rate(velocity.length() / WALK_ANIM_SPEED)
	_play("walk_" + facing)


func _set_walk_rate(k: float) -> void:
	if _sprite != null and _anim_lock <= 0.0:
		_sprite.speed_scale = clampf(k, 0.6, 1.4)


func is_ranged() -> bool:
	return _class_ranged() and not (arrows == 0 and uses_bow())   # D-090: no arrows left = fights up close


func _class_ranged() -> bool:
	return String(HeroTables.CLASSES[hero.hero_class]["reach"]) == "ranged"


func attack_range() -> float:
	if uses_bow() and arrows != 0:                   # D-082: longer, never beyond what the hero sees (D-090: with arrows)
		return minf(AiDefs.BOW_RANGE, float(vision_cells() * NavMap.CELL) * 0.9)
	return CombatRules.HERO_RANGED_RANGE if is_ranged() else CombatRules.HERO_MELEE_RANGE


func uses_bow() -> bool:
	return _class_ranged() and String(CombatVFX.WEAPON_FX.get(weapon_id(), {}).get("proj", "")) == "arrow"


func is_drawing() -> bool:
	return _draw_t >= 0.0


func attack_interval() -> float:
	return float(stats.get("interval", CombatRules.hero_interval(int(stats.get("spd", 5)))))


## Autonomy + order execution for one step, in layers (D-082, AiDefs.LAYERS):
##   1 survival: panic (D-081), dodging telegraphed blows, potions (_use_consumables), falling back hurt;
##   2 orders: pings and Commands (the order state; explicit orders always come first, D-016);
##   3 role: the class's job (tank peels for the weak, DPS focus, the healer stays back, the scout leads,
##     support helps and avoids the front), lifting fallen allies, using skills (D-065);
##   4 personality: nudges on top (reckless ahead, cautious behind, loyal close to the Master).
## Decisions (targets, skills, positions) are taken every AiDefs.decide_interval(Composure) seconds; in
## between the hero keeps doing what it decided (walking, swinging, drawing the bow).
func combat_tick(enemies: Array, map: NavMap) -> void:
	_map = map
	_last_foes = enemies
	if not alive or casting != "" or _draw_t >= 0.0:
		return
	if dash_t > 0.0:
		return                                   # mid-dash: nothing else moves the hero
	if _dodge_t > 0.0 and not path.is_empty():
		return                                   # finishing a dodge step
	var think := false
	if not is_controlled():
		_think_t -= _last_delta
		if _think_t <= 0.0:
			think = true
			decisions += 1
			_think_t = AiDefs.decide_interval(hero.composure if hero != null else 100) + combat_rng.randf() * AiDefs.DECIDE_JITTER
	if has_status("panicked"):
		ai_layer = "survival"
		_panic_tick(map)
		return
	if order != "move" and order != "retreat" and order != "rescue" and can_move() and not is_controlled():
		if _try_dodge(enemies, map):
			ai_layer = "survival"
			return
	match order:
		"rescue":
			ai_layer = "orders" if order_left > 0.0 else "role"
			_rescue_tick(map)
			return
		"move":
			if not path.is_empty():
				ai_layer = "orders"
				return                               # obeying a direct move
			order = "auto"
		"retreat":
			if path.is_empty():
				order_hold()
			ai_layer = "orders"
			return                                   # no fighting while retreating
		"follow":
			if follow_leader == null or not is_instance_valid(follow_leader) or not follow_leader.alive:
				order = "auto"
			elif position.distance_to(follow_leader.position) > FOLLOW_DISTANCE and (path.is_empty() or _repath <= 0.0) and target == null:
				_repath = REPATH_EVERY
				path = map.find_path(position, follow_leader.position)
	if not can_act():
		return
	if carrying:
		target = null                            # D-065: both hands on the relic; the others must protect them
		return
	if auto_skills and not is_controlled() and order != "move" and order != "retreat" and think:
		if _auto_skill(enemies):
			ai_layer = "role"
			return
	if _maybe_fall_back(map):
		ai_layer = "survival"
		return
	if is_controlled():
		target = null                            # D-059: the player attacks with Q, aimed at the cursor
		return
	if think and order == "auto" and _try_revive(enemies, map):
		ai_layer = "role"
		return
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null
		if order == "attack":
			order = "auto"
			FloatingText.spawn(self, "target down", Color(0.8, 0.8, 0.8), false)
	if order == "auto" and think and target != null:
		var better := _pick_target(enemies, chase_radius())   # role re-evaluation (tank peels, DPS focus)
		if better != null and better != target and _target_score(better) + 25.0 < _target_score(target):
			target = better
	if target == null:
		if not think and order != "attack_move" and order != "defend":
			return                                   # nothing decided yet: keeps walking where it was going
		var radius := attack_range() if order == "hold" else chase_radius()
		if order == "defend":
			radius = AiDefs.DEFEND_RADIUS
		target = _pick_target(enemies, radius, defend_point if order == "defend" else Vector2.INF)
		if target == null:
			ai_layer = "orders" if order != "auto" else "role"
			match order:
				"attack_move":
					if path.is_empty():
						if position.distance_to(order_point) < 30.0:
							order = "auto"
						else:
							path = map.find_path(position, order_point)
				"defend":
					if position.distance_to(defend_point) > 40.0 and (path.is_empty() or _repath <= 0.0):
						_repath = REPATH_EVERY
						path = map.find_path(position, defend_point)
				"follow", "hold":
					pass
				_:
					var quiver := arrow_corpse(AiDefs.ARROW_SEEK) if arrows >= 0 and arrows < AiDefs.ARROWS_START else null
					if quiver != null and order == "auto" and think:
						path = map.find_path(position, quiver.position)   # D-090: goes to pick its arrows up
						auto_path = true
						return
					if auto_path:
						path.clear()
						auto_path = false
					_stay_near_anchor(map)
			return
	ai_layer = "orders" if order != "auto" else "role"
	var d := position.distance_to(target.position)
	var sees := not is_ranged() or map.has_line_of_sight(position + Vector2(0, -12), target.position + Vector2(0, -12))
	if d <= attack_range() and sees:
		if is_ranged() and d < keep_distance() and order != "hold" and order != "defend" and _kite(target, map):
			return
		if role == "healer" and order == "auto" and d < AiDefs.HEALER_SAFE and _kite(target, map):
			return                                   # the healer keeps out of the melee
		path.clear()
		auto_path = false
		_face(target.position - position)
		if _cooldown <= 0.0:
			_cooldown = attack_interval()
			_basic_attack(target)
		elif _cooldown <= ATTACK_LEAD and not _prerolled and not is_ranged():
			_prerolled = true                    # anticipation: the swing starts, the blow lands on time
			_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, is_ranged(), true)
		return
	if order == "hold":
		target = null                            # out of reach: holding does not chase
		return
	if order == "defend" and target.position.distance_to(defend_point) > AiDefs.DEFEND_RADIUS * 1.3:
		target = null                            # defending: does not chase out of the area
		return
	if order == "follow" and follow_leader != null and target.position.distance_to(follow_leader.position) > FOLLOW_LEASH:
		target = null
		return
	if _repath <= 0.0 or path.is_empty():
		_repath = REPATH_EVERY
		var p := map.find_path(position, target.position)
		if not p.is_empty():
			path = p
			auto_path = true


## Distance a ranged hero keeps from the foe it shoots (the scout keeps more).
func keep_distance() -> float:
	return AiDefs.SCOUT_KEEP if role == "scout" else KITE_DISTANCE


## Layer 3 target choice. Lower score = better: distance, minus what the role wants. Imperfection: now and
## then (AiDefs.WRONG_TARGET_CHANCE, seeded) it takes any foe in reach instead of the best one.
## around = only foes within `radius` of this point (defend ping); INF = around the hero.
func _pick_target(enemies: Array, radius: float, around: Vector2 = Vector2.INF) -> SandboxEnemy:
	var pool: Array = []
	var centre := position if around == Vector2.INF else around
	for e in enemies:
		if is_instance_valid(e) and e.alive and centre.distance_to(e.position) < radius:
			pool.append(e)
	if pool.is_empty():
		return null
	if pool.size() > 1 and combat_rng.randf() < AiDefs.WRONG_TARGET_CHANCE:
		return pool[combat_rng.randi() % pool.size()]
	var best: SandboxEnemy = null
	var best_s := INF
	for e in pool:
		var sc := _target_score(e)
		if sc < best_s:
			best_s = sc
			best = e
	return best


func _target_score(e: SandboxEnemy) -> float:
	var sc := position.distance_to(e.position)
	if focus_hint != null and e == focus_hint:
		sc -= 140.0 if role == "dps" or role == "scout" else 70.0
	match role:
		"tank":
			# peel: the foe going for the weakest ally near the tank is worth the most
			if e.focus != null and is_instance_valid(e.focus) and e.focus != self and e.focus.alive \
					and position.distance_to(e.focus.position) <= AiDefs.PROTECT_RADIUS:
				sc -= 80.0 + 80.0 * (1.0 - float(e.focus.hp) / float(maxi(1, e.focus.max_hp)))
		"dps":
			sc -= 60.0 * (1.0 - float(e.hp) / float(maxi(1, e.max_hp)))   # finish the hurt one
			for a in squad:                          # stick to what the others already hit
				if is_instance_valid(a) and a != self and a.alive and a.target == e:
					sc -= 25.0
		"support":
			for a in squad:
				if is_instance_valid(a) and a != self and a.alive and a.target == e:
					sc -= 35.0
	return sc


## Layer 3: an autonomous hero lifts a fallen ally on its own when its score (role + bond with the fallen
## + personality, AiDefs.REVIVE_*) is high enough and no foe stands over the fallen. One helper per ally.
func _try_revive(enemies: Array, _map_ref: NavMap) -> bool:
	if hero == null or has_status("panicked"):
		return false
	var best: SandboxHero = null
	var best_s := -INF
	for d in squad:
		if not is_instance_valid(d) or d == self or not d.downed or d.dead or d.lost:
			continue
		if position.distance_to(d.position) > AiDefs.REVIVE_RADIUS:
			continue
		var taken := false
		for x in squad:
			if is_instance_valid(x) and x != self and x.rescue_target == d:
				taken = true
		if taken:
			continue
		var unsafe := false
		for e in enemies:
			if e.alive and e.position.distance_to(d.position) < AiDefs.REVIVE_SAFE:
				unsafe = true
				break
		if unsafe:
			continue
		var s := revive_score(d) - position.distance_to(d.position) / AiDefs.REVIVE_RADIUS * 0.5   # closer first
		if s >= AiDefs.REVIVE_MIN_SCORE and s > best_s:
			best_s = s
			best = d
	if best == null:
		return false
	order_rescue(best)
	say("Hang on!", 2.0)
	return true


## How much this hero wants to lift `d` (role, relationship level with them, traits; the Master always).
func revive_score(d: SandboxHero) -> float:
	var s := float(AiDefs.REVIVE_ROLE_SCORE.get(role, 0.6))
	if d.hero != null and hero.relationships.has(d.hero.id):
		if int((hero.relationships[d.hero.id] as Dictionary).get("level", 0)) >= AiDefs.REVIVE_BOND_LEVEL:
			s += AiDefs.REVIVE_BOND_SCORE
	if d.hero != null and d.hero.is_master:
		s += 1.0
	for t in hero.traits:
		s += float(AiDefs.REVIVE_TRAIT_SCORE.get(t, 0.0))
	return s


## D-059: the driven hero's basic attack, aimed at a world point (Q). Same weapon, reach, interval,
## damage and projectile as the autonomous attack; only the aim is the player's.
## Ranged (D-082): a real shot (ArrowShot) flies toward the cursor up to its reach and hits the FIRST
## visible foe it touches (trees stop it); a bow is drawn AiDefs.BOW_DRAW s first. Melee: a swing in a cone toward the cursor hits the closest foe in reach; it can miss.
## Returns false only when the attack is not ready (interval, stun, casting, down).
const AIM_CONE := 0.9             # radians either side of the aim for a melee swing


func aimed_attack(point: Vector2, enemies: Array, map: NavMap) -> bool:
	if not alive or not can_act() or casting != "" or _cooldown > 0.0 or _draw_t >= 0.0:
		return false
	var dir := point - position
	if dir.length() < 1.0:
		dir = HeroAnim.dir_vec(facing)
	dir = dir.normalized()
	_face(dir)
	_cooldown = attack_interval()
	_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, is_ranged())
	var reach := attack_range()
	var wf: Dictionary = CombatVFX.WEAPON_FX.get(weapon_id(), CombatVFX.WEAPON_FX["fist"])
	var hit: SandboxEnemy = null
	_map = map
	_last_foes = enemies
	if is_ranged():
		# D-082: a real shot toward the cursor (no aim error: the player aims). A bow is drawn first.
		basic_attacks += 1
		_draw_target = null
		_draw_point = position + dir * reach
		if uses_bow():
			_draw_t = AiDefs.BOW_DRAW
		else:
			_release_shot()
		return true
	basic_attacks += 1
	var best_d := INF
	for e in enemies:
		if not e.alive or not e.visible:
			continue
		var v: Vector2 = e.position - position
		if v.length() > reach + e.body_radius:
			continue
		if v.length() > 1.0 and absf(dir.angle_to(v)) > AIM_CONE:
			continue
		if v.length() < best_d:
			best_d = v.length()
			hit = e
	var swing_at := (hit.position + Vector2(0, -12)) if hit != null else position + dir * reach * 0.6 + Vector2(0, -12)
	CombatVFX.play(get_parent(), swing_at, String(wf["hit"]), float(wf.get("scale", 1.0)), dir.x < 0.0)
	if hit != null:
		if wf.has("extra"):
			CombatVFX.play(get_parent(), hit.position, String(wf["extra"]), 0.8)
		_melee_blows(hit, swing_at)
	return true


func attack_ready() -> bool:
	return alive and can_act() and casting == "" and _cooldown <= 0.0 and _draw_t < 0.0


## Autonomous reaction to a telegraphed strike (D-052): one roll per strike against a small chance
## from AGI and level (zero at level 1). On a failed roll the hero keeps doing what it was doing and
## takes the blow. Never overrides an explicit move/retreat/rescue order, never for a player-driven hero.
func _try_dodge(enemies: Array, map: NavMap) -> bool:
	for e in enemies:
		if not e.alive or not e.is_telegraphing() or e.windup_left() < CombatRules.DODGE_REACTION:
			continue
		var aim: Vector2 = e.aim_point()
		var r: float = e.telegraph_radius()
		if not e.in_telegraph(position):           # D-145: circle, cone or line
			continue
		var key: int = e.get_instance_id()
		if int(_dodge_seen.get(key, -1)) == int(e.strike_seq):
			continue                             # already decided for this strike
		_dodge_seen[key] = e.strike_seq
		var lvl := hero.level if hero != null else 1
		var away := position - aim
		if away.length() < 1.0:
			away = Vector2.RIGHT.rotated(float(slot))
		if dash_cd <= 0.0 and combat_rng.randf() < CombatRules.ai_dash_chance(int(stats.get("spd", 5)), lvl):
			var dir := away.normalized()
			if combat_rng.randf() < CombatRules.AI_DASH_WRONG:
				dir = dir.orthogonal() * (1.0 if combat_rng.randf() < 0.5 else -1.0)   # a poor read: sideways
			if dash(dir):
				return true
		if combat_rng.randf() >= CombatRules.auto_dodge_chance(int(stats.get("spd", 5)), lvl):
			continue                             # did not react in time
		var spot := aim + away.normalized() * (r + 22.0)
		if not map.can_step(position, spot):
			spot = aim - away.normalized().orthogonal() * (r + 22.0)
		if not map.can_step(position, spot):
			return false
		path.clear()
		path.append(spot)
		auto_path = true
		_dodge_t = 0.6
		return true
	return false


## Dash (CombatRules.DASH_*): a short burst with invulnerability frames. Returns false when it cannot
## (cooldown, stunned, rooted, casting, carrying the relic, down). The look: the hero leans and stretches
## along the dash, leaves fading after-images of its own current frame and a puff of dust, and squashes
## a little on landing (no roll frames needed: the Tiny Pixel Fantasy sheets have none).
## Farthest point of a dash along dir before a wall stops it.
func _dash_reach(dir: Vector2) -> Vector2:
	var end := position
	var step := CombatRules.DASH_DIST / 6.0
	for i in 6:
		var nxt := end + dir * step
		if _map != null and not _map.can_step(end, nxt):
			break
		end = nxt
	return end


func dash(dir: Vector2) -> bool:
	if dash_cd > 0.0 or dash_t > 0.0 or downed or not alive or not can_move() or casting != "" or carrying or dir.length() < 0.01:
		return false
	dir = dir.normalized()
	var end := position
	for d in [dir, dir.rotated(0.8), dir.rotated(-0.8)]:   # blocked straight ahead: slide along the wall
		end = _dash_reach(d)
		if end.distance_to(position) >= 8.0:
			dir = d
			break
	if end.distance_to(position) < 8.0:
		return false
	_dash_end = end
	dash_t = CombatRules.DASH_TIME
	dash_cd = CombatRules.DASH_CD
	iframe_t = CombatRules.DASH_IFRAMES
	dashes += 1
	path.clear()
	_ghost_t = 0.0
	if _sprite != null:
		var tw := create_tween()
		_sprite.scale = Vector2(1.25, 0.82) * art_scale           # stretch along the burst
		_sprite.rotation = dir.x * 0.18                           # lean into it
		tw.tween_property(_sprite, "scale", Vector2(0.9, 1.1) * art_scale, CombatRules.DASH_TIME)   # squash on landing
		tw.tween_property(_sprite, "scale", Vector2.ONE * art_scale, 0.12)
		tw.parallel().tween_property(_sprite, "rotation", 0.0, 0.12)
	var parent := get_parent()
	if parent != null and is_inside_tree():
		CombatVFX.play(parent, position, "dust", 0.8)
	return true


func _dash_step(delta: float) -> void:
	var speed := CombatRules.DASH_DIST / CombatRules.DASH_TIME
	position = position.move_toward(_dash_end, speed * delta)
	dash_t = maxf(0.0, dash_t - delta)
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = CombatRules.DASH_TIME / 4.0
		_after_image()
	if dash_t <= 0.0:
		position = _dash_end


## One fading copy of the hero's current frame (the dash trail).
func _after_image() -> void:
	if _sprite == null or _sprite.sprite_frames == null or not is_inside_tree() or get_parent() == null:
		return
	var g := Sprite2D.new()
	g.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	g.centered = _sprite.centered
	g.offset = _sprite.offset
	g.flip_h = _sprite.flip_h
	g.scale = _sprite.scale
	g.position = position + _sprite.position
	g.modulate = Color(0.65, 0.85, 1.0, 0.55)
	g.z_index = z_index - 1
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)


## Hurt and in a fight, an autonomous hero breaks off toward the driven hero or the squad centre
## (cautious ones sooner, reckless ones later). Never overrides an order, never for a driven hero.
func _maybe_fall_back(map: NavMap) -> bool:
	if is_controlled() or order != "auto" or target == null or _fallback_cd > 0.0:
		return false
	if float(hp) > float(max_hp) * fallback_hp():
		return false
	var to := anchor.position if anchor != null and is_instance_valid(anchor) and anchor.alive else rally_point
	if to == Vector2.INF or to.distance_to(position) < 60.0:
		return false
	_fallback_cd = 4.0
	var p := map.find_path(position, to)
	if p.is_empty():
		return false
	path = p
	auto_path = true
	target = null
	_dodge_t = 0.8                                  # commit to the step back for a moment
	FloatingText.spawn(self, "falling back", Color(0.85, 0.85, 1.0), false)
	return true


## With nothing to fight, an autonomous hero does not stand still while the player walks another
## hero away: it moves back within ANCHOR_LEASH of it (cautious heroes keep closer, see leash()).
func _stay_near_anchor(map: NavMap) -> void:
	if is_controlled() or order != "auto":
		return
	if explore_goal != Vector2.INF and path.is_empty() and float(hp) > float(max_hp) * 0.6:
		var p := map.find_path(position, explore_goal)   # an idle explorer peeks into the fog nearby
		explore_goal = Vector2.INF
		if not p.is_empty():
			path = p
			auto_path = true
			return
	if anchor == null or not is_instance_valid(anchor) or not anchor.alive:
		return
	# D-082 layers 3-4: where the role wants to stand around the Master, nudged by personality.
	var spot := role_spot()
	var slack := 40.0 if bool(persona.get("follows_master", false)) else leash() * 0.5
	if position.distance_to(spot) > slack and (path.is_empty() or _repath <= 0.0):
		_repath = REPATH_EVERY * 2.0
		var p := map.find_path(position, map.nearest_walkable(spot))
		if not p.is_empty():
			path = p
			auto_path = true


## Where this hero wants to stand when nothing is happening (D-082, roles + personality): the scout ahead
## of the Master (the way they walk), the healer and support behind, the tank in front, loyal ones close.
func role_spot() -> Vector2:
	if anchor == null or not is_instance_valid(anchor):
		return position
	var fwd := anchor.velocity.normalized() if anchor.velocity.length() > 5.0 else HeroAnim.dir_vec(anchor.facing)
	var ahead := float(persona.get("ahead", 0.0))
	match role:
		"scout":
			ahead += AiDefs.SCOUT_AHEAD
		"tank":
			ahead += 30.0
		"healer":
			ahead -= AiDefs.HEALER_BACK * 0.6
		"support":
			ahead -= AiDefs.SUPPORT_BACK * 0.6
	var side := fwd.orthogonal() * (40.0 if slot % 2 == 0 else -40.0)
	if bool(persona.get("follows_master", false)):
		side *= 0.6
	return anchor.position + fwd * ahead + side


## Temperament from traits (HeroTables.AGGRESSION), -3 (very cautious) .. 3 (reckless).
func aggression() -> int:
	if hero == null:
		return 0
	var a := 0
	for t in hero.traits:
		a += int(HeroTables.AGGRESSION.get(t, 0))
	return clampi(a, -3, 3)


func is_explorer() -> bool:
	if hero == null:
		return false
	if CombatRules.SCOUT_CLASSES.has(hero.hero_class):
		return true
	for t in hero.traits:
		if HeroTables.EXPLORER_TRAITS.has(t):
			return true
	return false


## How far from the driven hero this hero is willing to be (cautious closer, reckless further).
func leash() -> float:
	return clampf(HeroTables.LEASH_BASE + HeroTables.LEASH_PER_AGGRESSION * float(aggression()), 90.0, 330.0)


## How far an autonomous hero goes looking for a fight.
func chase_radius() -> float:
	return CombatRules.HERO_PERCEPTION + HeroTables.CHASE_PER_AGGRESSION * float(aggression())


func fallback_hp() -> float:
	return clampf(HeroTables.FALLBACK_HP - HeroTables.FALLBACK_PER_AGGRESSION * float(aggression()), 0.1, 0.6)


## Ranged heroes back off when a foe gets too close (keep their role distance). Not while that foe
## is already winding up a blow (stepping away then would be a free dodge, D-052), and not too often.
func _kite(foe: SandboxEnemy, map: NavMap) -> bool:
	if foe.is_telegraphing() or _kite_cd > 0.0:
		return false
	var spot := position + (position - foe.position).normalized() * 80.0
	if map.is_blocked(spot) or not map.has_line_of_sight(position, spot):
		return false
	_kite_cd = CombatRules.KITE_COOLDOWN
	path.clear()
	path.append(spot)
	auto_path = true
	_dodge_t = 0.4
	return true


## Carried potions and antidotes are used on their own (bounded autonomy, never instead of an order).
const ELIXIR_DUR := 60.0


func _use_consumables(delta: float) -> void:
	if has_status("poison"):
		was_poisoned = true
	if hero == null:
		return
	heal_potion_cd = maxf(0.0, heal_potion_cd - delta)
	_potion_cd = maxf(0.0, _potion_cd - delta)
	if _potion_cd > 0.0:
		return
	# D-077 elixirs: drunk when the hero first fights (target in sight), last ELIXIR_DUR seconds
	if target != null:
		for ex in [["elixir_strength", "empowered"], ["elixir_speed", "hasted"], ["elixir_defense", "fortified"]]:
			if int(hero.bag.get(ex[0], 0)) > 0 and not has_status(String(ex[1])):
				_spend(String(ex[0]))
				apply_status(String(ex[1]), ELIXIR_DUR, 0.0, self)
				FloatingText.spawn(self, String(ex[0]).replace("_", " "), Color(0.9, 0.8, 1.0), false)
				_potion_cd = 0.5
				return
	var auto_heal := not hero.is_master or SimMode.on       # the Master drinks on the player's key (D)
	if auto_heal and float(hp) < float(max_hp) * LootDefs.HEAL_POTION_AT and drink_potion() == "":
		return
	if has_status("poison") and int(hero.bag.get("antidote", 0)) > 0:
		_spend("antidote")
		statuses.erase("poison")
		CombatVFX.play(get_parent(), position + Vector2(0, -18), "sparkle_small", 1.0)
		FloatingText.spawn(self, "antidote", Color(0.6, 1.0, 0.5), false)


## Drinks the best healing potion in the bag. "" when drunk, otherwise why not (no potion, cooldown).
func drink_potion() -> String:
	if hero == null or not alive:
		return "cannot drink now"
	var id := "con_potion_major" if int(hero.bag.get("con_potion_major", 0)) > 0 else ("potion" if int(hero.bag.get("potion", 0)) > 0 else "")
	if id == "":
		return "no healing potions (alchemy brews them)"
	if heal_potion_cd > 0.0:
		return "potion ready in %ds" % ceili(heal_potion_cd)
	if hp >= max_hp:
		return "already at full health"
	_spend(id)
	heal_potion_cd = LootDefs.HEAL_POTION_CD
	heal(roundi(float(max_hp) * (LootDefs.HEAL_POTION_MAJOR if id == "con_potion_major" else LootDefs.HEAL_POTION)))
	CombatVFX.play(get_parent(), position + Vector2(0, -14), "heal", 1.0)
	FloatingText.spawn(self, "greater potion" if id == "con_potion_major" else "potion", Color(0.5, 1.0, 0.6), false)
	return ""


func _spend(res: String) -> void:
	hero.bag[res] = int(hero.bag[res]) - 1
	if int(hero.bag[res]) <= 0:
		hero.bag.erase(res)
	_potion_cd = POTION_CD


func move_mult() -> float:
	var m := super.move_mult()
	if carrying:
		m *= CARRY_MOVE
	if item_mods.has("slow_immune") and has_status("slow"):
		m /= float(CombatRules.STATUS["slow"]["move"])
	return m


## Damage bonus from equipment against a foe busy fighting someone else (Nightstalker set).
func _busy_mult(t: Node) -> float:
	if item_mods.has("busy_bonus") and t.get("focus") != null and t.get("focus") != self:
		return 1.0 + float(item_mods["busy_bonus"])
	return 1.0


## Weapon the hero swings: the equipped main-hand base, else the class's default (look only).
func weapon_id() -> String:
	if hero != null and hero.equipment.has("main_hand"):
		var it: Dictionary = hero.equipment["main_hand"]
		return String(it.get("visual_base", it.get("base", "fist")))   # D-082b: the kit's weapons look like their base
	if hero != null and not hero.equipment.is_empty():
		return "fist"                                # carries items but no weapon: bare hands (what is seen)
	return String(CombatVFX.CLASS_WEAPON.get(hero.hero_class if hero != null else "", "fist"))


## D-082b: the weapon pattern (AiDefs.WEAPON_PATTERN) needs both hands for two daggers: with items, the
## off hand must hold a dagger too; a hero without items fights with its class default (a rogue: two).
func weapon_pattern() -> Dictionary:
	var pat: Dictionary = AiDefs.WEAPON_PATTERN.get(weapon_id(), {})
	if pat.is_empty() or hero == null or hero.equipment.is_empty():
		return pat
	var off: Dictionary = hero.equipment.get("off_hand", {})
	return pat if String(off.get("visual_base", off.get("base", ""))) == "dagger" else {}


## D-082b shield (warriors): a small chance to block a FRONTAL blow (within the shield's arc of where the
## hero faces); a blocked blow loses a fixed share. Numbers in ItemDefs.BASES[...]["block"].
func take_hit(info: DamageInfo) -> int:
	var blk: Dictionary = item_mods.get("block", {})
	if not blk.is_empty() and alive and info != null and info.source != null and is_instance_valid(info.source) and info.source is Node2D:
		if is_frontal((info.source as Node2D).position, float(blk.get("arc_deg", 120.0))) and combat_rng.randf() < float(blk["chance"]):
			info.amount *= 1.0 - float(blk["reduce"])
			blocks += 1
			FloatingText.spawn(self, tr("Blocked"), Color(0.7, 0.7, 0.72), false, 0.9)
	return super.take_hit(info)


## True when `from` is in front of the hero (within arc_deg around where it faces).
func is_frontal(from: Vector2, arc_deg: float) -> bool:
	var to := from - position
	if to.length() < 0.5:
		return true
	return HeroAnim.dir_vec(facing).dot(to.normalized()) >= cos(deg_to_rad(arc_deg) * 0.5)


func _basic_attack(t: SandboxEnemy) -> void:
	basic_attacks += 1
	var wf: Dictionary = CombatVFX.WEAPON_FX.get(weapon_id(), CombatVFX.WEAPON_FX["fist"])
	if is_ranged():
		# D-082: a real shot. A bow is drawn AiDefs.BOW_DRAW s first (the pose shows it); the arrow leaves
		# toward where the target is at the release, with the shooter's aim error, and can miss.
		_prerolled = false
		_draw_target = t
		_draw_point = Vector2.INF
		if uses_bow():
			_draw_t = AiDefs.BOW_DRAW
			_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, true, true)
		else:
			_release_shot()
		return
	if not _prerolled:
		_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, false)
	_prerolled = false
	var aim := t.position + Vector2(0, -12)
	CombatVFX.play(get_parent(), aim, String(wf["hit"]), float(wf.get("scale", 1.0)), t.position.x < position.x)
	if wf.has("extra"):
		CombatVFX.play(get_parent(), t.position, String(wf["extra"]), 0.8)
	_melee_blows(t, aim)


## D-082 weapon pattern (AiDefs.WEAPON_PATTERN): one blow, or several (two daggers: left, then right
## `gap` s later), each `mult` of the hero's power. On-hit effects and flat armour apply to every blow.
func _melee_blows(t: SandboxEnemy, aim: Vector2) -> void:
	var pat := weapon_pattern()
	var hits := int(pat.get("hits", 1))
	var mult := float(pat.get("mult", 1.0))
	for k in hits:
		if k == 0:
			if arrows == 0 and uses_bow():
				mult *= AiDefs.NO_ARROW_MULT              # D-090: an archer with an empty quiver punches
			_land_basic(t, DamageInfo.make(float(power()) * mult * _busy_mult(t), String(stats.get("kind", "physical")), self, crit_chance, combat_rng), aim)
			continue
		_later(float(pat["gap"]) * float(k), func():
			if not alive or not is_instance_valid(t) or not t.alive or position.distance_to(t.position) > attack_range() + t.body_radius + 10.0:
				return                               # the second dagger finds nothing within reach
			_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, false, false, true)   # the other hand
			var wf2: Dictionary = CombatVFX.WEAPON_FX.get(weapon_id(), CombatVFX.WEAPON_FX["fist"])
			CombatVFX.play(get_parent(), t.position + Vector2(0, -12), String(wf2["hit"]), float(wf2.get("scale", 1.0)), _side == "left")
			var info2 := DamageInfo.make(float(power()) * mult * _busy_mult(t), String(stats.get("kind", "physical")), self, crit_chance, combat_rng)
			info2.set_meta("extra_blow", true)
			_land_basic(t, info2, t.position + Vector2(0, -12)))


## Releases the drawn shot (D-082): toward the target's position now (autonomy, with aim error by AGI,
## Composure and panic) or toward the point the player aimed at. The arrow is simulated in _tick_shots.
func _release_shot() -> void:
	_draw_t = -1.0
	var to := _draw_point
	var autonomous := _draw_target != null
	if autonomous:
		if not is_instance_valid(_draw_target) or not _draw_target.alive:
			_draw_target = null
			return                                   # nothing to loose at
		to = _draw_target.position
	_draw_target = null
	if to == Vector2.INF:
		return
	var dir := to - position
	if dir.length() < 1.0:
		dir = HeroAnim.dir_vec(facing)
	dir = dir.normalized()
	if autonomous:
		var err := deg_to_rad(AiDefs.aim_error_deg(int(stats.get("spd", 5)), hero.composure if hero != null else 100, has_status("panicked")))
		dir = dir.rotated(combat_rng.randf_range(-err, err))
	_face(dir)
	if not uses_bow():
		_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, true)
	var wf: Dictionary = CombatVFX.WEAPON_FX.get(weapon_id(), CombatVFX.WEAPON_FX["fist"])
	if arrows > 0:
		arrows -= 1                                  # D-090: a finite quiver
	var shot := ArrowShot.make(position, dir, attack_range() + 30.0, String(wf.get("proj", "arrow")))
	shot.set_meta("info", DamageInfo.make(float(power()), String(stats.get("kind", "physical")), self, crit_chance, combat_rng))
	var parent := get_parent()
	if parent != null:
		parent.add_child(shot)
	_shots.append(shot)
	shots_fired += 1


## Moves every shot in flight one tick; a shot that touches a foe lands its blow there (D-054 on arrival).
func _tick_shots(delta: float) -> void:
	if _shots.is_empty():
		return
	var still: Array = []
	for s in _shots:
		if not is_instance_valid(s):
			continue
		var was_done: bool = s.done
		var hit: Node2D = s.step(delta, _last_foes, _map)
		if hit != null:
			shots_hit += 1
			var info: DamageInfo = s.get_meta("info")
			info.amount *= _busy_mult(hit)
			_land_basic(hit as SandboxEnemy, info, hit.position + Vector2(0, -12))
			if arrows >= 0 and hit.get("arrows_in") != null:
				hit.set("arrows_in", int(hit.get("arrows_in")) + 1)   # D-090: recoverable from the body
				if not _arrow_corpses.has(hit):
					_arrow_corpses.append(hit)
			var wf: Dictionary = CombatVFX.WEAPON_FX.get(weapon_id(), CombatVFX.WEAPON_FX["fist"])
			CombatVFX.play(get_parent(), hit.position + Vector2(0, -12), String(wf["hit"]), float(wf.get("scale", 1.0)))
		if s.done and not s.is_inside_tree():
			if was_done or s.stuck_t <= 0.0:
				s.free()                             # never added to a tree (headless unit tests)
				continue
		if is_instance_valid(s) and (not s.done or s.stuck_t > 0.0):
			still.append(s)
	_shots = still


func _land_basic(t: SandboxEnemy, info: DamageInfo, aim: Vector2) -> void:
	if not is_instance_valid(t) or not t.alive:
		return                                   # the target died while the shot was in flight
	blows += 1
	combat_t = SkillDefs.COMBAT_LINGER
	synergy_before_hit(t, info)
	var dealt := t.take_hit(info)
	if res_kind == "energy" and not info.has_meta("extra_blow"):
		combo = mini(SkillDefs.COMBO_MAX, combo + SkillDefs.COMBO_PER_BASIC)
	if info.crit:
		CombatVFX.play(get_parent(), aim + Vector2(0, -8), "crit", 0.8)
		CombatFeel.freeze(_sprite, "crit")
		CombatFeel.freeze(t.get("_sprite"), "crit")
		CombatFeel.shake(self, "small", t.position - position)
	gain_resource(float(SkillDefs.RESOURCES[res_kind]["on_hit"]))
	_on_dealt(t, dealt)


## Equipment powers after a hit: lifesteal, on-hit statuses (uniques), heal on kill.
func _on_dealt(t: Combatant, dealt: int) -> void:
	if dealt > 0 and item_mods.has("lifesteal"):
		heal(roundi(float(dealt) * float(item_mods["lifesteal"])))
	for p in item_mods.get("procs", []):
		if t.alive and combat_rng.randf() < float(p["chance"]):
			t.apply_status(String(p["on_hit_status"]), float(p["dur"]), float(power()) * float(p["mult"]), self)
			CombatVFX.play(t.get_parent(), t.position + Vector2(0, -14), "spark_fire" if String(p["on_hit_status"]) == "burn" else "frost_burst", 0.6)
	if dealt > 0:
		_trinket_on_deal(t, dealt)
	if not t.alive and item_mods.has("kill_heal"):
		heal(roundi(float(max_hp) * float(item_mods["kill_heal"])))
		CombatVFX.play(get_parent(), position + Vector2(0, -14), "heal", 0.7)


func _rescue_tick(map: NavMap) -> void:
	if rescue_target == null or not is_instance_valid(rescue_target) or not rescue_target.downed:
		_after_rescue(map)
		return
	if position.distance_to(rescue_target.position) <= CombatRules.RESCUE_RANGE:
		path.clear()
		if channel_revive(rescue_target, _last_delta):
			if then_retreat != Vector2.INF:
				rescue_target.order_retreat(then_retreat + Vector2(18, 0), map)   # both head for the exit
			_after_rescue(map)
	elif path.is_empty() or _repath <= 0.0:
		_repath = REPATH_EVERY
		path = map.find_path(position, rescue_target.position)


## One tick of lifting `ally` (D-036, D-082: RESCUE_TIME s next to them; a hit resets it, see _on_hit).
## Used by the AI's rescue order and by the Master holding F. Returns true when the ally is up.
func channel_revive(ally: SandboxHero, delta: float) -> bool:
	if ally == null or not is_instance_valid(ally) or not ally.downed or ally.dead or ally.lost:
		rescue_progress = 0.0
		return false
	_face(ally.position - position)
	_play("ready_" + _side)
	rescue_target = ally
	rescue_progress += delta
	if rescue_progress < revive_time():
		return false
	rescue_progress = 0.0
	var resurrection := not f_action().is_empty()
	ally.revive(float(f_action().get("hp", CombatRules.RESCUE_HP)))
	if resurrection:
		CombatVFX.play(get_parent(), ally.position + Vector2(0, -16), "heal_aura", 1.2)
	CombatVFX.play(get_parent(), ally.position + Vector2(0, -16), "level_up", 1.0)
	credit("rescues", 1.0)
	if hero != null and ally.hero != null:
		hero.rescue_hero(ally.hero)          # memory, bond and Trust (Phase 3 data)
		if hero.is_master:
			MasterRules.bond_event(ally.hero, "rescued_by_master")   # D-081
	FloatingText.spawn(ally, "Resurrection!" if resurrection else "Rescued!", Color(0.5, 1.0, 0.6), true)
	return true


## D-142: the class action on F ({} = the common lift). The cleric's is Resurrection (SkillDefs.F_ACTIONS).
func f_action() -> Dictionary:
	return SkillDefs.f_action(hero.hero_class) if hero != null else {}


## Seconds this hero needs to lift a fallen ally (the cleric's Resurrection channel, else RESCUE_TIME).
func revive_time() -> float:
	return float(f_action().get("channel", CombatRules.RESCUE_TIME))


## D-065 autonomy: one skill per check, in this order: heal a hurt ally, break a creature's cast, draw
## blows off a hurt ally (taunt), shield when hurt, cleanse, then attack. Returns true if one fired.
func _auto_skill(enemies: Array) -> bool:
	var allies: Array = squad if not squad.is_empty() else [self]
	var order_of := ["heal", "interrupt", "taunt", "shield", "cleanse", "damage"]
	for want in order_of:
		for i in slots.size():
			var sk := slot_skill(i)
			if sk.is_empty() or skill_cd(i) > 0.0 or res < _cost(slots[i]):
				continue
			if bool(sk.get("finisher", false)) and not _finisher_worth():
				continue                                 # D-090: a finisher waits for combo points
			if _auto_kind(sk) != want:
				continue
			var aim := Vector2.INF
			var reach := float(sk["range"])
			match want:
				"heal":
					var hurt := false
					for a in allies:
						if is_instance_valid(a) and a.alive and position.distance_to(a.position) <= maxf(reach, 1.0) \
								and float(a.hp) < float(a.max_hp) * AUTO_HEAL_BELOW:
							hurt = true
					if not hurt:
						continue
				"interrupt":
					var caster: SandboxEnemy = null
					for e in enemies:
						if e.alive and e.visible and e.is_telegraphing() and (e.casting_skill != "" or e.is_heavy()) \
								and position.distance_to(e.position) <= maxf(reach, 75.0):
							caster = e
							break
					if caster == null:
						continue
					aim = caster.position
				"taunt":
					var threat := false
					for e in enemies:
						if e.alive and e.focus != null and e.focus != self and is_instance_valid(e.focus) \
								and float(e.focus.hp) < float(e.focus.max_hp) * 0.7 and position.distance_to(e.position) <= 170.0:
							threat = true
					if not threat:
						continue
				"shield":
					var low := float(hp) < float(max_hp) * 0.5
					for a in allies:
						if is_instance_valid(a) and a.alive and a != self and position.distance_to(a.position) <= 180.0 and float(a.hp) < float(a.max_hp) * 0.45:
							low = true
					if not low or enemies.is_empty():
						continue
				"cleanse":
					var bad := false
					for a in allies:
						if is_instance_valid(a) and a.alive and position.distance_to(a.position) <= maxf(reach, 1.0):
							for st in a.statuses:
								if bool(CombatRules.STATUS.get(st, {}).get("debuff", false)):
									bad = true
					if not bad:
						continue
				"damage":
					if target == null or not is_instance_valid(target) or not target.alive:
						continue
					if position.distance_to(target.position) > maxf(reach, attack_range()) + 10.0:
						continue
					aim = target.position if String(sk["target"]) == "target_aoe" else Vector2.INF
			if use_skill_slot(i, enemies, allies, aim):
				return true
	return false


## What a skill is for, as the autonomy sees it.
func _auto_kind(sk: Dictionary) -> String:
	var kinds: Array = []
	for e in sk["effects"]:
		kinds.append(String(e["t"]))
		for inner in e.get("inner", []):
			kinds.append(String(inner["t"]))
	if kinds.has("heal") or kinds.has("heal_pct"):
		return "heal"
	if kinds.has("interrupt"):                     # D-142: only Ambush, Interrupting Shot and Counterspell
		return "interrupt"
	if kinds.has("taunt"):
		return "taunt"
	if kinds.has("shield"):
		return "shield"
	if kinds.has("cleanse"):
		return "cleanse"
	return "damage"


## After a rescue: back to Auto, or on to the exit when the rescue was part of a retreat (#14).
func _after_rescue(map: NavMap) -> void:
	var exit := then_retreat
	stop()
	if exit != Vector2.INF:
		order_retreat(exit, map)


func _nearest(enemies: Array, radius: float) -> SandboxEnemy:
	var best: SandboxEnemy = null
	var best_d := radius
	for e in enemies:
		if not e.alive:
			continue
		var d: float = position.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


# --- active skills (combat Phase 3, D-040..D-043) -------------------------------------------------

func _setup_skills() -> void:
	res_kind = SkillDefs.resource_of(hero.hero_class)
	var rd: Dictionary = SkillDefs.RESOURCES[res_kind]
	res_max = float(rd["base"])
	if rd.has("per_attr"):
		res_max += float(hero.attributes().get(String(rd["per_attr"]), 0)) * float(rd["per"])
	res = res_max * float(rd["start"])
	combo = 0
	if uses_bow():
		arrows = AiDefs.ARROWS_START + int(hero.bag.get(AiDefs.ARROW_BAG_ID, 0))   # D-090 (the arrow item: pista D)
	slots.clear()
	for sid in hero.loadout:
		if SkillDefs.SKILLS.has(sid):
			slots.append(String(sid))


## D-090: regen (regen_combat while fighting, regen_still while standing still), decay out of combat.
func _tick_resource(delta: float) -> void:
	var rd: Dictionary = SkillDefs.RESOURCES[res_kind]
	var fighting := combat_t > 0.0
	var r := float(rd["regen"])
	if fighting and rd.has("regen_combat"):
		r = float(rd["regen_combat"])
	if rd.has("regen_still") and _still_t >= 0.4:
		r = float(rd["regen_still"])              # the archer's concentration
	res += r * delta
	if not fighting:
		res -= float(rd["decay"]) * delta         # Fury cools down out of combat
	res = clampf(res, 0.0, res_max)


## D-090 for the UI (party frames, HUD): the class resource now / at most / which one.
func resource_value() -> float:
	return res


func resource_max() -> float:
	return res_max


func resource_kind() -> String:
	return res_kind


func combo_points() -> int:
	return combo


## Arrows left (-1 = the hero does not use a bow).
func arrows_left() -> int:
	return arrows


func in_combat() -> bool:
	return combat_t > 0.0


## A finisher is worth it with 3+ combo points, or 1+ on a foe about to fall.
func _finisher_worth() -> bool:
	if combo >= 3:
		return true
	return combo >= 1 and target != null and is_instance_valid(target) and float(target.hp) < float(target.max_hp) * 0.35


## D-090: walks over the bodies that carry its arrows and takes ARROW_RECOVER of them back.
func _pick_up_arrows() -> void:
	if arrows < 0 or _arrow_corpses.is_empty():
		return
	var keep: Array = []
	for c in _arrow_corpses:
		if not is_instance_valid(c):
			continue
		if c.dead and position.distance_to(c.position) <= AiDefs.ARROW_PICKUP:
			var n := ceili(float(int(c.get("arrows_in"))) * AiDefs.ARROW_RECOVER)
			c.set("arrows_in", 0)
			if n > 0:
				arrows += n
				FloatingText.spawn(self, "+%d %s" % [n, tr("arrows")], Color(0.9, 0.8, 0.55), false, 1.0)
			continue
		keep.append(c)
	_arrow_corpses = keep


## The nearest dead creature with this hero's arrows in it within `radius` (null = none).
func arrow_corpse(radius: float) -> Node2D:
	var best: Node2D = null
	var best_d := radius
	for c in _arrow_corpses:
		if is_instance_valid(c) and c.dead and int(c.get("arrows_in")) > 0 and position.distance_to(c.position) < best_d:
			best_d = position.distance_to(c.position)
			best = c
	return best


## What a skill costs this hero (D-090: no resource = no cost).
func _cost(id: String) -> float:
	return 0.0 if res_kind == "none" else float(SkillDefs.info(id).get("cost", 0))


func gain_resource(amount: float) -> void:
	res = clampf(res + amount, 0.0, res_max)


func slot_skill(i: int) -> Dictionary:
	return SkillDefs.info(slots[i]) if i >= 0 and i < slots.size() else {}


func skill_cd(i: int) -> float:
	return float(cds.get(slots[i], 0.0)) if i >= 0 and i < slots.size() else 0.0


func skill_ready(i: int = 0) -> bool:
	var sk := slot_skill(i)
	return alive and not sk.is_empty() and skill_cd(i) <= 0.0 and res >= _cost(slots[i]) and casting == "" \
		and (not bool(sk.get("finisher", false)) or combo > 0)


func is_casting() -> bool:
	return casting != ""


## Direct skill activation (D-059: W E R = slots 0-2; Q is the basic attack). Returns true if it fired or started its
## cast. Refused only for a concrete reason, never by a random roll (D-016); the reason is kept in
## last_refusal for the UI. allies = every hero of the squad (self included).
func use_skill_slot(i: int, enemies: Array, allies: Array, aim: Vector2 = Vector2.INF) -> bool:
	last_refusal = ""
	_aim = aim
	var sk := slot_skill(i)
	if sk.is_empty():
		return _refuse("no skill learned")
	if not alive:
		return _refuse("down")
	if carrying:
		return _refuse("carrying the relic")
	if casting != "":
		return _refuse("already casting")
	if not can_act():
		return _refuse("stunned")
	if skill_cd(i) > 0.0:
		return _refuse("cooldown %.0fs" % ceilf(skill_cd(i)))
	var cost := _cost(slots[i])
	if res < cost:
		return _refuse("not enough %s" % String(SkillDefs.RESOURCES[res_kind]["name"]).to_lower())
	if bool(sk.get("finisher", false)) and combo <= 0:
		return _refuse("no combo points")
	var tgt := _skill_target(sk, enemies, allies)
	if tgt == null:
		return _refuse(last_refusal if last_refusal != "" else "no target in range")
	res -= cost
	cds[slots[i]] = float(sk["cd"])
	combat_t = SkillDefs.COMBAT_LINGER
	if bool(sk.get("finisher", false)):
		sk = sk.duplicate(true)
		sk["_combo"] = combo                     # D-090: the finisher spends every point
		combo = 0
	elif sk.has("combo"):
		combo = mini(SkillDefs.COMBO_MAX, combo + int(sk["combo"]))
	if tgt != self:
		_face(tgt.position - position)
	var point := tgt.position
	if String(sk["target"]) == "target_aoe" and _aim != Vector2.INF:
		point = position + (_aim - position).limit_length(float(sk["range"]))   # aimed area, within reach
		tgt = self
	if float(sk["cast"]) > 0.0:
		casting = slots[i]
		_start_cast_fx(casting)
		cast_left = float(sk["cast"])
		cast_target = tgt
		cast_point = point
		_cast_enemies = enemies
		_cast_allies = allies
		path.clear()
		_anim_lock = HeroAnim.play_cast(_sprite, _side)
		return true
	_firing = slots[i]
	_fire_skill(sk, tgt, point, enemies, allies)
	return true


func _refuse(reason: String) -> bool:
	last_refusal = reason
	return false


## Who the skill is aimed at. Self-centred skills return self; null = nothing valid in range.
func _skill_target(sk: Dictionary, enemies: Array, allies: Array) -> Combatant:
	var reach := float(sk["range"])
	match String(sk["target"]):
		"self":
			if _only_heals_self(sk) and hp >= max_hp:
				last_refusal = "already at full health"
				return null
			return self
		"self_aoe":
			for e in enemies:
				if e.alive and position.distance_to(e.position) <= reach:
					return self
			return null
		"ally_low":
			var best: Combatant = null
			var best_k := 1.0
			var needs_hurt := _effects_have(sk, ["heal"]) and not _effects_have(sk, ["cleanse", "shield"])
			for a in allies:
				if not is_instance_valid(a) or not a.alive or position.distance_to(a.position) > reach:
					continue
				var k := float(a.hp) / float(maxi(1, a.max_hp))
				if (k < best_k) or (best == null and not needs_hurt):
					best_k = k
					best = a
			if best == null and needs_hurt:
				last_refusal = "nobody is hurt"
			return best
		"target_aoe" when _aim != Vector2.INF:
			return self                          # aimed at the ground by the player: no foe needed there
		_:
			if _aim != Vector2.INF:              # aimed by the player: the foe in reach closest to the cursor
				var pick: Combatant = null
				var pick_d := INF
				for e in enemies:
					if e.alive and e.visible and position.distance_to(e.position) <= reach and e.position.distance_to(_aim) < pick_d:
						pick_d = e.position.distance_to(_aim)
						pick = e
				if pick == null:
					last_refusal = "out of range"
				return pick
			if target != null and is_instance_valid(target) and target.alive and position.distance_to(target.position) <= reach:
				return target                    # prefer the current target when in reach
			var best_e: Combatant = null
			var best_d := reach
			for e in enemies:
				if not e.alive or not e.visible:
					continue
				var d: float = position.distance_to(e.position)
				if d <= best_d:
					best_d = d
					best_e = e
			return best_e


func _only_heals_self(sk: Dictionary) -> bool:
	for e in sk["effects"]:
		if not (String(e["t"]) in ["heal", "heal_pct"]):
			return false
	return true


func _effects_have(sk: Dictionary, kinds: Array) -> bool:
	for e in sk["effects"]:
		if kinds.has(String(e["t"])):
			return true
	return false


## D-042: a cast is broken only by control (stun). The cost and cooldown are given back.
func interrupt_cast(reason: String = "interrupted") -> void:
	if casting == "":
		return
	res = minf(res_max, res + _cost(casting))
	cds[casting] = minf(float(cds.get(casting, 0.0)), CAST_BREAK_CD)
	casting = ""
	cast_target = null
	_anim_lock = 0.0
	_clear_cast_fx()
	CombatVFX.play(get_parent(), position + Vector2(0, -20), "parry", 0.8)
	FloatingText.spawn(self, reason, Color(1.0, 0.6, 0.4), false)


func _tick_cast(delta: float) -> void:
	if not can_act():
		interrupt_cast()
		return
	cast_left -= delta
	if cast_left > 0.0:
		return
	var sk := SkillDefs.info(casting)
	var tgt := cast_target
	_firing = casting
	casting = ""
	cast_target = null
	_clear_cast_fx()
	if tgt == null or not is_instance_valid(tgt) or not tgt.alive:
		if String(sk["target"]) != "target_aoe":
			FloatingText.spawn(self, "target lost", Color(0.8, 0.8, 0.8), false)
			return
		tgt = self                                # area skills still land where they were aimed
	_fire_skill(sk, tgt, cast_point, _cast_enemies, _cast_allies)


## Fires a skill: the look plays now; the effects land when its projectile arrives (D-054) or at once.
func _fire_skill(sk: Dictionary, tgt: Combatant, point: Vector2, enemies: Array, allies: Array) -> void:
	var id := _firing
	var centre := position
	match String(sk["target"]):
		"enemy":
			centre = tgt.position
		"target_aoe":
			centre = point if tgt == self else tgt.position
	var travel := _skill_travel(id, centre)
	_skill_vfx(id, String(sk["target"]), centre, float(sk.get("radius", sk["range"])), sk)
	_anim_lock = HeroAnim.play_cast(_sprite, _side)
	_later(travel, func(): _resolve_skill(sk, tgt, point, enemies, allies))


## Seconds the skill's projectile flies before it lands (0 = no projectile).
func _skill_travel(id: String, centre: Vector2) -> float:
	var fx: Dictionary = CombatVFX.SKILL_FX.get(id, {})
	if not fx.has("proj"):
		return 0.0
	var aim := centre + Vector2(0, -12)
	if fx.get("rain", false):
		return 0.45
	if fx.get("sky", false):
		return (centre + Vector2(-160, -420)).distance_to(aim) / 520.0
	return (position + Vector2(0, -16)).distance_to(aim) / float(fx.get("speed", 650.0))


func _resolve_skill(sk: Dictionary, tgt: Combatant, point: Vector2, enemies: Array, allies: Array) -> void:
	if not alive and not downed:
		return
	if tgt != self and (not is_instance_valid(tgt) or not tgt.alive):
		if String(sk["target"]) != "target_aoe":
			return                               # single target died in flight: the shot is wasted
		tgt = self
	var tmode := String(sk["target"])
	var foes: Array = []
	var friends: Array = []
	var centre := position
	_cur_combo = int(sk.get("_combo", 0))
	_cur_aoe = tmode == "self_aoe" or tmode == "target_aoe"
	match tmode:
		"enemy":
			foes.append(tgt)
			centre = tgt.position
		"self_aoe":
			for e in enemies:
				if e.alive and position.distance_to(e.position) <= float(sk["range"]):
					foes.append(e)
		"target_aoe":
			centre = point if tgt == self else tgt.position
			for e in enemies:
				if e.alive and centre.distance_to(e.position) <= float(sk.get("radius", 80.0)):
					foes.append(e)
		_:
			friends.append(tgt)
	for eff in sk["effects"]:
		_apply_effect(eff, foes, friends, centre, enemies, allies)
	_cur_combo = 0
	_cur_aoe = false
	_skill_vfx(_firing, tmode, centre, float(sk.get("radius", sk["range"])), sk)
	_anim_lock = HeroAnim.play_cast(_sprite, _side)


func _apply_effect(eff: Dictionary, foes: Array, friends: Array, centre: Vector2, enemies: Array, allies: Array) -> void:
	match String(eff["t"]):
		"damage":
			var kind := String(eff["kind"])
			if kind == "power":
				kind = String(stats.get("kind", "physical"))
			var base := float(stats["mag"]) if kind == "magical" else float(stats["atk"])
			for f in foes:
				var amount := base * float(eff["mult"]) * _busy_mult(f)
				if eff.has("bonus_if_busy") and f.get("focus") != null and f.get("focus") != self:
					amount *= float(eff["bonus_if_busy"])
				amount *= 1.0 + SkillDefs.FINISHER_PER_COMBO * float(_cur_combo)
				var info := DamageInfo.make(amount, kind, self, crit_chance, combat_rng)
				if _cur_aoe:
					info.set_meta("aoe", true)               # Safe Sweep (taunt_aoe) reads it
				synergy_before_hit(f, info)
				_on_dealt(f, f.take_hit(info))
		"status":
			var mag := float(eff.get("mag", 0.0))
			if eff.has("mult"):
				mag = float(power()) * float(eff["mult"])
			var sdur := float(eff["dur"]) * (1.0 + SkillDefs.FINISHER_PER_COMBO * float(_cur_combo))
			for u in (foes if not foes.is_empty() else friends):
				u.apply_status(String(eff["id"]), sdur, mag, self)
				if String(eff["id"]) == "marked" and hero != null and hero.hero_class == "class.archer" and u.get("spotted_t") != null:
					u.set("spotted_t", maxf(float(u.get("spotted_t")), sdur))   # D-090 Hunter's Eye: seen through the fog
					u.set("marked_by", self)
		"heal":
			for u in friends:
				var healed := float(u.heal(roundi(float(stats["mag"]) * float(eff["mult"]))))
				credit("healing", healed)
				_heal_threat(enemies, u, healed)
				CombatVFX.play(u.get_parent(), u.position + Vector2(0, -14), "heal", 0.9)
		"heal_pct":
			for u in friends:
				var healed2 := float(u.heal(roundi(float(u.max_hp) * float(eff["pct"]))))
				credit("healing", healed2)
				_heal_threat(enemies, u, healed2)
				CombatVFX.play(u.get_parent(), u.position + Vector2(0, -14), "heal", 0.9)
		"shield":
			for u in friends:
				var sm := float(item_mods.get("shield_mult", 1.0))      # Warden set: shields given...
				if u != self and u.get("item_mods") != null:
					sm *= float((u.get("item_mods") as Dictionary).get("shield_mult", 1.0))   # ...and received
				u.apply_status("shield", SHIELD_TIME, float(u.max_hp) * float(eff["pct"]) * sm, self)
				credit("shield", float(u.max_hp) * float(eff["pct"]) * sm)
		"cleanse":
			for u in friends:
				u.cleanse()
				CombatVFX.play(u.get_parent(), u.position + Vector2(0, -18), "sparkle_small", 1.0)
		"interrupt":
			for f in foes:
				if f.has_method("interrupt") and f.interrupt():
					CombatVFX.play(f.get_parent(), f.position + Vector2(0, -20), "parry", 1.0)
		"knockback":
			for f in foes:
				CombatVFX.play(f.get_parent(), f.position, "dust_puff", 1.0)
				_push(f, (f.position - position).normalized(), float(eff["dist"]))   # D-142: no longer breaks a cast
		"dash":
			if not foes.is_empty() and _map != null:
				var f: Node2D = foes[0]
				var spot := f.position + (position - f.position).normalized() * 28.0
				if _map.can_step(position, spot):
					CombatVFX.play(get_parent(), position, "dust", 0.9, spot.x < position.x)
					var was := position
					position = spot
					path.clear()
					CombatFeel.slide(_sprite, was - position)
					CombatVFX.play(get_parent(), position, "dust_puff", 1.0)
		"blink":
			if _map != null:
				var away := Vector2.DOWN
				var near := _nearest(enemies, 9999.0)
				if near != null and near.position.distance_to(position) > 1.0:
					away = (position - near.position).normalized()
				var spot := _map.nearest_walkable(position + away * float(eff["dist"]))
				CombatVFX.play(get_parent(), position + Vector2(0, -16), "teleport", 1.0)
				position = spot
				path.clear()
				CombatVFX.play(get_parent(), position + Vector2(0, -16), "teleport", 1.0)
		"taunt":
			for e in enemies:
				if e.alive and e.position.distance_to(position) <= float(eff["radius"]) and e.has_method("taunt"):
					e.taunt(self, float(eff["dur"]))
		"zone":
			var mag := 0.0
			if String(eff["status"]) == "regen":
				mag = float(stats["mag"]) * REGEN_PER_MAG
			var units: Array = enemies if bool(eff["foes"]) else allies
			CombatZone.spawn(get_parent(), centre, float(eff["radius"]), float(eff["dur"]),
				String(eff["status"]), float(eff["sdur"]), mag, units, self, bool(eff.get("once", false)))
		"allies":
			var near_allies: Array = []
			for a in allies:
				if is_instance_valid(a) and a.alive and a.position.distance_to(position) <= float(eff["radius"]):
					near_allies.append(a)
			for inner in eff["inner"]:
				_apply_effect(inner, [], near_allies, position, enemies, allies)


## Moves a unit along dir up to dist / its mass, stopping before walls. The heavier the unit, the
## shorter the push (a huge creature barely staggers); the sprite then slides over the gap.
func _push(u: Node2D, dir: Vector2, dist: float) -> void:
	if _map == null:
		return
	var mass := float(u.get("mass")) if u.get("mass") != null else 1.0
	dist /= maxf(0.25, mass)
	var start := u.position
	var step := 8.0
	var moved := 0.0
	while moved < dist:
		var np := u.position + dir * minf(step, dist - moved)
		if not _map.can_step(u.position, np):
			break
		u.position = np
		moved += step
	CombatFeel.slide(u.get("_sprite"), start - u.position)
	if mass >= 3.0:
		FloatingText.spawn(u, "stagger", Color(0.85, 0.85, 0.9), false)


## The skill's look (CombatVFX.SKILL_FX): projectiles fly to the target and the impacts play when
## they land; area effects are scaled to the skill's radius. Logic was already resolved.
func _skill_vfx(id: String, tmode: String, centre: Vector2, radius: float, sk: Dictionary) -> void:
	var fx: Dictionary = CombatVFX.SKILL_FX.get(id, {})
	var parent := get_parent()
	var from := position + Vector2(0, -16)
	var aim := centre + Vector2(0, -12)
	var delay := 0.0
	for k in fx.get("self", []):
		CombatVFX.play(parent, position + Vector2(0, -14), String(k), 1.0)
	if fx.has("proj"):
		var key := String(fx["proj"])
		var speed := float(fx.get("speed", 650.0))
		var ps := float(fx.get("proj_scale", 1.0))
		var n := int(fx.get("n", 1))
		if fx.get("rain", false):
			for j in n:
				var spot := centre + Vector2(combat_rng.randf_range(-1.0, 1.0), combat_rng.randf_range(-0.6, 0.6)) * radius * 0.8
				CombatVFX.projectile(parent, spot + Vector2(-60, -240 - 30 * j), spot, key, "spark_small", 700.0, ps, 0.8)
			delay = 0.45
		elif fx.get("sky", false):
			var start := centre + Vector2(-160, -420)
			CombatVFX.projectile(parent, start, aim, key, "", 520.0, ps)
			delay = start.distance_to(aim) / 520.0
		else:
			var side := (aim - from).normalized().orthogonal()
			for j in n:
				CombatVFX.projectile(parent, from + side * (float(j) - float(n - 1) * 0.5) * 8.0, aim, key, "", speed, ps)
			delay = from.distance_to(aim) / speed
	var flip := centre.x < position.x
	for k in fx.get("hit", []):
		_fx_later(String(k), aim, 1.0, delay, flip)
	var areas: Array = fx.get("area", [])
	for i in areas.size():
		if i == 0:                                     # the main effect covers the whole area (ring of copies)
			CombatVFX.area_burst(parent, centre + Vector2(0, -6), radius, String(areas[i]), delay)
		else:
			_fx_later(String(areas[i]), centre + Vector2(0, -6), CombatVFX.area_scale(String(areas[i]), radius), delay, false)
	if tmode == "self_aoe" or tmode == "target_aoe":
		_area_flash_later(centre, radius, delay)
		var weight := _skill_weight(sk, radius)
		if weight != "":
			_feel_later(weight, delay, centre)
	elif tmode == "enemy":
		_fire_fx(centre, 0.0)


## How hard an area skill lands on screen: big or slow-cast areas shake more (never a light skill).
func _skill_weight(sk: Dictionary, radius: float) -> String:
	if radius >= 110.0 and float(sk["cast"]) >= 1.0:
		return "medium"
	if radius >= 90.0 or float(sk["cast"]) >= 0.8:
		return "small"
	return ""


## The real radius of the area, drawn on the ground when it lands (the art is decoration around it).
## Runs `f` after `delay` seconds on a tween owned by this hero: if the hero (or the mission screen
## around it) is freed first, the tween dies with it and `f` never runs on freed nodes (B4).
func _after(delay: float, f: Callable) -> void:
	create_tween().tween_callback(f).set_delay(delay)


func _area_flash_later(centre: Vector2, radius: float, delay: float) -> void:
	var parent := get_parent()
	var col := Color(1.0, 0.7, 0.25)
	if delay <= 0.02 or not is_inside_tree():
		CombatFeel.area_flash(parent, centre, radius, col)
		return
	_after(delay, func(): CombatFeel.area_flash(parent, centre, radius, col))


func _feel_later(kind: String, delay: float, at: Vector2) -> void:
	if not is_inside_tree():
		return
	if delay <= 0.02:
		CombatFeel.shake(self, kind, at - position)
		return
	_after(delay, func(): CombatFeel.shake(self, kind, at - position))


func _fx_later(key: String, pos: Vector2, sc: float, delay: float, flip: bool) -> void:
	var parent := get_parent()
	if delay <= 0.02 or not is_inside_tree():
		CombatVFX.play(parent, pos, key, sc, flip)
		return
	_after(delay, func(): CombatVFX.play(parent, pos, key, sc, flip))


func _start_cast_fx(id: String) -> void:
	_clear_cast_fx()
	_cast_fx = CombatVFX.attach(self, String(CombatVFX.SKILL_FX.get(id, {}).get("cast", "circle_arcane")), Vector2(0, -2), 1.0, true)


func _clear_cast_fx() -> void:
	if _cast_fx != null and is_instance_valid(_cast_fx):
		_cast_fx.queue_free()
	_cast_fx = null


func _fire_fx(at: Vector2, radius: float) -> void:
	_fx = 0.35
	_fx_to = at - position
	_fx_radius = radius
	queue_redraw()


# --- trinket passives (owner 2026-11-02; ItemDefs.BASES "proc") --------------------------------

## Chance-based passives that fire when this hero lands a blow (basic attack or skill damage).
func _trinket_on_deal(t: Combatant, dealt: int) -> void:
	for p in item_mods.get("trinket_procs", []):
		var pr: Dictionary = p
		if combat_rng.randf() >= float(pr["chance"]):
			continue
		match String(pr["type"]):
			"leech_strike":
				heal(roundi(float(dealt) * float(pr["frac"])))
				CombatVFX.play(get_parent(), position + Vector2(0, -14), "heal", 0.7)
			"echo_strike":
				if t.alive:
					t.take_hit(DamageInfo.make(float(dealt) * float(pr["frac"]), "true", self))
			"mark_on_hit":
				if t.alive:
					t.apply_status("marked", float(pr["dur"]), 0.0, self)
			"cd_reduce":
				for sid in cds:
					cds[sid] = maxf(0.0, float(cds[sid]) - float(pr["secs"]))
			"mend_ally":
				var low: Combatant = null
				for u in (squad if not squad.is_empty() else [self]):
					if is_instance_valid(u) and (u as Combatant).alive and (low == null or float(u.hp) / float(u.max_hp) < float(low.hp) / float(low.max_hp)):
						low = u
				if low != null and low.hp < low.max_hp:
					credit("healing", float(low.heal(roundi(float(low.max_hp) * float(pr["pct"])))))
					CombatVFX.play(low.get_parent(), low.position + Vector2(0, -14), "heal", 0.7)
			_:
				continue
		if not SimMode.on:
			FloatingText.spawn(self, tr(String(ItemDefs.BASES.get(_proc_base(String(pr["type"])), {}).get("name", "")) ), Color(0.95, 0.85, 0.45), false, 0.8)


## Chance-based passives that fire when this hero is hurt.
func _trinket_on_hurt(info: DamageInfo, dmg: int) -> void:
	for p in item_mods.get("trinket_procs", []):
		var pr: Dictionary = p
		var ty := String(pr["type"])
		if not (ty in ["shield_on_hurt", "stun_on_hurt", "regen_on_hurt"]) or combat_rng.randf() >= float(pr["chance"]):
			continue
		match ty:
			"shield_on_hurt":
				apply_status("shield", float(pr["dur"]), float(max_hp) * float(pr["pct"]), self)
			"stun_on_hurt":
				if info.kind != "physical" or not (info.source is SandboxEnemy) or not is_instance_valid(info.source):
					continue
				(info.source as Combatant).apply_status("stun", float(pr["dur"]), 0.0, self)
			"regen_on_hurt":
				apply_status("regen", float(pr["dur"]), float(max_hp) * float(pr["pct"]), self)
		if not SimMode.on and dmg > 0:
			FloatingText.spawn(self, tr(String(ItemDefs.BASES.get(_proc_base(ty), {}).get("name", ""))), Color(0.95, 0.85, 0.45), false, 0.8)


## The trinket base that carries a passive type (for the floating text).
static func _proc_base(ty: String) -> String:
	for b in ItemDefs.BASES:
		if String((ItemDefs.BASES[b] as Dictionary).get("proc", {}).get("type", "")) == ty:
			return String(b)
	return ""


# --- Combatant hooks ------------------------------------------------------------------------

func _on_hit(info: DamageInfo, dmg: int) -> void:
	_flash = 0.15
	combat_t = SkillDefs.COMBAT_LINGER
	if dmg > 0 and item_mods.has("thorns") and info.source is SandboxEnemy and info.kind == "physical" and is_instance_valid(info.source):
		(info.source as Combatant).take_hit(DamageInfo.make(float(dmg) * float(item_mods["thorns"]), "true", self))
	gain_resource(float(SkillDefs.RESOURCES[res_kind]["on_hurt"]))
	if dmg > 0 and alive:
		_trinket_on_hurt(info, dmg)
	if rescue_progress > 0.0:
		rescue_progress = 0.0                         # D-036: taking damage interrupts the rescue (AI or held F)
		FloatingText.spawn(self, "interrupted", Color(1.0, 0.6, 0.4), false)
	if hp > 0 and info.source != null and is_instance_valid(info.source):
		HeroAnim.play_hit(_sprite, (position - info.source.position).normalized())


func _on_down() -> void:
	was_downed = true
	CombatFeel.shake(self, "medium")
	casting = ""
	_draw_t = -1.0
	_draw_target = null
	rescue_progress = 0.0
	_clear_cast_fx()
	CombatVFX.play(get_parent(), position, "blood", 1.0)
	cast_target = null
	path.clear()
	order = "auto"
	target = null
	rescue_target = null
	if _sprite != null:
		_sprite.stop()
		_sprite.play("down_" + _side)
	_anim_lock = 99999.0


func _on_revive() -> void:
	_anim_lock = 0.0
	_play("idle_" + facing)


## Permanent death (D-011) is not a remove_child: the camera jolts, the body stays a while and the
## hero's name is shown as it fades (HeroAnim.spawn_death). The memorial is written by the screen.
func _on_die() -> void:
	path.clear()
	CombatFeel.shake(self, "large")
	HeroAnim.spawn_death(self, _sprite, facing, _side, hero.display_name() if hero != null else "")
	visible = false


## 4-way facing. On diagonals the current axis is kept until the other one clearly dominates
## (FACING_HYSTERESIS), so a diagonal walk does not flip between side and front frames every step.
func _face(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	var horizontal := facing == "left" or facing == "right"
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	if horizontal:
		horizontal = ay <= ax * FACING_HYSTERESIS
	else:
		horizontal = ax > ay * FACING_HYSTERESIS
	if horizontal:
		facing = "right" if dir.x > 0.0 else "left"
	else:
		facing = "down" if dir.y > 0.0 else "up"
	if facing == "left" or facing == "right":
		_side = facing


func _play(anim: String) -> void:
	if _anim_lock > 0.0:
		return
	if _sprite != null and _sprite.animation != anim:
		_sprite.play(anim)


func _set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _draw() -> void:
	if hero == null or dead:
		return
	if downed:
		var k := clampf(agony / CombatRules.AGONY_TIME, 0.0, 1.0)
		draw_arc(Vector2(0, -12), 18.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(1.0, 0.35, 0.3), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-40, -36), "DOWN %s" % agony_text(), HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color(1.0, 0.5, 0.45))
		var lifter: SandboxHero = null
		for x in squad:
			if is_instance_valid(x) and x.rescue_target == self and x.rescue_progress > 0.0:
				lifter = x
		if lifter != null:
			draw_rect(Rect2(-18, -58, 36, 4), Color(0.1, 0.1, 0.1, 0.85))
			draw_rect(Rect2(-18, -58, 36.0 * lifter.rescue_progress / lifter.revive_time(), 4), Color(0.5, 1.0, 0.6))
		elif revive_prompt and not lost:
			var fa: Dictionary = {}
			for x in squad:
				if is_instance_valid(x) and x.hero != null and x.hero.is_master:
					fa = x.f_action()
			# D-082: interaction is F (QWER = combat); D-142: a cleric Master's F is Resurrection
			UIKit.draw_bubble(self, tr("Hold F: %s") % tr(String(fa["name"])) if not fa.is_empty() else tr("Hold F"), Vector2(0, -58))
		return
	if rescue_progress > 0.0:
		draw_rect(Rect2(-15, -52, 30.0 * rescue_progress / revive_time(), 3), Color(0.5, 1.0, 0.6))
	var sx := -15.0
	for id in statuses:
		draw_rect(Rect2(sx, -39, 4, 4), CombatRules.STATUS[id]["color"])
		sx += 6.0
	var w := 30.0
	draw_rect(Rect2(-w * 0.5, -46, w, 4), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-w * 0.5, -46, w * float(hp) / float(maxi(1, max_hp)), 4), Color(0.45, 0.85, 0.50))
	draw_rect(Rect2(-w * 0.5, -42, w, 2), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-w * 0.5, -42, w * res / maxf(1.0, res_max), 2), SkillDefs.RESOURCES[res_kind]["color"])
	for k in combo:                              # D-090 rogue combo points: gold pips under the bars
		draw_circle(Vector2(-w * 0.5 + 3.0 + float(k) * 6.0, -36.0), 2.0, Color(1.0, 0.85, 0.3))
	if arrows >= 0 and arrows <= AiDefs.ARROWS_LOW:  # D-090: a running-out quiver shows its count
		draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 + 2.0, -38), "%d" % arrows, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(1.0, 0.45, 0.35) if arrows == 0 else Color(0.95, 0.85, 0.6))
	if casting != "":
		var total := float(SkillDefs.info(casting)["cast"])
		draw_rect(Rect2(-18, -58, 36, 4), Color(0.1, 0.1, 0.1, 0.85))
		draw_rect(Rect2(-18, -58, 36.0 * (1.0 - cast_left / maxf(0.01, total)), 4), Color(0.95, 0.85, 0.4))
	if carrying:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -64), Vector2(6, -58), Vector2(0, -52), Vector2(-6, -58)]), Color(1.0, 0.82, 0.25))
	if _fx > 0.0:
		var a := _fx / 0.35
		if _fx_radius > 0.0:
			draw_arc(_fx_to, _fx_radius, 0.0, TAU, 32, Color(1.0, 0.7, 0.25, a), 3.0)
		elif _fx_to.length() > 1.0:
			draw_line(Vector2(0, -16), _fx_to + Vector2(0, -12), Color(1.0, 0.9, 0.5, a), 3.0)
		else:
			draw_arc(Vector2(0, -16), 22.0, 0.0, TAU, 24, Color(0.5, 1.0, 0.6, a), 3.0)
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, CombatRules.HERO_BODY, Color(0, 0, 0, 0.28))      # contact shadow
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.55))
	var col := hero.star_color()
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 28, Color.WHITE if selected else Color(col, 0.55), 3.0 if selected else 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-4, -52), str(slot + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, col)
	if chatter_timer > 0.0 and chatter_text != "":
		UIKit.draw_bubble(self, chatter_text, Vector2(0, -58))


## Agony left as m:ss (D-082: two minutes), for the hero and its portrait.
func agony_text() -> String:
	var s := ceili(agony)
	return "%d:%02d" % [s / 60, s % 60]


# --- D-090 synergies, aggro, bonds -------------------------------------------------------------------

## A synergy fired with this hero: counted (contrib "syn_<id>", read by the simulator), recorded in the
## codex the first time ("Synergy discovered!") and, at most every SYN_SHOW_EVERY s, named over the hero.
const SYN_SHOW_EVERY := 6.0


func synergy(id: String) -> void:
	credit("syn_" + id, 1.0)
	var nm := tr(String(SynergyDefs.info(id).get("name", id)))
	if SynergyDefs.discover(id):
		FloatingText.spawn(self, "%s %s" % [tr("Synergy discovered!"), nm], SynergyDefs.DISCOVER_COLOR, true, 2.5)
		say("%s %s" % [tr("Synergy discovered!"), nm], 3.0)
		_syn_shown[id] = SYN_SHOW_EVERY
	elif float(_syn_shown.get(id, 0.0)) <= 0.0:
		FloatingText.spawn(self, nm, Color(SynergyDefs.DISCOVER_COLOR, 0.85), false, 0.9)
		_syn_shown[id] = SYN_SHOW_EVERY


## Combos and formation on a blow this hero is about to land (basic attack or skill damage).
func synergy_before_hit(t: Combatant, info: DamageInfo) -> void:
	if t == null or not is_instance_valid(t) or not t.alive or info == null:
		return
	info.crit_chance += syn_crit                            # mentor
	if hero != null and hero.hero_class == "class.rogue" and t.has_status("stun"):
		info.crit_chance = 1.0                               # Opening: a stunned foe is an open book
		synergy("stun_crit")
	if t.has_status("frozen") and info.kind == "physical":
		info.amount *= float(SynergyDefs.param("shatter", "mult", 1.5))
		t.statuses.erase("frozen")
		CombatVFX.play(t.get_parent(), t.position + Vector2(0, -14), "frost_burst", 1.0)
		synergy("shatter")
	info.can_crit = info.rng != null and info.crit_chance > 0.0


## D-090 aggro: healing an ally draws threat from the creatures already fighting near it.
func _heal_threat(enemies: Array, healed_unit: Node2D, amount: float) -> void:
	if amount <= 0.0 or healed_unit == null:
		return
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.alerted and e.focus != null and e.has_method("add_threat") \
				and e.position.distance_to(healed_unit.position) <= AiDefs.THREAT_HEAL_RADIUS:
			e.add_threat(self, amount * AiDefs.THREAT_PER_HEAL)


## Bond synergies (rivals: more damage; friends: less damage taken) on top of the statuses.
func outgoing_mult() -> float:
	return super.outgoing_mult() * syn_out


func incoming_mult() -> float:
	return super.incoming_mult() * syn_in


static func _wrap_words(text: String, width: int) -> Array:
	var out: Array = []
	var cur := ""
	for w in text.split(" "):
		if cur.length() + w.length() + 1 > width and cur != "":
			out.append(cur)
			cur = w
		else:
			cur = w if cur == "" else cur + " " + w
	if cur != "":
		out.append(cur)
	return out
