## EnemySim — simulación determinista de un enemigo definido por datos.
##
## Los números salen de `data/enemies/*.json` (EnemyCatalog). Vive dentro de
## CombatWorld (RefCounted, sin nodos); la presentación (EnemyActor) solo lee su
## estado y escucha sus señales.
##
## Ciclo: IDLE -> CHASE -> TELEGRAPH -> ACTIVE -> RECOVER -> CHASE ...
## El TELEGRAPH dura `windup` segundos y fija la direccion del ataque al empezar:
## el jugador puede leer la zona y salirse de ella o esquivar justo al caer el
## golpe. El daño se resuelve una sola vez, al empezar ACTIVE.
##
## Implementa la misma interfaz de blanco que DummySim para el Warrior:
## `position`, `radius`, `alive` y `take_damage(amount)`.
class_name EnemySim
extends RefCounted

signal health_changed(current: float, maximum: float)
signal aggroed()
signal telegraph_started(attack: Dictionary, direction: Vector2)
signal attack_active(attack: Dictionary, direction: Vector2)
signal attack_landed(damage: float)
signal attack_missed()
signal hit(amount: float, position: Vector2)
signal died()
signal revived()

enum State { IDLE, CHASE, TELEGRAPH, ACTIVE, RECOVER, DEAD }

const WARRIOR_RADIUS := 14.0
## Margen para no quedarse pegado al jugador al perseguirlo.
const CONTACT_GAP := 2.0

var world: Object = null
var def_id: StringName = &""
var data: Dictionary = {}

var position: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO
var radius: float = 12.0
var max_health: float = 1.0
var health: float = 1.0
var alive: bool = true
var state: int = State.IDLE
var state_time: float = 0.0
var facing: Vector2 = Vector2.RIGHT
var hit_flash_ticks: int = 0

var current_attack: Dictionary = {}
var attack_direction: Vector2 = Vector2.RIGHT
var _attack_cooldowns: Dictionary = {}
var _dash_origin: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator


func _init(p_world: Object, p_def_id: StringName, p_position: Vector2, rng_seed: int = 1) -> void:
	world = p_world
	def_id = p_def_id
	data = EnemyCatalog.enemy(p_def_id)
	assert(not data.is_empty(), "enemigo desconocido: %s" % p_def_id)
	position = p_position
	spawn_position = p_position
	radius = float(data["stats"]["radius"])
	max_health = float(data["stats"]["health"])
	health = max_health
	_rng = RandomNumberGenerator.new()
	_rng.seed = rng_seed


func step(_tick_number: int, delta: float, warrior: Object) -> void:
	if not alive:
		state_time += delta
		var respawn := float(data["respawn_seconds"])
		if respawn > 0.0 and state_time >= respawn:
			revive()
		return

	if hit_flash_ticks > 0:
		hit_flash_ticks -= 1
	for attack_id: String in _attack_cooldowns.keys():
		var left := maxf(0.0, float(_attack_cooldowns[attack_id]) - delta)
		if left <= 0.0:
			_attack_cooldowns.erase(attack_id)
		else:
			_attack_cooldowns[attack_id] = left

	var target_alive: bool = warrior != null and bool(warrior.alive)
	match state:
		State.IDLE:
			if target_alive and position.distance_to(warrior.position) <= float(data["ai"]["aggro_range"]):
				_aggro()
		State.CHASE:
			_step_chase(delta, warrior, target_alive)
		State.TELEGRAPH:
			state_time += delta
			if state_time >= float(current_attack["windup"]):
				_activate(warrior)
		State.ACTIVE:
			state_time += delta
			_step_dash(delta)
			if state_time >= float(current_attack["active"]):
				state = State.RECOVER
				state_time = 0.0
		State.RECOVER:
			state_time += delta
			if state_time >= float(current_attack["recovery"]):
				state = State.CHASE
				state_time = 0.0
				current_attack = {}


func _aggro() -> void:
	state = State.CHASE
	state_time = 0.0
	aggroed.emit()


func _step_chase(delta: float, warrior: Object, target_alive: bool) -> void:
	if not target_alive:
		state = State.IDLE
		return
	var to_target: Vector2 = warrior.position - position
	var distance := to_target.length()
	if distance > float(data["ai"]["aggro_range"]) * float(data["ai"]["leash"]):
		state = State.IDLE
		return
	if distance > 0.001:
		facing = to_target / distance

	var attack := _pick_attack(distance)
	if not attack.is_empty():
		_start_telegraph(attack)
		return

	var contact := radius + WARRIOR_RADIUS + CONTACT_GAP
	if distance <= contact:
		return
	var step_length := minf(float(data["stats"]["speed"]) * delta, distance - contact)
	var desired := position + facing * step_length
	position = world.resolve_position(desired, radius, self) if world != null else desired


