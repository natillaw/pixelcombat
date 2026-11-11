class_name SandboxScreen
extends Control
## Real-time control sandbox (T-004..T-006, partial T-008). No pause, no time-slow (D-014).
## LMB select / drag-box   RMB move order   1-5 focus hero   Tab group view   G select squad.
## Camera switching never changes selection-independent orders: heroes keep walking.

signal back_requested

const TEST_SQUAD := [[101, 3], [202, 2], [303, 4], [404, 1], [505, 5]]   # [seed, stars] used if the party is not full
const SEPARATION := 26.0
const FORMATION_RADIUS := 44.0
# D-063: the world is drawn at the 640x360 base with whole-number zoom only (crisp pixel art): x1 normally,
# x0.5 when the squad is too spread out to fit. The whole-map overview (M) fits the map instead.
const GROUP_ZOOM_MIN := 0.5
const GROUP_ZOOM_MAX := 1.0
const FOLLOW_ZOOM := 1.0
# Camera feel (game feel report): look-ahead along the followed hero's motion, and a group zoom that
# only re-targets when the needed zoom moved by more than ZOOM_HYSTERESIS (no "breathing" while the
# squad walks). Easing itself lives in FeelCamera.
const LOOK_AHEAD := 0.18          # seconds of the hero's velocity
const LOOK_AHEAD_MAX := 28.0      # world pixels
const ZOOM_HYSTERESIS := 0.06

enum Mission { ACTIVE, SUCCESS, FAILED, ESCAPED }

const MISSION_NAME := "Recover the relic"
const PICKUP_RADIUS := 40.0
const EXTRACT_RADIUS := 56.0
const REWARD_GEMS := 100          # placeholder rewards (T-020): real tuning comes with the economy
const REWARD_STONES := 1
const SURVIVE_TIME := 75.0        # survival: seconds to hold out (default; a floor sets its own "survive_time", D-084)
const HOLD_TIME := 60.0           # defense: seconds a hero must stand at the shrine
const SHRINE_RADIUS := 120.0
const WAVE_EVERY := 12.0
const WAVE_MAX_ALIVE := 14
const CLUE_RADIUS := 56.0
const MISSION_TITLES := {"retrieval": "Recover the relic", "combat": "Clear the floor", "rescue": "Rescue the villager",
	"exploration": "Explore the forest", "survival": "Survive the onslaught", "defense": "Hold the shrine", "boss": "Defeat the chieftain", "escape": "Cross to the far side", "sabotage": "Destroy the totems",
	"farm": "Gather in the Wilds"}

var floor_number: int = 0
var map: NavMap = null
var heroes: Array[SandboxHero] = []
var enemies: Array[SandboxEnemy] = []
var selected: Array[SandboxHero] = []
var mission_state: Mission = Mission.ACTIVE
var relic: SandboxRelic
var expedition_applied: bool = false
var town_report: Dictionary = {}
var mission_type: String = "retrieval"      # from TowerExpedition (floor 0 = training ground relic)
var mission_timer: float = 0.0
var clues: Array[SandboxRelic] = []
var shrine: SandboxRelic = null
var boss: SandboxEnemy = null
var reward: Dictionary = {}
var _wave_timer: float = 0.0
var _escort: AnimatedSprite2D = null           # rescued villager following its carrier
var _rng := RandomNumberGenerator.new()
var carrier: SandboxHero = null
var defeated: int = 0
var elapsed: float = 0.0
var fallen: Array = []                        # display names of heroes lost this mission
var real_squad: bool = false                  # true when the squad is the player's saved party
var master_hero: SandboxHero = null           # D-080: the Master in this squad (always the driven hero), or null
var master_lost: bool = false                 # D-080: the Master's agony ran out or they were left behind
var _ending: bool = false                     # extract()/_wipe() are already ending the mission
var command_cd: Dictionary = {}               # D-081: command id -> seconds left
var reward_given: bool = false
var follow_slot: int = -1                     # -1 = group view
var overview: bool = false                    # M: whole-map view (camera only, never pauses)
var camera: FeelCamera
var debug_overlay: CombatDebugDraw = null       # F3 in debug builds only
var fog: FogMap = null                          # D-056: sight belongs to the heroes, not the camera
var _fog_view: FogView = null
var _fog_t: float = 0.0
var _scout_t: float = 0.0
const SCOUT_EVERY := 2.0
const SCOUT_REACH := 10                         # cells an idle explorer looks around itself for fog
var camera_target: Vector2 = Vector2.ZERO
var camera_zoom_target: float = 1.0
## D-082b camera (CameraDefs): "locked" follows the Master, "free" moves by edges / arrows / middle drag,
## "follow" = a hero picked with a double tap of its F-key. The zoom only changes when the player asks.
var cam_mode: String = "locked"
var cam_free_pos: Vector2 = Vector2.ZERO
var cam_follow: int = -1
var cam_zoom_i: int = CameraDefs.ZOOM_DEFAULT
var center_held: bool = false
var _hero_tap: Dictionary = {}               # slot -> time of the last press of its F-key
var _mid_drag: bool = false
var _explored_rect: Rect2 = Rect2()
var _edges: EdgeIndicators = null

var _viewport: SubViewport
var _world: Node2D
var _info: Label
var _hint: Label
var _squad_label: Label
var _skill_btns: Array[Button] = []    # skill slots 0-2 on W E R (D-059; Q = aimed basic attack)
const SKILL_KEYS := "WER"
var _q_held: bool = false                 # holding Q keeps firing at the cursor whenever ready
var _overlay: Control
var _band: ColorRect
var _hud: ExpeditionHud = null
var _menu: GameMenu = null
var _preview_slot: int = -1
var _look_at: Vector2 = Vector2.INF
var _look_t: float = 0.0
const LOOK_HOLD := 3.0
var _drag_start: Vector2 = Vector2.ZERO
var aiming_slot: int = -1                 # W/E/R held on the driven hero: indicator shown, cast on release
var _rmb_held: bool = false
var _rmb_t: float = 0.0
var _aim_view: SkillAimView = null
const RMB_REPEAT := 0.12                  # holding right click keeps steering the driven hero
var _dragging: bool = false
## D-082 pings (AiDefs.PINGS): Shift + click = quick contextual ping; hold it = the wheel. The ping goes to
## the whole party, or only to `ping_to` (picked by clicking a hero's portrait, then cleared).
var ping_to: SandboxHero = null
var spam_penalty: float = 0.0                 # Obedience lost for spamming pings (fades)
var pings_sent: int = 0
var _ping_times: Array = []                   # recent ping times (anti-spam)
var _ping_queue: Array = []                   # [{t, hero, kind, point, foe, ally}] answers on their way
var _ping_press: Vector2 = Vector2.INF        # Shift + click held here (screen), waiting to be a wheel
var _ping_hold: float = 0.0
var _wheel: PingWheel = null
var _arming_ping: String = ""                 # A in a Master squad: the next click is an "attack" ping
var markers: Array = []                       # PingMarker on the map (tests read them)
## D-082 interaction is F (QWER = combat only): held next to a fallen ally lifts them (RESCUE_TIME s),
## next to a gathering spot gathers it, at the extraction point escapes.
var interact_held: bool = false


func _init(p_floor: int = 0) -> void:
	floor_number = p_floor


func _ready() -> void:
	if map == null:
		if floor_number < 0:
			map = Game.new_wilds_map(-floor_number)          # D-066: a new map every run, never saved
		elif floor_number > 0:
			var game_node := get_node_or_null("/root/Game")
			if game_node != null and game_node.has_method("get_or_create_tower_floor_map"):
				map = game_node.get_or_create_tower_floor_map(floor_number)
			else:
				map = SandboxMap.new()
		else:
			map = SandboxMap.new()

	clip_contents = true
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	UIKit.fill(container)
	_viewport = SubViewport.new()
	_viewport.handle_input_locally = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(_viewport)

	_world = Node2D.new()
	_world.y_sort_enabled = true                 # lower on screen = in front (units, corpses, props)
	_viewport.add_child(_world)
	var ground := SandboxMapView.new(map)
	ground.z_index = -10                         # floor < zones (-5) < ground effects (-4) < units (0) < air effects (20)
	if not SimMode.on:                           # D-083 headless simulator: no map art
		_world.add_child(ground)
		_world.add_child(ground.prop_layer())     # trees, rocks, logs: Y-sorted with the units
	if not SimMode.on and SandboxMapView.has_camps(map) and BosqueArt.available():
		for fire in BosqueArt.campfires(map, (map as ProceduralMap).seed_value):
			_world.add_child(fire)
			Ambience.add_light(_world, fire.position + Vector2(0, -6), Color(1.0, 0.6, 0.25), 80)   # phase 8                   # master prompt I: animated campfires in the bandit camps
	var grade := CanvasModulate.new()            # master prompt G: one warm, slightly muted palette
	grade.color = Color(1.0, 0.97, 0.9)
	_viewport.add_child(grade)
	_setup_pista_a()                              # D-090: bushes (before the fog, so the fog covers them)
	fog = FogMap.new(map.width, map.height)
	if floor_number > 0:
		fog.unpack(Game.floor_explored(floor_number))     # what this account already explored here
	if not SimMode.on:                           # D-083: fog of war still rules sight, it is just not drawn
		_fog_view = FogView.new(fog)
		_world.add_child(_fog_view)
	camera = FeelCamera.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.bounds = Rect2(Vector2.ZERO, map.world_size())
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON   # eased per tick, drawn interpolated
	_viewport.add_child(camera)
	camera.make_current()
	Ambience.add_particles(camera, Vector2(640, 360))   # phase 8: leaves and fireflies (Options: effects)
	if not SimMode.on:                           # D-113 (pista C): floating dust, cloud shadows, birds, brake dust
		Ambience.add_dust(camera, Vector2(640, 360))
		_world.add_child(WorldLife.create(self, map.world_size(), hash(floor_number) ^ 0x11fe))
	# Smooth motion on any refresh rate: the rules tick at the physics rate and the world is drawn
	# interpolated between ticks, and so is the camera (eased in the same tick). The HUD is not. Turned off again when the mission screen closes.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	get_tree().physics_interpolation = true

	mission_type = String(TowerExpedition.get_floor_config(floor_number)["mission"]) if floor_number != 0 else "retrieval"
	_rng.seed = hash(floor_number) ^ 0x5eed ^ SimMode.run_seed   # D-083: run_seed is 0 in the game
	relic = SandboxRelic.new("captive" if mission_type == "rescue" else "relic")
	relic.position = map.center_of(map.relic_cell)      # never the extraction cell (F-003)
	_world.add_child(relic)
	_build_squad()
	_build_enemies()
	_spawn_nodes()
	_setup_mission()
	_apply_modifier()
	_place_secret()
	_build_ui()
	update_fog()
	select_all()
	group_view()
	update_camera_targets()
	camera.target_position = camera_target
	camera.target_zoom = camera_zoom_target
	camera.snap()
	_refresh_info()
	if not heroes.is_empty():
		var leader: SandboxHero = heroes[0]
		leader.say(HeroChatter.get_entry_line(leader.hero), 5.5)
	DevCommands.apply_to(self)                    # D-146: /god, /fly and /speed carry over to a new floor


func _build_squad() -> void:
	var squad: Array = Game.party_heroes()
	# bug fix (beta playthrough): a party with as many heroes as the floor lets in is real (it used to
	# need all 5, so a 1-hero floor sent a throwaway test squad and kept nothing)
	# D-082b: any real party goes (it used to need the floor's full size, and a smaller one silently sent a
	# throwaway test squad); the player was warned before entering (TowerExpedition.squad_report)
	real_squad = not squad.is_empty()
	if not real_squad:
		squad = []
		for entry in TEST_SQUAD:
			squad.append(HeroGenerator.generate(int(entry[0]), int(entry[1])))
	if floor_number != 0:
		squad = squad.slice(0, int(TowerExpedition.squad_report(floor_number, squad)["goes"]))   # the first N go in
	for i in squad.size():
		var h := SandboxHero.new(squad[i], i)
		h.squad = heroes
		var sc: Vector2i = map.spawn_cells[i % map.spawn_cells.size()]
		h.position = map.center_of(sc)
		h.died.connect(_on_hero_died)
		h.went_down.connect(_on_hero_down)
		(squad[i] as HeroData).set_composure(100)           # Composure is per mission (D-016)
		if (squad[i] as HeroData).is_master:
			h.no_death = not Game.hardcore                  # D-081: in hardcore the Master can die for real
			h.lost_down.connect(_on_master_lost)
			h.dmg_mult = MasterDefs.DAMAGE_MULT             # D-081: the Master leads, the others carry
			master_hero = h
		_world.add_child(h)
		heroes.append(h)
		if real_squad:
			_eat_meal(h)                                    # D-128: a meal from the bag buffs the whole run


## Visual type per spawn (T-024). Cosmetic only: all enemies keep the same provisional stats for now.
const ENEMY_TYPES := ["orc", "orc_warrior", "skeleton_base", "skeleton_mage", "orc_rogue"]


## v2 floors place encounters (groups, patrols, ambushes, guards); older maps one creature per cell.
func _build_enemies() -> void:
	if map is ProceduralMap and not (map as ProceduralMap).encounters.is_empty():
		for enc in (map as ProceduralMap).encounters:
			_spawn_encounter(enc)
		_assign_lookouts()
		return
	var cells: Array[Vector2i] = map.enemy_spawn_cells
	if cells.is_empty():
		cells = [Vector2i(10, 10)]
	for i in cells.size():
		_spawn_enemy(cells[i], TowerExpedition.foe_for(floor_number, i) if floor_number != 0 else ENEMY_TYPES[i % ENEMY_TYPES.size()])


var objective_enemies: Array[SandboxEnemy] = []   # the guards of the goal (the boss is the first one)
## Expedition ledger (vertical slice): what was gathered and dropped. Kept on success and on escape,
## lost if the squad is wiped. kill_xp = worth of the creatures killed (shared as XP at the end).
var ledger: Dictionary = {}
var kill_xp: int = 0
var nodes: Array[GatherNode] = []
var results: Dictionary = {}                     # Game.finish_expedition report, for the results screen
# pista D (D-120..D-125): loot stays on the bodies (LootBag) until looted into the heroes' backpacks
var loot_bags: Array = []                        # LootBag on the floor
var packs: Dictionary = {}                       # SandboxHero -> Array of item dicts (D-124)
var loot_report: Dictionary = {}                 # Game.deliver_packs + what was lost
var loot_stats: Dictionary = {"bodies": 0, "items": 0, "junk": 0, "looted": 0}
var _loot_win: LootWindow = null
var _loot_hold: float = 0.0
var _auto_loot: Dictionary = {}                  # hero -> seconds standing next to a body
const EXTRACT_GATHER := 1.8                     # escaping: every standing hero within this x EXTRACT_RADIUS


func _add_loot(res: String, n: int, at: Node2D) -> void:
	if n <= 0:
		return
	ledger[res] = int(ledger.get(res, 0)) + n
	if at != null and at.is_inside_tree():
		FloatingText.spawn(at, "+%d %s" % [n, String(EconomyDefs.RESOURCES.get(res, {}).get("name", res)).to_lower()], Color(0.95, 0.85, 0.45), false, 1.4)


func _on_enemy_died(e: SandboxEnemy) -> void:
	defeated += 1
	if e.ai_role == "leader":                   # D-082 morale: the bandits around a fallen leader may run
		for o in living_enemies():
			if o.position.distance_to(e.position) <= AiDefs.MORALE_RADIUS:
				o.morale_check()
	if mission_type == "sabotage" and e.job != "totem":
		_fallen_foes.append({"type": e.type_id, "pos": e.position})
	kill_xp += roundi(float(e.base_max_hp) * EnemyDefs.XP_PER_HP)
	var killer = e.get_meta("last_hitter") if e.has_meta("last_hitter") else null
	if killer != null and is_instance_valid(killer) and killer.has_method("credit"):
		killer.credit("kills", 1.0)
	# master prompt A: tower creatures drop their floor's rare materials and keys (LootDefs); creature
	# parts are hunted in the Wilds (D-066). D-120: they also carry gear, and it all stays on the body
	if floor_number > 0:
		var got := LootService.body_loot(floor_number, LootService.creature_rank(e.is_boss, e.ai_role, e.job), ItemLibrary.theme_of(e.type_id),
			int(Game.tower_cleared.get(str(floor_number), 0)) == 0, LootService.greed_bonus(heroes.map(func(x): return x.hero)), _rng, Game._next_uid)
		drop_loot(e.position, got["items"], got["res"])
		return
	var drops: Dictionary = EnemyDefs.DROPS.get(e.type_id, {})
	for res in drops:
		var d: Array = drops[res]
		if _rng.randf() < float(d[0]):
			_add_loot(String(res), _rng.randi_range(int(d[1]), int(d[2])), e)


