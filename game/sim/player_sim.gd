## PlayerSim — simulación determinista del Warrior (primer corte).
##
## Solo cambia dentro de step(), que llama CombatWorld una vez por tick fijo.
## La presentación lee sus campos y escucha sus señales; nunca escribe estado.
##
## Implementado: skills por datos (M1, M2 y S1-S5 desde SkillCatalog, con coste de
## Rage, cooldown y formas cone/line/circle), esquiva con i-frames, Rage,
## Vengeful Fury, M1 con cargas y M2 que se carga manteniendo el boton (estilo
## Drakantos), Ultimate Charge (sube al conectar golpes; War God's Descent la
## gasta entera), Special Iron Counter (postura que bloquea y contraataca),
## niveles con XP y skills que se desbloquean por nivel, loadout equipable,
## muerte y reset. El Skill Book completo vive en WarriorKit.
class_name PlayerSim
extends RefCounted

signal health_changed(current: float, maximum: float)
signal resource_changed(current: float, maximum: float)
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
signal attack_blocked(source_position: Vector2)
signal xp_gained(amount: int, source_position: Vector2)
signal item_gained(item: Dictionary)
signal bag_full(item: Dictionary)
signal inventory_changed()
signal gold_changed(total: int)
signal appearance_changed()
signal materials_changed()
signal material_gained(id: String, amount: int)
signal xp_changed(xp: int, to_next: int, level: int)
signal leveled_up(new_level: int, unlocked: Array)
signal loadout_changed()
signal class_changed(class_id: String)
signal buff_changed(active: bool, multiplier: float, seconds_left: float)
signal projectiles_launched(skill: Dictionary, direction: Vector2)
signal status_applied(id: String)

enum AttackState { IDLE, WINDUP, ACTIVE, RECOVERY }

const RADIUS := 14.0
## Radio como blanco (la simulacion pide `target.radius` a todo lo que se puede golpear).
var radius: float = RADIUS
## Hacia donde mira, para el golpe por la espalda de un rival.
var facing: Vector2:
	get:
		return aim_dir
## Ronda de "mas lento" (13 nov 2026): 168 -> 142 px/s, arranque y frenada un poco mas pesados.
const MOVE_SPEED := 142.0
const ACCELERATION := 1350.0
const FRICTION := 1900.0
const BASE_HEALTH := 100.0
## Regeneracion de vida fuera de combate (fraccion de la vida maxima por segundo). 0 = sin
## regeneracion; la fija el laboratorio de campana para medir el efecto.
static var regen_per_second: float = 0.015
## Segundos sin recibir dano para empezar a regenerar.
const REGEN_DELAY := 5.0
const HEALTH_PER_STAMINA := 10.0

const RAGE_DECAY_GRACE := 3.0
const RAGE_DECAY_PER_SECOND := 10.0
## Cambiar de equipo en un piso exige 4 s sin combatir.
const GEAR_SWAP_QUIET_TICKS := 240
const RAGE_TAKEN_CAP := 15.0
const RAGE_TAKEN_MIN := 1.0

const BUFFER_SECONDS := 0.25
const SKILL_SLOTS := ["S1", "S2", "S3", "S4", "S5"]
## Slots que se lanzan al pulsar (M1 se lanza manteniendo el boton).
const EDGE_SLOTS := ["M2", "S1", "S2", "S3", "S4", "S5", "SPECIAL", "ULTIMATE"]
const CRIT_MULTIPLIER := 1.5

var world: Object = null
var stats: CharacterStats
var resource: ClassResource

var position: Vector2 = Vector2(480, 380)
var velocity: Vector2 = Vector2.ZERO
var move_input: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.RIGHT

## Nivel y XP dentro del nivel. Las skills se desbloquean por nivel (unlock_level).
var level: int = 1
## Tope de nivel por progreso en la torre (lo pone la sesion: el piso mas alto desbloqueado). 0 = sin tope.
var level_cap: int = 0
var xp: int = 0

var max_health: float = 1.0
var health: float = 1.0
var alive: bool = true

var state: int = AttackState.IDLE
var state_time: float = 0.0
var current_skill: Dictionary = {}
var attack_aim: Vector2 = Vector2.RIGHT
## id de skill -> segundos restantes. El cooldown sigue a la skill, no al slot:
## cambiar el loadout no lo reinicia.
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
## Enemigos ya golpeados por la carga actual.
var _dodge_hit: Dictionary = {}
var dodge_dir: Vector2 = Vector2.DOWN
var cooldown_dodge: float = 0.0
var dodge_buffer_timer: float = 0.0

var vengeful_active: bool = false
var vengeful_until_tick: int = 0

var tick: int = 0
var last_combat_tick: int = 0
## Recurso y carga de ultimate ganados en el lanzamiento actual (para respetar el
## tope por lanzamiento de resource_cap y ult_cap).
var _swing_tracker: Dictionary = {"resource": 0.0, "ult": 0.0}

## Clase jugada y su definicion (data/classes). El nivel, la XP y el loadout se
## guardan por clase en `progress` al cambiar de clase.
var class_id: String = "warrior"
var class_def: Dictionary = {}
var resource_kind: String = "rage"
var progress: Dictionary = {}
## Mochila compartida por todas las clases (items concretos, ver ItemGen).
var bag: Array = []
## Equipo de la clase activa: ranura -> item. Cada clase guarda el suyo.
var equipment: Dictionary = {}
## Oro compartido por todas las clases.
var gold: int = 0
## Personaje: nombre, aspecto (cuerpo, piel, pelo...) elegido al crearlo y si ya se creo.
var character_name: String = "Despierto"
var appearance: Dictionary = {}
var character_created: bool = false
## Materiales (id -> cantidad), compartidos por las clases. No ocupan mochila.
var materials: Dictionary = {}
## En zona segura (ciudad, patio) se puede cambiar de clase y de loadout; en un
## piso de la torre no. Lo fija la sesion; los mundos de test son seguros.
var safe_zone: bool = true

## Mejora del siguiente ataque (Special de Mage/Archer, evasion del Rogue).
## Estados alterados activos (stun, slow, veneno).
var statuses: StatusSet = StatusSet.new()

var empower_mult: float = 1.0
var empower_until_tick: int = 0
var _strike_index: int = 0
var _attack_damage_mult: float = 1.0

var _m1_held: bool = false
## Clic derecho: tiempo mantenido (toque = basico, mantener = golpe cargado) y pulso de M1 tras un toque.
const BASIC_HOLD := 0.16
var _basic_time: float = 0.0
var _basic_pulse: int = 0
## Combo del basico (pasos) y ultimo tick en que se uso.
var _combo_index: int = 0
var _combo_tick: int = -100000
## Bloqueo (movilidad del guerrero): activo mientras se mantiene Espacio.
var blocking: bool = false
var block_time: float = 0.0
## Solo los tests de mecanicas (LegacyKit) equipan el Counterstrike del guerrero en el hueco Especial de antes.
static var allow_legacy_special: bool = false
signal block_started()
signal stealth_broken()
## Sigilo: bonus del primer golpe al salir de Stealth, golpes envenenados pendientes, golpes que aun aguanta Vanish y critico asegurado.
var _opening_bonus: float = 0.0
var venom_hits: int = 0
var vanish_hits_left: int = 0
var _force_crit: bool = false
signal block_ended()
signal attack_parried(source_position: Vector2)
## Huecos de la clase que se desbloquean por nivel (solo clases con `slot_gates`).
const SLOT_UNLOCK := {"S1": 2, "S2": 4, "S3": 8, "ULTIMATE": 6}
var _stance_spent: bool = false
var _slot_prev: Dictionary = {}
var _actions: Dictionary = {}
var _range_mult: float = 1.0
var _dodge_prev: bool = false
var _rng: RandomNumberGenerator


func _init(p_world: Object = null, p_class_id: String = "warrior") -> void:
	world = p_world
	_rng = _make_rng()
	statuses.applied.connect(func(id: String) -> void: status_applied.emit(id))
	_set_class_data(p_class_id if ClassCatalog.has_class(p_class_id) else "warrior")
	_build_stats()
	resource = ClassCatalog.create_resource(class_id)
	_auto_equip(_ids_unlocked_between(0, level))
	reset(position)


func _set_class_data(new_class_id: String) -> void:
	class_id = new_class_id
	class_def = ClassCatalog.class_def(class_id)
	resource_kind = String(class_def["resource"]["kind"])


## Equipa skills por slot ({"M1": id, "M2": id, "S1": id, ...} ) sustituyendo el
## loadout actual. Ignora ids desconocidos, no implementados, bloqueados por nivel
## o que no caben en el slot.
func set_loadout(new_loadout: Dictionary) -> void:
	loadout = {}
	charges = {}
	for slot: String in new_loadout:
		var id := StringName(String(new_loadout[slot]))
		if not _equip_reason(slot, id).is_empty():
			continue
		_equip_internal(slot, SkillCatalog.skill(id))
	loadout_changed.emit()


func _equip_internal(slot: String, skill: Dictionary) -> void:
	skill["slot"] = slot
	loadout[slot] = skill
	if skill.has("charges"):
		charges[slot] = float(skill["charges"]["max"])