## Entre los ataques listos y con el jugador a su alcance de disparo, elige uno
## segun su peso con el RNG del enemigo (determinista).
func _pick_attack(distance: float) -> Dictionary:
	var ready: Array = []
	var total := 0.0
	for attack: Dictionary in data["attacks"]:
		if _attack_cooldowns.has(String(attack["id"])):
			continue
		if distance > float(attack["trigger_range"]):
			continue
		ready.append(attack)
		total += float(attack["weight"])
	if ready.is_empty():
		return {}
	var roll := _rng.randf() * total
	for attack: Dictionary in ready:
		roll -= float(attack["weight"])
		if roll <= 0.0:
			return attack
	return ready[ready.size() - 1]


func _start_telegraph(attack: Dictionary) -> void:
	current_attack = attack
	state = State.TELEGRAPH
	state_time = 0.0
	attack_direction = facing
	telegraph_started.emit(attack, attack_direction)


func _activate(warrior: Object) -> void:
	state = State.ACTIVE
	state_time = 0.0
	_dash_origin = position
	_attack_cooldowns[String(current_attack["id"])] = float(current_attack["cooldown"])
	attack_active.emit(current_attack, attack_direction)
	_resolve_hit(warrior)


## El golpe se evalua una sola vez, al caer, contra la zona que se marco.
func _resolve_hit(warrior: Object) -> void:
	if warrior == null or not warrior.alive or not _in_zone(warrior.position):
		attack_missed.emit()
		return
	var amount := float(data["stats"]["damage"]) * float(current_attack["damage_mult"])
	var dealt: float = warrior.take_damage(amount, position, false)
	attack_landed.emit(dealt)


## Si un punto (centro del jugador) esta dentro de la zona del ataque actual.
func _in_zone(point: Vector2) -> bool:
	var to_target := point - position
	var distance := to_target.length()
	var reach := float(current_attack["range"]) + WARRIOR_RADIUS
	match String(current_attack["shape"]):
		"circle":
			return distance <= reach
		"line":
			var along := to_target.dot(attack_direction)
			var across := absf(to_target.cross(attack_direction))
			return along >= 0.0 and along <= reach and across <= float(current_attack["width"]) * 0.5 + WARRIOR_RADIUS
		_:
			if distance > reach:
				return false
			if distance <= 0.001:
				return true
			return absf(rad_to_deg(attack_direction.angle_to(to_target))) <= float(current_attack["arc"]) * 0.5


func _step_dash(delta: float) -> void:
	var dash := float(current_attack.get("dash_distance", 0.0))
	if dash <= 0.0:
		return
	var active := float(current_attack["active"])
	var speed := dash / active
	var travelled := position.distance_to(_dash_origin)
	var step_length := minf(speed * delta, dash - travelled)
	if step_length <= 0.0:
		return
	var desired := position + attack_direction * step_length
	position = world.resolve_position(desired, radius, self) if world != null else desired


func take_damage(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var armor := float(data["stats"].get("armor", 0.0))
	var reduced := amount * (1.0 - armor / (armor + 100.0))
	var dealt := minf(reduced, health)
	health -= dealt
	hit_flash_ticks = 6
	if state == State.IDLE:
		_aggro()
	health_changed.emit(health, max_health)
	hit.emit(dealt, position)
	if health <= 0.0:
		health = 0.0
		alive = false
		state = State.DEAD
		state_time = 0.0
		current_attack = {}
		died.emit()
	return dealt


func revive() -> void:
	alive = true
	health = max_health
	position = spawn_position
	state = State.IDLE
	state_time = 0.0
	current_attack = {}
	_attack_cooldowns = {}
	hit_flash_ticks = 0
	health_changed.emit(health, max_health)
	revived.emit()


## 0..1 mientras dura el aviso del ataque; 0 fuera de el.
func telegraph_progress() -> float:
	if state != State.TELEGRAPH or current_attack.is_empty():
		return 0.0
	return clampf(state_time / float(current_attack["windup"]), 0.0, 1.0)


func is_telegraphing() -> bool:
	return state == State.TELEGRAPH


func snapshot() -> Dictionary:
	return {
		"id": String(def_id),
		"position": [position.x, position.y],
		"health": health,
		"max_health": max_health,
		"alive": alive,
		"state": state,
		"telegraph": telegraph_progress(),
	}


## XP que da al morir (dato stats.xp).
func xp_reward() -> int:
	return int(data["stats"].get("xp", 0))