func _spawn_nodes() -> void:
	if not (map is ProceduralMap):
		return
	for n in (map as ProceduralMap).resource_nodes:
		var def: Dictionary = EconomyDefs.NODES.get(String(n["kind"]), {})
		var amounts := {}
		var rich := DungeonDefs.zone_richness((map as ProceduralMap).zone_of(n["cell"]), -floor_number) if is_wilds() else 1.0
		for res in def.get("res", {}):
			var r: Array = def["res"][res]
			var got := roundi(float(_rng.randi_range(int(r[0]), int(r[1]))) * rich)
			if got > 0:
				amounts[res] = got
		var g := GatherNode.new(String(n["kind"]), amounts)
		g.position = map.center_of(n["cell"])
		g.roll_charges()                             # D-117: 3-6 charges, one per ~5 s cycle
		_world.add_child(g)
		nodes.append(g)


## A hero next to a gathering spot and not fighting collects it (one gatherer at a time).
func _tick_gathering(delta: float) -> void:
	for g in nodes:
		if not is_instance_valid(g) or g.taken:
			continue                                   # gathered spots are freed (crash fix 2026-10-31)
		g.visible = fog == null or fog.is_explored(map.cell_of(g.position))
		var workers: Array = []
		for h in heroes:
			if h.alive and h.target == null and not h.is_casting() and h.position.distance_to(g.position) <= GatherNode.RANGE \
					and (not h.is_controlled() or not _locked() or interact_held):   # D-082: the Master gathers with F
				workers.append(h)
		var got := g.work(delta, workers)            # D-117: one charge per cycle; the spot fades when empty
		if not workers.is_empty():
			var who: SandboxHero = workers[0]
			for res in got:
				_add_loot(String(res), int(got[res]), who)
				who.credit("gathered", float(got[res]))
	nodes.assign(nodes.filter(func(n): return is_instance_valid(n) and not n.taken))


## "" when the squad can escape now (every standing hero near the extraction point), else why not.
func extract_block() -> String:
	if mission_state != Mission.ACTIVE:
		return "the mission is over"
	var at := map.center_of(map.extract_cell)
	var standing := heroes.filter(func(h): return h.alive)
	if standing.is_empty():
		return "nobody is standing"
	for h in standing:
		if h.position.distance_to(at) > EXTRACT_RADIUS * EXTRACT_GATHER:
			return "%s is not at the extraction point" % h.hero.display_name()
	return ""


## Escape (vertical slice): keep what was gathered and dropped, lose the completion reward. Heroes
## lying downed away from the exit cannot be carried out and are lost (D-036 "left behind").
func extract() -> bool:
	if extract_block() != "":
		FloatingText.spawn(heroes[0], extract_block(), Color(1.0, 0.6, 0.5), false, 2.0)
		return false
	var at := map.center_of(map.extract_cell)
	_ending = true
	for h in heroes:
		if h.downed and h.position.distance_to(at) > EXTRACT_RADIUS * EXTRACT_GATHER:
			h.killed_by = "left behind"
			h.die()                              # D-080: the Master is not killed, only lost
	_end_mission(Mission.FAILED if master_lost else Mission.ESCAPED)   # leaving without the Master fails
	return true


func _spawn_encounter(enc: Dictionary) -> void:
	var group: Array = []
	var cells: Array = enc["cells"]
	var tactics := tactics_on()
	var order: Array = []                         # D-083 simulator: config "enemies.count" (1.0 in the game)
	var want := cells.size()
	if not is_equal_approx(SimMode.enemy_count, 1.0):
		want = roundi(float(cells.size()) * SimMode.enemy_count)
		if String(enc["zone"]) == "objective":
			want = maxi(1, want)                     # the goal keeps its boss / first guard
	for i in cells.size():
		var copies := want / cells.size() + (1 if i < want % cells.size() else 0)
		for k in copies:
			order.append(i)
	for i in order:
		var e := _spawn_enemy(cells[i], String(enc["members"][i]))
		e.tactical = tactics
		e.home = e.position
		if is_wilds():
			e.scale_stats(DungeonDefs.zone_strength(String(enc["zone"])))   # deeper = harder
		match String(enc["kind"]):
			"ambush":
				e.dormant = true
				e.visible = false
			"patrol":
				for c in enc["patrol"]:
					e.patrol.append(map.center_of(c))
		group.append(e)
		if String(enc["zone"]) == "objective":
			objective_enemies.append(e)
	for e in group:
		e.group_mates = group
	# D-082: a bandit group (not an ambush) has a horn: one bandit wakes every sleeping camp nearby
	if String(enc["kind"]) != "ambush" and group.size() >= 2:
		for e in group:
			var se := e as SandboxEnemy
			if se.ai_role != "" and se.ai_role != "leader" and se.job == "":
				se.job = "horn"
				break
	# 2026-10-31: in a tactics area every awake pack of CALLER_MIN_PACK+ has a caller (its support, else
	# its last member) that howls for reinforcements unless it dies first
	if tactics and String(enc["kind"]) != "ambush" and String(enc["zone"]) != "objective" and group.size() >= 3:
		var caller: SandboxEnemy = group[group.size() - 1]
		for e in group:
			if (e as SandboxEnemy).role == "support":
				caller = e
		caller.job = "caller"
		caller.called_reinforcements.connect(_on_caller)


## Creatures use tactical targeting, anti-blob aim and callers (data: DungeonDefs.TACTICS / floor "tactics").
func tactics_on() -> bool:
	if is_wilds():
		return DungeonDefs.TACTICS
	return floor_number > 0 and bool(TowerExpedition.get_floor_config(floor_number).get("tactics", false))


func _on_caller(c: SandboxEnemy) -> void:
	var foes: Array = TowerExpedition.get_floor_config(floor_number)["foes"]
	for i in EnemyDefs.CALLER_ADDS:
		var spot := map.nearest_walkable(c.position + Vector2.RIGHT.rotated(TAU * float(i) / float(EnemyDefs.CALLER_ADDS)) * 60.0)
		var e := _spawn_enemy(map.cell_of(spot), String(foes[(i * 2 + 1) % foes.size()]))
		e.tactical = true
		if is_wilds():
			e.scale_stats(DungeonDefs.zone_strength(String((map as ProceduralMap).zone_of(map.cell_of(c.position)))))
		e.alert()
		e.visible = fog == null or fog.is_visible(map.cell_of(e.position))


## D-065 floors with "lookouts": in each awake group (not ambushers, not the goal's guards) its fastest
## member is a lookout: when it sees the squad it runs to warn the nearest other group.
func _assign_lookouts() -> void:
	if floor_number <= 0 or not bool(TowerExpedition.get_floor_config(floor_number).get("lookouts", false)):
		return
	var done := {}
	for e in enemies:
		if done.has(e) or e.dormant or objective_enemies.has(e) or e.group_mates.size() < 2:
			continue
		var fastest: SandboxEnemy = null
		for m in e.group_mates:
			done[m] = true
			if fastest == null or m.speed > fastest.speed:
				fastest = m
		if fastest != null:
			fastest.job = "scout"


var _surround_t: float = 0.0


## D-084: a hero with SURROUND_MIN+ awake foes within SURROUND_RADIUS takes SURROUND_MULT damage (formation
## and pulling one group at a time pay off; charging into a camp does not).
func _update_surrounded(foes: Array) -> void:
	for h in heroes:
		var n := 0
		if h.alive:
			for e in foes:
				if e.alerted and not e.dormant and e.position.distance_to(h.position) <= AiDefs.SURROUND_RADIUS:
					n += 1
		h.surround_mult = AiDefs.SURROUND_MULT if n >= AiDefs.SURROUND_MIN else 1.0


var _spawned: int = 0                            # D-083: spawn order, part of each creature's dice seed


func _spawn_enemy(c: Vector2i, type_id: String) -> SandboxEnemy:
	var e := SandboxEnemy.new()
	e.setup_type(type_id, floor_number)
	e.position = map.center_of(c)
	_spawned += 1
	e.spawn_seed = hash([SimMode.run_seed, floor_number, _spawned])
	if not is_equal_approx(SimMode.enemy_hp, 1.0):          # D-083 simulator multipliers (1.0 in the game)
		e.base_max_hp = maxi(1, roundi(float(e.base_max_hp) * SimMode.enemy_hp))
		e.max_hp = e.base_max_hp
		e.hp = e.max_hp
	if not is_equal_approx(SimMode.enemy_dmg, 1.0):
		e.atk = maxi(1, roundi(float(e.atk) * SimMode.enemy_dmg))
	e.died.connect(_on_enemy_died)
	e.hero_list = heroes
	_world.add_child(e)
	enemies.append(e)
	return e


## Per-floor objective (D-031 floors use the mission type from TowerExpedition).
func _setup_mission() -> void:
	relic.visible = mission_type == "retrieval" or mission_type == "rescue"
	match mission_type:
		"boss":
			if not objective_enemies.is_empty():
				boss = objective_enemies[0]          # v2: the boss waits at the goal with its guards
			elif not enemies.is_empty():
				boss = enemies[0]
			if boss != null:
				boss.make_boss(String(TowerExpedition.get_floor_config(floor_number).get("boss_name", "Orc Chieftain")))
				boss.enrage_after = float(EnemyDefs.BOSS_ENRAGE_AFTER.get(floor_number, 0.0))
				if bool(TowerExpedition.get_floor_config(floor_number).get("altar", false)):
					_setup_altar()
				boss.boss_phase.connect(_on_boss_phase)
				_spawn_shamans()
		"exploration":
			var spread := _clue_rooms()
			if spread.size() >= 3:
				for c in spread:
					var clue := SandboxRelic.new("clue")
					clue.position = map.nearest_walkable(map.center_of(c))
					_world.add_child(clue)
					clues.append(clue)
				return
			var spots: Array[Vector2i] = []
			for c in map.treasure_cells + map.enemy_spawn_cells:
				if not spots.has(c) and Vector2(c).distance_to(Vector2(map.extract_cell)) > 8.0:
					spots.append(c)
			spots.append(map.relic_cell)
			for i in mini(3, spots.size()):
				var clue := SandboxRelic.new("clue")
				clue.position = map.center_of(spots[spots.size() - 1 - i])
				_world.add_child(clue)
				clues.append(clue)
		"sabotage":
			var spots := _clue_rooms()
			for c in spots.slice(0, FloorMods.TOTEMS):
				var t := _spawn_enemy(c, FloorMods.TOTEM_ID)
				t.job = "totem"
				t.enemy_name = "Bandit Totem"
				t.home = t.position
				totems.append(t)
				var guard: Array = [t]
				for gi in FloorMods.TOTEM_GUARDS.size():
					var g := _spawn_enemy(map.cell_of(map.nearest_walkable(t.position + Vector2.RIGHT.rotated(PI * float(gi)) * 50.0)), String(FloorMods.TOTEM_GUARDS[gi]))
					g.tactical = tactics_on()
					g.home = t.position
					guard.append(g)
				for m in guard:
					m.group_mates = guard
		"defense":
			shrine = SandboxRelic.new("shrine")
			# beside the exit portal, not on it (2026-11-02: the stone and the portal were drawn on top of each other)
			shrine.position = map.nearest_walkable(map.center_of(map.extract_cell) + Vector2(-110, 36))
			_world.add_child(shrine)


## Exploration (playtest D4): the three markers lie in three different rooms of the explore, danger and
## objective bands, each as far as possible from the entrance and from the others, so finding them
## means crossing the floor instead of one trip to the goal. Deterministic per floor (no RNG).
func _clue_rooms() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (map is ProceduralMap):
		return out
	var start := Vector2(map.spawn_cells[0]) if not map.spawn_cells.is_empty() else Vector2.ZERO
	var cands: Array[Vector2i] = []
	for z in (map as ProceduralMap).room_zones:
		if String(z["zone"]) != "entrance":
			cands.append((z["rect"] as Rect2i).get_center())
	cands = cands.filter(func(c): return not map.is_blocked_cell(c) and Vector2(c).distance_to(start) > 20.0)
	while out.size() < 3 and not cands.is_empty():
		var best := 0
		var best_score := -INF
		for i in cands.size():
			var p := Vector2(cands[i])
			var score := p.distance_to(start) * (0.5 if out.is_empty() else 0.0)
			var nearest := INF
			for o in out:
				nearest = minf(nearest, p.distance_to(Vector2(o)))
			if not out.is_empty():
				score += nearest
			if score > best_score:
				best_score = score
				best = i
		out.append(cands[best])
		cands.remove_at(best)
	return out


## D-065: the boss fights with shamans beside it. While one lives the boss is "warded" (takes 40% less
## damage) and they heal and shield it (a stun breaks the shield). Kill or stun the shamans first.
var shamans: Array[SandboxEnemy] = []


func _spawn_shamans() -> void:
	var cfg := TowerExpedition.get_floor_config(floor_number)
	var n := int(cfg.get("shamans", EnemyDefs.BOSS_SHAMANS))
	var bandits := BanditArt.has(boss.type_id)
	for i in n:
		var spot := map.nearest_walkable(boss.position + Vector2.RIGHT.rotated(PI * 0.5 + TAU * float(i) / float(n)) * 85.0)
		var s := _spawn_enemy(map.cell_of(spot), "bandido_chaman" if bandits else "mushroom_blue")
		s.tactical = tactics_on()
		s.job = "shaman"
		s.enemy_name = "Bandit Healer" if bandits else "Grove Shaman"
		s.skills = ["ward", "mend"]
		s.home = boss.position
		s.group_mates = boss.group_mates
		boss.group_mates.append(s)
		objective_enemies.append(s)
		shamans.append(s)


func _tick_boss_wards() -> void:
	if boss == null or not boss.alive:
		return
	if shamans.any(func(s): return s.alive):
		boss.apply_status("warded", 0.6)


## #8: the boss calls its warband: creatures around it wake and come, and new ones join beside it.
func _on_boss_phase(b: SandboxEnemy, phase: int) -> void:
	var ph: Dictionary = EnemyDefs.BOSS_PHASES[phase]
	for e in living_enemies():
		if e != b and e.position.distance_to(b.position) <= float(ph["call_radius"]):
			e.alert()
			e.home = b.position                     # guards leave their posts to defend the boss
	var foes: Array = TowerExpedition.get_floor_config(floor_number)["foes"]
	var pool: Array = foes.slice(1) if foes.size() > 1 else foes
	for i in int(ph["adds"]):
		var spot := map.nearest_walkable(b.position + Vector2.RIGHT.rotated(TAU * float(i) / float(ph["adds"]) + 0.4) * 70.0)
		var e := _spawn_enemy(map.cell_of(spot), String(pool[(phase * 3 + i) % pool.size()]))
		e.alert()
		e.visible = fog == null or fog.is_visible(map.cell_of(e.position))
	CombatFeel.shake(b, "medium")


## --- master prompt E: the Crimson Baron's altar (numbers in AltarDefs) ----------------------------
var altars: Array[BaronAltar] = []
var vuln_t: float = 0.0              # seconds of vulnerability left (0 = shielded)
var shield_breaks: int = 0
var _altar_adds_t: float = 0.0
var _altar_slam_t: float = 0.0
var _hint_said: bool = false
var _shield_fx: AnimatedSprite2D = null


func _setup_altar() -> void:
	boss.immune = true
	boss.immune_hit.connect(_on_immune_hit)
	boss.boss_phase.connect(func(_b, _p): pass)
	altars.append(_place_altar(1.0))
	if ResourceLoader.exists("res://assets/fx/bandidos/fx_escudo_altar.png"):
		var tex := load("res://assets/fx/bandidos/fx_escudo_altar.png") as Texture2D
		var sf := SpriteFrames.new()
		sf.set_animation_speed("default", 6.0)
		for i in 4:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 48, 0, 48, 48)
			sf.add_frame("default", at)
		_shield_fx = AnimatedSprite2D.new()
		_shield_fx.sprite_frames = sf
		_shield_fx.scale = Vector2.ONE * 2.0
		_shield_fx.position = Vector2(0, -40)
		boss.add_child(_shield_fx)
		_shield_fx.play("default")


