## CombatWorld — unidad determinista de simulación del primer corte.
##
## Es el único Tickable registrado en TickManager. Dentro de un tick avanza al
## Warrior y a los muñecos en orden fijo. El mismo objeto se puede crear y
## avanzar en headless (step) sin árbol de escena, y su snapshot() es la base
## para netcode: input por tick -> simulación -> snapshot.
class_name CombatWorld
extends "res://core/tickable.gd"

signal tick_advanced(tick_number: int)
signal projectile_spawned(projectile: ProjectileSim)
signal projectile_removed(projectile: ProjectileSim)
signal enemy_spawned(enemy: EnemySim)
signal zone_spawned(zone: GroundZone)
signal layout_loaded(layout: FloorLayout)
signal loot_dropped(item: Dictionary, position: Vector2)
signal loot_spawned(drop: LootDrop)
signal loot_removed(drop: LootDrop)
signal gather_started(node: Object)
signal enemy_killed(enemy: EnemySim)
signal interacted(object: Interactable)
signal gather_interrupted(node: Object, reason: String)
signal resource_gathered(node: ResourceNode, material_id: String, amount: int)

const PlayerSimScript := preload("res://game/sim/player_sim.gd")
const DummySimScript := preload("res://game/sim/dummy_sim.gd")

const DEFAULT_BOUNDS := Rect2(0, 0, 960, 640)

var tick: int = 0
var rng: RandomNumberGenerator
var bounds: Rect2 = DEFAULT_BOUNDS
var obstacles: Array = []
var player: PlayerSim
var dummies: Array = []
var enemies: Array = []
var projectiles: Array = []
## Escenario cargado (patio, ciudad o piso de la torre); null en mundos de test.
var layout: FloorLayout = null
## Verdadero mientras load_layout() crea los enemigos (la arena los dibuja luego).
var loading_layout: bool = false
var pending_input: InputMessage = null
## RNG propio del botin (no altera la secuencia del combate).
var loot_rng: RandomNumberGenerator
## Items en el suelo (se recogen al acercarse).
var loot_drops: Array = []
## Duracion del ultimo paso (la sesion la usa para los temporizadores).
var step_delta: float = 1.0 / 60.0
## Mapa de casillas (muros, agua, puertas) de los escenarios grandes; null en los demas.
var grid: TileGrid = null
var _flow_field: PackedInt32Array = PackedInt32Array()
var _flow_cell: Vector2i = Vector2i(-99999, -99999)
var _flow_version: int = -1
var _pickup_prev: bool = false
## Nodos de recoleccion del escenario (veta, hierba, arbol).
var resource_nodes: Array = []
## Nodo que se esta recolectando y segundos que faltan.
var gather_node: Object = null
## Objetos de mision (altares, balizas, jaulas...).
var interactables: Array = []
## Reliquias que lleva el jugador (mision de reliquia).
var relics_carried: int = 0
var gather_left: float = 0.0
var _gather_from: Vector2 = Vector2.ZERO
var _gather_health: float = 0.0


func _init(seed_value: int = 1337) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	loot_rng = RandomNumberGenerator.new()
	loot_rng.seed = seed_value * 31 + 7
	player = PlayerSimScript.new(self)
	player.position = Vector2(480, 380)


func setup_arena(arena_bounds: Rect2, arena_obstacles: Array = [], p_grid: TileGrid = null) -> void:
	bounds = arena_bounds
	obstacles = arena_obstacles.duplicate()
	grid = p_grid
	_flow_cell = Vector2i(-99999, -99999)
	player.position = bounds.get_center()
	player.reset(bounds.get_center())


func add_dummy(spawn: Vector2, auto_attack: bool = true) -> DummySim:
	var dummy := DummySimScript.new(self, spawn, auto_attack)
	dummies.append(dummy)
	return dummy


## Crea un enemigo definido en data/enemies. Cada uno tiene su propio RNG, derivado
## de la semilla del mundo y de su orden de creacion (determinista).
func add_enemy(def_id: StringName, spawn: Vector2, level_scale: float = 1.0) -> EnemySim:
	var enemy := EnemySim.new(self, def_id, spawn, int(rng.seed) + (enemies.size() + 1) * 7919)
	enemy.apply_scale(level_scale)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemies.append(enemy)
	enemy_spawned.emit(enemy)
	return enemy


