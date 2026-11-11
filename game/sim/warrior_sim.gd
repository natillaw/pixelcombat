## WarriorSim — simulación determinista del Warrior (primer corte).
##
## Solo cambia dentro de step(), que llama CombatWorld una vez por tick fijo.
## La presentación lee sus campos y escucha sus señales; nunca escribe estado.
##
## Implementado: skills por datos (M1, M2 y S1-S5 desde SkillCatalog, con coste de
## Rage, cooldown y formas cone/line/circle), esquiva con i-frames, Rage,
## Vengeful Fury, M1 con cargas y M2 que se carga manteniendo el boton (estilo
## Drakantos), Ultimate Charge (sube al conectar golpes; War God's Descent la
## gasta entera), muerte y reset. El Skill Book completo vive en WarriorKit.
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
signal dodge_started(direction: Vector2)
signal dodge_ended()
signal attack_evaded(source_position: Vector2)
signal skill_denied(slot: String, reason: String)
signal ultimate_changed(current: float, maximum: float)
signal ultimate_ready()

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
const SKILL_SLOTS := ["S1", "S2", "S3", "S4", "S5"]
## Slots que se lanzan al pulsar (M1 se lanza manteniendo el boton).
const EDGE_SLOTS := ["M2", "S1", "S2", "S3", "S4", "S5"]
const DEFAULT_LOADOUT := {
	"M1": &"warrior_m1",
	"M2": &"warrior_m2",
	"S1": &"cleaving_strike",
	"S2": &"piercing_thrust",
	"ULTIMATE": &"war_gods_descent",
}
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
## slot -> segundos restantes. Un slot sin entrada esta listo.
var cooldowns: Dictionary = {}
## slot -> skill (copia del catalogo). Se cambia con set_loadout() en zona segura.
var loadout: Dictionary = {}
var buffered_slot: String = ""
var buffer_timer: float = 0.0

## Ultimate Charge 0..ULTIMATE_CHARGE_MAX. Sube al conectar golpes.
var ultimate_charge: float = 0.0
## Segundos que lleva cargandose el ataque actual con `hold` (M2).
var hold_time: float = 0.0
## slot -> cargas actuales (decimal: se recargan de forma continua). Solo slots
## cuya skill declara `charges` (M1).
var charges: Dictionary = {}
## Punto de aterrizaje de las skills con anchor aim_leap (y origen del salto).
var attack_point: Vector2 = Vector2.ZERO

var dodging: bool = false
var dodge_time: float = 0.0
var dodge_dir: Vector2 = Vector2.DOWN
var cooldown_dodge: float = 0.0
var dodge_buffer_timer: float = 0.0

var vengeful_active: bool = false
var vengeful_until_tick: int = 0

var tick: int = 0
var last_combat_tick: int = 0
var swing_rage_gained: float = 0.0
var swing_ult_gained: float = 0.0
var _attack_damage_mult: float = 1.0

var _m1_held: bool = false
var _slot_prev: Dictionary = {}
var _actions: Dictionary = {}
var _range_mult: float = 1.0
var _dodge_prev: bool = false
var _rng: RandomNumberGenerator


func _init(p_world: Object = null) -> void:
	world = p_world
	_rng = _make_rng()
	_build_stats()
	resource = WarriorKit.create_rage_resource()
	set_loadout(DEFAULT_LOADOUT)
	reset(position)


## Equipa skills por slot ({"M1": id, "M2": id, "S1": id, ...}). Ignora ids que
## no existen o no estan implementados, y slots desconocidos.
func set_loadout(new_loadout: Dictionary) -> void:
	loadout = {}
	charges = {}
	for slot: String in new_loadout:
		if slot != "M1" and slot != "M2" and slot != "ULTIMATE" and not SKILL_SLOTS.has(slot):
			continue
		var skill: Dictionary = SkillCatalog.skill(StringName(String(new_loadout[slot])))
		if skill.is_empty() or not bool(skill.get("implemented", false)):
			continue
		skill["slot"] = slot
		loadout[slot] = skill
		if skill.has("charges"):
			charges[slot] = float(skill["charges"]["max"])