## An altar in a room ALTAR_MIN..MAX cells from the Baron; side = +1 / -1 picks the opposite end.
func _place_altar(side: float) -> BaronAltar:
	var best := map.center_of(map.relic_cell)
	var best_score := -INF
	var bc := map.cell_of(boss.position)
	var r := RandomNumberGenerator.new()
	r.seed = hash(floor_number) + altars.size() * 31 + int(elapsed)
	if map is ProceduralMap:
		for z in (map as ProceduralMap).room_zones:
			var c: Vector2i = (z["rect"] as Rect2i).get_center()
			var d := Vector2(c).distance_to(Vector2(bc))
			if map.is_blocked_cell(c) or d < AltarDefs.ALTAR_MIN_CELLS or d > AltarDefs.ALTAR_MAX_CELLS:
				continue
			var score := r.randf() + (side * float(c.x - bc.x) / 40.0)
			for a in altars:
				score += Vector2(c).distance_to(Vector2(map.cell_of(a.position))) / 20.0
			if score > best_score:
				best_score = score
				best = map.center_of(c)
	var altar := BaronAltar.new()
	altar.position = map.nearest_walkable(best)
	altar.boss = boss
	altar.heroes = heroes
	_world.add_child(altar)
	Ambience.add_light(_world, altar.position, Color(1.0, 0.2, 0.15), 90, true)
	return altar


func _altar_tick(delta: float) -> void:
	if boss == null or not boss.alive or altars.is_empty():
		return
	var frac := float(boss.hp) / float(maxi(1, boss.max_hp))
	if vuln_t > 0.0:
		vuln_t -= delta
		_altar_slam_t -= delta
		if _altar_slam_t <= 0.0:
			_altar_slam_t = AltarDefs.SLAM_EVERY
			boss.force_area(altars[0].position)
		if vuln_t <= 0.0:
			boss.immune = true                          # the shield comes back
			FloatingText.spawn(boss, "The shield returns!", Color(1.0, 0.35, 0.3), true, 2.0)
			for a in altars:
				a.done = false
			if frac < AltarDefs.PHASE3_AT:                 # phase 3: the altar moves after each window
				var old: BaronAltar = altars[0]
				altars[0] = _place_altar(1.0 if (hash([floor_number, int(elapsed), altars.size(), SimMode.run_seed]) & 1) == 0 else -1.0)   # D-083: seeded, was randf()
				old.queue_free()
	else:
		if frac < AltarDefs.PHASE2_AT and altars.size() < 2 and frac >= AltarDefs.PHASE3_AT:
			altars.append(_place_altar(-1.0))           # phase 2: a second altar on the far side
		elif frac < AltarDefs.PHASE3_AT and altars.size() > 1:
			altars.pop_back().queue_free()
		for a in altars:
			a.tick_channel(delta)
		var need := altars.size() if AltarDefs.BOTH_REQUIRED else 1
		if altars.filter(func(a): return a.done).size() >= need:
			vuln_t = AltarDefs.VULN_TIME
			shield_breaks += 1
			_altar_slam_t = 1.5
			boss.immune = false
			FloatingText.spawn(boss, "The shield breaks!", Color(1.0, 0.85, 0.4), true, 2.0)
	if _shield_fx != null:
		_shield_fx.visible = boss.immune
		_shield_fx.modulate.a = 0.6 + 0.4 * altars[0].pulse()
	# the Baron sends adds to the altar (more often while someone channels)
	_altar_adds_t -= delta * (2.0 if altars.any(func(a): return a.progress > 0.0) else 1.0)
	if _altar_adds_t <= 0.0 and boss.alerted:
		_altar_adds_t = AltarDefs.ADDS_EVERY
		var target: BaronAltar = altars[0]
		for i in AltarDefs.ADDS:
			var spot := map.nearest_walkable(target.position + Vector2.RIGHT.rotated(TAU * float(i) / float(AltarDefs.ADDS) + 0.7) * 120.0)
			var e := _spawn_enemy(map.cell_of(spot), String(AltarDefs.ADD_TYPES[i % AltarDefs.ADD_TYPES.size()]))
			e.tactical = true
			e.home = target.position
			e.alert()
			e.visible = fog == null or fog.is_visible(map.cell_of(e.position))


## A hero says it once per attempt, the first time the shield eats a blow (master prompt E hint).
func _on_immune_hit() -> void:
	if _hint_said:
		return
	_hint_said = true
	var standing := living_heroes()
	if standing.is_empty():
		return
	var h: SandboxHero = standing[0]
	var line := String(AltarDefs.HERO_LINES["default"])
	for t in h.hero.traits:
		if AltarDefs.HERO_LINES.has(String(t)):
			line = String(AltarDefs.HERO_LINES[String(t)])
			break
	h.say(line, 4.5)


## --- master prompt D: sabotage (FloorMods) --------------------------------------------------
var totems: Array[SandboxEnemy] = []
var _fallen_foes: Array = []         # [{type, pos}] bandits that died (a totem can raise them)
var _revive_t: float = FloorMods.REVIVE_EVERY


func _revive_tick(delta: float) -> void:
	_revive_t -= delta
	if _revive_t > 0.0:
		return
	_revive_t = FloorMods.REVIVE_EVERY
	for t in totems:
		if not t.alive:
			continue
		for i in _fallen_foes.size():
			var f: Dictionary = _fallen_foes[i]
			if (f["pos"] as Vector2).distance_to(t.position) <= FloorMods.REVIVE_RADIUS:
				_fallen_foes.remove_at(i)
				var e := _spawn_enemy(map.cell_of(f["pos"]), String(f["type"]))
				e.tactical = tactics_on()
				e.alert()
				e.visible = fog == null or fog.is_visible(map.cell_of(e.position))
				FloatingText.spawn(e, "Risen by the totem!", Color(0.9, 0.4, 1.0), false, 1.4)
				break


## D-077 secret objective: a hidden cache in the room furthest from the goal and the entrance. It is
## invisible until a hero walks close; taking it and then completing the floor counts as the secret
## (bonus XP, ProgressionDefs.SECRET_MULT, and a tiny chance at a unique, ItemLibrary.UNIQUE_CHANCE).
var secret_done := false
var secret: SandboxRelic = null
const SECRET_SEE := 70.0


func _place_secret() -> void:
	if floor_number <= 0 or not (map is ProceduralMap):
		return
	var best := Vector2.INF
	var best_s := -INF
	var start := map.center_of(map.spawn_cells[0]) if not map.spawn_cells.is_empty() else Vector2.ZERO
	var goal := map.center_of(map.relic_cell)
	for z in (map as ProceduralMap).room_zones:
		var c := map.center_of((z["rect"] as Rect2i).position + Vector2i(1, 1))
		if map.is_blocked_cell(map.cell_of(c)):
			continue
		var s := minf(c.distance_to(start), c.distance_to(goal))
		if s > best_s:
			best_s = s
			best = c
	if best == Vector2.INF:
		return
	secret = SandboxRelic.new("relic")
	secret.position = best
	secret.visible = false
	secret.modulate = Color(1.0, 0.85, 0.4)
	_world.add_child(secret)


func _secret_tick() -> void:
	if secret == null or secret_done:
		return
	for h in heroes:
		if h.alive and h.position.distance_to(secret.position) <= SECRET_SEE:
			if not secret.visible:
				secret.visible = true
			elif h.position.distance_to(secret.position) <= PICKUP_RADIUS:
				secret_done = true
				secret.visible = false
				h.credit("objective", 2.0)
				FloatingText.spawn(h, "A secret!", Color(1.0, 0.85, 0.4), true, 2.0)


## Defense: seconds at the shrine (a floor may set "hold_time"; else HOLD_TIME).
## D-084: survival length per floor (floor 9 was 75 s: won without a fight).
func survive_time() -> float:
	return float(TowerExpedition.get_floor_config(floor_number).get("survive_time", SURVIVE_TIME)) if floor_number > 0 else SURVIVE_TIME


func hold_time() -> float:
	return float(TowerExpedition.get_floor_config(floor_number).get("hold_time", HOLD_TIME)) if floor_number > 0 else HOLD_TIME


## Master prompt D: one floor modifier from floor 3 (data: the floor's "modifier", numbers in FloorMods).
var modifier: String = ""


## D-079 soft block: computed once when the squad enters (PowerCalc.floor_effect): damage multipliers when
## the squad is short of what the floor expects, and how strong the modifier still is for each hero
## (1 = in full; less when the hero carries the town's counter or a gift covers it).
var soft_block: Dictionary = {}


func _apply_modifier() -> void:
	modifier = String(TowerExpedition.get_floor_config(floor_number).get("modifier", "")) if floor_number > 0 else ""
	var strength: Array = []
	if floor_number > 0:
		soft_block = PowerCalc.floor_effect(floor_number, heroes.map(func(h): return h.hero), Game.town_buildings)
		strength = soft_block["strength"]
		for h in heroes:
			h.soft_in = float(soft_block["taken"])
			h.soft_out = float(soft_block["dealt"])
	var avg := 1.0
	if not strength.is_empty():
		avg = 0.0
		for v in strength:
			avg += float(v) / float(strength.size())
	match modifier:
		"fog":
			for i in heroes.size():
				heroes[i].vision_mod = -roundi(float(FloorMods.FOG_VISION) * (float(strength[i]) if i < strength.size() else 1.0))
		"no_heal":
			for i in heroes.size():
				var st := float(strength[i]) if i < strength.size() else 1.0
				heroes[i].heal_block = st >= 1.0
				heroes[i].heal_mult = 1.0 - st
		"enrage":
			for e in enemies:
				e.enrage_low = true
				e.enrage_atk = 1.0 + (FloorMods.ENRAGE_ATK - 1.0) * avg
		"hazard":
			for i in heroes.size():
				heroes[i].poison_mult = float(strength[i]) if i < strength.size() else 1.0
			if map is ProceduralMap:
				var r := RandomNumberGenerator.new()
				r.seed = (map as ProceduralMap).seed_value + 9
				var rooms: Array = (map as ProceduralMap).room_zones.filter(func(z): return String(z["zone"]) != "entrance")
				for i in mini(FloorMods.HAZARD_ZONES, rooms.size()):
					var rc: Rect2i = (rooms[r.randi() % rooms.size()] as Dictionary)["rect"]
					var at := map.nearest_walkable(map.center_of(rc.position + Vector2i(r.randi_range(1, maxi(1, rc.size.x - 2)), r.randi_range(1, maxi(1, rc.size.y - 2)))))
					CombatZone.spawn(_world, at, FloorMods.HAZARD_RADIUS, 1e9, "poison", FloorMods.HAZARD_DUR, FloorMods.HAZARD_MAG, heroes, null)


## D-066: a run in the repeatable Wilds (negative floor numbers are its tiers).
func is_wilds() -> bool:
	return floor_number < 0


func mission_title() -> String:
	return String(MISSION_TITLES.get(mission_type, MISSION_NAME))


func _spawn_wave() -> void:
	# bug fix (full playthrough): the cap counted the floor's own creatures too, so a floor with 40 of
	# them never got a wave; it now counts only the living wave creatures
	_wave_live = _wave_live.filter(func(e): return is_instance_valid(e) and e.alive)
	var cap := int(TowerExpedition.get_floor_config(floor_number).get("wave_cap", WAVE_MAX_ALIVE)) if floor_number > 0 else WAVE_MAX_ALIVE
	if _wave_live.size() >= cap or map.enemy_spawn_cells.is_empty():
		return
	# master prompt D (protection): waves grow and march on the objective (the shrine, else the squad)
	_wave_n += 1
	var cfg := TowerExpedition.get_floor_config(floor_number) if floor_number > 0 else {}
	var size := int(cfg.get("wave_base", 2)) + int(float(_wave_n) * float(cfg.get("wave_growth", 0.0)))
	var target := shrine.position if shrine != null else _centre_of_squad()
	# bug fix (full playthrough): waves came from the far end and never reached the shrine in time;
	# they now enter from spawn spots WAVE_NEAR..WAVE_FAR cells away from what they attack
	var tc := map.cell_of(target)
	var near: Array = map.enemy_spawn_cells.filter(func(c): var d := Vector2(c).distance_to(Vector2(tc)); return d >= WAVE_NEAR and d <= WAVE_FAR)
	if near.is_empty():
		near = map.enemy_spawn_cells
	for i in size:
		var c: Vector2i = near[_rng.randi() % near.size()]
		var e := _spawn_enemy(c, TowerExpedition.foe_for(floor_number, _rng.randi()))
		_wave_live.append(e)
		if cfg.has("wave_base"):
			e.tactical = true
			e.home = target
			e.alert()


var _wave_n: int = 0
var _wave_live: Array = []
const WAVE_NEAR := 8.0                           # cells
const WAVE_FAR := 20.0


func _centre_of_squad() -> Vector2:
	var live := living_heroes()
	var c := Vector2.ZERO
	for h in live:
		c += h.position / float(maxi(1, live.size()))
	return c


## "Clear the floor" (playtest B6): the last creatures can be ambushers, hidden until a hero walks next
## to them, even in rooms already explored, so a first-time player could not find them. When only
## REVEAL_LAST are left, or every creature left is a sleeping ambusher, they are marked on the minimap
## (their position, not their sight).
const REVEAL_LAST := 3


func revealed_enemies() -> Array:
	if mission_type != "combat" or mission_state != Mission.ACTIVE:
		return []
	var live := living_enemies()
	return live if live.size() <= REVEAL_LAST or live.all(func(e): return e.dormant) else []


func living_heroes() -> Array:
	return heroes.filter(func(h): return h.alive)


func living_enemies() -> Array:
	return enemies.filter(func(e): return e.alive)


## Creatures the squad can see right now (fog of war): what heroes target and what can be clicked.
func visible_enemies() -> Array:
	return enemies.filter(func(e): return e.alive and e.visible)


## Shared context for autonomy, refreshed every SCOUT_EVERY seconds: the squad centre (where hurt
## heroes fall back to) and, for idle explorers with no foe in sight, the nearest unexplored spot within
## reach of them and of the driven hero (they scout, they do not wander off alone).
func _direct_autonomy() -> void:
	_update_explored_rect()
	var alive := heroes.filter(func(h): return h.alive)
	if alive.is_empty():
		return
	var centre := Vector2.ZERO
	for h in alive:
		centre += h.position
	centre /= float(alive.size())
	var danger := not visible_enemies().is_empty()
	for h in alive:
		h.rally_point = centre
		if danger or h.is_controlled() or h.order != "auto" or not h.is_explorer() or h.is_moving() or fog == null:
			continue
		var spot := _fog_frontier(map.cell_of(h.position))
		var leash_from: Vector2 = h.anchor.position if h.anchor != null else centre
		if spot != Vector2.INF and spot.distance_to(leash_from) <= h.leash() + 140.0:
			h.explore_goal = spot


## Nearest walkable cell (breadth-first over walkable cells, up to SCOUT_REACH) next to never-seen fog.
func _fog_frontier(from: Vector2i) -> Vector2:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if seen.has(n) or absi(n.x - from.x) > SCOUT_REACH or absi(n.y - from.y) > SCOUT_REACH:
				continue
			seen[n] = true
			if not fog.is_explored(n):
				return map.center_of(c)
			if not map.is_blocked_cell(n):
				queue.append(n)
	return Vector2.INF


## Recomputes sight from the heroes (never from the camera) and shows only creatures in sight.
func update_fog() -> void:
	if fog == null:
		return
	var viewers: Array = []
	var lookers: Array = []
	for h in heroes:
		if not h.dead:
			viewers.append([map.cell_of(h.position), h.vision_cells()])
			lookers.append(h)
	var found: Array = fog.update(viewers, map)
	for i in lookers.size():
		lookers[i].credit("explored", float(found[i]))
	for e in enemies:
		if e.alive:
			e.visible = not e.dormant and (fog_off or fog.is_visible(map.cell_of(e.position)) or e.spotted_t > 0.0)   # D-082 spotted
	if _fog_view != null:
		_fog_view.visible = not fog_off
		_fog_view.refresh()