## Anade un proyectil al mundo; lo avanza step() hasta que muere.
## Zonas persistentes en el suelo (ataques de jefe con `zone`).
var zones: Array = []


func spawn_zone(zone: GroundZone) -> void:
	zones.append(zone)
	zone_spawned.emit(zone)


func spawn_projectile(projectile: ProjectileSim) -> void:
	projectiles.append(projectile)
	projectile_spawned.emit(projectile)


## Carga un escenario: limpia enemigos, munecos y proyectiles, fija limites y
## obstaculos, coloca al jugador en la entrada (con vida y recursos nuevos; su
## nivel, XP, clase y loadout se conservan) y crea los enemigos del layout con su
## escala de dificultad.
func load_layout(new_layout: FloorLayout) -> void:
	loading_layout = true
	layout = new_layout
	for projectile: ProjectileSim in projectiles.duplicate():
		projectile.alive = false
		projectile_removed.emit(projectile)
	projectiles.clear()
	for zone: GroundZone in zones:
		zone.alive = false
	zones.clear()
	dummies.clear()
	enemies.clear()
	for drop: LootDrop in loot_drops.duplicate():
		_remove_drop(drop)
	resource_nodes.clear()
	interactables.clear()
	relics_carried = 0
	gather_node = null
	pending_input = null
	setup_arena(new_layout.bounds(), new_layout.obstacles, new_layout.grid)
	player.position = new_layout.player_spawn
	player.reset(new_layout.player_spawn)
	for spec: Dictionary in new_layout.dummies:
		add_dummy(spec["position"], bool(spec["auto_attack"]))
	for spec: Dictionary in new_layout.enemies:
		spawn_from_spec(spec, new_layout.enemy_scale)
	var node_tier := maxi(new_layout.tier, 1)
	for spec: Dictionary in new_layout.resources:
		var resource := ResourceNode.new(String(spec["kind"]), node_tier, spec["position"])
		resource.rich = bool(spec.get("rich", false))
		resource_nodes.append(resource)
	for spec: Dictionary in new_layout.interactables:
		interactables.append(Interactable.new(String(spec["kind"]), spec["position"], String(spec.get("group", "")), float(spec.get("channel", 2.0)), String(spec.get("requires", "")), String(spec.get("label", ""))))
	# Altares, jaulas, sellos y las vetas/arboles no se atraviesan.
	for object: Interactable in interactables:
		if ["altar", "seal", "cage", "relic_altar"].has(object.kind):
			obstacles.append({"position": object.position, "radius": 16.0, "hidden": true})
	for node: ResourceNode in resource_nodes:
		if node.kind != "herb":
			obstacles.append({"position": node.position, "radius": 14.0, "hidden": true})
	loading_layout = false
	layout_loaded.emit(new_layout)