func _refill_charges() -> void:
	for slot: String in loadout:
		var skill: Dictionary = loadout[slot]
		if skill.has("charges"):
			charges[slot] = float(skill["charges"]["max"])


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
	cooldowns = {}
	_slot_prev = {}
	buffered_slot = ""
	buffer_timer = 0.0
	dodging = false
	dodge_time = 0.0
	cooldown_dodge = 0.0
	dodge_buffer_timer = 0.0
	_dodge_prev = false
	vengeful_active = false
	vengeful_until_tick = 0
	last_combat_tick = 0
	swing_rage_gained = 0.0
	swing_ult_gained = 0.0
	hold_time = 0.0
	_range_mult = 1.0
	_refill_charges()
	ultimate_charge = 0.0
	attack_point = position
	resource.current_amount = 0.0
	ultimate_changed.emit(ultimate_charge, WarriorKit.ULTIMATE_CHARGE_MAX)
	health_changed.emit(health, max_health)
	rage_changed.emit(resource.get_current(), resource.max_amount)
	attack_state_changed.emit(state)


func step(tick_number: int, delta: float, input: Object) -> void:
	tick = tick_number
	_read_input(input)
	_tick_timers(delta)
	_update_dodge(delta)
	_update_attack(delta)
	_update_movement(delta)
	_update_rage(delta)


func _read_input(input: Object) -> void:
	_actions = {} if input == null else input.actions
	if input == null:
		move_input = Vector2.ZERO
		_m1_held = false
		_dodge_prev = false
		_slot_prev = {}
		return
	move_input = (input.move_dir as Vector2).limit_length(1.0)
	var aim: Vector2 = input.aim_dir
	if aim.length_squared() > 0.0001:
		aim_dir = aim.normalized()
	_m1_held = bool(input.actions.get("m1", false))
	var dodge_pressed := bool(input.actions.get("dodge", false))
	if dodge_pressed and not _dodge_prev:
		dodge_buffer_timer = float(WarriorKit.DODGE["buffer"])
	_dodge_prev = dodge_pressed
	# M2 y S1-S5 se lanzan al pulsar (mantener M2 despues del windup la carga).
	for slot: String in EDGE_SLOTS:
		var pressed := bool(input.actions.get(slot.to_lower(), false))
		if pressed and not bool(_slot_prev.get(slot, false)):
			buffered_slot = slot
			buffer_timer = BUFFER_SECONDS
		_slot_prev[slot] = pressed
	var ult_pressed := bool(input.actions.get("ultimate", false))
	if ult_pressed and not bool(_slot_prev.get("ULTIMATE", false)):
		buffered_slot = "ULTIMATE"
		buffer_timer = BUFFER_SECONDS
	_slot_prev["ULTIMATE"] = ult_pressed


func _tick_timers(delta: float) -> void:
	for slot: String in charges.keys():
		var recharge := float((loadout[slot] as Dictionary)["charges"]["recharge"])
		charges[slot] = minf(float((loadout[slot] as Dictionary)["charges"]["max"]), float(charges[slot]) + delta / recharge)
	for slot: String in cooldowns.keys():
		var left := maxf(0.0, float(cooldowns[slot]) - delta)
		if left <= 0.0:
			cooldowns.erase(slot)
		else:
			cooldowns[slot] = left
	cooldown_dodge = maxf(0.0, cooldown_dodge - delta)
	dodge_buffer_timer = maxf(0.0, dodge_buffer_timer - delta)
	if buffer_timer > 0.0:
		buffer_timer = maxf(0.0, buffer_timer - delta)
		if buffer_timer <= 0.0:
			buffered_slot = ""


## Esquiva: avanza la que esta en curso o arranca la bufferizada. Puede cancelar
## un ataque en WINDUP o RECOVERY, no en ACTIVE.
func _update_dodge(delta: float) -> void:
	if dodging:
		dodge_time += delta
		return
	if dodge_buffer_timer <= 0.0 or cooldown_dodge > 0.0 or not alive:
		return
	if state == AttackState.ACTIVE:
		return
	if state != AttackState.IDLE and bool(current_skill.get("uncancelable", false)):
		return
	_start_dodge(delta)


func _start_dodge(delta_for_start: float) -> void:
	dodge_buffer_timer = 0.0
	if state != AttackState.IDLE:
		_cancel_attack()
	if move_input.length_squared() > 0.0001:
		dodge_dir = move_input.normalized()
	else:
		dodge_dir = -aim_dir
	dodging = true
	dodge_time = delta_for_start
	cooldown_dodge = float(WarriorKit.DODGE["cooldown"])
	dodge_started.emit(dodge_dir)


