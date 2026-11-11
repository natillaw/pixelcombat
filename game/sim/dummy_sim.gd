## DummySim — simulación determinista de un muñeco de entrenamiento.
##
## Vive dentro de CombatWorld (RefCounted, sin nodos) para poder probarse en
## headless. La presentación (game/actors/dummy_actor.gd) solo lee su estado.
class_name DummySim
extends RefCounted

signal health_changed(current: float, maximum: float)
signal telegraph_started(direction: Vector2, radius: float, arc_degrees: float)
signal attack_landed(damage: float)
signal attack_missed()
signal hit(amount: float, position: Vector2)
signal died()
signal revived()

enum State { IDLE, TELEGRAPH, RECOVER, DEAD }

const MAX_HEALTH := 300.0
const RADIUS := 16.0
const ATTACK_RANGE := 92.0
const ATTACK_ARC := 70.0
const ATTACK_DAMAGE := 22.0
const TELEGRAPH_SECONDS := 0.72
const RECOVER_SECONDS := 0.35
const COOLDOWN_SECONDS := 2.60
const RESPAWN_SECONDS := 3.0

var world: Object = null
var position: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO
var auto_attack: bool = true
var max_health: float = MAX_HEALTH
var health: float = MAX_HEALTH
var alive: bool = true
var state: int = State.IDLE
var state_time: float = 0.0
var cooldown: float = 0.0
var facing: Vector2 = Vector2.LEFT
var hit_flash_ticks: int = 0
var radius: float = RADIUS
var attack_direction: Vector2 = Vector2.LEFT


func _init(p_world: Object = null, p_position: Vector2 = Vector2.ZERO, p_auto_attack: bool = true) -> void:
	world = p_world
	position = p_position
	spawn_position = p_position
	auto_attack = p_auto_attack


func step(tick_number: int, delta: float, warrior: Object) -> void:
	if not alive:
		state_time += delta
		if state_time >= RESPAWN_SECONDS:
			revive()
		return

	if hit_flash_ticks > 0:
		hit_flash_ticks -= 1

	if warrior != null and warrior.alive:
		facing = (warrior.position - position).normalized()

	cooldown = maxf(0.0, cooldown - delta)

	if not auto_attack:
		return

	match state:
		State.IDLE:
			if warrior != null and warrior.alive and cooldown <= 0.0:
				if position.distance_to(warrior.position) <= ATTACK_RANGE:
					_start_telegraph()
		State.TELEGRAPH:
			state_time += delta
			if state_time >= TELEGRAPH_SECONDS:
				_resolve_attack(warrior)
		State.RECOVER:
			state_time += delta
			if state_time >= RECOVER_SECONDS:
				state = State.IDLE
				state_time = 0.0
		_:
			pass


func _start_telegraph() -> void:
	state = State.TELEGRAPH
	state_time = 0.0
	attack_direction = facing
	telegraph_started.emit(attack_direction, ATTACK_RANGE, ATTACK_ARC)


func _resolve_attack(warrior: Object) -> void:
	state = State.RECOVER
	state_time = 0.0
	cooldown = COOLDOWN_SECONDS

	if warrior == null or not warrior.alive:
		attack_missed.emit()
		return

	var to_target: Vector2 = warrior.position - position
	if to_target.length() > ATTACK_RANGE:
		attack_missed.emit()
		return

	var angle_degrees := rad_to_deg(attack_direction.angle_to(to_target))
	if absf(angle_degrees) > ATTACK_ARC * 0.5:
		attack_missed.emit()
		return

	var dealt: float = warrior.take_damage(ATTACK_DAMAGE, position, false)
	attack_landed.emit(dealt)


func take_damage(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, health)
	health -= dealt
	hit_flash_ticks = 6
	health_changed.emit(health, max_health)
	hit.emit(dealt, position)
	if health <= 0.0:
		health = 0.0
		alive = false
		state = State.DEAD
		state_time = 0.0
		died.emit()
	return dealt


func revive() -> void:
	alive = true
	health = max_health
	state = State.IDLE
	state_time = 0.0
	cooldown = 1.0
	hit_flash_ticks = 0
	health_changed.emit(health, max_health)
	revived.emit()


func telegraph_progress() -> float:
	if state != State.TELEGRAPH:
		return 0.0
	return clampf(state_time / TELEGRAPH_SECONDS, 0.0, 1.0)


func is_telegraphing() -> bool:
	return state == State.TELEGRAPH


func snapshot() -> Dictionary:
	return {
		"position": [position.x, position.y],
		"health": health,
		"max_health": max_health,
		"alive": alive,
		"state": state,
		"telegraph": telegraph_progress(),
	}