## Botin al morir un enemigo (las crias invocadas no sueltan nada). El tier sale del
## piso si hay uno cargado y, si no, del propio enemigo.
func _on_enemy_died(enemy: EnemySim) -> void:
	enemy_killed.emit(enemy)
	if enemy.summoned:
		return
	var tier: int = layout.tier if layout != null and layout.tier > 0 else int(enemy.data.get("tier", 1))
	var kind := "normal"
	if enemy.is_boss():
		var spike := TowerCatalog.spike_kind(layout.floor_number) if layout != null and layout.floor_number > 0 else ""
		kind = spike if spike != "" else ("mid_boss" if bool(enemy.data.get("elite_boss", false)) else "boss")
	player.add_gold(int(round(float(enemy.xp_reward()) * float(ItemCatalog.loot().get("gold_per_xp", 0.0)))))
	var material_table: Dictionary = enemy.data.get("materials", {})
	for kind_id: String in material_table:
		if loot_rng.randf() < float(material_table[kind_id]):
			player.add_material(MaterialCatalog.material_id(kind_id, tier), loot_rng.randi_range(1, 2) + (2 if kind != "normal" else 0))
	# Pociones sueltas: raras en enemigos normales, seguras en jefes.
	var loot_config := ItemCatalog.loot()
	var boss_kill := kind != "normal"
	if boss_kill or loot_rng.randf() < float(loot_config.get("potion_chance", 0.0)):
		player.add_consumable("health_potion", 2 if boss_kill else 1)
	if boss_kill or loot_rng.randf() < float(loot_config.get("resource_potion_chance", 0.0)):
		player.add_consumable("resource_potion", 1)
	var item := ItemGen.roll_drop(loot_rng, tier, kind, enemy.data.get("loot", {}))
	if enemy.elite and item.is_empty() and loot_rng.randf() < 0.6:
		item = ItemGen.roll_item(loot_rng, tier, "", "", "", "", 1.5)
	if item.is_empty():
		return
	var spot := resolve_position(enemy.position + Vector2.from_angle(loot_rng.randf() * TAU) * 14.0, 8.0)
	var drop := LootDrop.new(item, spot)
	loot_drops.append(drop)
	loot_spawned.emit(drop)
	loot_dropped.emit(item, spot)


## Crea un enemigo desde la descripcion de un layout: {id, position, required?, group?,
## elite?, boost?: [vida, dano], invulnerable?, scale_mult?}.
func spawn_from_spec(spec: Dictionary, base_scale: float) -> EnemySim:
	var enemy := add_enemy(StringName(String(spec["id"])), spec["position"], base_scale * float(spec.get("scale_mult", 1.0)))
	enemy.required = bool(spec.get("required", true))
	enemy.group = String(spec.get("group", ""))
	if bool(spec.get("elite", false)):
		enemy.make_elite()
	if spec.has("boost"):
		enemy.boost(float(spec["boost"][0]), float(spec["boost"][1]))
	enemy.invulnerable = bool(spec.get("invulnerable", false))
	return enemy


func submit_input(input: InputMessage) -> void:
	pending_input = input


func step(delta: float, tick_number: int = -1) -> void:
	step_delta = delta
	if tick_number >= 0:
		tick = tick_number
	else:
		tick += 1

	player.step(tick, delta, pending_input)
	for dummy: DummySim in dummies:
		dummy.step(tick, delta, player)
	for enemy: EnemySim in enemies.duplicate():
		enemy.step(tick, delta, player)
	for zone: GroundZone in zones.duplicate():
		zone.step(delta, player)
		if not zone.alive:
			zones.erase(zone)
	for projectile: ProjectileSim in projectiles.duplicate():
		projectile.step(self, delta)
		if not projectile.alive:
			projectiles.erase(projectile)
			projectile_removed.emit(projectile)

	_step_loot(delta)
	_step_pickup()
	_step_gather(delta)
	pending_input = null
	tick_advanced.emit(tick)


## Envejece el botin del suelo y borra el caducado.
func _step_loot(delta: float) -> void:
	for drop: LootDrop in loot_drops.duplicate():
		drop.age += delta
		if drop.expired():
			_remove_drop(drop)


## Lo que se puede coger con clic cerca de `point`: el item del suelo mas cercano al
## punto, dentro del radio de clic y del alcance del jugador. null si no hay.
func target_at(point: Vector2) -> Object:
	var best: Object = null
	var best_distance := INF
	for drop: LootDrop in loot_drops:
		var distance := drop.position.distance_to(point)
		if distance <= LootDrop.CLICK_RADIUS and distance < best_distance:
			best = drop
			best_distance = distance
	for node: ResourceNode in resource_nodes:
		var distance := node.position.distance_to(point)
		if not node.depleted and distance <= ResourceNode.CLICK_RADIUS and distance < best_distance:
			best = node
			best_distance = distance
	for object: Interactable in interactables:
		var distance := object.position.distance_to(point)
		if object.clickable() and distance <= Interactable.CLICK_RADIUS and distance < best_distance:
			best = object
			best_distance = distance
	return best