## Corta el ataque actual sin resolver el golpe. Los cooldowns ya gastados se
## conservan para que cancelar con la esquiva no sea gratis.
func _cancel_attack() -> void:
	var cancelled := current_skill
	state = AttackState.IDLE
	state_time = 0.0
	current_skill = {}
	buffered_slot = ""
	buffer_timer = 0.0
	hold_time = 0.0
	attack_state_changed.emit(state)
	attack_finished.emit(cancelled)


func _update_attack(delta: float) -> void:
	if state == AttackState.IDLE:
		_try_start_attack()
		return

	state_time += delta

	if state == AttackState.WINDUP and state_time >= float(current_skill["windup"]):
		if _is_charging(delta):
			return
		_apply_hold_bonus()
		state = AttackState.ACTIVE
		state_time -= float(current_skill["windup"])
		if String(current_skill.get("anchor", "self")) == "aim_leap":
			position = attack_point
			velocity = Vector2.ZERO
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


## Mantener el boton de una skill con `hold` tras acabar el windup la carga hasta
## su maximo, momento en que se lanza sola. Devuelve true mientras sigue cargando.
func _is_charging(delta: float) -> bool:
	if not current_skill.has("hold"):
		return false
	var max_hold := float(current_skill["hold"]["max"])
	if hold_time >= max_hold or not _slot_held(String(current_skill["slot"])):
		return false
	hold_time = minf(hold_time + delta, max_hold)
	state_time = float(current_skill["windup"])
	return hold_time < max_hold


func _slot_held(slot: String) -> bool:
	return bool(_actions.get(slot.to_lower(), false))


## Aplica el bonus de la carga justo al soltar: dano y alcance proporcionales a
## lo mantenido.
func _apply_hold_bonus() -> void:
	if not current_skill.has("hold") or hold_time <= 0.0:
		return
	var hold: Dictionary = current_skill["hold"]
	var fraction := clampf(hold_time / float(hold["max"]), 0.0, 1.0)
	_attack_damage_mult *= 1.0 + fraction * float(hold["damage_bonus"])
	_range_mult = 1.0 + fraction * float(hold["range_bonus"])


## 0..1: cuanto lleva cargado el ataque actual (0 si no tiene `hold`).
func charge_fraction() -> float:
	if state != AttackState.WINDUP or not current_skill.has("hold"):
		return 0.0
	return clampf(hold_time / float(current_skill["hold"]["max"]), 0.0, 1.0)


## Alcance real del ataque actual, con el bonus de carga ya aplicado.
func attack_range_now() -> float:
	if current_skill.is_empty():
		return 0.0
	return float(current_skill["range"]) * _range_mult


func charges_left(slot: String) -> float:
	return float(charges.get(slot, 0.0))


func charges_max(slot: String) -> float:
	if not loadout.has(slot) or not (loadout[slot] as Dictionary).has("charges"):
		return 0.0
	return float((loadout[slot] as Dictionary)["charges"]["max"])


func _try_start_attack() -> void:
	if not alive or dodging:
		return
	if buffered_slot != "":
		var slot := buffered_slot
		if not loadout.has(slot):
			buffered_slot = ""
			buffer_timer = 0.0
		elif attack_cooldown_left(slot) <= 0.0:
			buffered_slot = ""
			buffer_timer = 0.0
			var reason := _afford_reason(slot)
			if reason.is_empty():
				_start_attack(slot)
				return
			skill_denied.emit(slot, reason)
	if _m1_held and loadout.has("M1") and attack_cooldown_left("M1") <= 0.0 and _afford_reason("M1").is_empty():
		_start_attack("M1")


## "" si se puede pagar la skill del slot; si no, el motivo ("resource" = Rage,
## "charge" = Ultimate Charge).
func _afford_reason(slot: String) -> String:
	if not loadout.has(slot):
		return "slot"
	var skill: Dictionary = loadout[slot]
	if resource.get_current() < float(skill.get("cost", 0.0)):
		return "resource"
	if ultimate_charge < float(skill.get("charge", 0.0)):
		return "charge"
	if skill.has("charges") and float(charges.get(slot, 0.0)) < 1.0:
		return "charges"
	return ""