## "" si `id` se puede equipar en `slot`; si no, el motivo: "slot", "unknown",
## "not_implemented", "locked" (nivel insuficiente), "wrong_class" o "wrong_slot".
func _equip_reason(slot: String, id: StringName) -> String:
	if slot != "M1" and slot != "M2" and slot != "SPECIAL" and slot != "ULTIMATE" and not SKILL_SLOTS.has(slot):
		return "slot"
	var skill: Dictionary = SkillCatalog.skill(id)
	if skill.is_empty():
		return "unknown"
	if String(skill.get("class", "")) != class_id:
		return "wrong_class"
	if not bool(skill.get("implemented", false)):
		return "not_implemented"
	if bool(skill.get("world", false)) and not learned_skills.has(String(id)):
		return "not_learned"
	if int(skill["unlock_level"]) > level:
		return "locked"
	if bool(class_def.get("slot_gates", false)) and SLOT_UNLOCK.has(slot) and level < int(SLOT_UNLOCK[slot]):
		return "slot_locked"
	if not slot_accepts(slot, skill):
		return "wrong_slot"
	return ""


## Un slot S1-S5 acepta skills genericas ("S"); los demas, solo la suya.
func slot_accepts(slot: String, skill: Dictionary) -> bool:
	var skill_slot := String(skill.get("slot", ""))
	if SKILL_SLOTS.has(slot):
		return skill_slot == "S"
	if slot == "SPECIAL" and bool(skill.get("legacy_special", false)) and allow_legacy_special:
		return true
	return skill_slot == slot


## Skills "de mundo" aprendidas (libros, jefes, maestros): no vienen con la clase; se guardan.
var learned_skills: Array = []

## Consumibles (pociones y comida) por id; no ocupan la mochila. Enfriamiento compartido de pociones.
var consumables: Dictionary = {}
var potion_cooldown_left: float = 0.0
signal consumable_used(id: String)
## Encargos del Gremio aceptados, contador del tablon y total cobrados.
var bounties: Array = []
var bounty_serial: int = 0
var bounties_done: int = 0
## Alijo del banco (items guardados en la ciudad).
var bank: Array = []
const BANK_SIZE := 30


func consumable_count(id: String) -> int:
	return int(consumables.get(id, 0))


## Anade `count` unidades (hasta el tope de pila); devuelve cuantas entraron.
func add_consumable(id: String, count: int = 1) -> int:
	if not ConsumableCatalog.has(id) or count <= 0:
		return 0
	var room := ConsumableCatalog.max_stack() - consumable_count(id)
	var added := mini(count, maxi(room, 0))
	if added > 0:
		consumables[id] = consumable_count(id) + added
		inventory_changed.emit()
	return added


## La skill de mundo de la clase que aun no se conoce y es mas facil (menor nivel); &"" si ya las conoce todas.
func _next_world_skill() -> StringName:
	var best: StringName = &""
	var best_level := 1000
	for id: StringName in SkillCatalog.ids_for_class(class_id):
		var skill: Dictionary = SkillCatalog.skill(id)
		if bool(skill.get("world", false)) and bool(skill.get("implemented", false)) and not learned_skills.has(String(id)) and int(skill["unlock_level"]) < best_level:
			best = id
			best_level = int(skill["unlock_level"])
	return best


## Usa un consumible: "" si se uso o el motivo ("none", "dead", "cooldown", "full").
func use_consumable(id: String) -> String:
	if not alive:
		return "dead"
	if not rule("allow_consumables"):
		return "rules"
	if consumable_count(id) <= 0 or not ConsumableCatalog.has(id):
		return "none"
	var spec: Dictionary = ConsumableCatalog.item(id)
	var effect: Dictionary = spec["effect"]
	if String(spec["kind"]) == "book":
		var target := String(effect.get("learn", "world_skill"))
		var next: StringName = _next_world_skill() if target == "world_skill" else StringName(target)
		if next == &"":
			return "known"
		var skill: Dictionary = SkillCatalog.skill(next)
		if not skill.is_empty() and String(skill.get("class", "")) != class_id:
			return "wrong_class"
		if not learn_skill(next):
			return "known"
	elif String(spec["kind"]) == "potion":
		if potion_cooldown_left > 0.0:
			return "cooldown"
		var heal := float(effect.get("heal_pct", 0.0)) * max_health
		var restore := float(effect.get("resource_pct", 0.0)) * resource.max_amount
		var can_heal := heal > 0.0 and health < max_health
		var can_restore := restore > 0.0 and resource.get_current() < resource.max_amount
		if not can_heal and not can_restore:
			return "full"
		if can_heal:
			health = minf(max_health, health + heal)
			health_changed.emit(health, max_health)
		if can_restore:
			_gain_resource(restore)
		potion_cooldown_left = ConsumableCatalog.potion_cooldown()
	else:
		statuses.apply(String(effect["status"]), float(effect["duration"]), float(effect["strength"]))
	consumables[id] = consumable_count(id) - 1
	if consumables[id] <= 0:
		consumables.erase(id)
	inventory_changed.emit()
	consumable_used.emit(id)
	return ""


## Tecla rapida: usa el mejor consumible de `quick` ("health" | "resource") que tengas.
func use_quick(quick: String) -> String:
	for id: String in ConsumableCatalog.quick_ids(quick):
		if consumable_count(id) > 0:
			return use_consumable(id)
	return "none"


## Aprende una skill de mundo de la clase actual. false si no existe, no es de mundo o ya la tiene.
func learn_skill(id: StringName) -> bool:
	if not rule("allow_world_skills"):
		return false
	var skill: Dictionary = SkillCatalog.skill(id)
	if skill.is_empty() or String(skill.get("class", "")) != class_id or not bool(skill.get("world", false)) or learned_skills.has(String(id)):
		return false
	learned_skills.append(String(id))
	if level >= int(skill["unlock_level"]):
		_auto_equip([id])
	loadout_changed.emit()
	return true


## El loadout solo se edita en reposo (zona segura / entre combates).
func can_edit_loadout() -> bool:
	return alive and state == AttackState.IDLE and not dodging and safe_zone


## El equipo se cambia en reposo y tambien dentro de los pisos, si llevas unos segundos sin combatir.
func can_change_gear() -> bool:
	return alive and state == AttackState.IDLE and not dodging and not blocking and (safe_zone or tick - last_combat_tick > GEAR_SWAP_QUIET_TICKS)


## Por que no se puede cambiar de equipo ahora (texto para el jugador); "" si se puede.
func gear_block_reason() -> String:
	if can_change_gear():
		return ""
	if not alive:
		return "Estas muerto."
	if blocking:
		return "Estas bloqueando: suelta el bloqueo."
	if state != AttackState.IDLE or dodging:
		return "Termina la accion en curso."
	var left := float(GEAR_SWAP_QUIET_TICKS - (tick - last_combat_tick)) / 60.0
	return "Acabas de pelear o recibir dano: espera %.0f s." % maxf(left, 1.0)


## Equipa `id` en `slot`. Devuelve "" si salio bien o el motivo del rechazo (los
## de _equip_reason, mas "busy" si no se puede editar ahora). Si la skill ya
## estaba en otro slot, se mueve.
func equip(slot: String, id: StringName) -> String:
	if not can_edit_loadout():
		return "busy"
	var reason := _equip_reason(slot, id)
	if not reason.is_empty():
		return reason
	for other: String in loadout.keys():
		if StringName(String((loadout[other] as Dictionary)["id"])) == id:
			loadout.erase(other)
			charges.erase(other)
	_equip_internal(slot, SkillCatalog.skill(id))
	loadout_changed.emit()
	return ""


## Vacia un slot S1-S5, SPECIAL o ULTIMATE (M1 y M2 no se vacian).
func unequip(slot: String) -> bool:
	if not can_edit_loadout() or not loadout.has(slot):
		return false
	if slot == "M1" or slot == "M2":
		return false
	loadout.erase(slot)
	loadout_changed.emit()
	return true


func is_unlocked(id: StringName) -> bool:
	var skill: Dictionary = SkillCatalog.skill(id)
	return not skill.is_empty() and int(skill["unlock_level"]) <= level


# --- Niveles y XP -----------------------------------------------------------


func xp_to_next() -> int:
	return Progression.xp_to_next(level)


