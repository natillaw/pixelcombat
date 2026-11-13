## QuestManager — el estado de las misiones de una partida: ofertas por piso (guardadas, sin rerolls), misiones activas,
## progreso por eventos, reclamacion de recompensas sin duplicados, historial, cadenas y eventos secretos.
##
## Estados de una instancia: locked, available, active, completed, failed, abandoned, claimed.
## Limite: como mucho MAX_SIDE misiones secundarias (type "side") activas; las principales, las de cadena y las secretas
## no cuentan. La instancia es un Dictionary (serializable): ver QuestGenerator.instantiate. Es logica pura: no toca el
## inventario salvo en claim(), que usa RewardManager.
class_name QuestManager
extends RefCounted

signal changed(instance: Dictionary)
signal notice(text: String)

const MAX_SIDE := 3
const VERSION := 1

var instances: Dictionary = {}
## piso -> [ids de instancia ofrecidas] (se generan una vez por partida y se guardan).
var offers: Dictionary = {}
var history: Array = []
var done: Dictionary = {}
## Definiciones de historia/cadena ya desbloqueadas (pendientes de aceptar).
var unlocked: Array = []
var counter: int = 0
var run_seed: int = 20261110
var counters: Dictionary = {}
var secrets_done: Dictionary = {}
var secret_progress: Dictionary = {}
var choices: Dictionary = {}
## Estado del piso actual para objetivos de condicion (sin pociones, sin dano).
var floor_state: Dictionary = {"potion_used": false, "damage_taken": false, "floor": 1}
## Banderas del mundo (se comparten con TowerState.flags).
var flags: Dictionary = {}


func _init(p_flags: Dictionary = {}, p_seed: int = 20261110) -> void:
	flags = p_flags
	run_seed = p_seed
	unlocked = _initial_story()


## Misiones principales sin prerrequisitos de mision: la historia empieza disponible.
func _initial_story() -> Array:
	var out: Array = []
	for def: Dictionary in QuestLibrary.find("main"):
		out.append(String(def["id"]))
	return out


# --- Ofertas ----------------------------------------------------------------------


## Las ofertas del tablon de un piso. Se generan la primera vez y se guardan: abrir el tablon otra vez, volver a entrar
## o recargar la partida no cambia nada.
func offers_for(floor_info: Dictionary, class_id: String = "") -> Array:
	var floor_number := int(floor_info["floor"])
	if not offers.has(floor_number):
		var ids: Array = []
		for instance: Dictionary in QuestGenerator.generate_offers(floor_info, run_seed, 0, flags, done, history, class_id):
			counter += 1
			instance["id"] = "q%d" % counter
			instances[instance["id"]] = instance
			ids.append(instance["id"])
			history.append(instance["def"])
		offers[floor_number] = ids
	var out: Array = []
	for id: Variant in offers[floor_number]:
		out.append(instances[id])
	return out


func active_side_count() -> int:
	var count := 0
	for instance: Dictionary in instances.values():
		if String(instance["state"]) == "active" and String(instance["type"]) == "side":
			count += 1
	return count


func active() -> Array:
	return instances.values().filter(func(i: Dictionary) -> bool: return String(i["state"]) == "active")


func with_state(state: String) -> Array:
	return instances.values().filter(func(i: Dictionary) -> bool: return String(i["state"]) == state)


# --- Acciones ---------------------------------------------------------------------


## "" si se acepta; si no, el motivo: unknown, state, limit.
func accept(id: String) -> String:
	if not instances.has(id):
		return "unknown"
	var instance: Dictionary = instances[id]
	if not ["available", "abandoned"].has(String(instance["state"])):
		return "state"
	if String(instance["type"]) == "side" and active_side_count() >= MAX_SIDE:
		return "limit"
	_reset_progress(instance)
	instance["state"] = "active"
	instance["accepted_at"] = counters.size()
	changed.emit(instance)
	return ""


## Abandona una mision activa: vuelve al tablon (reiniciada) si es secundaria; las demas quedan abandonadas.
func abandon(id: String) -> bool:
	if not instances.has(id) or String((instances[id] as Dictionary)["state"]) != "active":
		return false
	var instance: Dictionary = instances[id]
	_reset_progress(instance)
	instance["state"] = "abandoned"
	changed.emit(instance)
	return true


