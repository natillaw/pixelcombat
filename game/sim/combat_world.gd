## CombatWorld — unidad determinista de simulación del primer corte.
##
## Es el único Tickable registrado en TickManager. Dentro de un tick avanza al
## Warrior y a los muñecos en orden fijo. El mismo objeto se puede crear y
## avanzar en headless (step) sin árbol de escena, y su snapshot() es la base
## para netcode: input por tick -> simulación -> snapshot.
class_name CombatWorld
extends "res://core/tickable.gd"

signal tick_advanced(tick_number: int)

const WarriorSimScript := preload("res://game/sim/warrior_sim.gd")
const DummySimScript := preload("res://game/sim/dummy_sim.gd")

const DEFAULT_BOUNDS := Rect2(0, 0, 960, 640)

var tick: int = 0
var rng: RandomNumberGenerator
var bounds: Rect2 = DEFAULT_BOUNDS
var obstacles: Array = []
var warrior: WarriorSim
var dummies: Array = []
var pending_input: InputMessage = null


func _init(seed_value: int = 1337) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	warrior = WarriorSimScript.new(self)
	warrior.position = Vector2(480, 380)


func setup_arena(arena_bounds: Rect2, arena_obstacles: Array = []) -> void:
	bounds = arena_bounds
	obstacles = arena_obstacles.duplicate()
	warrior.position = bounds.get_center()
	warrior.reset(bounds.get_center())


func add_dummy(spawn: Vector2, auto_attack: bool = true) -> DummySim:
	var dummy := DummySimScript.new(self, spawn, auto_attack)
	dummies.append(dummy)
	return dummy


func submit_input(input: InputMessage) -> void:
	pending_input = input


func step(delta: float, tick_number: int = -1) -> void:
	if tick_number >= 0:
		tick = tick_number
	else:
		tick += 1

	warrior.step(tick, delta, pending_input)
	for dummy: DummySim in dummies:
		dummy.step(tick, delta, warrior)

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


func resolve_position(desired: Vector2, radius: float) -> Vector2:
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

	return pos


func reset() -> void:
	tick = 0
	pending_input = null
	warrior.reset(bounds.get_center())
	for dummy: DummySim in dummies:
		dummy.position = dummy.spawn_position
		dummy.revive()


func snapshot() -> Dictionary:
	var dummy_states: Array = []
	for dummy: DummySim in dummies:
		dummy_states.append(dummy.snapshot())
	return {
		"tick": tick,
		"warrior": warrior.snapshot(),
		"dummies": dummy_states,
	}
