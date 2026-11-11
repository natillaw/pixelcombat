## WarriorSim — simulación determinista del Warrior (primer corte).
##
## Solo cambia dentro de step(), que llama CombatWorld una vez por tick fijo.
## La presentación lee sus campos y escucha sus señales; nunca escribe estado.
##
## Implementado: M1 Sword Slash, M2 Heavy Strike, Rage, Vengeful Fury, muerte y
## reset. El Skill Book completo vive en WarriorKit como datos.
class_name WarriorSim
extends RefCounted

signal health_changed(current: float, maximum: float)
signal rage_changed(current: float, maximum: float)
signal attack_started(skill: Dictionary, direction: Vector2)
signal attack_hit(skill: Dictionary, target: Object, damage: float, critical: bool, hit_position: Vector2)
signal attack_finished(skill: Dictionary)
signal damage_taken(amount: float, source_position: Vector2, is_dot: bool)
signal died()
signal vengeful_changed(active: bool, seconds_left: float)
signal attack_state_changed(state: int)

enum AttackState { IDLE, WINDUP, ACTIVE, RECOVERY }

const RADIUS := 14.0
const MOVE_SPEED := 168.0
const ACCELERATION := 1500.0
const FRICTION := 2100.0
const BASE_HEALTH := 100.0
const HEALTH_PER_STAMINA := 10.0

const RAGE_DECAY_GRACE := 5.0
const RAGE_DECAY_PER_SECOND := 6.0
const RAGE_TAKEN_CAP := 15.0
const RAGE_TAKEN_MIN := 1.0

const BUFFER_SECONDS := 0.25
const CRIT_MULTIPLIER := 1.5

var world: Object = null
var stats: CharacterStats
var resource: ClassResource

var position: Vector2 = Vector2(480, 380)
var velocity: Vector2 = Vector2.ZERO
var move_input: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.RIGHT

var max_health: float = 1.0
var health: float = 1.0
var alive: bool = true

var state: int = AttackState.IDLE
var state_time: float = 0.0
var current_skill: Dictionary = {}
var attack_aim: Vector2 = Vector2.RIGHT
var cooldown_m1: float = 0.0
var cooldown_m2: float = 0.0
var buffered_slot: String = ""
var buffer_timer: float = 0.0

var vengeful_active: bool = false
var vengeful_until_tick: int = 0

var tick: int = 0
var last_combat_tick: int = 0
var swing_rage_gained: float = 0.0
var _attack_damage_mult: float = 1.0

var _m1_held: bool = false
var _rng: RandomNumberGenerator


func _init(p_world: Object = null) -> void:
	world = p_world
	_rng = _make_rng()
	_build_stats()
	resource = WarriorKit.create_rage_resource()
	reset(position)


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if world != null and world.get("rng") != null:
		rng.seed = int(world.rng.seed)
	else:
		rng.seed = 1337
	return rng


func _build_stats() -> void:
	stats = CharacterStats.new()
	stats.set_base_stat(&"strength", 20.0)
	stats.set_base_stat(&"stamina", 18.0)
	stats.set_base_stat(&"agility", 10.0)
	stats.set_base_stat(&"armor", 40.0)
	stats.set_base_stat(&"attack_power_bonus", 0.0)
	stats.set_base_stat(&"crit_chance", 0.10)
	stats.set_base_stat(&"weapon_min", 12.0)
	stats.set_base_stat(&"weapon_max", 18.0)
	stats.set_base_stat(&"weapon_speed", 2.6)
	max_health = BASE_HEALTH + stats.get_stat(&"stamina") * HEALTH_PER_STAMINA
	health = max_health


func reset(spawn: Vector2 = Vector2(480, 380)) -> void:
	position = spawn
	velocity = Vector2.ZERO
	move_input = Vector2.ZERO
	aim_dir = Vector2.RIGHT
	health = max_health
	alive = true
	state = AttackState.IDLE
	state_time = 0.0
	current_skill = {}
	cooldown_m1 = 0.0
	cooldown_m2 = 0.0
	buffered_slot = ""
	buffer_timer = 0.0
	vengeful_active = false
	vengeful_until_tick = 0
	last_combat_tick = 0
	swing_rage_gained = 0.0
	resource.current_amount = 0.0
	health_changed.emit(health, max_health)
	rage_changed.emit(resource.get_current(), resource.max_amount)
	attack_state_changed.emit(state)