## Suma XP (p. ej. al matar un enemigo) y sube de nivel las veces que haga falta.
## Subir de nivel recalcula los stats, cura del todo y equipa las skills que se
## desbloquean en los slots libres.
func grant_xp(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	var ceiling := effective_max_level()
	if amount <= 0 or level >= Progression.max_level() or not rule("allow_xp"):
		return
	xp_gained.emit(amount, source_position)
	xp += amount
	var previous := level
	while level < ceiling and xp >= Progression.xp_to_next(level):
		xp -= Progression.xp_to_next(level)
		level += 1
	if level >= ceiling:
		# Tope alcanzado: la barra se queda casi llena (la XP sobrante no se pierde del todo, pero no pasa de nivel).
		xp = mini(xp, maxi(Progression.xp_to_next(level) - 1, 0))
	if level != previous:
		_apply_level_change(previous)
	xp_changed.emit(xp, xp_to_next(), level)


## Nivel maximo que se puede alcanzar ahora: el tope del piso (level_cap) si lo hay y, si no, el maximo del juego.
func effective_max_level() -> int:
	return mini(level_cap, Progression.max_level()) if level_cap > 0 else Progression.max_level()


## Fija el nivel (depuracion, tests y reinicio). Con un nivel menor se retiran las
## skills que dejan de estar desbloqueadas.
func set_level(new_level: int) -> void:
	var previous := level
	level = clampi(new_level, 1, Progression.max_level())
	xp = 0
	_apply_level_change(previous)
	xp_changed.emit(xp, xp_to_next(), level)


func reset_progression() -> void:
	set_level(1)


func _apply_level_change(previous: int) -> void:
	_build_stats()
	health = max_health
	var unlocked: Array = []
	if level < previous:
		for slot: String in loadout.keys():
			if int((loadout[slot] as Dictionary)["unlock_level"]) > level:
				loadout.erase(slot)
				charges.erase(slot)
	else:
		unlocked = _ids_unlocked_between(previous, level)
		_auto_equip(unlocked)
	health_changed.emit(health, max_health)
	loadout_changed.emit()
	if level > previous:
		leveled_up.emit(level, unlocked)


## Ids de skills implementadas cuyo nivel de desbloqueo esta en (from, to], por
## orden de nivel.
func _ids_unlocked_between(from_level: int, to_level: int) -> Array:
	var found: Array = []
	for id: StringName in SkillCatalog.ids_for_class(class_id):
		var skill: Dictionary = SkillCatalog.skill(id)
		var unlock_at := int(skill["unlock_level"])
		if bool(skill.get("world", false)) and not learned_skills.has(String(id)):
			continue
		if bool(skill.get("implemented", false)) and unlock_at > from_level and unlock_at <= to_level:
			found.append({"id": id, "level": unlock_at})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
	return found.map(func(entry: Dictionary) -> StringName: return entry["id"])


## Pone cada skill recien desbloqueada en su slot preferido (el del default_loadout
## de la clase)
## si esta libre, o en el primer slot libre donde quepa.
func _auto_equip(ids: Array) -> void:
	for id: StringName in ids:
		var skill: Dictionary = SkillCatalog.skill(id)
		var already := false
		for slot: String in loadout:
			if StringName(String((loadout[slot] as Dictionary)["id"])) == id:
				already = true
		if already:
			continue
		var target := ""
		var defaults: Dictionary = class_def["default_loadout"]
		for slot: String in defaults:
			if StringName(String(defaults[slot])) == id and not loadout.has(slot) and slot_accepts(slot, skill):
				target = slot
		if target.is_empty():
			for slot: String in ["M1", "M2", "S1", "S2", "S3", "S4", "S5", "SPECIAL", "ULTIMATE"]:
				if not loadout.has(slot) and slot_accepts(slot, skill):
					target = slot
					break
		if not target.is_empty():
			_equip_internal(target, skill)


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
	var base: Dictionary = class_def["stats"]
	var growth: Dictionary = Progression.growth(class_id)
	var levels_gained := float(level - 1)
	stats = CharacterStats.new()
	stats.main_stat = StringName(String(class_def["main_stat"]))
	for stat: String in ["strength", "agility", "stamina", "intellect", "armor"]:
		stats.set_base_stat(StringName(stat), float(base[stat]) + float(growth.get(stat + "_per_level", 0.0)) * levels_gained)
	var gear := gear_stats()
	for stat: String in ["strength", "agility", "stamina", "intellect", "armor"]:
		stats.set_base_stat(StringName(stat), stats.get_stat(StringName(stat)) + float(gear.get(stat, 0.0)))
	stats.set_base_stat(&"attack_power_bonus", float(gear.get("attack_power_bonus", 0.0)))
	stats.set_base_stat(&"spell_power_bonus", float(gear.get("spell_power_bonus", 0.0)))
	stats.set_base_stat(&"crit_chance", float(base["crit_chance"]) + float(gear.get("crit_chance", 0.0)))
	stats.set_base_stat(&"weapon_min", float(base["weapon_min"]) + float(gear.get("weapon_min", 0.0)))
	stats.set_base_stat(&"weapon_max", float(base["weapon_max"]) + float(gear.get("weapon_max", 0.0)))
	stats.set_base_stat(&"weapon_speed", float(base["weapon_speed"]))
	max_health = (BASE_HEALTH + stats.get_stat(&"stamina") * HEALTH_PER_STAMINA) * pvp_tuning("health")
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
	blocking = false
	block_time = 0.0
	_basic_time = 0.0
	_basic_pulse = 0
	vengeful_active = false
	vengeful_until_tick = 0
	last_combat_tick = 0
	_swing_tracker = {"resource": 0.0, "ult": 0.0}
	empower_mult = 1.0
	empower_until_tick = 0
	_strike_index = 0
	hold_time = 0.0
	statuses.clear(true)
	_range_mult = 1.0
	_refill_charges()
	ultimate_charge = 0.0
	attack_point = position
	resource.current_amount = float(class_def["resource"]["start"])
	ultimate_changed.emit(ultimate_charge, WarriorKit.ULTIMATE_CHARGE_MAX)
	health_changed.emit(health, max_health)
	resource_changed.emit(resource.get_current(), resource.max_amount)
	attack_state_changed.emit(state)


func step(tick_number: int, delta: float, input: Object) -> void:
	tick = tick_number
	_read_input(input, delta)
	_tick_timers(delta)
	potion_cooldown_left = maxf(0.0, potion_cooldown_left - delta)
	_update_statuses(delta)
	_update_dodge(delta)
	_update_attack(delta)
	_update_movement(delta)
	_update_resource(delta)
	_update_regen(delta)


func _update_regen(delta: float) -> void:
	if (regen_per_second <= 0.0 and not statuses.has("fed")) or not alive or health >= max_health:
		return
	if tick - last_combat_tick < int(REGEN_DELAY * 60.0):
		return
	health = minf(max_health, health + max_health * (regen_per_second + statuses.strength("fed")) * delta)


func _read_input(input: Object, delta: float = 1.0 / 60.0) -> void:
	_actions = {} if input == null else (input.actions as Dictionary).duplicate()
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
	# Basico en el clic derecho: un toque lanza el basico (M1) y mantener carga el golpe fuerte (M2).
	if bool(_actions.get("basic", false)):
		_basic_time += delta
		if _basic_time >= BASIC_HOLD:
			_actions["m2"] = true
	else:
		if _basic_time > 0.0 and _basic_time < BASIC_HOLD:
			_basic_pulse = 3
		_basic_time = 0.0
	if _basic_pulse > 0:
		_actions["m1"] = true
		_basic_pulse -= 1
	_m1_held = bool(_actions.get("m1", false))
	var dodge_pressed := bool(_actions.get("dodge", false))
	if dodge_pressed and not _dodge_prev:
		dodge_buffer_timer = float(WarriorKit.DODGE["buffer"])
	_dodge_prev = dodge_pressed
	# M2 y S1-S5 se lanzan al pulsar (mantener M2 despues del windup la carga).
	for slot: String in EDGE_SLOTS:
		var pressed := bool(_actions.get(slot.to_lower(), false))
		if pressed and not bool(_slot_prev.get(slot, false)):
			buffered_slot = slot
			buffer_timer = BUFFER_SECONDS
		_slot_prev[slot] = pressed
	for quick: String in ["quick_health", "quick_resource"]:
		var held := bool(_actions.get(quick, false))
		if held and not bool(_slot_prev.get(quick, false)):
			use_quick(quick.trim_prefix("quick_"))
		_slot_prev[quick] = held
	# Atajos de depuracion (F5 sube un nivel, F6 vuelve al nivel 1): son acciones
	# del input para que sigan siendo deterministas.
	for action: String in ["debug_level_up", "debug_level_reset", "debug_class_next"]:
		var down := bool(_actions.get(action, false))
		if down and not bool(_slot_prev.get(action, false)):
			if action == "debug_level_up":
				set_level(level + 1)
			elif action == "debug_level_reset":
				reset_progression()
			else:
				var ids := ClassCatalog.all_ids()
				switch_class(ids[(ids.find(class_id) + 1) % ids.size()])
		_slot_prev[action] = down


## Aplica un estado al jugador (stun, slow, veneno). Devuelve false si es inmune.
## Un stun cancela lo que estuviera haciendo, incluida la esquiva.
func apply_status(id: String, duration: float, strength: float = 0.0, source: Vector2 = Vector2.ZERO) -> bool:
	if not alive:
		return false
	var applied := statuses.apply(id, duration, strength)
	if applied and (id == "knockback" or id == "pull"):
		push_from(source, strength if id == "knockback" else -strength)
		return true
	if applied and id == "stun":
		if state != AttackState.IDLE:
			_cancel_attack()
		if dodging:
			dodging = false
			dodge_ended.emit()
		buffered_slot = ""
		buffer_timer = 0.0
		dodge_buffer_timer = 0.0
	return applied


## Empuje instantaneo lejos de `source` (knockback). No atraviesa muros.
func push_from(source: Vector2, distance: float) -> void:
	var away := position - source
	if away.length_squared() < 0.0001:
		away = -aim_dir
	if distance < 0.0:
		# Atraer: sin pasar de largo del origen.
		distance = -minf(-distance, maxf(away.length() - RADIUS - 8.0, 0.0))
	position = world.resolve_position(position + away.normalized() * distance, RADIUS) if world != null else position + away.normalized() * distance
	velocity = Vector2.ZERO


## Avanza los estados; el veneno hace su dano continuo (que ignora i-frames y
## posturas). Aturdido, el jugador pierde las pulsaciones bufferizadas.
func _update_statuses(delta: float) -> void:
	var dot := statuses.step(delta)
	if dot > 0.0 and alive:
		take_damage(dot, Vector2.ZERO, true)
	if statuses.is_stunned():
		buffered_slot = ""
		buffer_timer = 0.0
		dodge_buffer_timer = 0.0


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
	var mob := mobility()
	if String(mob.get("kind", "")) == "block":
		_update_block(delta, mob)
		return
	if dodging:
		dodge_time += delta
		return
	if dodge_buffer_timer <= 0.0 or cooldown_dodge > 0.0 or not alive or statuses.is_stunned():
		return
	if mob.has("cost") and resource.get_current() < float(mob["cost"]):
		return
	if state == AttackState.ACTIVE and not current_skill.has("stance"):
		return
	if state != AttackState.IDLE and bool(current_skill.get("uncancelable", false)):
		return
	_start_dodge(delta)


## Habilidad de movilidad de la clase (barra espaciadora): el esquive base de WarriorKit.DODGE con
## lo que redefina `mobility` en la clase (rodar, cargar, blink, salto atras).
func mobility() -> Dictionary:
	var merged: Dictionary = WarriorKit.DODGE.duplicate()
	for key: String in class_def.get("mobility", {}):
		merged[key] = class_def["mobility"][key]
	return merged


func _start_dodge(delta_for_start: float) -> void:
	dodge_buffer_timer = 0.0
	if state != AttackState.IDLE:
		_cancel_attack()
	var mob := mobility()
	var mode := String(mob.get("dir", "move"))
	if mode == "aim":
		dodge_dir = aim_dir
	elif mode == "back":
		dodge_dir = -aim_dir
	elif move_input.length_squared() > 0.0001:
		dodge_dir = move_input.normalized()
	elif mode == "move_aim":
		dodge_dir = aim_dir
	else:
		dodge_dir = -aim_dir
	if mob.has("cost"):
		resource.consume(float(mob["cost"]))
		resource_changed.emit(resource.get_current(), resource.max_amount)
	dodging = true
	dodge_time = delta_for_start
	_dodge_hit = {}
	cooldown_dodge = float(mob["cooldown"])
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

	if state == AttackState.ACTIVE and current_skill.has("strikes"):
		_process_strikes()

	if state == AttackState.WINDUP and state_time >= float(current_skill["windup"]):
		if _is_charging(delta):
			return
		_apply_hold_bonus()
		state = AttackState.ACTIVE
		state_time -= float(current_skill["windup"])
		if String(current_skill.get("anchor", "self")) == "aim_leap":
			position = attack_point
			velocity = Vector2.ZERO
		_enter_active()
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


## Lo que ocurre al empezar la fase ACTIVE segun el tipo de skill: abrir la
## postura, aplicar la mejora, lanzar proyectiles, empezar los golpes multiples o
## resolver el golpe.
func _enter_active() -> void:
	if current_skill.has("stance"):
		_stance_spent = false
		return
	if current_skill.has("buff"):
		var buff: Dictionary = current_skill["buff"]
		_apply_buff(float(buff["next_damage_mult"]), float(buff["duration"]))
		return
	if current_skill.has("teleport_behind"):
		_shadow_step()
		return
	if String(current_skill.get("shape", "")) == "self" and current_skill.has("zone") and not current_skill.has("self_status"):
		_spawn_skill_zone()
		return
	if current_skill.has("grant_venom_hits"):
		venom_hits = int(current_skill["grant_venom_hits"])
		return
	if current_skill.has("self_heal_pct"):
		health = minf(max_health, health + max_health * float(current_skill["self_heal_pct"]))
		health_changed.emit(health, max_health)
		return
	if current_skill.has("self_status"):
		var self_status: Dictionary = current_skill["self_status"]
		statuses.apply(String(self_status["id"]), float(self_status["duration"]), float(self_status["strength"]))
		if current_skill.has("resource_burst"):
			_gain_resource(float(current_skill["resource_burst"]))
		if current_skill.has("zone"):
			_spawn_skill_zone()
		if bool(current_skill.get("vanish", false)):
			vanish_hits_left = 1
			_combo_index = 0
			_force_crit = true
		return
	match String(current_skill.get("shape", "cone")):
		"projectile":
			_launch_projectiles()
		"self":
			pass
		_:
			if current_skill.has("strikes"):
				_strike_index = 0
				_process_strikes()
			else:
				_resolve_attack_hit()


## Resuelve los golpes multiples que ya tocan segun el tiempo de la fase ACTIVE.
## El ultimo golpe usa final_mult.
func _process_strikes() -> void:
	var strikes: Dictionary = current_skill["strikes"]
	var count := int(strikes["count"])
	var interval := float(strikes["interval"])
	while _strike_index < count and state_time >= float(_strike_index) * interval:
		var strike_mult := float(strikes["final_mult"]) if _strike_index == count - 1 else 1.0
		_resolve_attack_hit(strike_mult)
		_strike_index += 1


## Lanza los proyectiles de la skill (en abanico si count > 1) con el dano ya
## calculado (carga, mejoras, pasiva). Comparten el tope de recurso del lanzamiento.
func _launch_projectiles() -> void:
	if world == null:
		return
	var spec: Dictionary = current_skill["projectile"]
	var count := int(spec["count"])
	var spread := float(spec["spread"])
	for i: int in range(count):
		var offset := 0.0 if count == 1 else lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		var direction := attack_aim.rotated(deg_to_rad(offset))
		var projectile := ProjectileSim.new(self, current_skill, direction, position + direction * (RADIUS - 2.0), _attack_damage_mult, _range_mult, _swing_tracker)
		world.spawn_projectile(projectile)
	projectiles_launched.emit(current_skill, attack_aim)


## Mejora el siguiente ataque con dano x `multiplier` durante `seconds`. No se
## acumula: volver a aplicarla la refresca.
func _apply_buff(multiplier: float, seconds: float) -> void:
	empower_mult = multiplier
	empower_until_tick = tick + int(seconds * 60.0)
	buff_changed.emit(true, empower_mult, seconds)


func _consume_empower() -> void:
	empower_mult = 1.0
	empower_until_tick = 0
	buff_changed.emit(false, 1.0, 0.0)


func empower_seconds_left() -> float:
	if empower_mult <= 1.0:
		return 0.0
	return maxf(0.0, float(empower_until_tick - tick) / 60.0)


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
	if hold.has("full_on_hit") and fraction >= 0.99:
		current_skill["on_hit"] = (current_skill.get("on_hit", []) as Array) + (hold["full_on_hit"] as Array)
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
	var base_range: float = float(current_skill["range"]) if current_skill.has("range") else float(current_skill.get("projectile", {}).get("range", 0.0))
	return base_range * _range_mult


func charges_left(slot: String) -> float:
	return float(charges.get(slot, 0.0))


func charges_max(slot: String) -> float:
	if not loadout.has(slot) or not (loadout[slot] as Dictionary).has("charges"):
		return 0.0
	return float((loadout[slot] as Dictionary)["charges"]["max"])


func _try_start_attack() -> void:
	if not alive or dodging or blocking or statuses.is_stunned():
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
	if statuses.has("silence") and slot != "M1" and slot != "M2":
		return "silenced"
	if resource.get_current() < float(skill.get("cost", 0.0)) and not skill.has("spark_mult"):
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
	if current_skill.has("stealth_toggle") and is_hidden():
		# Volver a usar Stealth/Vanish estando oculto lo rompe (sin gastar).
		current_skill = {}
		_break_stealth()
		return
	if not current_skill.has("stealth_toggle"):
		_break_stealth()
	if current_skill.has("combo"):
		_apply_combo()
	_apply_mage_rules()
	var cost := float(current_skill.get("cost", 0.0))
	if cost > 0.0:
		resource.consume(cost)
		resource_changed.emit(resource.get_current(), resource.max_amount)
	if current_skill.has("charges"):
		charges[slot] = maxf(0.0, float(charges.get(slot, 0.0)) - 1.0)
	hold_time = 0.0
	_range_mult = 1.0
	_stance_spent = false
	var charge := float(current_skill.get("charge", 0.0))
	if charge > 0.0:
		ultimate_charge = maxf(0.0, ultimate_charge - charge)
		ultimate_changed.emit(ultimate_charge, WarriorKit.ULTIMATE_CHARGE_MAX)

	var cast_cfg: Dictionary = class_def.get("ult_charge", {}).get("on_cast", {})
	if not cast_cfg.is_empty() and String(current_skill.get("slot", "")) != "ULTIMATE":
		_gain_ultimate(float(cast_cfg.get("flat", 0.0)) + cost * float(cast_cfg.get("per_cost", 0.0)))

	attack_aim = aim_dir
	state = AttackState.WINDUP
	state_time = 0.0
	_swing_tracker = {"resource": 0.0, "ult": 0.0}
	_strike_index = 0
	_attack_damage_mult = float(current_skill["damage_mult"])
	if empower_mult > 1.0 and not current_skill.has("buff") and String(current_skill.get("shape", "cone")) != "self":
		_attack_damage_mult *= empower_mult
		_consume_empower()
	attack_point = position
	if String(current_skill.get("anchor", "self")) == "aim_leap":
		var landing := position + attack_aim * float(current_skill["leap_distance"])
		attack_point = world.resolve_position(landing, RADIUS) if world != null else landing
	elif String(current_skill.get("anchor", "self")) == "aim_point":
		var marked := position + attack_aim * float(current_skill["point_distance"])
		attack_point = world.resolve_position(marked, RADIUS) if world != null else marked

	if bool(current_skill.get("consumes_vengeful", false)) and vengeful_active:
		_attack_damage_mult *= 1.0 + float(WarriorKit.PASSIVE["bonus"])
		vengeful_active = false
		vengeful_until_tick = 0
		vengeful_changed.emit(false, 0.0)

	# Los basicos cuentan el cooldown desde que acaba el ataque; las demas skills,
	# desde que se lanzan.
	var cooldown_key := String(current_skill["id"])
	if String(current_skill["kind"]) == "basic":
		cooldowns[cooldown_key] = total_attack_duration(current_skill) + float(current_skill["cooldown"])
	else:
		cooldowns[cooldown_key] = float(current_skill["cooldown"])

	attack_state_changed.emit(state)
	attack_started.emit(current_skill, attack_aim)


## Origen de la zona del golpe: el punto marcado (aim_point) o el propio jugador.
func _hit_origin() -> Vector2:
	if String(current_skill.get("anchor", "self")) == "aim_point":
		return attack_point
	return position


## Golpea a los objetivos dentro de la forma de la skill actual (cone, line o
## circle). Los proyectiles y las mejoras no usan esta ruta.
func _resolve_attack_hit(strike_mult: float = 1.0) -> void:
	if current_skill.is_empty() or world == null:
		return
	var shape := String(current_skill.get("shape", "cone"))
	if shape == "projectile" or shape == "self":
		return
	_spawn_skill_zone()
	for target: Object in _targets_in_shape(world.get_living_targets(self)):
		_apply_skill_hit(target, current_skill, _attack_damage_mult * strike_mult * _zone_multiplier(target), _swing_tracker)


## Un golpe de `skill` contra `target` con multiplicador `mult`: critico, tirada de
## dano (fisico con arma o magico con Spell Power), XP si muere, recurso y carga de
## ultimate (con los topes de `tracker`) y la senal attack_hit.
func _apply_skill_hit(target: Object, skill: Dictionary, mult: float, tracker: Dictionary) -> void:
	var critical: bool = _rng.randf() < stats.get_crit_chance() or _force_crit
	_force_crit = false
	var roll: float = stats.roll_spell_damage(_rng) if String(skill.get("damage_type", "physical")) == "magic" else stats.roll_weapon_damage(_rng)
	var damage: float = roll * mult * (1.0 + statuses.strength("might") + statuses.strength("warcry")) * pvp_tuning("damage")
	var behind := _is_behind(target)
	var bonus := 0.0
	if behind:
		bonus += float(class_def.get("backstab_bonus", 0.0))
	if statuses.has("backstab") and behind:
		bonus += statuses.strength("backstab")
		statuses.remove("backstab")
	if _opening_bonus > 0.0:
		bonus += _opening_bonus
		_opening_bonus = 0.0
	damage *= 1.0 + bonus
	if skill.has("bonus_vs") and target.get("statuses") != null and (target.statuses as StatusSet).has(String(skill["bonus_vs"]["status"])):
		damage *= float(skill["bonus_vs"]["mult"])
	if skill.has("execute") and target.get("max_health") != null and float(target.health) <= float(target.max_health) * float(skill["execute"]["below"]):
		if bool(skill["execute"].get("kill", false)):
			if not (target.has_method("is_boss") and target.is_boss()):
				damage = float(target.health) + 1000.0
		else:
			damage *= float(skill["execute"]["mult"])
	if critical:
		damage *= CRIT_MULTIPLIER
	# Un rival (PvP) recibe el golpe con su origen, para que el bloqueo y la esquiva funcionen como siempre.
	var dealt: float = target.take_damage(damage, position) if target is PlayerSim else target.take_damage(damage)
	if target.alive and dealt > 0.0 and target.has_method("apply_status"):
		if venom_hits > 0:
			venom_hits -= 1
			target.apply_status("poison", 5.0, 6.0, position)
		elif String(class_def.get("passive", "")) == "shadow_venom" and level >= int(class_def.get("passive_level", 1)) and behind:
			target.apply_status("poison", 3.0, 3.0, position)
	if not target.alive and target.has_method("xp_reward"):
		grant_xp(int(target.xp_reward()), target.position)
	elif dealt > 0.0 and skill.has("on_hit") and target.has_method("apply_status"):
		for effect: Dictionary in skill["on_hit"]:
			target.apply_status(String(effect["id"]), float(effect["duration"]), float(effect.get("strength", 0.0)), position)

	var resource_left: float = float(skill["resource_cap"]) - float(tracker["resource"])
	var resource_gain := minf(float(skill["resource_gain"]), maxf(resource_left, 0.0))
	if resource_gain > 0.0:
		tracker["resource"] = float(tracker["resource"]) + resource_gain
		_gain_resource(resource_gain)

	var cfg: Dictionary = class_def.get("ult_charge", {})
	var ult_left: float = float(skill.get("ult_cap", 0.0)) - float(tracker["ult"])
	var ult_gain := minf(float(skill.get("ult_gain", 0.0)), maxf(ult_left, 0.0)) * float(cfg.get("hit_scale", 1.0))
	if ult_gain > 0.0:
		tracker["ult"] = float(tracker["ult"]) + ult_gain
		_gain_ultimate(ult_gain)
	_ult_extras_on_hit(cfg, target, skill, critical)

	last_combat_tick = tick
	attack_hit.emit(skill, target, dealt, critical, target.position)


## Cada clase carga su ultimate a su manera (`ult_charge` en la clase): el guerrero con golpes y
## castigo recibido, el picaro esquivando y rematando envenenados, el mago lanzando hechizos y el
## arquero con aciertos a larga distancia y criticos.
func _ult_extras_on_hit(cfg: Dictionary, target: Object, skill: Dictionary, critical: bool) -> void:
	if cfg.is_empty() or String(skill.get("slot", "")) == "ULTIMATE":
		return
	var extra := 0.0
	if critical:
		extra += float(cfg.get("on_crit", 0.0))
	if target.get("statuses") != null and target.statuses.has("poison"):
		extra += float(cfg.get("on_poisoned", 0.0))
	var far: Dictionary = cfg.get("far_hit", {})
	if not far.is_empty() and target.position.distance_to(position) >= float(far["distance"]):
		extra += float(far["amount"])
	if not target.alive:
		extra += float(cfg.get("on_kill", 0.0))
	if extra > 0.0:
		_gain_ultimate(extra)


func _gain_ultimate_class(kind: String, base: float) -> void:
	var cfg: Dictionary = class_def.get("ult_charge", {})
	var value := base * float(cfg.get("hit_scale", 1.0)) if kind == "hit" else base
	if value > 0.0:
		_gain_ultimate(value)


## Impacto de un proyectil (llamado por ProjectileSim). `scale` reduce el dano
## de las explosiones respecto al impacto directo.
func projectile_hit(projectile: Object, target: Object, scale: float = 1.0) -> void:
	_apply_skill_hit(target, projectile.skill, float(projectile.damage_mult) * scale, projectile.tracker)


## Multiplicador por zona: las skills con center_radius pegan mas fuerte al
## centro (War God's Descent).
func _zone_multiplier(target: Object) -> float:
	if not current_skill.has("center_radius"):
		return 1.0
	if target.position.distance_to(_hit_origin()) <= float(current_skill["center_radius"]):
		return float(current_skill["center_mult"])
	return 1.0


## Objetivos dentro de la forma de la skill actual, con el limite max_targets
## (los mas cercanos primero). Mantiene el orden original si no hay limite.
func _targets_in_shape(candidates: Array) -> Array:
	var shape := String(current_skill.get("shape", "cone"))
	var attack_range := float(current_skill["range"]) * _range_mult
	var hits: Array = []
	var origin := _hit_origin()
	for target: Object in candidates:
		var to_target: Vector2 = target.position - origin
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
			return a.position.distance_squared_to(origin) < b.position.distance_squared_to(origin))
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
	var factor := _movement_factor() * statuses.speed_mult() * (0.5 if blocking else 1.0)
	var desired := move_input * MOVE_SPEED * factor
	var rate := ACCELERATION if move_input.length_squared() > 0.0001 else FRICTION
	velocity = velocity.move_toward(desired, rate * delta)
	if velocity.length_squared() < 0.01:
		velocity = Vector2.ZERO
	position += velocity * delta
	if world != null:
		position = world.resolve_position(position, RADIUS)


