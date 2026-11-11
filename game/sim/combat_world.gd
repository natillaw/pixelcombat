## CombatWorld — unidad determinista de simulación del primer corte.
##
## Es el único Tickable registrado en TickManager. Dentro de un tick avanza al
## Warrior y a los muñecos en orden fijo. El mismo objeto se puede crear y
## avanzar en headless (step) sin árbol de escena, y su snapshot() es la base
## para netcode: input por tick -> simulación -> snapshot.
class_name CombatWorld
extends "res://core/tickable.gd"

signal tick_advanced(tick_number: int)

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
var pending_input: InputMessage = null


func _init(seed_value: int = 1337) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
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
func add_enemy(def_id: StringName, spawn: Vector2) -> EnemySim:
	var enemy := EnemySim.new(self, def_id, spawn, int(rng.seed) + (enemies.size() + 1) * 7919)
	enemies.append(enemy)
	return enemy


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
	for enemy: EnemySim in enemies:
		enemy.step(tick, delta, player)

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


## Todo lo que el Warrior puede golpear: muñecos y enemigos vivos.
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
	for enemy: EnemySim in enemies:
		enemy.revive()


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
	}