func fail(id: String) -> bool:
	if not instances.has(id) or String((instances[id] as Dictionary)["state"]) != "active":
		return false
	(instances[id] as Dictionary)["state"] = "failed"
	changed.emit(instances[id])
	return true


func _reset_progress(instance: Dictionary) -> void:
	for objective: Dictionary in instance["objectives"]:
		objective["progress"] = 0


## Crea y activa una mision de historia, de cadena o secreta (no cuenta para el limite de 3). Devuelve la instancia o {}.
func start_quest(def_id: String, floor_info: Dictionary, class_id: String = "") -> Dictionary:
	var def := QuestLibrary.definition(def_id)
	if def.is_empty():
		return {}
	for instance: Dictionary in instances.values():
		if String(instance["def"]) == def_id and ["active", "completed", "available"].has(String(instance["state"])):
			return {}
	counter += 1
	var instance := QuestGenerator.instantiate(def, floor_info, SeedManager.seed_for([run_seed, "story", def_id, counter]), class_id)
	instance["id"] = "q%d" % counter
	instance["state"] = "active"
	instance["accepted_at"] = counters.size()
	instances[instance["id"]] = instance
	unlocked.erase(def_id)
	changed.emit(instance)
	notice.emit("Nueva mision: %s" % String(instance["title"]))
	return instance


## Misiones de historia/cadena desbloqueadas y compatibles con el piso (para el tablon de historia).
func story_available(floor_info: Dictionary) -> Array:
	var out: Array = []
	for def_id: Variant in unlocked:
		var def := QuestLibrary.definition(String(def_id))
		if not def.is_empty() and QuestLibrary.compatible(def, floor_info, flags, done):
			out.append(def)
	return out


## Elige una rama de una mision con decision: pone las banderas de la rama, completa su objetivo de condicion y desbloquea su siguiente.
func choose_branch(id: String, branch_id: String) -> bool:
	if not instances.has(id) or String((instances[id] as Dictionary)["state"]) != "active":
		return false
	var instance: Dictionary = instances[id]
	var def := QuestLibrary.definition(String(instance["def"]))
	for branch: Dictionary in def.get("branches", []):
		if String(branch["id"]) == branch_id:
			choices[String(instance["def"])] = branch_id
			for flag: Variant in branch.get("set_flags", []):
				flags[String(flag)] = true
			for next_id: Variant in branch.get("next", []):
				if not unlocked.has(String(next_id)):
					unlocked.append(String(next_id))
			for objective: Dictionary in instance["objectives"]:
				if String(objective["kind"]) == "condition":
					objective["progress"] = objective["required"]
			_check_complete(instance)
			return true
	return false


## Reclama la recompensa de una mision completada: una sola vez. Devuelve {ok, reason}.
func claim(id: String, player: PlayerSim) -> Dictionary:
	if not instances.has(id):
		return {"ok": false, "reason": "unknown"}
	var instance: Dictionary = instances[id]
	if bool(instance["reward_claimed"]) or String(instance["state"]) == "claimed":
		return {"ok": false, "reason": "claimed"}
	if String(instance["state"]) != "completed":
		return {"ok": false, "reason": "state"}
	var result := RewardManager.deliver(player, instance["rewards"], flags)
	if not bool(result["ok"]):
		return result
	instance["reward_claimed"] = true
	instance["state"] = "claimed"
	var def := QuestLibrary.definition(String(instance["def"]))
	done[String(instance["def"])] = int(done.get(String(instance["def"]), 0)) + 1
	for flag: Variant in def.get("set_flags", []):
		flags[String(flag)] = true
	if not def.has("branches"):
		for next_id: Variant in def.get("next", []):
			if not unlocked.has(String(next_id)) and not done.has(String(next_id)):
				unlocked.append(String(next_id))
	changed.emit(instance)
	return {"ok": true, "reason": ""}


# --- Eventos ----------------------------------------------------------------------