## Descanso en una hoguera: cura `fraction` de la vida maxima (y vuelve el recurso de clase a la mitad).
func rest(fraction: float) -> void:
	if not alive:
		return
	health = minf(max_health, health + max_health * fraction)
	health_changed.emit(health, max_health)


## Salto de las skills aim_leap: recorre la distancia hasta attack_point durante
## el windup, ignorando el input de movimiento.
func _move_leap(delta: float) -> void:
	var speed: float = float(current_skill["leap_distance"]) / maxf(float(current_skill["windup"]), 0.001)
	position = position.move_toward(attack_point, speed * delta)
	velocity = Vector2.ZERO


## La carga (guerrero): aturde a cada enemigo que toca durante el desplazamiento.
func _charge_hits(mob: Dictionary) -> void:
	for target: Object in world.get_living_targets(self):
		if _dodge_hit.has(target.get_instance_id()):
			continue
		if target.position.distance_to(position) > RADIUS + float(target.radius) + 8.0:
			continue
		_dodge_hit[target.get_instance_id()] = true
		if target.has_method("apply_status"):
			target.apply_status("stun", float(mob["stun_on_hit"]), 0.0)
		var dealt: float = target.take_damage(stats.roll_weapon_damage(_rng) * float(mob.get("damage_mult", 0.6)))
		if not target.alive and target.has_method("xp_reward"):
			grant_xp(int(target.xp_reward()), target.position)
		_gain_ultimate_class("hit", float(mob.get("ult_gain", 4.0)))
		last_combat_tick = tick
		attack_hit.emit({"id": "charge", "slot": "MOBILITY", "kind": "skill"}, target, dealt, false, target.position)