func _build_ui() -> void:
	if SimMode.on:                               # D-083 headless simulator: no HUD (labels only, never shown)
		_info = Label.new()
		_squad_label = Label.new()
		add_child(_info)
		add_child(_squad_label)
		_info.visible = false
		_squad_label.visible = false
		return
	Ambience.add_vignette(self)                  # phase 8: under the HUD, over the world
	# D-063: the expedition HUD (party, skills, orders, objective, minimap, boss). The old text panel lives
	# on as the Details panel (I): _info and _squad_label are refreshed as before.
	_info = UIKit.label("", 14, UIKit.TEXT)
	_info.custom_minimum_size = Vector2(240, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_squad_label = UIKit.label("", 12, UIKit.MUTED)
	_squad_label.custom_minimum_size = Vector2(240, 0)
	_edges = EdgeIndicators.new(self)                # D-082b: off-screen heroes and pings, under the HUD
	add_child(_edges)
	_hud = ExpeditionHud.new(self)
	add_child(_hud)

	_band = ColorRect.new()
	_band.color = Color(ArtPalette.GREEN[3], 0.22)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.visible = false
	add_child(_band)
	UIKit.music("boss" if mission_type == "boss" else ("explore" if floor_number != 0 else "battle"))


## Esc / the menu button: options and a way out, the expedition keeps running (D-062, D-014).
func open_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.close()
		return
	_menu = GameMenu.new()
	_menu.leave_label = "Leave (the squad abandons the floor)" if mission_state == Mission.ACTIVE and floor_number != 0 else "Back to the town"
	_menu.leave_requested.connect(func(_to): back_requested.emit())
	add_child(_menu)


## Hovering a skill in the HUD shows its reach (and area at the mouse) for the hero in focus.
func preview_skill(slot: int) -> void:
	_preview_slot = slot
	if slot >= 0 and _aim_view == null:
		_aim_view = SkillAimView.new()
		_world.add_child(_aim_view)


## Minimap click: look at a point for a few seconds (camera only; orders and focus unchanged).
func look_at_world(p: Vector2) -> void:
	overview = false
	_look_at = p
	_look_t = LOOK_HOLD


# --- selection / camera commands (public so tests and a future HUD can call them) ----------

func select_only(list: Array) -> void:
	if _locked():
		list = [master_hero]                     # D-082: with a Master only the Master takes direct orders
	selected.clear()
	for h in heroes:
		h.selected = h.alive and list.has(h) and h.obeys()      # D-051: no obedience, no orders
		if h.selected:
			selected.append(h)
		elif h.alive and list.has(h) and not h.obeys():
			_refuse_command(h)
	_refresh_info()


## D-051: a hero below the obedience threshold ignores the command and says so.
func _refuse_command(h: SandboxHero) -> void:
	FloatingText.spawn(h, "ignores you (Obedience %d)" % h.hero.obedience, Color(1.0, 0.6, 0.4), false, 1.6)


## Space: the driven hero dashes the way it is moving (or to the cursor when standing still); in group
## view every selected hero dashes toward the cursor.
func dash_selected() -> void:
	var cursor := screen_to_world(get_local_mouse_position())
	var c := controlled()
	var who: Array = [c] if c != null else heroes.filter(func(h): return h.selected and h.alive)
	for h in who:
		var dir: Vector2 = h.velocity if h.velocity.length() > 5.0 else cursor - h.position
		if dir.length() < 4.0:                       # cursor on the hero: dash the way it faces
			dir = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(h.facing, Vector2.DOWN)
		h.dash(dir)


## The hero the player drives right now (D-053), or null in group view.
func controlled() -> SandboxHero:
	for h in heroes:
		if h.is_controlled():
			return h
	return null


func _set_controlled(h: SandboxHero) -> void:
	for o in heroes:
		o.controller = "player" if o == h else "ai"
		o.anchor = h if o != h else null


## D-053: 1-5 (Shift+1-5 = heroes 6-10 in a raid) focuses AND takes direct control of that hero.
## Same hero, same skills, cooldowns and rules: only who decides changes. Refused, with the reason, for
## an empty/fallen slot or a hero without obedience (D-051).
func select_slot(i: int) -> void:
	if i < 0 or i >= heroes.size():
		return
	var h := heroes[i]
	if _locked() and h != master_hero:
		set_ping_target(h)                       # D-082: a portrait click picks who the next ping is for
		return                                   # D-080: with a Master in the squad only the Master is driven
	if not h.alive:
		if h.downed or h.dead:
			FloatingText.spawn(h, "down" if h.downed else "fallen", Color(0.8, 0.8, 0.8), false)
		return
	if not h.obeys():
		_refuse_command(h)
		return
	overview = false
	select_only([h])
	follow_slot = i
	_set_controlled(h)


func select_all() -> void:
	select_only(heroes)


func group_view() -> void:
	follow_slot = -1
	# everybody back to autonomy; D-080: except the Master, who stays driven while standing
	_set_controlled(master_hero if _locked() and master_hero.alive else null)


## D-080: true when the squad has a Master, so control never leaves them (MasterDefs.DEBUG_HERO_SWITCH
## brings back the 1-5 switch of D-053; squads without a Master, like the test squad, keep it).
func _locked() -> bool:
	return master_hero != null and not MasterDefs.DEBUG_HERO_SWITCH


## Pure data: where the camera wants to be. update_camera() eases toward it each frame.
## Pure data: where the camera wants to be (FeelCamera eases toward it). D-082b: the zoom is the player's
## whole step only (never changed by the camera itself); the followed unit is framed above the HUD.
func update_camera_targets() -> void:
	if heroes.is_empty():
		return
	camera_zoom_target = float(CameraDefs.ZOOM_STEPS[cam_zoom_i])
	if _look_t > 0.0 and _look_at != Vector2.INF:
		camera_target = _look_at
		return
	if overview:
		var ws: Vector2 = map.world_size()
		var vs := Vector2(_viewport.size) if _viewport != null and _viewport.size.x > 0 else Vector2(640, 360)
		camera_target = ws * 0.5
		camera_zoom_target = minf(vs.x / ws.x, vs.y / ws.y)        # M: whole-map view, asked by the player
		return
	if center_held:
		camera_target = _framed(camera_focus_unit())
		return
	match cam_mode:
		"free":
			camera_target = cam_free_pos
		"follow":
			if cam_follow >= 0 and cam_follow < heroes.size() and not heroes[cam_follow].dead:
				camera_target = _framed(heroes[cam_follow])
			else:
				cam_mode = "locked"
				camera_target = _framed(camera_focus_unit())
		_:
			camera_target = _framed(camera_focus_unit())


## Who the locked camera follows: the Master; without one (test squads) the driven / focused hero, else
## the first one still on the map.
func camera_focus_unit() -> SandboxHero:
	if master_hero != null:
		return master_hero
	if follow_slot >= 0 and follow_slot < heroes.size():
		return heroes[follow_slot]
	var c := controlled()
	if c != null:
		return c
	for h in heroes:
		if not h.dead:
			return h
	return heroes[0]


## Camera centre that shows `u` centred in the part of the screen the HUD does not cover, a little ahead of
## where it walks, and never closer than CameraDefs.BOTTOM_MIN of the screen height to the bottom of it.
func _framed(u: SandboxHero) -> Vector2:
	var z := maxf(0.05, camera_zoom_target)
	var view := Vector2(_viewport.size) if _viewport != null and _viewport.size.x > 0 else Vector2(640, 360)
	var hud := hud_bottom()
	var lead := (u.velocity * CameraDefs.LOOK_AHEAD).limit_length(CameraDefs.LOOK_AHEAD_MAX)
	var c := u.position + Vector2(0, -12) + lead + Vector2(0, hud * 0.5 / z)
	# the unit's place on screen: y_screen = view.y / 2 + (u.y - c.y) * z; keep it inside the safe band
	var lo := view.y * CameraDefs.BOTTOM_MIN
	var hi := view.y - hud - view.y * CameraDefs.BOTTOM_MIN
	var ys := view.y * 0.5 + (u.position.y - c.y) * z
	if hi > lo:
		ys = clampf(ys, lo, hi)
	c.y = u.position.y - (ys - view.y * 0.5) / z
	return c


## Height of the HUD band at the bottom of the screen (canvas pixels; 0 without a HUD).
func hud_bottom() -> float:
	return _hud.bottom_inset() if _hud != null and is_instance_valid(_hud) and _hud.visible else 0.0


func world_to_screen(p: Vector2) -> Vector2:
	var view := Vector2(_viewport.size) if _viewport != null else size
	return (p - camera.position - camera.offset) * camera.zoom.x + view * 0.5


## Y: locked on the Master <-> free. Switching to free starts where the camera is.
func toggle_camera_mode() -> void:
	if cam_mode == "locked":
		cam_mode = "free"
		cam_free_pos = camera.position
	else:
		cam_mode = "locked"
	cam_follow = -1


## F1-F5: centres the camera on that party member (F1 = the Master); a double tap follows them until the
## camera is moved, Y or the centre key. The press time comes from the caller (tests pass their own).
func camera_hero_key(slot_i: int, now: float = -1.0) -> void:
	if slot_i < 0 or slot_i >= heroes.size() or heroes[slot_i].dead:
		return
	if now < 0.0:
		now = Time.get_ticks_msec() / 1000.0
	var last := float(_hero_tap.get(slot_i, -99.0))
	_hero_tap[slot_i] = now
	overview = false
	_look_t = 0.0
	if now - last <= CameraDefs.DOUBLE_TAP:
		cam_mode = "follow"
		cam_follow = slot_i
		return
	cam_mode = "free"
	cam_follow = -1
	cam_free_pos = _framed(heroes[slot_i])


## Moves the free camera (edges, arrows, middle drag) and keeps it on the map and near what the party
## has explored (the fog is respected: it never shows unexplored ground far away).
func camera_pan(world_delta: Vector2) -> void:
	if cam_mode != "free":
		cam_mode = "free"
		cam_free_pos = camera.position
	cam_follow = -1
	cam_free_pos = _clamp_free(cam_free_pos + world_delta)


## Jumps the camera to a world point (minimap, edge markers).
func camera_jump(p: Vector2) -> void:
	cam_mode = "free"
	cam_follow = -1
	cam_free_pos = _clamp_free(p)


func _clamp_free(p: Vector2) -> Vector2:
	var r := Rect2(Vector2.ZERO, map.world_size())
	if _explored_rect.size.x > 0.0:
		r = r.intersection(_explored_rect)
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


## Bounding box of the explored cells (+ CameraDefs.EXPLORED_MARGIN), refreshed with the autonomy pass.
func _update_explored_rect() -> void:
	if fog == null:
		_explored_rect = Rect2()
		return
	var lo := Vector2i(map.width, map.height)
	var hi := Vector2i(-1, -1)
	for y in map.height:
		for x in map.width:
			if fog.is_explored(Vector2i(x, y)):
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	if hi.x < 0:
		_explored_rect = Rect2()
		return
	var m := CameraDefs.EXPLORED_MARGIN
	_explored_rect = Rect2(map.center_of(lo - Vector2i(m, m)), Vector2(hi - lo + Vector2i(2 * m, 2 * m)) * float(NavMap.CELL))


func _free_camera_input(delta: float) -> void:
	if DevCommands.console_open:
		return                                   # D-146: the arrows browse the console history
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if cam_mode == "free" and get_window() != null and get_window().has_focus() and not DisplayServer.get_name().begins_with("headless"):
		var mp := get_local_mouse_position()
		var e := CameraDefs.EDGE_PX
		if Rect2(Vector2.ZERO, size).has_point(mp):
			if mp.x <= e:
				dir.x -= 1.0
			elif mp.x >= size.x - e:
				dir.x += 1.0
			if mp.y <= e:
				dir.y -= 1.0
			elif mp.y >= size.y - e:
				dir.y += 1.0
	if dir != Vector2.ZERO:
		camera_pan(dir.normalized() * CameraDefs.PAN_SPEED * delta / maxf(0.05, camera.zoom.x))


func screen_to_world(p: Vector2) -> Vector2:
	var view := Vector2(_viewport.size)
	return camera.position + camera.offset + (p - view * 0.5) / camera.zoom.x      # offset = screen shake


var _arming_attack_move: bool = false


## A: the next left click is an attack-move destination.
func arm_attack_move() -> void:
	_arming_attack_move = not selected.is_empty()


func attack_move_selected(world_point: Vector2) -> void:
	var n := selected.size()
	for i in n:
		var offset := Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(TAU * float(i - 1) / float(maxi(1, n - 1))) * FORMATION_RADIUS
		if not selected[i].order_attack_move(world_point + offset, map):
			FloatingText.spawn(selected[i], "can't reach", Color(1.0, 0.6, 0.4), false)
	_mark(world_point, Color(1.0, 0.6, 0.3))


func hold_selected() -> void:
	for h in selected:
		h.order_hold()
		_mark(h.position, Color(0.6, 0.8, 1.0))


## F: the selection follows the focused hero (key 1-5), else the first living hero not selected.
func follow_selected() -> void:
	var leader: SandboxHero = heroes[follow_slot] if follow_slot >= 0 and follow_slot < heroes.size() else null
	if leader == null or not leader.alive or selected.size() == 1 and selected[0] == leader:
		leader = null
		for h in heroes:
			if h.alive and not selected.has(h):
				leader = h
				break
	if leader == null:
		for h in selected:
			FloatingText.spawn(h, "no one to follow", Color(1.0, 0.6, 0.4), false)
		return
	for h in selected:
		if h != leader:
			h.order_follow(leader)


## C: the selection gathers around its centre, then goes back to Auto.
func regroup_selected() -> void:
	var live := selected.filter(func(h): return h.alive)
	if live.is_empty():
		return
	var c := Vector2.ZERO
	for h in live:
		c += h.position
	c /= float(live.size())
	order_move_selected(map.nearest_walkable(c))
	_mark(c, Color(0.6, 1.0, 0.6))


## X: run to the extraction point, no fighting on the way. #14 of the playtest: escaping used to leave
## every downed ally behind (they die, D-036). Now each retreating hero first picks up the nearest fallen
## ally within RETREAT_PICKUP (not one another hero is already helping), then both run for the exit.
const RETREAT_PICKUP := 260.0


func retreat_selected() -> void:
	var exit := map.center_of(map.extract_cell)
	var taken: Array = heroes.filter(func(x): return x.rescue_target != null).map(func(x): return x.rescue_target)
	for i in selected.size():
		var h: SandboxHero = selected[i]
		var offset := Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(1, selected.size()))) * 26.0
		if h.rescue_target != null and h.then_retreat != Vector2.INF:
			continue                              # already picking someone up on the way out (X pressed again)
		var fallen_ally: SandboxHero = null
		for d in heroes:
			if _locked() and h == master_hero:
				break                                # D-082: the Master lifts allies with F, never on its own
			if d.downed and not d.dead and not taken.has(d) and d.position.distance_to(h.position) <= RETREAT_PICKUP \
					and (fallen_ally == null or d.position.distance_to(h.position) < fallen_ally.position.distance_to(h.position)):
				fallen_ally = d
		if fallen_ally != null:
			taken.append(fallen_ally)
			h.order_rescue(fallen_ally)
			h.then_retreat = exit + offset
			continue
		if not h.order_retreat(exit + offset, map):
			FloatingText.spawn(h, "no way out", Color(1.0, 0.6, 0.4), false)
	_mark(exit, Color(0.4, 1.0, 0.7))


## T (D-065): the selected heroes use their skills on their own, or only when the player presses W/E/R.
## Lets the player keep a healer's mana or a stun for the right moment, and leave the rest free.
func toggle_auto_skills() -> void:
	var live := selected.filter(func(h): return h.alive)
	if live.is_empty():
		return
	var on := not live.all(func(h): return h.auto_skills)
	for h in live:
		h.auto_skills = on
		FloatingText.spawn(h, "skills: %s" % ("auto" if on else "manual"), Color(0.8, 0.9, 1.0), false)


func order_move_selected(world_point: Vector2) -> void:
	var n := selected.size()
	for i in n:
		var offset := Vector2.ZERO
		if n > 1 and i > 0:
			offset = Vector2.RIGHT.rotated(TAU * float(i - 1) / float(n - 1)) * FORMATION_RADIUS
		var p := map.find_path(selected[i].position, world_point + offset)
		if selected[i].dev_fly:
			p.clear()
			p.append(world_point + offset)                # D-146 /fly: any point, walls included
		if p.is_empty():
			FloatingText.spawn(selected[i], "can't reach", Color(1.0, 0.6, 0.4), false)
		selected[i].order_move(p)