## Si el jugador llega a `target` (item o nodo) para cogerlo o recolectarlo.
func in_reach(target: Object) -> bool:
	if not player.alive or target == null:
		return false
	if target is LootDrop:
		return player.position.distance_to((target as LootDrop).position) <= LootDrop.PICKUP_RANGE
	if target is Interactable:
		return player.position.distance_to((target as Interactable).position) <= ResourceNode.GATHER_RANGE
	return player.position.distance_to((target as ResourceNode).position) <= ResourceNode.GATHER_RANGE


## Clic izquierdo sobre `point`: recoge el item o empieza a recolectar el nodo.
## Devuelve "" si hizo algo o el motivo: "none" (nada ahi), "far", "wait" (el item
## acaba de caer), "full" (mochila llena), "busy" (ya recolectando o atacando).
func try_click(point: Vector2) -> String:
	var target := target_at(point)
	if target == null:
		return "none"
	if not in_reach(target):
		return "far"
	if target is LootDrop:
		var drop := target as LootDrop
		if not drop.can_pick_up():
			return "wait"
		if not player.bag_has_room():
			player.bag_full.emit(drop.item)
			return "full"
		player.add_item(drop.item)
		_remove_drop(drop)
		return ""
	if target is Interactable and (target as Interactable).requires == "relic" and relics_carried <= 0:
		return "needs"
	if gather_node != null or player.state != PlayerSimScript.AttackState.IDLE or player.dodging:
		return "busy"
	var node: Object = target
	gather_node = node
	gather_left = node.gather_seconds()
	_gather_from = player.position
	_gather_health = player.health
	gather_started.emit(node)
	return ""


## Avanza la recoleccion: se interrumpe si el jugador se mueve, ataca, esquiva, recibe
## dano o muere; al terminar da materiales y agota el nodo.
func _step_gather(delta: float) -> void:
	if gather_node == null:
		return
	var reason := ""
	if not player.alive:
		reason = "dead"
	elif player.position.distance_to(_gather_from) > 3.0:
		reason = "moved"
	elif player.health < _gather_health - 0.001:
		reason = "hit"
	elif player.state != PlayerSimScript.AttackState.IDLE or player.dodging:
		reason = "busy"
	if reason != "":
		var node := gather_node
		gather_node = null
		gather_interrupted.emit(node, reason)
		return
	gather_left -= delta
	if gather_left > 0.0:
		return
	var finished := gather_node
	gather_node = null
	if finished is Interactable:
		var object := finished as Interactable
		object.done = true
		if object.kind == "relic":
			relics_carried += 1
		elif object.kind == "relic_altar":
			relics_carried = maxi(relics_carried - 1, 0)
		interacted.emit(object)
		return
	var node := finished as ResourceNode
	node.depleted = true
	var amount := ResourceNode.RICH_YIELD
	if not node.rich:
		var spec := MaterialCatalog.gather_yield()
		amount = loot_rng.randi_range(int(spec["min"]), int(spec["max"]))
		if loot_rng.randf() < float(spec["bonus_chance"]):
			amount += 1
	player.add_material(node.material_id(), amount)
	resource_gathered.emit(node, node.material_id(), amount)


## El clic de recoger actua una vez por pulsacion (flanco), sobre el cursor.
func _step_pickup() -> void:
	var pressed := pending_input != null and bool(pending_input.actions.get("pickup", false))
	if pressed and not _pickup_prev and player.alive:
		try_click(pending_input.target_pos)
	_pickup_prev = pressed


func _remove_drop(drop: LootDrop) -> void:
	loot_drops.erase(drop)
	loot_removed.emit(drop)


func _on_tick(tick_number: int, delta: float) -> void:
	step(delta, tick_number)


func get_living_dummies() -> Array:
	var living: Array = []
	for dummy: DummySim in dummies:
		if dummy.alive:
			living.append(dummy)
	return living