## Un paso de la esquiva. Ocupa exactamente `duration` segundos y recorre
## `distance` px; el tick que cumple la duracion es el ultimo con movimiento de
## esquiva y ahi termina.
func _move_dodge(delta: float) -> void:
	var mob := mobility()
	var dodge_speed: float = float(mob["distance"]) / float(mob["duration"])
	velocity = dodge_dir * dodge_speed
	position += velocity * delta
	if world != null:
		position = world.resolve_position(position, RADIUS)
		if mob.has("stun_on_hit"):
			_charge_hits(mob)
	if dodge_time >= float(mob["duration"]) - 0.0001:
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


func _gain_resource(amount: float) -> void:
	var before := resource.get_current()
	resource.generate(amount)
	if not is_equal_approx(before, resource.get_current()):
		resource_changed.emit(resource.get_current(), resource.max_amount)


## Mantenimiento por tick: caduca la pasiva y las mejoras, y mueve el recurso segun
## la clase (Rage decae fuera de combate; Energy y Mana se regeneran).
func _update_resource(delta: float) -> void:
	if vengeful_active and tick >= vengeful_until_tick:
		vengeful_active = false
		vengeful_changed.emit(false, 0.0)
	if empower_mult > 1.0 and tick >= empower_until_tick:
		_consume_empower()

	if resource_kind == "rage":
		if resource.get_current() <= 0.0:
			return
		var grace_ticks := int(RAGE_DECAY_GRACE * 60.0)
		if tick - last_combat_tick > grace_ticks:
			var before := resource.get_current()
			resource.current_amount = maxf(0.0, before - RAGE_DECAY_PER_SECOND * delta)
			if not is_equal_approx(before, resource.get_current()):
				resource_changed.emit(resource.get_current(), resource.max_amount)
		return
	if resource.current_amount < resource.max_amount:
		var before := resource.current_amount
		var regen := float(class_def["resource"]["regen_per_second"])
		if tick - last_combat_tick > 180 and class_def["resource"].has("regen_out_of_combat"):
			regen = float(class_def["resource"]["regen_out_of_combat"])
		resource.generate(regen * delta)
		if not is_equal_approx(before, resource.current_amount):
			resource_changed.emit(resource.get_current(), resource.max_amount)


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, is_dot: bool = false) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	if is_invulnerable() and not is_dot:
		attack_evaded.emit(source_position)
		_gain_ultimate(float(class_def.get("ult_charge", {}).get("on_evade", 0.0)))
		return 0.0
	if not is_dot and _stance_blocks(source_position):
		_block_with_stance(source_position)
		return 0.0
	if blocking and not is_dot and _block_covers(source_position):
		var left := _resolve_block(amount, source_position)
		if left < 0.0:
			return 0.0
		amount = left

	var reduced := statuses.absorb(amount * (1.0 - armor_reduction()) * (1.0 + statuses.strength("curse")))
	if statuses.has("manashield") and reduced > 0.0 and resource.get_current() > 0.0:
		# Mana Shield: el mana absorbe parte del dano (1 de mana por 1 de dano).
		var soaked := minf(reduced * statuses.strength("manashield"), resource.get_current())
		resource.consume(soaked)
		resource_changed.emit(resource.get_current(), resource.max_amount)
		reduced -= soaked
	if reduced <= 0.0:
		return 0.0
	var dealt := minf(reduced, health)
	_hit_breaks_stealth()
	health -= dealt

	if resource_kind == "rage" and not is_dot:
		var percent_lost := (dealt / max_health) * 100.0
		_gain_resource(clampf(percent_lost, RAGE_TAKEN_MIN, RAGE_TAKEN_CAP))
	last_combat_tick = tick
	if not is_dot:
		var taken_cfg: Dictionary = class_def.get("ult_charge", {})
		_gain_ultimate(clampf((dealt / max_health) * 100.0 * float(taken_cfg.get("on_taken_per_percent", 0.0)), 0.0, float(taken_cfg.get("on_taken_cap", 10.0))))



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
	var mob := mobility()
	return dodge_time >= float(mob["iframe_start"]) and dodge_time < float(mob["iframe_end"])