## Right-click: on an enemy = attack it, on a downed ally = rescue (nearest selected hero goes),
## on the ground = move. Returns the order given ("attack" | "rescue" | "move" | "").
func order_context(world_point: Vector2) -> String:
	if selected.is_empty():
		return ""
	if controlled() != null and selected.size() == 1 and selected[0].is_controlled():
		order_move_selected(world_point)          # D-059: the driven hero only moves on right click
		_mark(world_point, Color(1, 1, 1))
		return "move"
	var foe: SandboxEnemy = null
	var foe_d := INF
	for e in visible_enemies():                 # the click area follows the body; hidden foes cannot be clicked
		var d: float = e.pick_distance(world_point)
		if d <= 0.0 and (foe == null or e.position.distance_to(world_point) < foe_d):
			foe = e
			foe_d = e.position.distance_to(world_point)
	if foe != null:
		for h in selected:
			h.order_attack(foe)
		_mark(foe.position, Color(1.0, 0.35, 0.3))
		return "attack"
	for ally in heroes:
		if ally.downed and ally.position.distance_to(world_point) <= 30.0:
			var best: SandboxHero = null
			for h in selected:
				if h.alive and (best == null or h.position.distance_to(ally.position) < best.position.distance_to(ally.position)):
					best = h
			if best != null:
				best.order_rescue(ally)
				_mark(ally.position, Color(0.5, 1.0, 0.6))
				return "rescue"
	order_move_selected(world_point)
	_mark(world_point, Color(1, 1, 1))
	return "move"


# --- D-082 pings ----------------------------------------------------------------------------------

## The next ping goes only to `h` (clicking the same portrait again: back to the whole party).
func set_ping_target(h: SandboxHero) -> void:
	ping_to = null if ping_to == h or h == null or not h.alive else h
	if ping_to != null:
		FloatingText.spawn(ping_to, "listening", Color(0.8, 0.95, 1.0), false, 1.0)


## Shift + click: what the click is on decides the ping (enemy = attack, gathering spot = gather, fallen
## ally = help, anything else = go there).
func quick_ping(world_point: Vector2) -> int:
	var foe := _foe_at(world_point)
	if foe != null:
		return ping("attack", world_point, foe)
	if _downed_at(world_point) != null:
		return ping("help", world_point)
	if _node_at(world_point) != null:
		return ping("gather", world_point)
	return ping("move", world_point)


func _foe_at(p: Vector2) -> SandboxEnemy:
	var foe: SandboxEnemy = null
	for e in visible_enemies():
		if e.pick_distance(p) <= 0.0 and (foe == null or e.position.distance_to(p) < foe.position.distance_to(p)):
			foe = e
	return foe


func _downed_at(p: Vector2) -> SandboxHero:
	for h in heroes:
		if h.downed and not h.dead and not h.lost and h.position.distance_to(p) <= 34.0:
			return h
	return null


func _node_at(p: Vector2) -> GatherNode:
	var best: GatherNode = null
	for g in nodes:
		if is_instance_valid(g) and not g.taken and g.visible and g.position.distance_to(p) <= 48.0 \
				and (best == null or g.position.distance_to(p) < best.position.distance_to(p)):
			best = g
	return best


## Sends a ping (AiDefs.PINGS) to the party, or to ping_to only. Each recipient answers with a short line
## and obeys after a delay (personality, inside/outside the Master's Leadership radius), or says no when its
## Obedience (effective, minus the spam penalty) is below CombatRules.OBEY_MIN. Deterministic, never a roll
## (D-016). Spamming pings lowers everyone's Obedience for a while. Returns how many will obey.
func ping(kind: String, world_point: Vector2, foe: SandboxEnemy = null) -> int:
	if not AiDefs.PINGS.has(kind) or mission_state != Mission.ACTIVE:
		return 0
	if kind == "camp" and start_camp(world_point) != "":
		return 0                                     # D-090: no kit, or creatures too close (it says why)
	if kind in ["attack", "spotted"] and foe == null:
		foe = _foe_at(world_point)
	var ally: SandboxHero = _downed_at(world_point) if kind == "help" else null
	_count_ping()
	pings_sent += 1
	var marker := PingMarker.make(kind, foe.position if foe != null else world_point, foe)
	_world.add_child(marker)
	markers.append(marker)
	markers = markers.filter(func(m): return is_instance_valid(m))
	if kind == "spotted" and foe != null:
		foe.spotted_t = AiDefs.SPOTTED_TIME                  # everyone sees it through the fog for a while
		foe.visible = true
	var to: Array = [ping_to] if ping_to != null and ping_to.alive else heroes.filter(func(x): return x.alive and x != master_hero)
	ping_to = null
	var obeyed := 0
	for h in to:
		if h == master_hero or not h.alive:
			continue
		var ans := ping_answer(h, kind)
		h.say(HeroChatter.ping_line(h.hero, kind, bool(ans["obeys"]), h.combat_rng), 2.2)
		if not bool(ans["obeys"]):
			continue
		obeyed += 1
		_ping_queue.append({"t": float(ans["delay"]), "hero": h, "kind": kind, "point": world_point, "foe": foe, "ally": ally})
	return obeyed


## How `h` answers a ping: {"obeys": bool, "delay": seconds}. Deterministic (D-016).
func ping_answer(h: SandboxHero, kind: String) -> Dictionary:
	if h.has_status("panicked"):
		return {"obeys": false, "delay": 0.0}
	if float(h.effective_obedience()) - spam_penalty < float(CombatRules.OBEY_MIN):
		return {"obeys": false, "delay": 0.0}
	if kind == "danger" and float(h.hp) > float(h.max_hp) * float(h.persona.get("ignore_retreat_hp", 2.0)):
		return {"obeys": false, "delay": 0.0}           # a reckless hero with health to spare ignores the retreat
	var delay := AiDefs.REACT_BASE + float(h.persona.get("delay", 0.0))
	if kind == "attack":
		delay += float(h.persona.get("attack_delay", 0.0))
	if not h.in_master_radius():
		delay += AiDefs.OUT_OF_RADIUS_DELAY
	return {"obeys": true, "delay": maxf(0.0, delay)}


func _count_ping() -> void:
	_ping_times.append(elapsed)
	_ping_times = _ping_times.filter(func(t): return elapsed - float(t) <= AiDefs.SPAM_WINDOW)
	if _ping_times.size() > AiDefs.SPAM_COUNT:
		spam_penalty = minf(AiDefs.SPAM_MAX, spam_penalty + AiDefs.SPAM_PENALTY)


func _tick_pings(delta: float) -> void:
	spam_penalty = maxf(0.0, spam_penalty - AiDefs.SPAM_DECAY * delta)
	if _ping_queue.is_empty():
		return
	var due: Array = []
	for q in _ping_queue:
		q["t"] = float(q["t"]) - delta
		if float(q["t"]) <= 0.0:
			due.append(q)
	for q in due:
		_ping_queue.erase(q)
		var h: SandboxHero = q["hero"]
		if is_instance_valid(h) and h.alive and not h.has_status("panicked"):
			_apply_ping(h, String(q["kind"]), q["point"], q["foe"], q["ally"])


## What an obeyed ping makes the hero do. Every ping order ends after AiDefs.PING_ORDER_TIME (back to Auto).
func _apply_ping(h: SandboxHero, kind: String, point: Vector2, foe, ally) -> void:
	var m := master_hero
	match kind:
		"regroup":
			if m != null and m.alive:
				h.order_move(map.find_path(h.position, map.nearest_walkable(m.position + Vector2.RIGHT.rotated(float(h.slot) * 1.3) * 36.0)))
		"attack":
			if foe != null and is_instance_valid(foe) and foe.alive:
				h.order_attack(foe)
				h.focus_hint = foe
			else:
				h.order_attack_move(map.nearest_walkable(point), map)
		"defend":
			h.stop()
			h.order = "defend"
			h.defend_point = map.nearest_walkable(point)
			h.path = map.find_path(h.position, h.defend_point)
		"explore", "move":
			h.order_move(map.find_path(h.position, map.nearest_walkable(point)))
		"gather":
			var g := _node_at(point)
			h.order_move(map.find_path(h.position, map.nearest_walkable(g.position if g != null else point)))
		"danger":
			var away := (h.position - point).normalized() if h.position.distance_to(point) > 1.0 else Vector2.DOWN
			var to := h.position + away * AiDefs.DANGER_DIST
			if m != null and m.alive and m.position.distance_to(point) > AiDefs.DANGER_DIST * 0.6:
				to = m.position
			h.order_move(map.find_path(h.position, map.nearest_walkable(to)))
		"spotted":
			if foe != null and is_instance_valid(foe):
				h.focus_hint = foe                  # a hint, not an order: the role decides when
			return
		"camp":
			var spot := camp.position if camp != null and is_instance_valid(camp) else point
			h.order_move(map.find_path(h.position, map.nearest_walkable(spot + Vector2.RIGHT.rotated(float(h.slot) * 1.25) * 40.0)))
		"help":
			if ally != null and is_instance_valid(ally) and ally.downed:
				h.order_rescue(ally)
				return                               # a rescue ends on its own
			h.order_move(map.find_path(h.position, map.nearest_walkable(point)))
	h.order_left = AiDefs.PING_ORDER_TIME


## The wheel: opened after holding Shift + click AiDefs.PING_WHEEL_HOLD s (screen position).
func open_wheel(at: Vector2) -> void:
	close_wheel()
	_wheel = PingWheel.new()
	_wheel.centre = at
	for cid in MasterDefs.COMMANDS:
		var c: Dictionary = MasterDefs.COMMANDS[cid]
		var learned := master_hero != null and MasterRules.commands(master_hero.hero).has(cid)
		_wheel.command_names[int(c["slot"])] = String(c["name"]) if learned else ""
		_wheel.command_cd[int(c["slot"])] = float(command_cd.get(cid, 0.0))
	add_child(_wheel)


func close_wheel() -> void:
	if _wheel != null and is_instance_valid(_wheel):
		_wheel.queue_free()
	_wheel = null


## Releasing the wheel at screen point `at`: a ping (at the world point under where it opened) or a
## Command (same effect and cooldown as keys 1 2 3).
func release_wheel(at: Vector2) -> String:
	if _wheel == null:
		return ""
	var choice := PingWheel.pick_at(_wheel.centre, at)
	var world := screen_to_world(_wheel.centre)
	close_wheel()
	if choice.has("ping"):
		ping(String(choice["ping"]), world)
		return String(choice["ping"])
	if choice.has("command"):
		use_command(int(choice["command"]), world)
		return "command"
	return ""


# --- D-082 interaction (F) ------------------------------------------------------------------------

## F held: the Master lifts the fallen ally next to them (a hit resets it), else gathers the spot next to
## them; pressing F at the extraction point escapes. Also marks who shows the "Hold F" prompt.
func _tick_interact(delta: float) -> void:
	var m := master_hero
	for h in heroes:
		h.revive_prompt = m != null and m.alive and h.downed and not h.dead and not h.lost \
				and m.position.distance_to(h.position) <= AiDefs.REVIVE_PROMPT_RANGE
	if m == null or not m.alive or not m.is_controlled():
		return
	var lifting: SandboxHero = null
	if interact_held:
		for h in heroes:
			if h.revive_prompt and (lifting == null or m.position.distance_to(h.position) < m.position.distance_to(lifting.position)):
				lifting = h
	if lifting != null:
		if m.rescue_target != lifting:
			m.rescue_progress = 0.0
		if m.channel_revive(lifting, delta):
			m.rescue_target = null
	elif m.rescue_progress > 0.0 or m.rescue_target != null:
		m.rescue_progress = 0.0                   # let go of F or walked away: start again
		if m.order != "rescue":
			m.rescue_target = null
	_tick_master_loot(m, delta, lifting == null)  # D-121: hold F at a glowing body


## F pressed (not held): escape when the squad stands at the extraction point.
func interact_press() -> void:
	interact_held = true
	if master_hero == null or not master_hero.alive:
		return
	if master_hero.position.distance_to(map.center_of(map.extract_cell)) <= EXTRACT_RADIUS * EXTRACT_GATHER \
			and not heroes.any(func(h): return h.revive_prompt):
		extract()


func interact_release() -> void:
	interact_held = false


## Small fading ring where an order was given (order feedback).
func _mark(at: Vector2, color: Color) -> void:
	var m := OrderMarker.new()
	m.position = at
	m.color = color
	_world.add_child(m)


## Orders available to the panel and the keyboard. Never randomly refused (D-016).
func stop_selected() -> void:
	for h in selected:
		h.stop()
		h.target = null


## Fires skill slot `slot_index` (Q=0 .. R=3) of every selected hero. Each refusal shows its reason
## over the hero (D-016: never random). Returns how many fired.
func use_skill_selected(slot_index: int = 0, aim: Vector2 = Vector2.INF) -> int:
	var fired := 0
	var foes := living_enemies()
	for h in selected:
		if h.use_skill_slot(slot_index, foes, heroes, aim if h.is_controlled() else Vector2.INF):
			fired += 1
		elif h.alive:
			FloatingText.spawn(h, h.last_refusal, Color(0.8, 0.8, 0.8), false)
	return fired


# --- simulation ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	tick(delta)
	_step_camera(delta)


## Camera easing runs in the physics tick, after the units moved, so both are interpolated together.
func _step_camera(delta: float) -> void:
	_look_t = maxf(0.0, _look_t - delta)
	update_camera_targets()
	camera.target_position = camera_target             # the look-ahead is in the framing (_framed)
	camera.target_zoom = camera_zoom_target
	camera.step(delta)


func tick(delta: float) -> void:
	if mission_state != Mission.ACTIVE:
		return                                    # mission over: the result screen is up
	var foes := living_enemies()
	for h in heroes:
		h.tick(delta)
		h.combat_tick(foes.filter(func(e): return e.visible), map)    # heroes only fight what they see
	var targets := heroes.filter(func(h): return not h.dead)
	for e in foes:
		e._allies = foes                          # supports heal from this list
		if not ai_frozen:                         # D-146 dev console /ai freeze
			e.tick(delta, targets, map)
	for h in heroes:
		if not h.alive and selected.has(h):
			selected.erase(h)
		if not h.alive and h.is_controlled():
			group_view()                         # the driven hero fell: back to the squad view
	if _locked() and master_hero.alive and not master_hero.is_controlled():
		_set_controlled(master_hero)             # D-080: a rescued Master takes the lead again
	_tick_leadership(delta)
	_tick_pings(delta)
	_tick_interact(delta)
	_separate()
	_separate_enemies()
	_surround_t -= delta
	if _surround_t <= 0.0:
		_surround_t = 0.25
		_update_surrounded(foes)
	_tick_boss_wards()
	_tick_gathering(delta)
	_tick_pista_a(delta, foes)
	_tick_loot(delta)                             # pista D: bodies, F to loot, allies loot what they stand on
	_fog_t -= delta
	if _fog_t <= 0.0:
		_fog_t = CombatRules.FOG_EVERY
		update_fog()
	_scout_t -= delta
	if _scout_t <= 0.0:
		_scout_t = SCOUT_EVERY
		_direct_autonomy()
	_altar_tick(delta)
	_secret_tick()
	_update_mission(delta)


# --- mission: non-combat objective + extraction + result (T-011) ------------------------