func _start_attack(slot: String) -> void:
	if state != AttackState.IDLE or not loadout.has(slot):
		return

	current_skill = (loadout[slot] as Dictionary).duplicate(true)
	var cost := float(current_skill.get("cost", 0.0))
	if cost > 0.0:
		resource.consume(cost)
		rage_changed.emit(resource.get_current(), resource.max_amount)
	if current_skill.has("charges"):
		charges[slot] = maxf(0.0, float(charges.get(slot, 0.0)) - 1.0)
	hold_time = 0.0
	_range_mult = 1.0
	var charge := float(current_skill.get("charge", 0.0))
	if charge > 0.0:
		ultimate_charge = maxf(0.0, ultimate_charge - charge)
		ultimate_changed.emit(ultimate_charge, WarriorKit.ULTIMATE_CHARGE_MAX)

	attack_aim = aim_dir
	state = AttackState.WINDUP
	state_time = 0.0
	swing_rage_gained = 0.0
	swing_ult_gained = 0.0
	_attack_damage_mult = float(current_skill["damage_mult"])
	attack_point = position
	if String(current_skill.get("anchor", "self")) == "aim_leap":
		var landing := position + attack_aim * float(current_skill["leap_distance"])
		attack_point = world.resolve_position(landing, RADIUS) if world != null else landing

	if bool(current_skill.get("consumes_vengeful", false)) and vengeful_active:
		_attack_damage_mult *= 1.0 + float(WarriorKit.PASSIVE["bonus"])
		vengeful_active = false
		vengeful_until_tick = 0
		vengeful_changed.emit(false, 0.0)

	# Los basicos cuentan el cooldown desde que acaba el ataque; las demas skills,
	# desde que se lanzan.
	if String(current_skill["kind"]) == "basic":
		cooldowns[slot] = total_attack_duration(current_skill) + float(current_skill["cooldown"])
	else:
		cooldowns[slot] = float(current_skill["cooldown"])

	attack_state_changed.emit(state)
	attack_started.emit(current_skill, attack_aim)


func _resolve_attack_hit() -> void:
	if current_skill.is_empty() or world == null:
		return
	var targets: Array = _targets_in_shape(world.get_living_targets())

	for target: Object in targets:
		var critical: bool = _rng.randf() < stats.get_crit_chance()
		var damage: float = stats.roll_weapon_damage(_rng) * _attack_damage_mult * _zone_multiplier(target)
		if critical:
			damage *= CRIT_MULTIPLIER
		var dealt: float = target.take_damage(damage)

		var rage_left: float = float(current_skill["rage_cap"]) - swing_rage_gained
		var rage_gain := minf(float(current_skill["rage_gain"]), maxf(rage_left, 0.0))
		if rage_gain > 0.0:
			swing_rage_gained += rage_gain
			_gain_rage(rage_gain)

		var ult_left: float = float(current_skill.get("ult_cap", 0.0)) - swing_ult_gained
		var ult_gain := minf(float(current_skill.get("ult_gain", 0.0)), maxf(ult_left, 0.0))
		if ult_gain > 0.0:
			swing_ult_gained += ult_gain
			_gain_ultimate(ult_gain)

		last_combat_tick = tick
		attack_hit.emit(current_skill, target, dealt, critical, target.position)


## Multiplicador por zona: las skills con center_radius pegan mas fuerte al
## centro (War God's Descent).
func _zone_multiplier(target: Object) -> float:
	if not current_skill.has("center_radius"):
		return 1.0
	if target.position.distance_to(position) <= float(current_skill["center_radius"]):
		return float(current_skill["center_mult"])
	return 1.0


## Objetivos dentro de la forma de la skill actual, con el limite max_targets
## (los mas cercanos primero). Mantiene el orden original si no hay limite.
func _targets_in_shape(candidates: Array) -> Array:
	var shape := String(current_skill.get("shape", "cone"))
	var attack_range := float(current_skill["range"]) * _range_mult
	var hits: Array = []
	for target: Object in candidates:
		var to_target: Vector2 = target.position - position
		var distance := to_target.length()
		if distance <= 0.001 or distance > attack_range + target.radius:
			continue
		if shape == "cone":
			if absf(rad_to_deg(attack_aim.angle_to(to_target))) > float(current_skill["arc"]) * 0.5:
				continue
		elif shape == "line":
			var along := to_target.dot(attack_aim)
			var across := absf(to_target.cross(attack_aim))
			if along < 0.0 or along > attack_range + target.radius:
				continue
			if across > float(current_skill["width"]) * 0.5 + target.radius:
				continue
		# circle: basta con estar a menos de range + radio.
		hits.append(target)
	var limit := int(current_skill.get("max_targets", 0))
	if limit > 0 and hits.size() > limit:
		hits.sort_custom(func(a: Object, b: Object) -> bool:
			return a.position.distance_squared_to(position) < b.position.distance_squared_to(position))
		hits = hits.slice(0, limit)
	return hits