## Alimenta las misiones activas y los eventos secretos con un evento del juego. Devuelve los ids de instancias que
## acaban de completarse. `floor_info` (opcional) sirve para iniciar misiones secretas en el piso actual.
func on_event(event: String, subject: String, amount: int = 1, floor_info: Dictionary = {}) -> Array:
	var key := "%s|%s" % [event, subject]
	counters[key] = int(counters.get(key, 0)) + amount
	if event == "floor_entered":
		floor_state = {"potion_used": false, "damage_taken": false, "floor": int(subject)}
	elif event == "potion_used":
		floor_state["potion_used"] = true
	elif event == "player_damaged":
		floor_state["damage_taken"] = true
	var finished: Array = []
	for instance: Dictionary in active():
		var changed_any := false
		for objective: Dictionary in instance["objectives"]:
			if ObjectiveTracker.apply(objective, event, subject, amount, floor_state):
				changed_any = true
		if changed_any:
			changed.emit(instance)
			if _check_complete(instance):
				finished.append(instance["id"])
	var state := {"counters": counters, "done": secrets_done, "progress": secret_progress, "flags": flags, "floor": int(floor_state.get("floor", 1)), "items": []}
	for secret: Dictionary in SecretEvents.process(event, subject, state):
		_apply_secret(secret["effect"], floor_info)
	return finished


func _apply_secret(effect: Dictionary, floor_info: Dictionary) -> void:
	if effect.has("flag"):
		flags[String(effect["flag"])] = true
	if effect.has("message"):
		notice.emit(String(effect["message"]))
	if effect.has("start_quest") and not floor_info.is_empty():
		start_quest(String(effect["start_quest"]), floor_info)


## Completa la instancia si todos sus objetivos obligatorios estan cumplidos.
func _check_complete(instance: Dictionary) -> bool:
	if String(instance["state"]) != "active":
		return false
	for objective: Dictionary in instance["objectives"]:
		if not bool(objective["optional"]) and int(objective["progress"]) < int(objective["required"]):
			return false
	instance["state"] = "completed"
	instance["completed_at"] = counters.size()
	changed.emit(instance)
	notice.emit("Mision completada: %s" % String(instance["title"]))
	return true


# --- Guardado (versionado) ----------------------------------------------------------


func to_dict() -> Dictionary:
	return {"version": VERSION, "instances": instances.duplicate(true), "offers": offers.duplicate(true), "history": history.duplicate(), "done": done.duplicate(),
		"unlocked": unlocked.duplicate(), "counter": counter, "counters": counters.duplicate(), "secrets_done": secrets_done.duplicate(),
		"secret_progress": secret_progress.duplicate(), "choices": choices.duplicate()}


## Restaura el estado guardado descartando lo que ya no existe (definiciones borradas, datos corruptos).
static func from_dict(data: Dictionary, p_flags: Dictionary, p_seed: int) -> QuestManager:
	var manager := QuestManager.new(p_flags, p_seed)
	if int(data.get("version", 0)) != VERSION:
		return manager
	for id: Variant in (data.get("instances", {}) as Dictionary):
		var instance: Variant = (data["instances"] as Dictionary)[id]
		if instance is Dictionary and QuestLibrary.has_definition(String((instance as Dictionary).get("def", ""))) and (instance as Dictionary).has("objectives") and (instance as Dictionary).has("rewards"):
			manager.instances[String(id)] = (instance as Dictionary).duplicate(true)
	for floor_key: Variant in (data.get("offers", {}) as Dictionary):
		var ids: Array = []
		for id: Variant in data["offers"][floor_key]:
			if manager.instances.has(String(id)):
				ids.append(String(id))
		manager.offers[int(str(floor_key))] = ids
	manager.history = (data.get("history", []) as Array).duplicate()
	manager.done = (data.get("done", {}) as Dictionary).duplicate()
	manager.unlocked = (data.get("unlocked", manager.unlocked) as Array).filter(func(id: Variant) -> bool: return QuestLibrary.has_definition(String(id)))
	manager.counter = int(data.get("counter", 0))
	manager.counters = (data.get("counters", {}) as Dictionary).duplicate()
	manager.secrets_done = (data.get("secrets_done", {}) as Dictionary).duplicate()
	manager.secret_progress = (data.get("secret_progress", {}) as Dictionary).duplicate()
	manager.choices = (data.get("choices", {}) as Dictionary).duplicate()
	return manager