func dodge_cooldown_left() -> float:
	return cooldown_dodge


func dodge_cooldown_total() -> float:
	return float(mobility()["cooldown"])


## Verdadero mientras la postura del Special esta abierta (y no ha bloqueado aun).
func stance_active() -> bool:
	return state == AttackState.ACTIVE and current_skill.has("stance") and not _stance_spent


## Una fuente real (distinta de Vector2.ZERO) dentro del arco frontal de la
## postura, segun hacia donde apunta el jugador, es bloqueada.
func _stance_blocks(source_position: Vector2) -> bool:
	if not stance_active() or source_position == Vector2.ZERO:
		return false
	var toward := source_position - position
	if toward.length_squared() < 0.0001:
		return true
	return absf(rad_to_deg(aim_dir.angle_to(toward))) <= float(current_skill["stance"]["arc"]) * 0.5 + 0.01


## Anula el golpe, gira hacia quien lo lanzo y devuelve el contraataque con la
## forma de la skill. Despues recupera mas rapido que si la postura expira.
func _block_with_stance(source_position: Vector2) -> void:
	_stance_spent = true
	var toward := source_position - position
	if toward.length_squared() > 0.0001:
		attack_aim = toward.normalized()
	attack_blocked.emit(source_position)
	_resolve_attack_hit()
	var empower: Dictionary = current_skill["stance"].get("empower", {})
	if not empower.is_empty():
		_apply_buff(float(empower["mult"]), float(empower["duration"]))
	current_skill["recovery"] = float(current_skill["stance"]["counter_recovery"])
	state = AttackState.RECOVERY
	state_time = 0.0
	attack_state_changed.emit(state)


## Cambia de clase (solo en reposo). Cada clase conserva su propio nivel, XP y
## loadout: volver a una clase la deja como estaba. Es la misma simulacion, con
## otro recurso, otros stats y otras skills; las senales siguen conectadas.
func switch_class(new_class_id: String) -> String:
	if not ClassCatalog.has_class(new_class_id):
		return "unknown"
	if new_class_id == class_id:
		return ""
	if not can_edit_loadout():
		return "busy"
	_save_progress()
	_activate_class(new_class_id)
	return ""


## Deja `new_class_id` como clase activa con su nivel, XP y loadout guardados en
## `progress` (o los de un personaje nuevo si no hay).
func _activate_class(new_class_id: String) -> void:
	_set_class_data(new_class_id)
	var saved: Dictionary = progress.get(class_id, {})
	level = int(saved.get("level", 1))
	xp = int(saved.get("xp", 0))
	equipment = {}
	for slot: String in saved.get("equipment", {}):
		var piece: Variant = (saved["equipment"] as Dictionary)[slot]
		if ItemCatalog.is_valid_item(piece) and String(ItemCatalog.item(String(piece["id"]))["slot"]) == slot and ItemCatalog.can_equip_base(String(piece["id"]), class_id):
			equipment[slot] = ItemCatalog.normalized(piece)
	_build_stats()
	resource.resource_name = String(class_def["resource"]["name"])
	resource.max_amount = float(class_def["resource"]["max"])
	loadout = {}
	charges = {}
	if saved.has("loadout"):
		for slot: String in saved["loadout"]:
			var id := StringName(String(saved["loadout"][slot]))
			if _equip_reason(slot, id).is_empty():
				_equip_internal(slot, SkillCatalog.skill(id))
	else:
		_auto_equip(_ids_unlocked_between(0, level))
	reset(position)
	class_changed.emit(class_id)
	loadout_changed.emit()
	xp_changed.emit(xp, xp_to_next(), level)


## Modo de reglas (data/rules.json): "pve" es la aventura; "pvp" normaliza al personaje.
var rule_mode: String = "pve"
## Estado de la aventura guardado mientras se juega una partida normalizada.
var _pve_state: Dictionary = {}


