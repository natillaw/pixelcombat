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
signal layout_loaded(layout: FloorLayout)
signal loot_dropped(item: Dictionary, position: Vector2)

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


func _init(seed_value: int = 1337) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	loot_rng = RandomNumberGenerator.new()
	loot_rng.seed = seed_value * 31 + 7
	player = PlayerSimScript.new(self)
	player.position = Vector2(480, 380)


func setup_arena(arena_bounds: Rect2, arena_obstacles: Array = []) -> void:
	bounds = arena_bounds
	obstacles = arena_obstacles.duplicate()
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
	dummies.clear()
	enemies.clear()
	pending_input = null
	setup_arena(new_layout.bounds(), new_layout.obstacles)
	player.position = new_layout.player_spawn
	player.reset(new_layout.player_spawn)
	for spec: Dictionary in new_layout.dummies:
		add_dummy(spec["position"], bool(spec["auto_attack"]))
	for spec: Dictionary in new_layout.enemies:
		var enemy := add_enemy(StringName(String(spec["id"])), spec["position"], new_layout.enemy_scale)
		enemy.required = bool(spec.get("required", true))
	loading_layout = false
	layout_loaded.emit(new_layout)


## Botin al morir un enemigo (las crias invocadas no sueltan nada). El tier sale del
## piso si hay uno cargado y, si no, del propio enemigo.
func _on_enemy_died(enemy: EnemySim) -> void:
	if enemy.summoned:
		return
	var tier: int = layout.tier if layout != null and layout.tier > 0 else int(enemy.data.get("tier", 1))
	var kind := "normal"
	if enemy.is_boss():
		var spike := TowerCatalog.spike_kind(layout.floor_number) if layout != null and layout.floor_number > 0 else ""
		kind = spike if spike != "" else "boss"
	player.add_gold(int(round(float(enemy.xp_reward()) * float(ItemCatalog.loot().get("gold_per_xp", 0.0)))))
	var item := ItemGen.roll_drop(loot_rng, tier, kind, enemy.data.get("loot", {}))
	if item.is_empty():
		return
	player.add_item(item)
	loot_dropped.emit(item, enemy.position)


func submit_input(input: InputMessage) -> void:
	pending_input = input


func step(delta: float, tick_number: int = -1) -> void:
	if tick_number >= 0:
		tick = tick_number
	else:
		tick += 1

	player.step(tick, delta, pending_input)
	for dummy: DummySim in dummies:
		dummy.step(tick, delta, player)
	for enemy: EnemySim in enemies.duplicate():
		enemy.step(tick, delta, player)
	for projectile: ProjectileSim in projectiles.duplicate():
		projectile.step(self, delta)
		if not projectile.alive:
			projectiles.erase(projectile)
			projectile_removed.emit(projectile)

	pending_input = null
	tick_advanced.emit(tick)


func _on_tick(tick_number: int, delta: float) -> void:
	step(delta, tick_number)


func get_living_dummies() -> Array:
	var living: Array = []
	for dummy: DummySim in dummies:
		if dummy.alive:
			living.append(dummy)
	return living


## Si un circulo de `radius` en `point` toca algun obstaculo fijo (pilares).
func blocked_by_obstacle(point: Vector2, radius: float) -> bool:
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