func _update_mission(delta: float) -> void:
	elapsed += delta
	match mission_type:
		"combat":
			if living_enemies().is_empty():
				_end_mission(Mission.SUCCESS)
				return
		"boss":
			if boss != null and not boss.alive:
				_end_mission(Mission.SUCCESS)
				return
		"sabotage":
			_revive_tick(delta)
			if not totems.is_empty() and totems.all(func(t): return not t.alive):
				_end_mission(Mission.SUCCESS)
				return
		"escape":
			# master prompt D: cross to the far side; every standing hero must reach it
			var goal := map.center_of(map.relic_cell)
			var standing := heroes.filter(func(h): return h.alive and not h.downed)
			if not standing.is_empty() and standing.all(func(h): return h.position.distance_to(goal) <= EXTRACT_RADIUS * EXTRACT_GATHER):
				for h in standing:
					h.credit("objective", 2.0)
				_end_mission(Mission.SUCCESS)
				return
		"exploration":
			for clue in clues:
				var finder = heroes.filter(func(h): return h.alive and h.position.distance_to(clue.position) <= CLUE_RADIUS)
				if clue.visible and not finder.is_empty():
					clue.visible = false
					finder[0].credit("objective", 3.0)
			if clues.all(func(c): return not c.visible):
				_end_mission(Mission.SUCCESS)
				return
		"survival", "defense":
			_wave_timer += delta
			if _wave_timer >= WAVE_EVERY:
				_wave_timer = 0.0
				_spawn_wave()
			if mission_type == "survival":
				mission_timer += delta
			elif heroes.any(func(h): return h.alive and h.position.distance_to(shrine.position) <= SHRINE_RADIUS):
				mission_timer += delta
				for h in heroes:
					if h.alive and h.position.distance_to(shrine.position) <= SHRINE_RADIUS:
						h.credit("objective", delta / hold_time() * 3.0)
				shrine.progress = clampf(mission_timer / hold_time(), 0.0, 1.0)
			if mission_timer >= (survive_time() if mission_type == "survival" else hold_time()) and not living_heroes().is_empty():
				_end_mission(Mission.SUCCESS)
				return
	var limit := float(TowerExpedition.get_floor_config(floor_number).get("time_limit", 0.0)) if floor_number > 0 else 0.0
	if limit > 0.0 and elapsed >= limit:
		FloatingText.spawn(heroes[0], "Too late!", Color(1.0, 0.4, 0.3), false, 2.5)
		if mission_type == "escape":
			_end_mission(Mission.FAILED)               # D-084: the pass closes; too slow is a loss
		else:
			_end_mission(Mission.ESCAPED)              # the captive is lost; the squad walks out
		return
	if mission_type != "retrieval" and mission_type != "rescue":
		if living_heroes().is_empty():
			_wipe()
		return
	if _escort != null:
		_escort.visible = carrier != null
		if carrier != null:
			_escort.position = carrier.position + Vector2(-20, 6)
	if carrier == null and relic.visible:
		for h in heroes:
			if h.alive and h.position.distance_to(relic.position) <= PICKUP_RADIUS:
				carrier = h
				h.carrying = true
				h.credit("objective", 2.0)
				h.queue_redraw()
				relic.visible = false
				if mission_type == "rescue" and _escort == null:
					_escort = AnimatedSprite2D.new()
					_escort.sprite_frames = CazArt.villager_frames(3)
					_escort.offset = Vector2(0, -16)
					_world.add_child(_escort)
					_escort.play("idle_down")
				break
	if carrier != null and carrier.position.distance_to(map.center_of(map.extract_cell)) <= EXTRACT_RADIUS:
		carrier.credit("objective", 2.0)
		_end_mission(Mission.SUCCESS)
	elif living_heroes().is_empty():
		_wipe()


## D-036: nobody left standing to carry the fallen out -> every downed hero dies, mission failed.
func _wipe() -> void:
	_ending = true
	for h in heroes:
		if h.downed:
			h.killed_by = "left behind"
			h.die()
	_end_mission(Mission.FAILED)


## A hero fell (not dead yet): the relic drops where they lie; an escorted villager waits there.
func _on_hero_down(h: SandboxHero) -> void:
	_drop_pack(h)                                 # D-124: their loot falls with them
	for o in heroes:                             # D-081: seeing an ally (or the Master) fall shakes the others
		if o != h:
			shake(o, "master_down" if h.hero != null and h.hero.is_master else "ally_down")
	if carrier == h:
		carrier = null
		h.carrying = false
		relic.position = h.position
		relic.visible = true
	if selected.has(h):
		selected.erase(h)
	if h.hero != null:
		h.say("", 0.0)


## D-081: command cooldowns, Composure lost at low health, Composure back when a panic ends, and devoted
## heroes (bond tier with "rescue") running on their own to lift a fallen Master.
func _tick_leadership(delta: float) -> void:
	for id in command_cd.keys():
		command_cd[id] = maxf(0.0, float(command_cd[id]) - delta)
	for h in heroes:
		if not h.alive or h.hero == null or h.hero.is_master:
			continue
		var low := float(h.hp) < float(h.max_hp) * MasterDefs.LOW_HP_FRAC
		if low and not h.low_hp_shaken:
			h.low_hp_shaken = true
			shake(h, "low_hp")
		elif not low:
			h.low_hp_shaken = false
		var panicking := h.has_status("panicked")
		if h.was_panicked and not panicking:
			h.hero.set_composure(maxi(h.hero.composure, MasterDefs.PANIC_RECOVER))
		h.was_panicked = panicking
	if master_hero != null and master_hero.downed and not master_hero.dead and not master_hero.lost \
			and not heroes.any(func(x): return x.rescue_target == master_hero):
		var best: SandboxHero = null
		for h in heroes:
			if h.alive and not h.is_controlled() and h.hero != null and not h.has_status("panicked") \
					and bool(MasterRules.bond_tier(h.hero.bond_master)["rescue"]) \
					and (best == null or h.position.distance_to(master_hero.position) < best.position.distance_to(master_hero.position)):
				best = h
		if best != null:
			best.order_rescue(master_hero)
			best.say("Hold on!", 2.0)


## D-081 panic: a hero loses Composure on an event (after Leadership and bond) and panics below the line.
## The Master never panics.
func shake(h: SandboxHero, why: String) -> void:
	if not h.alive or h.hero == null or h.hero.is_master:
		return
	var m: HeroData = master_hero.hero if master_hero != null else null
	h.hero.set_composure(h.hero.composure - roundi(float(MasterRules.composure_loss(h.hero, m, why, h.in_master_radius()))))
	if h.hero.composure < MasterDefs.PANIC_BELOW and not h.has_status("panicked"):
		h.apply_status("panicked", MasterDefs.PANIC_TIME)
		h.order = "auto"
		h.target = null
		FloatingText.spawn(h, "panics!", Color(1.0, 0.95, 0.5), false, 1.6)


## D-081: fires the command in slot `slot` (keys 1 2 3). aim = where the player points (the Master's
## target for "focus fire"). Heroes answer only inside the Master's radius and with enough Obedience.
## Returns how many answered (-1 = could not be used: locked, on cooldown, no Master standing).
func use_command(slot: int, aim: Vector2 = Vector2.INF) -> int:
	if master_hero == null or not master_hero.alive or mission_state != Mission.ACTIVE:
		return -1
	var id := ""
	for cid in MasterRules.commands(master_hero.hero):
		if int(MasterDefs.COMMANDS[cid]["slot"]) == slot:
			id = cid
	if id == "":
		FloatingText.spawn(master_hero, "not learned yet", Color(0.8, 0.8, 0.8), false)
		return -1
	if float(command_cd.get(id, 0.0)) > 0.0:
		FloatingText.spawn(master_hero, "%ds" % ceili(float(command_cd[id])), Color(0.8, 0.8, 0.8), false)
		return -1
	var c: Dictionary = MasterDefs.COMMANDS[id]
	command_cd[id] = float(c["cooldown"])
	var radius := MasterRules.leadership_radius(master_hero.hero)
	var foe: SandboxEnemy = null
	if id == "focus_fire":
		var from: Vector2 = aim if aim != Vector2.INF else master_hero.position
		for e in visible_enemies():
			if foe == null or e.position.distance_to(from) < foe.position.distance_to(from):
				foe = e
	var answered := 0
	for h in heroes:
		if h == master_hero or not h.alive or h.position.distance_to(master_hero.position) > radius:
			continue
		if h.effective_obedience() < CombatRules.OBEY_MIN and id != "hold_fast":
			_refuse_command(h)
			continue
		answered += 1
		match id:
			"focus_fire":
				if foe != null and not h.has_status("panicked"):
					h.order_attack(foe)
				h.apply_status("focused", float(c["duration"]))
			"regroup":
				if not h.has_status("panicked"):
					h.order_move(map.find_path(h.position, master_hero.position))
				h.apply_status("rallied", float(c["duration"]))
			"hold_fast":
				if h.statuses.has("panicked"):
					h.statuses.erase("panicked")
				h.hero.set_composure(h.hero.composure + int(c["composure"]))
		FloatingText.spawn(h, "!", Color(1.0, 0.85, 0.4), false)
	FloatingText.spawn(master_hero, String(c["name"]), Color(1.0, 0.85, 0.4), false, 2.0)
	_mark(master_hero.position, Color(1.0, 0.85, 0.4))
	return answered


## D-080: the Master's agony ran out (or they were left behind): no death, the expedition fails at once.
## Standing heroes carry them and the downed out; with nobody standing _wipe() handles the rest.
func _on_master_lost(_c: Combatant) -> void:
	master_lost = true
	FloatingText.spawn(master_hero, "The Master has fallen!", Color(1.0, 0.4, 0.3), false, 2.5)
	if not _ending and mission_state == Mission.ACTIVE:
		if living_heroes().is_empty():
			_wipe()
		else:
			_end_mission(Mission.FAILED)


## Permanent death (D-011): the saved hero is removed from the roster and written to the
## memorial. Sandbox test heroes are not on the roster, so nothing is recorded for them.
func _on_hero_died(h: SandboxHero) -> void:
	fallen.append(h.hero.display_name())
	for o in heroes:
		if o != h:
			shake(o, "ally_died")
	if carrier == h:
		carrier = null
		h.carrying = false
		relic.position = h.position
		relic.visible = true
	var cause := "Slain by %s" % h.killed_by if h.killed_by != "" else "Fell in battle"
	Game.record_death(h.hero, cause, mission_title() if floor_number != 0 else MISSION_NAME)
	if h == master_hero:                          # D-081 hardcore: the Master is dead, the game is over
		master_lost = true
		if not _ending and mission_state == Mission.ACTIVE:
			_end_mission(Mission.FAILED)


func _end_mission(state: Mission) -> void:
	mission_state = state
	if floor_number > 0 and fog != null:
		Game.set_floor_explored(floor_number, fog.pack())   # saved with the rewards / town report below
	for h in heroes:
		h.stop()
	var outcome := "success" if state == Mission.SUCCESS else ("escaped" if state == Mission.ESCAPED else "failed")
	var entries: Array = []
	for h in heroes:
		entries.append({"hero": h.hero, "alive": not h.dead, "contrib": h.contrib})
	_settle_loot(outcome)                         # D-124: packs home (or lost) before the floor reward
	if real_squad and not reward_given:
		reward_given = true
		if floor_number < 0:
			results = Game.finish_wilds(-floor_number, outcome, ledger, entries, kill_xp)
		elif floor_number > 0:
			results = Game.finish_expedition(floor_number, outcome, ledger, entries, kill_xp, mission_type, secret_done)
			reward = results.get("reward", {})
		elif state == Mission.SUCCESS:
			Game.grant(REWARD_GEMS, REWARD_STONES, 0)
	elif not real_squad:
		# test squad: show what would have happened, keep nothing
		var preview := ExpeditionResults.compute(entries, outcome, floor_number if is_wilds() else maxi(1, floor_number), kill_xp)
		results = {"outcome": outcome, "loot": {}, "lost_loot": ledger.duplicate(), "reward": {}, "xp": [],
			"mvp": (preview["mvp"] as HeroData).display_name() if preview["mvp"] != null else "", "mvp_reason": preview["mvp_reason"]}
	if real_squad and not expedition_applied:
		# the town lives on while the squad was away; survivors come home tired, maybe sick (HQ Phase 1)
		expedition_applied = true
		var back: Array = []
		for h in heroes:
			if not h.dead:
				back.append({"hero": h.hero, "downed": h.was_downed, "poisoned": h.was_poisoned, "master_lost": h.lost})
		town_report = Game.after_expedition(back, floor_number, fallen.size(), EconomyDefs.expedition_hours(elapsed))   # owner 2026-11-02: 20 min away = 2 days
	_show_result()