func _update_movement(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return
	if dodging:
		_move_dodge(delta)
		return
	if state == AttackState.WINDUP and String(current_skill.get("anchor", "self")) == "aim_leap":
		_move_leap(delta)
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


## Salto de las skills aim_leap: recorre la distancia hasta attack_point durante
## el windup, ignorando el input de movimiento.
func _move_leap(delta: float) -> void:
	var speed: float = float(current_skill["leap_distance"]) / maxf(float(current_skill["windup"]), 0.001)
	position = position.move_toward(attack_point, speed * delta)
	velocity = Vector2.ZERO


## Un paso de la esquiva. Ocupa exactamente `duration` segundos y recorre
## `distance` px; el tick que cumple la duracion es el ultimo con movimiento de
## esquiva y ahi termina.
func _move_dodge(delta: float) -> void:
	var dodge_speed: float = float(WarriorKit.DODGE["distance"]) / float(WarriorKit.DODGE["duration"])
	velocity = dodge_dir * dodge_speed
	position += velocity * delta
	if world != null:
		position = world.resolve_position(position, RADIUS)
	if dodge_time >= float(WarriorKit.DODGE["duration"]) - 0.0001:
		dodging = false
		velocity = dodge_dir * MOVE_SPEED if move_input.length_squared() > 0.0001 else Vector2.ZERO
		dodge_ended.emit()


func _movement_factor() -> float:
	if state == AttackState.IDLE or current_skill.is_empty():
		return 1.0
	var move: Dictionary = current_skill["move"]
	if state == AttackState.WINDUP:
		return float(move["windup"])
	if state == AttackState.ACTIVE:
		return float(move["active"])
	return float(move["recovery"])


func _gain_ultimate(amount: float) -> void:
	var before := ultimate_charge
	ultimate_charge = minf(ultimate_charge + amount, WarriorKit.ULTIMATE_CHARGE_MAX)
	if is_equal_approx(before, ultimate_charge):
		return
	ultimate_changed.emit(ultimate_charge, WarriorKit.ULTIMATE_CHARGE_MAX)
	if before < WarriorKit.ULTIMATE_CHARGE_MAX and ultimate_charge >= WarriorKit.ULTIMATE_CHARGE_MAX:
		ultimate_ready.emit()


func ultimate_ready_now() -> bool:
	return ultimate_charge >= WarriorKit.ULTIMATE_CHARGE_MAX


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
	if is_invulnerable() and not is_dot:
		attack_evaded.emit(source_position)
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
		dodging = false
		state = AttackState.IDLE
		current_skill = {}
		velocity = Vector2.ZERO
		died.emit()

	return dealt


## Verdadero durante la ventana de i-frames de la esquiva.
func is_invulnerable() -> bool:
	if not dodging:
		return false
	return dodge_time >= float(WarriorKit.DODGE["iframe_start"]) and dodge_time < float(WarriorKit.DODGE["iframe_end"])


func dodge_cooldown_left() -> float:
	return cooldown_dodge


func dodge_cooldown_total() -> float:
	return float(WarriorKit.DODGE["cooldown"])


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
	return float(cooldowns.get(slot, 0.0))


func attack_cooldown_total(slot: String) -> float:
	if not loadout.has(slot):
		return 0.0
	var skill: Dictionary = loadout[slot]
	if String(skill["kind"]) == "basic":
		return total_attack_duration(skill) + float(skill["cooldown"])
	return float(skill["cooldown"])


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
		"dodging": dodging,
		"dodge_cd": cooldown_dodge,
		"cooldowns": cooldowns.duplicate(),
		"ultimate": ultimate_charge,
		"charges": charges.duplicate(),
		"hold": hold_time,
		"alive": alive,
	}