## Cambia de modo de reglas. En PvP el personaje se sustituye por uno normalizado de la misma clase (nivel
## fijo, sin equipo ni consumibles ni skills de mundo); al volver a "pve" se restaura la aventura tal cual.
func enter_rules(mode: String) -> String:
	if not RuleSet.has_mode(mode):
		return "unknown"
	if mode == rule_mode:
		return ""
	if rule_mode == "pve":
		_pve_state = export_state()
	rule_mode = mode
	var rules := RuleSet.rules(mode)
	if not bool(rules["normalized"]):
		import_state(_pve_state)
		_pve_state = {}
		return ""
	progress = {}
	learned_skills = []
	consumables = {}
	progress[class_id] = {"level": int(rules["level"]), "xp": 0, "equipment": {}}
	_activate_class(class_id)
	return ""


## Multiplicador de equilibrio PvP de esta clase ("health" o "damage"); 1.0 fuera de PvP.
func pvp_tuning(key: String) -> float:
	if rule_mode == "pve":
		return 1.0
	var tuning: Dictionary = RuleSet.rules(rule_mode).get("class_tuning", {})
	return float((tuning.get(class_id, {}) as Dictionary).get(key, 1.0))


func rule(key: String) -> bool:
	return bool(RuleSet.rules(rule_mode).get(key, true))


## Estado que se guarda en disco: la clase activa y el nivel, XP y loadout de cada
## clase.
func export_state() -> Dictionary:
	if rule_mode != "pve" and not _pve_state.is_empty():
		return _pve_state.duplicate(true)      # en una partida normalizada no se guarda nada del personaje de arena
	_save_progress()
	return {"class_id": class_id, "progress": progress.duplicate(true), "bag": bag.duplicate(true), "gold": gold, "materials": materials.duplicate(), "consumables": consumables.duplicate(), "bank": bank.duplicate(true), "bounties": bounties.duplicate(true), "bounty_serial": bounty_serial, "bounties_done": bounties_done, "learned": learned_skills.duplicate(), "character": {"name": character_name, "appearance": appearance.duplicate(), "created": character_created}}


## Restaura un estado guardado (sin comprobar si se puede editar el loadout).
func import_state(data: Dictionary) -> void:
	var saved := _as_dict(data.get("progress"))
	progress = {}
	for id: String in saved:
		if ClassCatalog.has_class(id) and saved[id] is Dictionary:
			progress[id] = (saved[id] as Dictionary).duplicate(true)
	gold = maxi(_as_int(data.get("gold"), 0), 0)
	consumables = {}
	var saved_consumables := _as_dict(data.get("consumables"))
	for id: String in saved_consumables:
		if ConsumableCatalog.has(id) and _as_int(saved_consumables[id], 0) > 0:
			consumables[id] = mini(_as_int(saved_consumables[id], 0), ConsumableCatalog.max_stack())
	bank = []
	for piece: Variant in _as_array(data.get("bank")):
		if ItemCatalog.is_valid_item(piece) and bank.size() < BANK_SIZE:
			bank.append(ItemCatalog.normalized(piece))
	potion_cooldown_left = 0.0
	bounties = []
	for entry: Variant in _as_array(data.get("bounties")):
		if entry is Dictionary and (entry as Dictionary).has("template") and (entry as Dictionary).has("count") and (entry as Dictionary).has("progress"):
			bounties.append((entry as Dictionary).duplicate(true))
	bounty_serial = maxi(_as_int(data.get("bounty_serial"), 0), 0)
	bounties_done = maxi(_as_int(data.get("bounties_done"), 0), 0)
	learned_skills = []
	for id: Variant in _as_array(data.get("learned")):
		if SkillCatalog.skill(StringName(String(id))).get("world", false) and not learned_skills.has(String(id)):
			learned_skills.append(String(id))
	var saved_character := _as_dict(data.get("character"))
	character_name = str(saved_character.get("name", "Despierto"))
	appearance = _as_dict(saved_character.get("appearance")).duplicate()
	character_created = bool(saved_character.get("created", false))
	materials = {}
	var saved_materials := _as_dict(data.get("materials"))
	for id: String in saved_materials:
		if MaterialCatalog.is_valid(id) and _as_int(saved_materials[id], 0) > 0:
			materials[id] = _as_int(saved_materials[id], 0)
	bag = []
	for piece: Variant in _as_array(data.get("bag")):
		if ItemCatalog.is_valid_item(piece) and bag.size() < ItemCatalog.bag_size():
			bag.append(ItemCatalog.normalized(piece))
	var target := str(data.get("class_id", "warrior"))
	_activate_class(target if ClassCatalog.has_class(target) else "warrior")


static func _as_dict(value: Variant) -> Dictionary:
	return (value as Dictionary) if value is Dictionary else {}


static func _as_array(value: Variant) -> Array:
	return (value as Array) if value is Array else []


static func _as_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and (value as String).is_valid_int():
		return int(value)
	return fallback


func _save_progress() -> void:
	var equipped: Dictionary = {}
	for slot: String in loadout:
		equipped[slot] = String((loadout[slot] as Dictionary)["id"])
	progress[class_id] = {"level": level, "xp": xp, "loadout": equipped, "equipment": equipment.duplicate(true)}


# --- Inventario y equipo ------------------------------------------------------


## Suma de los stats del equipo puesto.
func gear_stats() -> Dictionary:
	var total: Dictionary = {}
	for slot: String in equipment:
		for stat: String in (equipment[slot] as Dictionary)["stats"]:
			total[stat] = float(total.get(stat, 0.0)) + float((equipment[slot] as Dictionary)["stats"][stat])
	return total


func bag_has_room() -> bool:
	return bag.size() < ItemCatalog.bag_size()


## Guarda un item en la mochila; si no cabe, avisa con bag_full y lo pierde.
func add_item(item: Dictionary) -> bool:
	if bag.size() >= ItemCatalog.bag_size():
		bag_full.emit(item)
		return false
	bag.append(item)
	item_gained.emit(item)
	inventory_changed.emit()
	return true


## Motivo por el que no se puede equipar el item de la mochila (o "" si se puede).
func equip_reason(index: int) -> String:
	if index < 0 or index >= bag.size():
		return "unknown"
	if not rule("allow_gear"):
		return "rules"
	if not can_change_gear():
		return "busy"
	var piece: Dictionary = bag[index]
	if not ItemCatalog.can_equip_base(String(piece["id"]), class_id):
		return "class"
	return ""


## Equipa el item de la mochila; el que hubiera en esa ranura vuelve a la mochila.
func equip_from_bag(index: int) -> String:
	var reason := equip_reason(index)
	if reason != "":
		return reason
	var piece: Dictionary = bag[index]
	var slot := String(ItemCatalog.item(String(piece["id"]))["slot"])
	var previous: Variant = equipment.get(slot)
	bag.remove_at(index)
	equipment[slot] = piece
	if previous != null:
		bag.append(previous)
	_refresh_gear()
	return ""


func unequip_gear(slot: String) -> String:
	if not equipment.has(slot):
		return "unknown"
	if not can_change_gear():
		return "busy"
	if bag.size() >= ItemCatalog.bag_size():
		return "full"
	bag.append(equipment[slot])
	equipment.erase(slot)
	_refresh_gear()
	return ""


func material_count(id: String) -> int:
	return int(materials.get(id, 0))


func add_material(id: String, amount: int) -> void:
	if amount <= 0 or not MaterialCatalog.is_valid(id):
		return
	materials[id] = material_count(id) + amount
	material_gained.emit(id, amount)
	materials_changed.emit()


## Si hay de todo lo que pide `cost` (id -> cantidad).
func has_materials(cost: Dictionary) -> bool:
	for id: String in cost:
		if material_count(id) < int(cost[id]):
			return false
	return true


func spend_materials(cost: Dictionary) -> bool:
	if not has_materials(cost):
		return false
	for id: String in cost:
		materials[id] = material_count(id) - int(cost[id])
		if int(materials[id]) <= 0:
			materials.erase(id)
	materials_changed.emit()
	return true


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


## Fija el nombre y el aspecto del personaje (el creador); la ropa no se elige: sale del equipo.
func set_character(new_name: String, new_appearance: Dictionary) -> void:
	character_name = new_name.strip_edges() if not new_name.strip_edges().is_empty() else "Despierto"
	appearance = new_appearance.duplicate()
	character_created = true
	appearance_changed.emit()


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


## Vende un item de la mochila (solo en zona segura); devuelve el oro ganado o -1.
func sell_from_bag(index: int) -> int:
	if index < 0 or index >= bag.size() or not safe_zone:
		return -1
	var value := ItemCatalog.sell_value(bag[index])
	bag.remove_at(index)
	add_gold(value)
	inventory_changed.emit()
	return value