## Si un circulo de `radius` en `point` toca algun obstaculo fijo (pilares).
## Direccion para acercarse al jugador rodeando muros (campo de flujo desde la casilla
## del jugador, recalculado solo cuando el jugador cambia de casilla o se abre una
## puerta). ZERO si no hay mapa de casillas o ya esta en la casilla del jugador.
func path_direction(from: Vector2) -> Vector2:
	if grid == null:
		return Vector2.ZERO
	var cell := grid.world_to_cell(player.position)
	if cell != _flow_cell or grid.version != _flow_version:
		_flow_cell = cell
		_flow_version = grid.version
		_flow_field = grid.distance_field(cell)
	return grid.flow_direction(_flow_field, from)


## Si hay paso libre (sin muros) entre dos puntos; siempre true sin mapa de casillas.
func line_of_sight(a: Vector2, b: Vector2) -> bool:
	return grid == null or grid.line_clear(a, b)


func blocked_by_obstacle(point: Vector2, radius: float) -> bool:
	if grid != null and grid.shot_blocked(point, radius):
		return true
	for obstacle: Dictionary in obstacles:
		var min_distance := radius + float(obstacle["radius"])
		if point.distance_squared_to(obstacle["position"]) < min_distance * min_distance:
			return true
	return false


## Todo lo que el jugador puede golpear: muñecos y enemigos vivos.
func get_living_targets() -> Array:
	var living: Array = get_living_dummies()
	for enemy: EnemySim in enemies:
		if enemy.alive:
			living.append(enemy)
	return living


## Empuja `desired` fuera de limites, obstaculos, muñecos y enemigos vivos.
## `ignore` es quien se mueve (para no chocar consigo mismo).
func resolve_position(desired: Vector2, radius: float, ignore: Object = null) -> Vector2:
	var pos := desired
	pos.x = clampf(pos.x, bounds.position.x + radius, bounds.end.x - radius)
	pos.y = clampf(pos.y, bounds.position.y + radius, bounds.end.y - radius)
	if grid != null:
		pos = grid.push_out(pos, radius)

	for obstacle: Dictionary in obstacles:
		var center: Vector2 = obstacle["position"]
		var obstacle_radius := float(obstacle["radius"])
		var diff := pos - center
		var min_distance := radius + obstacle_radius
		if diff.length_squared() < min_distance * min_distance:
			if diff.length_squared() < 0.0001:
				diff = Vector2.RIGHT
			pos = center + diff.normalized() * min_distance

	for dummy: DummySim in dummies:
		if not dummy.alive:
			continue
		var diff := pos - dummy.position
		var min_distance := radius + dummy.radius
		if diff.length_squared() < min_distance * min_distance:
			if diff.length_squared() < 0.0001:
				diff = Vector2.RIGHT
			pos = dummy.position + diff.normalized() * min_distance

	for enemy: EnemySim in enemies:
		if not enemy.alive or enemy == ignore:
			continue
		var diff := pos - enemy.position
		var min_distance := radius + enemy.radius
		if diff.length_squared() < min_distance * min_distance:
			if diff.length_squared() < 0.0001:
				diff = Vector2.RIGHT
			pos = enemy.position + diff.normalized() * min_distance

	return pos


func reset() -> void:
	tick = 0
	pending_input = null
	player.reset(bounds.get_center())
	for dummy: DummySim in dummies:
		dummy.position = dummy.spawn_position
		dummy.revive()
	# Las crias invocadas por un jefe desaparecen con el reinicio.
	for enemy: EnemySim in enemies.duplicate():
		if enemy.summoned:
			enemy.alive = false
			enemy.state_time = 99.0
			enemies.erase(enemy)
	for enemy: EnemySim in enemies:
		enemy.revive()
	for projectile: ProjectileSim in projectiles.duplicate():
		projectile.alive = false
		projectile_removed.emit(projectile)
	projectiles.clear()


func snapshot() -> Dictionary:
	var dummy_states: Array = []
	for dummy: DummySim in dummies:
		dummy_states.append(dummy.snapshot())
	var enemy_states: Array = []
	for enemy: EnemySim in enemies:
		enemy_states.append(enemy.snapshot())
	return {
		"tick": tick,
		"player": player.snapshot(),
		"dummies": dummy_states,
		"enemies": enemy_states,
		"projectiles": projectiles.map(func(p: ProjectileSim) -> Dictionary: return p.snapshot()),
	}