func step(tick_number: int, delta: float, input: Object) -> void:
	tick = tick_number
	_read_input(input)
	_tick_timers(delta)
	_update_attack(delta)
	_update_movement(delta)
	_update_rage(delta)


func _read_input(input: Object) -> void:
	if input == null:
		move_input = Vector2.ZERO
		_m1_held = false
		return
	move_input = (input.move_dir as Vector2).limit_length(1.0)
	var aim: Vector2 = input.aim_dir
	if aim.length_squared() > 0.0001:
		aim_dir = aim.normalized()
	_m1_held = bool(input.actions.get("m1", false))
	if bool(input.actions.get("m2", false)):
		buffered_slot = "M2"
		buffer_timer = BUFFER_SECONDS


func _tick_timers(delta: float) -> void:
	cooldown_m1 = maxf(0.0, cooldown_m1 - delta)
	cooldown_m2 = maxf(0.0, cooldown_m2 - delta)
	if buffer_timer > 0.0:
		buffer_timer = maxf(0.0, buffer_timer - delta)
		if buffer_timer <= 0.0:
			buffered_slot = ""


func _update_attack(delta: float) -> void:
	if state == AttackState.IDLE:
		_try_start_attack()
		return

	state_time += delta

	if state == AttackState.WINDUP and state_time >= float(current_skill["windup"]):
		state = AttackState.ACTIVE
		state_time -= float(current_skill["windup"])
		_resolve_attack_hit()
		attack_state_changed.emit(state)
	elif state == AttackState.ACTIVE and state_time >= float(current_skill["active"]):
		state = AttackState.RECOVERY
		state_time -= float(current_skill["active"])
		attack_state_changed.emit(state)
	elif state == AttackState.RECOVERY and state_time >= float(current_skill["recovery"]):
		var finished := current_skill
		state = AttackState.IDLE
		state_time = 0.0
		current_skill = {}
		attack_state_changed.emit(state)
		attack_finished.emit(finished)


func _try_start_attack() -> void:
	if not alive:
		return
	if buffered_slot == "M2" and cooldown_m2 <= 0.0:
		buffered_slot = ""
		buffer_timer = 0.0
		_start_attack("M2")
		return
	if _m1_held and cooldown_m1 <= 0.0:
		_start_attack("M1")


func _start_attack(slot: String) -> void:
	if state != AttackState.IDLE:
		return
	if slot != "M1" and slot != "M2":
		return

	current_skill = WarriorKit.M1.duplicate(true) if slot == "M1" else WarriorKit.M2.duplicate(true)
	attack_aim = aim_dir
	state = AttackState.WINDUP
	state_time = 0.0
	swing_rage_gained = 0.0
	_attack_damage_mult = float(current_skill["damage_mult"])

	if slot == "M2" and vengeful_active:
		_attack_damage_mult *= 1.0 + float(WarriorKit.PASSIVE["bonus"])
		vengeful_active = false
		vengeful_until_tick = 0
		vengeful_changed.emit(false, 0.0)

	var total := total_attack_duration(current_skill)
	if slot == "M1":
		cooldown_m1 = total + float(current_skill["cooldown"])
	else:
		cooldown_m2 = total + float(current_skill["cooldown"])

	attack_state_changed.emit(state)
	attack_started.emit(current_skill, attack_aim)


func _resolve_attack_hit() -> void:
	if current_skill.is_empty() or world == null:
		return
	var attack_range := float(current_skill["range"])
	var half_arc := float(current_skill["arc"]) * 0.5
	var targets: Array = world.get_living_dummies()

	for target: Object in targets:
		var to_target: Vector2 = target.position - position
		var distance := to_target.length()
		if distance <= 0.001 or distance > attack_range + target.radius:
			continue
		if absf(rad_to_deg(attack_aim.angle_to(to_target))) > half_arc:
			continue

		var critical: bool = _rng.randf() < stats.get_crit_chance()
		var damage: float = stats.roll_weapon_damage(_rng) * _attack_damage_mult
		if critical:
			damage *= CRIT_MULTIPLIER
		var dealt: float = target.take_damage(damage)

		var rage_left: float = float(current_skill["rage_cap"]) - swing_rage_gained
		var rage_gain := minf(float(current_skill["rage_gain"]), maxf(rage_left, 0.0))
		if rage_gain > 0.0:
			swing_rage_gained += rage_gain
			_gain_rage(rage_gain)

		last_combat_tick = tick
		attack_hit.emit(current_skill, target, dealt, critical, target.position)