## Tira un item de la mochila sin cobrar nada.
func discard_from_bag(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	bag.remove_at(index)
	inventory_changed.emit()
	return true


## Recalcula los stats tras cambiar el equipo conservando el porcentaje de vida.
func _refresh_gear() -> void:
	var ratio := health / maxf(max_health, 1.0)
	_build_stats()
	health = max_health * ratio
	inventory_changed.emit()


## Bloqueo del guerrero ----------------------------------------------------------------


func _update_block(delta: float, mob: Dictionary) -> void:
	var held := bool(_actions.get("dodge", false))
	if blocking:
		block_time += delta
		# Mantener el escudo gasta Rage cada segundo; sin Rage se baja solo.
		var drain := float(mob.get("block_drain", 0.0)) * delta
		if drain > 0.0 and block_time > float(mob["parry_window"]):
			resource.consume(drain)
			resource_changed.emit(resource.get_current(), resource.max_amount)
			if resource.get_current() <= 0.0:
				_end_block(mob)
				return
		if not held or not alive or statuses.is_stunned():
			_end_block(mob)
		return
	if dodge_buffer_timer <= 0.0 or cooldown_dodge > 0.0 or not alive or statuses.is_stunned():
		return
	if state == AttackState.ACTIVE and not current_skill.has("stance"):
		return
	if state != AttackState.IDLE and bool(current_skill.get("uncancelable", false)):
		return
	dodge_buffer_timer = 0.0
	if state != AttackState.IDLE:
		_cancel_attack()
	blocking = true
	block_time = 0.0
	block_started.emit()


func _end_block(mob: Dictionary) -> void:
	blocking = false
	cooldown_dodge = float(mob["cooldown"])
	block_ended.emit()


## El golpe viene del frente (dentro del arco del escudo).
func _block_covers(source_position: Vector2) -> bool:
	if source_position == Vector2.ZERO:
		return false
	var toward := source_position - position
	if toward.length_squared() < 0.0001:
		return true
	return absf(rad_to_deg(aim_dir.angle_to(toward))) <= float(mobility().get("block_arc", 150.0)) * 0.5


## Devuelve el dano que aun pasa (>= 0) o -1 si el golpe se anula del todo (parry perfecto).
func _resolve_block(amount: float, source_position: Vector2) -> float:
	var mob := mobility()
	if block_time <= float(mob["parry_window"]):
		block_time = 1.0
		_on_parry(source_position)
		return -1.0
	var cost := amount * float(mob["block_cost"])
	if resource.get_current() >= cost:
		resource.consume(cost)
		resource_changed.emit(resource.get_current(), resource.max_amount)
		_trigger_vengeful()
		attack_blocked.emit(source_position)
		return amount * (1.0 - float(mob["block_reduction"]))
	# Sin Rage el escudo se rompe: el golpe entra entero y quedas aturdido.
	_end_block(mob)
	apply_status("stun", 1.0)
	return amount


func _on_parry(source_position: Vector2) -> void:
	attack_parried.emit(source_position)
	var nearest: EnemySim = null
	var best := 80.0
	if world != null:
		for enemy: EnemySim in world.enemies:
			var distance := enemy.position.distance_to(source_position)
			if enemy.alive and distance < best:
				best = distance
				nearest = enemy
	if nearest != null:
		# A un jefe no se le aturde: un tambaleo corto de 0,5 s.
		if nearest.is_boss():
			nearest.apply_status("stagger", 0.5)
		else:
			nearest.apply_status("stun", 0.8)
	_gain_ultimate(float(class_def.get("ult_charge", {}).get("on_parry", 12.0)))
	_gain_resource(10.0)
	_trigger_vengeful()
	last_combat_tick = tick


## Furia vengativa (pasiva del guerrero, desde su nivel de pasiva): tras bloquear o hacer parry, el siguiente golpe fuerte hace mas dano.
func _trigger_vengeful() -> void:
	if String(class_def.get("passive", "")) != "vengeful_fury" or level < int(class_def.get("passive_level", 1)):
		return
	vengeful_active = true
	vengeful_until_tick = tick + int(float(WarriorKit.PASSIVE["window"]) * 60.0)
	vengeful_changed.emit(true, vengeful_seconds_left())


## Paso del combo del basico: sube el dano y el arco del tercero y le anade empuje.
func _apply_combo() -> void:
	var combo: Dictionary = current_skill["combo"]
	if tick - _combo_tick > int(float(combo["reset"]) * 60.0):
		_combo_index = 0
	var index := _combo_index
	current_skill["damage_mult"] = float(current_skill["damage_mult"]) * float((combo["mults"] as Array)[index])
	current_skill["arc"] = float(current_skill.get("arc", 90.0)) + float((combo["arc_bonus"] as Array)[index])
	if index == int(combo["steps"]) - 1 and combo.has("last_on_hit"):
		current_skill["on_hit"] = (current_skill.get("on_hit", []) as Array) + (combo["last_on_hit"] as Array)
	_combo_index = (index + 1) % int(combo["steps"])
	_combo_tick = tick


## Zona de suelo de una skill (grieta de la ultimate): dana a los enemigos que se queden dentro.
func _spawn_skill_zone() -> void:
	if not current_skill.has("zone") or world == null:
		return
	var spec: Dictionary = (current_skill["zone"] as Dictionary).duplicate(true)
	spec["owner"] = "player"
	world.spawn_zone(GroundZone.new(spec, _hit_origin(), stats.roll_weapon_damage(_rng)))


## Magia: Arcane Surge (tras una skill, el siguiente basico sale gratis y +50 %) y el chispazo (basico sin mana).
func _apply_mage_rules() -> void:
	var surge_on := String(class_def.get("passive", "")) == "arcane_surge" and level >= int(class_def.get("passive_level", 1))
	var kind := String(current_skill.get("kind", ""))
	if surge_on and kind == "basic" and statuses.has("surge"):
		statuses.remove("surge")
		current_skill["cost"] = 0.0
		current_skill["damage_mult"] = float(current_skill["damage_mult"]) * 1.5
		return
	if surge_on and (kind == "skill" or kind == "ultimate"):
		statuses.apply("surge", 8.0, 0.5)
	if current_skill.has("spark_mult") and resource.get_current() < float(current_skill.get("cost", 0.0)):
		current_skill["cost"] = 0.0
		current_skill["damage_mult"] = float(current_skill["damage_mult"]) * float(current_skill["spark_mult"])


## Sigilo ---------------------------------------------------------------------------------


func is_hidden() -> bool:
	return statuses.has("stealth") or statuses.has("vanish") or statuses.has("concealed")


## Sale del sigilo (atacar, usar otra skill, recibir dano): Stealth deja un bonus para el primer golpe.
func _break_stealth() -> void:
	if not is_hidden():
		return
	_opening_bonus = statuses.strength("stealth")
	statuses.remove("stealth")
	statuses.remove("vanish")
	statuses.remove("concealed")
	vanish_hits_left = 0
	stealth_broken.emit()


## Un golpe recibido: rompe Stealth y el humo; Vanish aguanta el primero.
func _hit_breaks_stealth() -> void:
	if statuses.has("vanish") and vanish_hits_left > 0:
		vanish_hits_left -= 1
		return
	if is_hidden():
		_break_stealth()


## El jugador esta a la espalda del objetivo (este mira en sentido contrario).
func _is_behind(target: Object) -> bool:
	if target.get("facing") == null:
		return false
	var to_player: Vector2 = (position - target.position).normalized()
	return (target.facing as Vector2).dot(to_player) < -0.25


## Shadow Step: te teletransportas detras del enemigo mas cercano hacia donde apuntas.
func _shadow_step() -> void:
	var spec: Dictionary = current_skill["teleport_behind"]
	var best: EnemySim = null
	var best_distance := float(spec["range"])
	if world != null:
		for enemy: EnemySim in world.enemies:
			if not enemy.alive:
				continue
			var to_enemy := enemy.position - position
			var distance := to_enemy.length()
			if distance > best_distance or distance < 0.001:
				continue
			if absf(rad_to_deg(aim_dir.angle_to(to_enemy))) > 55.0:
				continue
			best = enemy
			best_distance = distance
	if best == null:
		return
	var behind := best.position - best.facing * (best.radius + RADIUS + 6.0)
	position = world.resolve_position(behind, RADIUS)
	aim_dir = (best.position - position).normalized()
	velocity = Vector2.ZERO
	statuses.apply(String(spec["backstab"]["id"]), float(spec["backstab"]["duration"]), float(spec["backstab"]["strength"]))


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
	if not loadout.has(slot):
		return 0.0
	if (loadout[slot] as Dictionary).has("stealth_toggle") and is_hidden():
		return 0.0
	return float(cooldowns.get(String((loadout[slot] as Dictionary)["id"]), 0.0))


func attack_cooldown_total(slot: String) -> float:
	if not loadout.has(slot):
		return 0.0
	var skill: Dictionary = loadout[slot]
	if String(skill["kind"]) == "basic":
		return total_attack_duration(skill) + float(skill["cooldown"])
	return float(skill["cooldown"])


func is_attacking() -> bool:
	return state != AttackState.IDLE


func resource_amount() -> float:
	return resource.get_current()


func snapshot() -> Dictionary:
	return {
		"position": [position.x, position.y],
		"velocity": [velocity.x, velocity.y],
		"aim": [aim_dir.x, aim_dir.y],
		"health": health,
		"max_health": max_health,
		"class": class_id,
		"statuses": statuses.snapshot(),
		"resource": resource.get_current(),
		"empower": empower_mult,
		"state": state,
		"vengeful": vengeful_active,
		"dodging": dodging,
		"dodge_cd": cooldown_dodge,
		"cooldowns": cooldowns.duplicate(),
		"ultimate": ultimate_charge,
		"level": level,
		"xp": xp,
		"charges": charges.duplicate(),
		"hold": hold_time,
		"alive": alive,
	}