static func _res_line(d: Dictionary) -> String:
	var parts: Array = []
	for k in d:
		if int(d[k]) > 0:
			parts.append("%d %s" % [int(d[k]), String(EconomyDefs.RESOURCES.get(k, {}).get("name", k)).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


func result_text() -> String:
	var lines: Array = []
	match mission_state:
		Mission.SUCCESS:
			lines.append("MISSION COMPLETE")
		Mission.ESCAPED:
			lines.append("BACK FROM THE WILDS" if is_wilds() else "ESCAPED — the squad got out")
		_:
			lines.append("MISSION FAILED")
	lines.append(mission_title() if floor_number != 0 else MISSION_NAME)
	lines.append("Time: %d:%02d   Enemies defeated: %d / %d   Survivors: %d / %d" % [floori(elapsed / 60.0), int(elapsed) % 60,
		defeated, enemies.size(), living_heroes().size(), heroes.size()])
	if fog != null and floor_number > 0:
		lines.append("Explored: %d%% of the floor (remembered)" % roundi(fog.explored_fraction() * 100.0))
	if not fallen.is_empty():
		lines.append("Fallen (permanent): %s" % ", ".join(fallen))
	if master_lost:
		lines.append("The Master is dead. The game is over (hardcore)." if Game.game_over else "The Master fell and was carried home wounded.")
	var mem: Dictionary = reward.get("memory", {})
	if not mem.is_empty():                        # D-081: a memory of the Former Master
		lines.append("")
		lines.append("%s: %s" % [tr("A memory returns"), tr(String(mem["title"]))])
		lines.append(tr(String(mem["text"])))
	lines.append("")
	if not real_squad:
		lines.append("Test squad: nothing is kept.  Gathered: %s" % _res_line(ledger))
	elif mission_state == Mission.FAILED:
		lines.append("Lost in the tower: %s" % _res_line(results.get("lost_loot", ledger)))
	else:
		lines.append("Gathered and dropped (kept): %s" % _res_line(results.get("loot", {})))
	lines.append_array(loot_lines())              # D-124: the backpacks
	if mission_state == Mission.ESCAPED and not is_wilds():
		lines.append("No completion reward: the objective was not finished.")
	if mission_state == Mission.SUCCESS and real_squad:
		if floor_number > 0:
			lines.append("Completion reward%s: %d gems, %d stones, %d books, %d starsteel, %d spirit essence" % [
				"" if bool(reward.get("first", true)) else " (floor already cleared: a small one)",
				int(reward.get("gems", 0)), int(reward.get("stones", 0)), int(reward.get("books", 0)),
				int(reward.get("starsteel", 0)), int(reward.get("essence", 0))])
			for b in reward.get("skill_books", []):
				lines.append("Skill book found: %s" % String(SkillDefs.info(String(b)).get("name", b)))
			for it in reward.get("items", []):
				lines.append("Loot: %s" % String(it))
			if int(reward.get("left_behind", 0)) > 0:
				lines.append("%d item(s) left behind: the stash is full (upgrade the warehouse)" % int(reward["left_behind"]))
		else:
			lines.append("Reward: %d gems, %d stone (training ground)" % [REWARD_GEMS, REWARD_STONES])
	if String(results.get("mvp", "")) != "":
		lines.append("")
		lines.append("MVP OF THE EXPEDITION: %s — %s%s" % [String(results["mvp"]), String(results.get("mvp_reason", "")),
			("  (+%d XP)" % int(results.get("mvp_bonus", 0))) if int(results.get("mvp_bonus", 0)) > 0 else ""])
	if not (results.get("xp", []) as Array).is_empty():
		lines.append("Experience:")
		for x in results["xp"]:
			if not bool(x["alive"]):
				continue
			var lv := "  Lv %d -> %d" % [int(x["from"]), int(x["to"])] if int(x["levels"]) > 0 else "  Lv %d" % int(x["to"])
			lines.append("  %s%s: +%d XP%s%s" % ["* " if bool(x["mvp"]) else "", String(x["name"]), int(x["xp"]), lv, " (rank cap: ascend)" if bool(x["capped"]) else ""])
	if not town_report.is_empty():
		lines.append("Back in town: a day passed.")
		var evs: Array = town_report.get("events", [])
		for i in mini(3, evs.size()):
			lines.append("  " + String(evs[i]))
	return "\n".join(lines)


const RESULT_SCROLL := Vector2(300, 150)     # D-116 (pista C): results window fits the 640x360 view


func _show_result() -> void:
	if SimMode.on:
		return                                   # D-083 headless simulator: the runner reads the result
	var center := CenterContainer.new()
	add_child(center)
	UIKit.fill(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)  # px
	panel.add_child(vb)
	# D-063 results: headline, then a scrollable report; the MVP stands out in gold with its reason
	if _hud != null:
		_hud.visible = false
	UIKit.music("results")
	var lines := result_text().split("
")
	var head := UIKit.label(lines[0], 28, UIKit.ACCENT if mission_state != Mission.FAILED else UIKit.BAD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = RESULT_SCROLL           # D-116: was 360x230 in a 640x360 view (blocked the screen)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 1)
	scroll.add_child(body)
	for i in range(1, lines.size()):
		var ln := String(lines[i])
		var mvp := ln.begins_with("MVP OF THE EXPEDITION")
		var l := UIKit.label(ln, 20 if mvp else 14, ArtPalette.GOLD[3] if mvp else (UIKit.ACCENT if ln.begins_with("  *") else UIKit.TEXT))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(RESULT_SCROLL.x - 12, 0)
		body.add_child(l)
	var back := UIKit.button("Back to town", func(): back_requested.emit(), Vector2(260, 40))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(back)
	UIKit.pop_in(panel)                          # D-116: eased entrance
	_overlay = center


## Anti-clumping: heroes closer than SEPARATION are pushed apart; idle ones yield first,
## and nobody is ever pushed into a wall.
func _separate() -> void:
	for i in heroes.size():
		for j in range(i + 1, heroes.size()):
			var a := heroes[i]
			var b := heroes[j]
			if not a.alive or not b.alive:
				continue
			var d := b.position - a.position
			var dist := d.length()
			if dist >= SEPARATION:
				continue
			var dir := d / dist if dist > 0.01 else Vector2.RIGHT.rotated(float(i * 5 + j))
			var corr := SEPARATION - dist
			var wa := 0.3 if a.is_moving() else 1.0
			var wb := 0.3 if b.is_moving() else 1.0
			_nudge(a, -dir * corr * wa / (wa + wb))
			_nudge(b, dir * corr * wb / (wa + wb))


## Enemies keep apart from each other and from heroes (only the enemy is pushed). The gap is the sum
## of the two bodies (CombatRules.SIZE), so a golem keeps heroes out of its sprite and two rats can
## crowd together; the lighter of two creatures gives way more.
func _separate_enemies() -> void:
	var live := living_enemies()
	for i in live.size():
		var a: SandboxEnemy = live[i]
		for j in range(i + 1, live.size()):
			var b: SandboxEnemy = live[j]
			var d := b.position - a.position
			var gap := (a.body_radius + b.body_radius) * 0.95
			if absf(d.x) >= gap or absf(d.y) >= gap:
				continue                                 # D-083: cheap reject (same result, far fewer square roots)
			var dist := d.length()
			if dist < gap and dist > 0.01:
				var share := b.mass / (a.mass + b.mass)
				var push := d / dist * (gap - dist)
				_nudge_any(a, -push * share)
				_nudge_any(b, push * (1.0 - share))
		for h in heroes:
			if not h.alive:
				continue
			var d2 := a.position - h.position
			var dist2 := d2.length()
			var gap2 := (a.body_radius + CombatRules.HERO_BODY) * 0.9
			if dist2 < gap2 and dist2 > 0.01:
				_nudge_any(a, d2 / dist2 * (gap2 - dist2))


func _nudge_any(n: Node2D, v: Vector2) -> void:
	var np := n.position + v
	if map.can_step(n.position, np):
		n.position = np


func _nudge(h: SandboxHero, v: Vector2) -> void:
	var np := h.position + v
	if map.can_step(h.position, np):
		h.position = np


func _process(delta: float) -> void:
	if debug_overlay != null:
		debug_overlay.queue_redraw()
	var driven := controlled()
	if _q_held and driven != null and driven.attack_ready():
		attack_at_cursor()                       # holding Q fires again as soon as the attack is ready
	if _rmb_held and driven != null and mission_state == Mission.ACTIVE:
		_rmb_t -= delta                          # hold right click: the hero keeps following the cursor
		if _rmb_t <= 0.0:
			_rmb_t = RMB_REPEAT
			var p := screen_to_world(get_local_mouse_position())
			if driven.order == "move" and not driven.path.is_empty() and driven.path[driven.path.size() - 1].distance_to(p) > 16.0:
				order_move_selected(p)
	if _aim_view != null:
		var focus: SandboxHero = driven if driven != null else (selected[0] if selected.size() == 1 else null)
		_aim_view.hero = focus
		_aim_view.slot = aiming_slot if aiming_slot >= 0 else _preview_slot
		_aim_view.cursor = screen_to_world(get_local_mouse_position())
		_aim_view.queue_redraw()
	if _ping_press != Vector2.INF and _wheel == null:
		_ping_hold += delta                       # Shift + click held: it becomes the wheel
		if _ping_hold >= AiDefs.PING_WHEEL_HOLD:
			open_wheel(_ping_press)
	_free_camera_input(delta)
	if _dragging:
		var m := get_local_mouse_position()
		_band.position = _drag_start.min(m)
		_band.size = (m - _drag_start).abs()
		_band.visible = (m - _drag_start).length() > 8.0
	_refresh_info()


# --- input ---------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mid_drag:
		camera_pan(-(event as InputEventMouseMotion).relative / maxf(0.05, camera.zoom.x))   # middle drag
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mid_drag = mb.pressed
			return
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var step := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1   # whole zoom steps only
			cam_zoom_i = clampi(cam_zoom_i + step, 0, CameraDefs.ZOOM_STEPS.size() - 1)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _edges != null and not mb.shift_pressed:
			var to := _edges.hit(mb.position)
			if to != Vector2.INF:
				camera_jump(to)                      # click on an edge marker: jump there
				return
		if event.button_index == MOUSE_BUTTON_LEFT and _locked():
			# D-082: in a Master squad the left click pings (Shift + click quick, held = the wheel; A then click = attack)
			if event.pressed and _arming_ping != "":
				ping(_arming_ping, screen_to_world(event.position))
				_arming_ping = ""
				return
			if event.pressed and Input.is_key_pressed(AiDefs.PING_MODIFIER):
				_ping_press = event.position
				_ping_hold = 0.0
				return
			if not event.pressed and _wheel != null:
				release_wheel(event.position)
				_ping_press = Vector2.INF
				return
			if not event.pressed and _ping_press != Vector2.INF:
				quick_ping(screen_to_world(_ping_press))
				_ping_press = Vector2.INF
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _arming_attack_move:
				_arming_attack_move = false
				attack_move_selected(screen_to_world(event.position))
				return
			if event.pressed:
				_drag_start = event.position
				_dragging = true
			elif _dragging:
				_dragging = false
				_band.visible = false
				_finish_left(event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_held = event.pressed
			_rmb_t = RMB_REPEAT
			if event.pressed:
				order_context(screen_to_world(event.position))


func _finish_left(end: Vector2, additive: bool) -> void:
	var picked: Array = []
	if (end - _drag_start).length() > 8.0:
		var a := screen_to_world(_drag_start)
		var b := screen_to_world(end)
		var rect := Rect2(a.min(b), (a - b).abs())
		for h in heroes:
			if h.alive and rect.has_point(h.position + Vector2(0, -16)):
				picked.append(h)
	else:
		var p := screen_to_world(end)
		var best: SandboxHero = null
		var best_d := 30.0
		for h in heroes:
			if not h.alive:
				continue
			var d := (h.position + Vector2(0, -16)).distance_to(p)
			if d < best_d:
				best_d = d
				best = h
		if best != null:
			picked.append(best)
	if additive:
		for h in selected:
			if not picked.has(h):
				picked.append(h)
	elif picked.size() == 1 and (end - _drag_start).length() <= 8.0:
		select_slot(heroes.find(picked[0]))       # clicking one hero takes control of it (D-053)
		return
	if picked.size() > 1 or picked.is_empty():
		group_view()                             # a box or an empty click: squad orders, autonomy on
	select_only(picked)


func _exit_tree() -> void:
	if is_inside_tree():
		get_tree().physics_interpolation = bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))


## F3 (debug builds only): bodies, strike/attack/perception ranges, paths, targets and AI state.
func toggle_debug_overlay(dev: bool = false) -> void:
	if not OS.is_debug_build() and not dev:      # D-146: the unlocked dev console works in exported builds
		return
	if debug_overlay == null:
		debug_overlay = CombatDebugDraw.new(self)
		_world.add_child(debug_overlay)
	else:
		debug_overlay.queue_free()
		debug_overlay = null


## D-059: Q = the driven hero's basic attack toward the mouse (no hero driven: nothing happens).
func attack_at_cursor() -> bool:
	var driven := controlled()
	if driven == null or mission_state != Mission.ACTIVE:
		return false
	return driven.aimed_attack(screen_to_world(get_local_mouse_position()), living_enemies(), map)


func _skill_key(i: int, pressed: bool) -> void:
	var driven := controlled()
	if driven == null:
		if pressed:
			use_skill_selected(i)                # group: autonomy picks targets, as before
		return
	if pressed:
		aiming_slot = i                          # show range + area while held
		if _aim_view == null:
			_aim_view = SkillAimView.new()
			_world.add_child(_aim_view)
	elif aiming_slot == i:
		aiming_slot = -1
		use_skill_selected(i, screen_to_world(get_local_mouse_position()))


## The Master's healing potion (LootDefs.POTION_KEY). Refusals are shown over the Master.
func master_potion() -> String:
	if master_hero == null or not is_instance_valid(master_hero):
		return "no Master"
	var why: String = master_hero.drink_potion()
	if why != "" and not SimMode.on:
		FloatingText.spawn(master_hero, tr(why), Color(1.0, 0.75, 0.5), false, 1.2)
	return why


## Squad order keys (also the HUD buttons). D-082: in a Master squad they become pings to the party
## (H defend here, C regroup, X the Master retreats and the squad comes, A then click = attack ping,
## S lifts every ping order); V = follow (F is interaction now).
func squad_key(key: int) -> void:
	match key:
		KEY_S:
			if _locked():
				for h in heroes:                     # D-082: every ping order is lifted, all back to Auto
					if h != master_hero and h.alive and h.order != "rescue":
						h.stop()
			stop_selected()
		KEY_A:
			if _locked():
				_arming_ping = "attack"              # D-082: the next click pings "attack here"
			else:
				arm_attack_move()
		KEY_H:
			if _locked():
				ping("defend", master_hero.position)  # D-082: squad orders are pings in a Master squad
			else:
				hold_selected()
		KEY_V:
			follow_selected()                      # D-082: F is interaction now; follow moved to V
		KEY_C:
			if _locked():
				ping("regroup", master_hero.position)
			else:
				regroup_selected()
		KEY_X:
			if _locked():
				ping("regroup", master_hero.position) # the squad comes along with the Master
			retreat_selected()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo or DevCommands.console_open:
		return
	if event.keycode == KEY_Q:
		_q_held = event.pressed
		if event.pressed:
			attack_at_cursor()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F:
		if event.pressed:                        # D-082: interaction (lift a fallen ally, gather, escape)
			interact_press()
		else:
			interact_release()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == CameraDefs.KEY_CENTER:
		center_held = event.pressed                # hold: centred on the Master while held
		if not event.pressed and cam_mode == "free":
			cam_free_pos = camera.position          # stays where the Master is when released
		cam_follow = -1 if event.pressed else cam_follow
		if event.pressed and cam_mode == "follow":
			cam_mode = "locked"
		get_viewport().set_input_as_handled()
		return
	if event.keycode == LootDefs.POTION_KEY and event.pressed:
		master_potion()                          # owner 2026-11-02: the Master drinks only on this key
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_SPACE and event.pressed:
		dash_selected()
		get_viewport().set_input_as_handled()
		return
	var skill_keys := {KEY_W: 0, KEY_E: 1, KEY_R: 2}
	if skill_keys.has(event.keycode):
		_skill_key(int(skill_keys[event.keycode]), event.pressed)
		get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			if not _locked():                    # D-080: no hero switch with a Master (debug flag aside)
				select_slot(event.keycode - KEY_1 + (5 if event.shift_pressed else 0))
			elif MasterDefs.COMMAND_KEYS.has(event.keycode):   # D-081: Master commands
				use_command(MasterDefs.COMMAND_KEYS.find(event.keycode), screen_to_world(get_local_mouse_position()))
		KEY_TAB:
			overview = false
			group_view()
		CameraDefs.KEY_DEBUG:
			toggle_debug_overlay()
		CameraDefs.KEY_TOGGLE:
			toggle_camera_mode()
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5:
			camera_hero_key(CameraDefs.HERO_KEYS.find(event.keycode))
		KEY_M:
			overview = not overview
		KEY_G:
			select_all()
		KEY_S, KEY_A, KEY_H, KEY_V, KEY_C, KEY_X:
			squad_key(event.keycode)
		KEY_T:
			toggle_auto_skills()
		KEY_ESCAPE:
			if _wheel != null:
				close_wheel()
				_ping_press = Vector2.INF
			elif _arming_ping != "":
				_arming_ping = ""
			elif _arming_attack_move:
				_arming_attack_move = false
			else:
				open_menu()
		KEY_I:
			if _hud != null:
				_hud.toggle_details()
		_:
			return
	get_viewport().set_input_as_handled()


# --- hero panel (contextual, minimal version of T-008) ---------------------------------------

func _refresh_info() -> void:
	if _info == null:
		return
	var view := "Focus: hero %d" % (follow_slot + 1) if follow_slot >= 0 else "Group view"
	var goal := "Objective: " + _objective_text()
	if selected.is_empty():
		_info.text = "%s\n%s\nNothing selected" % [view, goal]
	elif selected.size() == 1:
		var sh: SandboxHero = selected[0]
		var h: HeroData = sh.hero
		var st := h.get_stats()
		var sk_lines: Array = []
		for i in sh.slots.size():
			var sk: Dictionary = sh.slot_skill(i)
			var sk_state := "READY" if sh.skill_ready(i) else ("%.0fs" % ceilf(sh.skill_cd(i)) if sh.skill_cd(i) > 0.0 else "need %d" % int(sk["cost"]))
			sk_lines.append("%s %s [%s]" % [SKILL_KEYS[i], sk["name"], sk_state])
		_info.text = "%s\n%s\n%s  |  %d-star %s  |  Lv %d\nHP %d/%d  %s %d/%d  ATK %d  MAG %d  DEF %d\nTrust %d   Obedience %d   Composure %d\nSkills: %s\nOrder: %s%s" % [
			view, goal, h.display_name(), h.stars, h.class_title(), h.level,
			sh.hp, sh.max_hp, SkillDefs.RESOURCES[sh.res_kind]["name"], roundi(sh.res), roundi(sh.res_max), st["atk"], st["mag"], st["def"], h.trust, h.obedience, h.composure,
			"  ".join(sk_lines) if not sk_lines.is_empty() else "none", sh.order_label(), ("  · casting " + String(SkillDefs.info(sh.casting)["name"])) if sh.casting != "" else ""]
	else:
		var names: Array = []
		for s in selected:
			names.append(s.hero.hero_name.split(" ")[0])
		_info.text = "%s\n%s\n%d heroes selected: %s\nOrders: Move (right-click), Stop (S), Skills (W E R); 1-5 to drive one hero, Q to attack" % [view, goal, selected.size(), ", ".join(names)]
	for i in _skill_btns.size():
		var slot_i := i
		var b := _skill_btns[i]
		b.disabled = not selected.any(func(h): return h.skill_ready(slot_i))
		if selected.size() == 1 and i < (selected[0] as SandboxHero).slots.size():
			var nm := String((selected[0] as SandboxHero).slot_skill(i)["name"])
			b.text = "%s %s" % [SKILL_KEYS[i], nm.left(7)]
			b.tooltip_text = String((selected[0] as SandboxHero).slot_skill(i)["desc"])
		else:
			b.text = SKILL_KEYS[i]
	var rows: Array = []
	for i in heroes.size():
		var hh := heroes[i]
		var nm := hh.hero.hero_name.split(" ")[0]
		if hh.alive:
			var ready: Array = []
			for k in hh.slots.size():
				if hh.skill_ready(k):
					ready.append(SKILL_KEYS[k])
			rows.append("%d %s  HP %d/%d  %s %d  %s · %s%s" % [i + 1, nm, hh.hp, hh.max_hp, String(SkillDefs.RESOURCES[hh.res_kind]["name"]).left(1), roundi(hh.res), hh.order_label(),
				("ready " + "".join(ready)) if not ready.is_empty() else "no skill ready", "  [RELIC]" if hh.carrying else ""])
		elif hh.downed:
			rows.append("%d %s  DOWN %s — hold F next to them" % [i + 1, nm, hh.agony_text()])
		else:
			rows.append("%d %s  FALLEN" % [i + 1, nm])
	_squad_label.text = "\n".join(rows)


func _objective_text() -> String:
	match mission_state:
		Mission.SUCCESS:
			return "complete"
		Mission.FAILED:
			return "failed"
	if fog != null and floor_number > 0:
		return _mission_objective() + "  ·  explored %d%%" % roundi(fog.explored_fraction() * 100.0)
	return _mission_objective()


func _mission_objective() -> String:
	match mission_type:
		"farm":
			return "gather and get out at the entrance (X)  ·  deeper = richer and deadlier"
		"combat":
			var n := living_enemies().size()
			return "defeat every enemy (%d left%s)" % [n, ", marked on the map" if not revealed_enemies().is_empty() else ""]
		"boss":
			return "defeat %s" % (boss.enemy_name if boss != null else "the boss")
		"exploration":
			var left := clues.filter(func(c): return c.visible).size()
			return "discover the clues (%d left)" % left
		"survival":
			return "survive %d s" % maxi(0, int(survive_time() - mission_timer))
		"defense":
			return "keep a hero at the shrine (%d%%)" % int(shrine.progress * 100.0)
		"rescue":
			return "escort the villager to EXTRACT" if carrier != null else "find the villager calling for help"
	if carrier != null:
		return "carry the relic to EXIT"
	if map is SandboxMap:
		return "recover the relic (far room, top right)"
	return "find the relic in the far room and bring it back to EXTRACT"


# --- pista A (D-090): bushes, squad synergies, camp --------------------------------------------------

var bushes: BushField = null
var camp: CampSite = null
var camp_test_kits: int = CampDefs.TEST_KITS     # while pista D's kit item does not exist
var camps_done: int = 0                           # stats (simulator, tests)
var camps_interrupted: int = 0
var _syn_t: float = 0.0


func _setup_pista_a() -> void:
	var seed_v := int(map.get("seed_value")) if map.get("seed_value") != null else floor_number
	bushes = BushField.make(map, seed_v)
	_world.add_child(bushes)


func _tick_pista_a(delta: float, foes: Array) -> void:
	_syn_t -= delta
	if _syn_t <= 0.0:
		_syn_t = SquadSynergies.EVERY
		SquadSynergies.update(heroes, foes, bushes, fog, map)
	if camp != null:
		if not is_instance_valid(camp) or not camp.tick(delta, foes):
			camp = null


## D-090 "Camp here": "" when the camp starts, otherwise why not (also said by the Master).
func start_camp(point: Vector2) -> String:
	var why := camp_refusal(point)
	if why != "":
		if master_hero != null:
			master_hero.say(tr(why), 2.5)
		return why
	if CampDefs.kit_is_item():
		for h in heroes:
			if h.alive and h.hero != null and int(h.hero.bag.get(CampDefs.KIT_ID, 0)) > 0:
				h.hero.bag[CampDefs.KIT_ID] = int(h.hero.bag[CampDefs.KIT_ID]) - 1
				if int(h.hero.bag[CampDefs.KIT_ID]) <= 0:
					h.hero.bag.erase(CampDefs.KIT_ID)
				break
	else:
		camp_test_kits -= 1
	camp = CampSite.make(map.nearest_walkable(point), heroes)
	camp.finished.connect(func(_c, ok: bool, _w: String):
		if ok:
			camps_done += 1
		else:
			camps_interrupted += 1)
	_world.add_child(camp)
	return ""


## Why the squad cannot camp at `point` now ("" = it can).
func camp_refusal(point: Vector2) -> String:
	if mission_state != Mission.ACTIVE:
		return "not now"
	if camp != null and is_instance_valid(camp):
		return "already camping"
	if not camp_kit_available():
		return "no camp kit"
	for e in living_enemies():
		if not e.dormant and e.position.distance_to(point) <= CampDefs.SAFE_RADIUS and (e.alerted or e.visible):
			return "enemies too close"
	return ""


func camp_kit_available() -> bool:
	if not CampDefs.kit_is_item():
		return camp_test_kits > 0
	for h in heroes:
		if h.alive and h.hero != null and int(h.hero.bag.get(CampDefs.KIT_ID, 0)) > 0:
			return true
	return false


# --- pista D (D-120..D-128): loot on the bodies, backpacks, meals ----------------------------------

## Leaves loot on the floor (a body, or the pack of a fallen hero). Nothing is left when it is empty.
func drop_loot(at: Vector2, items: Array, res: Dictionary, source: String = "body", owner_name: String = "") -> LootBag:
	if items.is_empty() and res.is_empty():
		return null
	var b := LootBag.new()
	b.items = items.duplicate()
	b.res = res.duplicate()
	b.source = source
	b.owner_name = owner_name
	b.position = at
	_world.add_child(b)
	loot_bags.append(b)
	if source == "body":
		loot_stats["bodies"] = int(loot_stats["bodies"]) + 1
		loot_stats["items"] = int(loot_stats["items"]) + items.size()
		loot_stats["junk"] = int(loot_stats["junk"]) + items.filter(func(it): return ItemDefs.is_junk(it)).size()
		var best := LootService.best_rarity(items)
		if best != "" and best != "junk" and best != "common" and not SimMode.on:
			FloatingText.spawn(b, tr(String(ItemDefs.RARITIES[best]["name"])), ItemDefs.rarity_color(best), false, 1.4)
	return b


## D-124: the items a hero carries in this run.
func pack_of(h: SandboxHero) -> Array:
	if not packs.has(h):
		packs[h] = []
	return packs[h]


func pack_room(h: SandboxHero) -> int:
	return LootService.pack_slots(h.hero) - pack_of(h).size()


## Takes item `idx` (-1 = all that fits, plus the materials) from a bag into the looter's pack, else the
## nearest standing ally's with room (allies = false: only the looter's). Message for the loot window.
func take_loot(bag: LootBag, idx: int, looter: SandboxHero, allies: bool = true) -> String:
	if not is_instance_valid(bag) or looter == null:
		return ""
	var msg := ""
	if idx < 0:
		for k in bag.res:
			_add_loot(String(k), int(bag.res[k]), bag)
		bag.res = {}
	var left: Array = []
	var taken := 0
	for i in bag.items.size():
		var it: Dictionary = bag.items[i]
		if idx >= 0 and i != idx:
			left.append(it)
			continue
		var who := _pack_with_room(looter, allies)
		if who == null:
			left.append(it)
			msg = tr("No room in the backpacks")
			continue
		pack_of(who).append(it)
		taken += 1
		if who != looter and msg == "":
			msg = tr("%s carries it") % who.hero.display_name()
	bag.items = left
	loot_stats["looted"] = int(loot_stats["looted"]) + taken
	if bag.is_empty():
		_remove_bag(bag)
	return msg if msg != "" else (tr("Taken") if taken > 0 else "")


func _pack_with_room(looter: SandboxHero, allies: bool) -> SandboxHero:
	if looter.alive and pack_room(looter) > 0:
		return looter
	if not allies:
		return null
	var best: SandboxHero = null
	for h in heroes:
		if h.alive and not h.downed and pack_room(h) > 0 and (best == null or h.position.distance_to(looter.position) < best.position.distance_to(looter.position)):
			best = h
	return best


func _remove_bag(bag: LootBag) -> void:
	loot_bags.erase(bag)
	if _loot_win != null and is_instance_valid(_loot_win) and _loot_win.bag == bag:
		_loot_win.queue_free()
		_loot_win = null
	bag.queue_free()


## The nearest bag with something in it within r (only where the squad has seen).
func _bag_near(at: Vector2, r: float) -> LootBag:
	var best: LootBag = null
	for b in loot_bags:
		if is_instance_valid(b) and not b.is_empty() and b.position.distance_to(at) <= r \
				and (best == null or b.position.distance_to(at) < best.position.distance_to(at)):
			best = b
	return best


## AI looting rule (LootDefs.LOOT_SAFE_RADIUS): no living creature near `at`.
func loot_safe(at: Vector2) -> bool:
	return not enemies.any(func(e): return e.alive and e.position.distance_to(at) <= LootDefs.LOOT_SAFE_RADIUS)


## Defense and survival: the AI never leaves its post to loot (LootDefs.HOLD_MISSIONS).
func loot_holds_post() -> bool:
	return LootDefs.HOLD_MISSIONS.has(mission_type)


## D-121: the Master holds F next to a glowing body for LOOT_HOLD s (not while lifting an ally).
func _tick_master_loot(m: SandboxHero, delta: float, free_hands: bool) -> void:
	var bag := _bag_near(m.position, LootDefs.LOOT_RANGE)
	for b in loot_bags:
		if is_instance_valid(b):
			b.prompt = b == bag
			if b != bag:
				b.hold = 0.0
	if bag == null or not free_hands or not interact_held:
		_loot_hold = 0.0
		if bag != null:
			bag.hold = 0.0
		return
	_loot_hold += delta
	bag.hold = _loot_hold / LootDefs.LOOT_HOLD
	if _loot_hold >= LootDefs.LOOT_HOLD:
		_loot_hold = 0.0
		bag.hold = 0.0
		open_loot(bag)


## Opens the loot window (the game keeps running). Headless (simulator): takes everything that fits.
func open_loot(bag: LootBag) -> void:
	if SimMode.on or not is_inside_tree():
		take_loot(bag, -1, master_hero)
		return
	if _loot_win != null and is_instance_valid(_loot_win):
		if _loot_win.bag == bag:
			return
		_loot_win.queue_free()
	_loot_win = LootWindow.new(bag, self)
	add_child(_loot_win)


## Fog hides the bags; the window closes when the Master walks away; autonomous heroes with nothing to
## fight loot the body they stand on (greedy ones reach further, D-125).
func _tick_loot(delta: float) -> void:
	for b in loot_bags.duplicate():
		if not is_instance_valid(b):
			loot_bags.erase(b)
			continue
		b.visible = not SimMode.on and (fog == null or fog.is_explored(map.cell_of(b.position)))
	if _loot_win != null and is_instance_valid(_loot_win) and (master_hero == null or not is_instance_valid(_loot_win.bag)
			or master_hero.position.distance_to(_loot_win.bag.position) > LootDefs.LOOT_RANGE * 2.5):
		_loot_win.queue_free()
		_loot_win = null
	for h in heroes:
		if h == master_hero or not h.alive or h.downed or h.target != null or h.is_casting() or not loot_safe(h.position):
			_auto_loot.erase(h)
			continue
		var reach := LootDefs.AUTO_LOOT_RANGE * (float(LootDefs.GREEDY["loot_range_mult"]) if LootService.is_greedy(h.hero) and not loot_holds_post() else 1.0)
		var b := _bag_near(h.position, reach)
		if b == null or (pack_room(h) <= 0 and b.res.is_empty()):
			_auto_loot.erase(h)
			continue
		_auto_loot[h] = float(_auto_loot.get(h, 0.0)) + delta
		if float(_auto_loot[h]) >= LootDefs.AUTO_LOOT_TIME:
			_auto_loot.erase(h)
			take_loot(b, -1, h, false)


## D-124: a fallen hero drops their pack where they fell; anyone may pick it up.
func _drop_pack(h: SandboxHero) -> void:
	var items: Array = packs.get(h, [])
	packs.erase(h)
	if not items.is_empty():
		drop_loot(h.position, items, {}, "pack", h.hero.display_name() if h.hero != null else "")


## D-124 at the end: on success or escape every pack goes home (the bodies near the squad are swept
## first); on a wipe, or with a test squad, the packs are lost. Unlooted bodies stay in the tower.
func _settle_loot(outcome: String) -> void:
	if not loot_report.is_empty() or floor_number <= 0:
		return
	var lost := 0
	if outcome != "failed" and real_squad:
		var swept: Array = []
		for b in loot_bags.duplicate():
			if is_instance_valid(b) and heroes.any(func(x): return x.alive and x.position.distance_to(b.position) <= LootDefs.END_SWEEP):
				swept.append_array(b.items)
				for k in b.res:
					_add_loot(String(k), int(b.res[k]), null)
				_remove_bag(b)
		var list: Array = []
		for h in packs:
			if (h as SandboxHero).dead:
				lost += (packs[h] as Array).size()
			elif not (packs[h] as Array).is_empty():
				list.append({"hero": (h as SandboxHero).hero, "items": packs[h]})
		var lead: SandboxHero = master_hero if master_hero != null else (heroes[0] if not heroes.is_empty() else null)
		if not swept.is_empty() and lead != null:
			list.append({"hero": lead.hero, "items": swept})
			loot_stats["looted"] = int(loot_stats["looted"]) + swept.size()
		loot_report = Game.deliver_packs(list)
	else:
		for h in packs:
			lost += (packs[h] as Array).size()
		loot_report = {"items": [], "failed": true}
	for b in loot_bags:
		if is_instance_valid(b):
			lost += b.items.size()
	loot_report["lost"] = lost


## Result screen lines about the backpacks.
func loot_lines() -> Array:
	var out: Array = []
	if loot_report.is_empty():
		return out
	if bool(loot_report.get("failed", false)):
		if int(loot_report.get("lost", 0)) > 0:
			out.append(tr("Lost in the tower with the backpacks: %d item(s)") % int(loot_report["lost"]))
		return out
	var its: Array = loot_report.get("items", [])
	out.append(tr("Brought home in the backpacks: %d item(s)") % its.size())
	for i in mini(its.size(), 8):
		out.append("  · %s" % String(its[i]))
	if its.size() > 8:
		out.append("  · …")
	if int(loot_report.get("left_behind", 0)) > 0:
		out.append(tr("%d item(s) left behind: the stash is full") % int(loot_report["left_behind"]))
	if int(loot_report.get("lost", 0)) > 0:
		out.append(tr("%d item(s) left on the floor: nobody looted them") % int(loot_report["lost"]))
	for c in loot_report.get("caught", []):
		out.append(String(c))
	return out


## D-128: a hero eats the first meal in their bag when the expedition starts (a buff for the whole run).
func _eat_meal(h: SandboxHero) -> void:
	var hd: HeroData = h.hero
	if hd == null:
		return
	for id in LootDefs.CONSUMABLES:
		var meal: Dictionary = (LootDefs.CONSUMABLES[id] as Dictionary).get("meal", {})
		if meal.is_empty() or int(hd.bag.get(id, 0)) <= 0:
			continue
		hd.bag[id] = int(hd.bag[id]) - 1
		if int(hd.bag[id]) <= 0:
			hd.bag.erase(id)
		h.max_hp = roundi(float(h.max_hp) * (1.0 + float(meal.get("hp_pct", 0.0))))
		h.hp = h.max_hp
		for st in ["atk", "mag"]:
			if h.stats.has(st):
				h.stats[st] = roundi(float(h.stats[st]) * (1.0 + float(meal.get(st + "_pct", 0.0))))
		h.armor = roundi(float(h.armor) * (1.0 + float(meal.get("def_pct", 0.0))))     # broth / feast
		h.mres = roundi(float(h.mres) * (1.0 + float(meal.get("mres_pct", 0.0))))
		h.set_meta("meal", id)
		if not SimMode.on:
			FloatingText.spawn(h, tr("Well fed"), Color(0.95, 0.75, 0.4), false, 1.6)
		return


# --- D-146 dev console hooks (DevCommands calls these; the rules stay here) -----------------------

var ai_frozen: bool = false                       # /ai freeze: creatures stop thinking and moving
var fog_off: bool = false                         # /fog off: every creature shown, fog not drawn (memory untouched)


func dev_set_fog(on: bool) -> void:
	fog_off = not on
	update_fog()


func dev_open_secret() -> void:
	if secret == null or secret_done:
		return
	secret_done = true
	secret.visible = false
	var m: SandboxHero = master_hero if master_hero != null else (heroes[0] if not heroes.is_empty() else null)
	if m != null:
		FloatingText.spawn(m, "A secret!", Color(1.0, 0.85, 0.4), true, 2.0)


## /objective complete: the goal of this mission counts as met. Carry missions put the relic (or the
## villager) on the Master, so the extraction is still walked; the others end on the next tick.
func dev_complete_objective() -> String:
	var m: SandboxHero = master_hero if master_hero != null else (heroes[0] if not heroes.is_empty() else null)
	match mission_type:
		"retrieval", "rescue":
			if carrier == null and m != null:
				relic.position = m.position          # picked up on the next tick, through the normal path
			return "Objetivo en manos del Máster: ve a la extracción"
		"combat":
			for e in living_enemies():
				e.immune = false
				e.die()
		"boss":
			if boss != null and boss.alive:
				boss.immune = false
				boss.die()
		"sabotage":
			for t in totems:
				if t.alive:
					t.die()
		"exploration":
			for c in clues:
				c.visible = false
		"survival", "defense":
			mission_timer = survive_time() if mission_type == "survival" else hold_time()
		"escape":
			var goal := map.center_of(map.relic_cell)
			for h in heroes:
				if h.alive:
					h.stop()
					h.position = map.nearest_walkable(goal)
	return "Objetivo cumplido (%s)" % mission_type