func _update_movement(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return
	var factor := _movement_factor()
	var desired := move_input * MOVE_SPEED * factor
	var rate := ACCELERATION if move_input.length_squared() > 0.0001 else FRICTION
	velocity = velocity.move_toward(desired, rate * delta)
	if velocity.length_squared() < 0.01:
		velocity = Vector2.ZERO
	position += velocity * delta
	if world != null:
		position = world.resolve_position(position, RADIUS)


func _movement_factor() -> float:
	if state == AttackState.IDLE:
		return 1.0
	var slot := String(current_skill.get("slot", "M1"))
	if state == AttackState.WINDUP:
		return 0.35 if slot == "M1" else 0.0
	if state == AttackState.ACTIVE:
		return 0.15 if slot == "M1" else 0.0
	return 0.50 if slot == "M1" else 0.20


func _gain_rage(amount: float) -> void:
	var before := resource.get_current()
	resource.generate(amount)
	if not is_equal_approx(before, resource.get_current()):
		rage_changed.emit(resource.get_current(), resource.max_amount)


func _update_rage(delta: float) -> void:
	if vengeful_active and tick >= vengeful_until_tick:
		vengeful_active = false
		vengeful_changed.emit(false, 0.0)

	if resource.get_current() <= 0.0:
		return
	var grace_ticks := int(RAGE_DECAY_GRACE * 60.0)
	if tick - last_combat_tick > grace_ticks:
		var before := resource.get_current()
		resource.current_amount = maxf(0.0, before - RAGE_DECAY_PER_SECOND * delta)
		if not is_equal_approx(before, resource.get_current()):
			rage_changed.emit(resource.get_current(), resource.max_amount)


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, is_dot: bool = false) -> float:
	if not alive or amount <= 0.0:
		return 0.0

	var reduced := amount * (1.0 - armor_reduction())
	var dealt := minf(reduced, health)
	health -= dealt

	var percent_lost := (dealt / max_health) * 100.0
	_gain_rage(clampf(percent_lost, RAGE_TAKEN_MIN, RAGE_TAKEN_CAP))
	last_combat_tick = tick

	if not is_dot:
		vengeful_active = true
		vengeful_until_tick = tick + int(float(WarriorKit.PASSIVE["window"]) * 60.0)
		vengeful_changed.emit(true, vengeful_seconds_left())

	health_changed.emit(health, max_health)
	damage_taken.emit(dealt, source_position, is_dot)

	if health <= 0.0:
		health = 0.0
		alive = false
		state = AttackState.IDLE
		current_skill = {}
		velocity = Vector2.ZERO
		died.emit()

	return dealt


func armor_reduction() -> float:
	var armor := stats.get_stat(&"armor")
	return armor / (armor + 100.0)


func vengeful_seconds_left() -> float:
	if not vengeful_active:
		return 0.0
	return maxf(0.0, float(vengeful_until_tick - tick) / 60.0)


func total_attack_duration(skill: Dictionary) -> float:
	if skill.is_empty():
		return 0.0
	return float(skill["windup"]) + float(skill["active"]) + float(skill["recovery"])


func attack_cooldown_left(slot: String) -> float:
	return cooldown_m1 if slot == "M1" else cooldown_m2


func attack_cooldown_total(slot: String) -> float:
	var skill := WarriorKit.M1 if slot == "M1" else WarriorKit.M2
	return total_attack_duration(skill) + float(skill["cooldown"])


func is_attacking() -> bool:
	return state != AttackState.IDLE


func rage() -> float:
	return resource.get_current()


func snapshot() -> Dictionary:
	return {
		"position": [position.x, position.y],
		"velocity": [velocity.x, velocity.y],
		"aim": [aim_dir.x, aim_dir.y],
		"health": health,
		"max_health": max_health,
		"rage": resource.get_current(),
		"state": state,
		"vengeful": vengeful_active,
		"alive": alive,
	}
