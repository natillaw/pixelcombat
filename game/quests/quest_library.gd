## QuestLibrary — la biblioteca de definiciones de misiones (plantillas), tablas de recompensa y eventos secretos,
## cargada de data/quests/*.json. Valida el esquema, busca por tipo, categoria, etiqueta, rareza y compatibilidad con un
## piso. Una definicion es una plantilla: la mision que lleva el jugador es una QuestInstance (ver QuestGenerator).
class_name QuestLibrary
extends RefCounted

const DIR := "res://data/quests/"
const TYPES := ["main", "side", "secret", "chain"]
const CATEGORIES := ["combat", "exploration", "survival", "collection", "challenge", "investigation", "rescue", "social", "bounty"]
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const OBJECTIVE_KINDS := ["kill", "collect", "interact", "discover", "reach", "survive", "protect", "deliver", "complete", "condition"]

static var _data: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {"definitions": {}, "rarity_weights": {}, "repetition": {}, "tables": {}, "rarity_mult": {}, "secrets": []}
	var defs: Variant = _read("definitions.json")
	if defs is Dictionary:
		_data["rarity_weights"] = (defs as Dictionary).get("rarity_weights", {})
		_data["repetition"] = (defs as Dictionary).get("repetition", {})
		for entry: Variant in (defs as Dictionary).get("definitions", []):
			if not (entry is Dictionary):
				_errors.append("una definicion no es un objeto")
				continue
			var id := String((entry as Dictionary).get("id", ""))
			if id.is_empty() or (_data["definitions"] as Dictionary).has(id):
				_errors.append("definicion sin id o duplicada: '%s'" % id)
				continue
			(_data["definitions"] as Dictionary)[id] = entry
	var tables: Variant = _read("reward_tables.json")
	if tables is Dictionary:
		_data["tables"] = (tables as Dictionary).get("tables", {})
		_data["rarity_mult"] = (tables as Dictionary).get("rarity_mult", {})
	var secrets: Variant = _read("secret_events.json")
	if secrets is Dictionary:
		_data["secrets"] = (secrets as Dictionary).get("events", [])
	_errors.append_array(validate_all())


static func _read(file: String) -> Variant:
	var path := DIR + file
	if not FileAccess.file_exists(path):
		_errors.append("falta %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_errors.append("%s: JSON invalido" % path)
	return parsed


static func errors() -> Array[String]:
	_ensure()
	return _errors.duplicate()


static func definition(id: String) -> Dictionary:
	_ensure()
	return ((_data["definitions"] as Dictionary).get(id, {}) as Dictionary).duplicate(true)


static func has_definition(id: String) -> bool:
	_ensure()
	return (_data["definitions"] as Dictionary).has(id)


static func definition_ids() -> Array:
	_ensure()
	return (_data["definitions"] as Dictionary).keys()


static func table(id: String) -> Dictionary:
	_ensure()
	return ((_data["tables"] as Dictionary).get(id, {}) as Dictionary).duplicate(true)


static func table_ids() -> Array:
	_ensure()
	return (_data["tables"] as Dictionary).keys()


static func rarity_mult(rarity: String) -> float:
	_ensure()
	return float((_data["rarity_mult"] as Dictionary).get(rarity, 1.0))


static func rarity_weights() -> Dictionary:
	_ensure()
	return (_data["rarity_weights"] as Dictionary).duplicate()


static func repetition() -> Dictionary:
	_ensure()
	return (_data["repetition"] as Dictionary).duplicate()


static func secrets() -> Array:
	_ensure()
	return (_data["secrets"] as Array).duplicate(true)


## Definiciones de un tipo (y opcionalmente categoria o etiqueta).
static func find(type: String = "", category: String = "", tag: String = "") -> Array:
	_ensure()
	var out: Array = []
	for id: String in definition_ids():
		var def := definition(id)
		if type != "" and String(def["type"]) != type:
			continue
		if category != "" and String(def["category"]) != category:
			continue
		if tag != "" and not (def.get("tags", []) as Array).has(tag):
			continue
		out.append(def)
	return out


## Compatibilidad de una definicion con un piso: rango de pisos, bioma, enemigos (si pide matar), prerrequisitos.
## `floor_info`: {floor, biome, enemy_ids: [...], objects: {altar: n, ...}}; `flags` banderas del mundo; `done` ids reclamados.
static func compatible(def: Dictionary, floor_info: Dictionary, flags: Dictionary, done: Dictionary) -> bool:
	var floor_number := int(floor_info["floor"])
	if floor_number < int(def.get("floor_min", 1)) or floor_number > int(def.get("floor_max", 100)):
		return false
	var biomes: Array = def.get("biomes", [])
	if not biomes.is_empty() and not biomes.has(String(floor_info.get("biome", "forest"))):
		return false
	var prerequisites: Dictionary = def.get("prerequisites", {})
	for flag: Variant in prerequisites.get("flags", []):
		if not bool(flags.get(String(flag), false)):
			return false
	for quest_id: Variant in prerequisites.get("quests_done", []):
		if not done.has(String(quest_id)):
			return false
	for objective: Dictionary in def.get("objectives", []):
		if not objective_possible(objective, floor_info):
			return false
	return true


## Un objetivo es posible en el piso si el piso tiene lo que pide (enemigos compatibles u objetos).
static func objective_possible(objective: Dictionary, floor_info: Dictionary) -> bool:
	var target := String(objective.get("target", ""))
	var count := _max_count(objective)
	match String(objective["kind"]):
		"kill":
			var matching := 0
			for id: Variant in floor_info.get("enemy_ids", []):
				if target_matches_enemy(target, String(id)):
					matching += 1
			return matching > 0
		"interact", "discover":
			var objects: Dictionary = floor_info.get("objects", {})
			return int(objects.get(target, 0)) >= count
		"survive":
			return int((floor_info.get("objects", {}) as Dictionary).get("beacon", 0)) >= 1
		_:
			return true


static func target_matches_enemy(target: String, enemy_id: String) -> bool:
	if target.ends_with("*"):
		return enemy_id.begins_with(target.trim_suffix("*"))
	if target == "beast":
		return Bounties.BEAST_IDS.has(enemy_id)
	return target == enemy_id


static func _max_count(objective: Dictionary) -> int:
	var count: Variant = objective.get("count", 1)
	return int((count as Array)[0]) if count is Array else int(count)


## Problemas del esquema de todos los archivos (lista vacia = bien).
static func validate_all() -> Array[String]:
	var problems: Array[String] = []
	var defs: Dictionary = _data["definitions"]
	for id: String in defs:
		var def: Dictionary = defs[id]
		for field: String in ["title", "desc", "type", "category", "rarity"]:
			if String(def.get(field, "")).is_empty():
				problems.append("%s: falta '%s'" % [id, field])
		if not TYPES.has(String(def.get("type", ""))):
			problems.append("%s: tipo invalido" % id)
		if not CATEGORIES.has(String(def.get("category", ""))):
			problems.append("%s: categoria invalida" % id)
		if not RARITIES.has(String(def.get("rarity", ""))):
			problems.append("%s: rareza invalida" % id)
		if int(def.get("floor_min", 1)) > int(def.get("floor_max", 100)):
			problems.append("%s: floor_min > floor_max" % id)
		var objectives: Variant = def.get("objectives")
		if not (objectives is Array) or (objectives as Array).is_empty():
			problems.append("%s: necesita objetivos" % id)
		else:
			var seen := {}
			var mandatory := 0
			for objective: Variant in objectives:
				if not (objective is Dictionary) or not OBJECTIVE_KINDS.has(String((objective as Dictionary).get("kind", ""))):
					problems.append("%s: objetivo invalido" % id)
					continue
				var oid := String((objective as Dictionary).get("id", ""))
				if oid.is_empty() or seen.has(oid):
					problems.append("%s: objetivo sin id o repetido '%s'" % [id, oid])
				seen[oid] = true
				if not bool((objective as Dictionary).get("optional", false)):
					mandatory += 1
				var count: Variant = (objective as Dictionary).get("count", 1)
				if (count is Array and ((count as Array).size() != 2 or int((count as Array)[0]) > int((count as Array)[1]) or int((count as Array)[0]) < 1)) or (not (count is Array) and int(count) < 1):
					problems.append("%s: cantidad invalida en '%s'" % [id, oid])
			if mandatory == 0:
				problems.append("%s: necesita al menos un objetivo obligatorio" % id)
		if not (_data["tables"] as Dictionary).has(String(def.get("rewards", ""))):
			problems.append("%s: tabla de recompensa desconocida '%s'" % [id, def.get("rewards", "")])
		for next_id: Variant in def.get("next", []):
			if not defs.has(String(next_id)):
				problems.append("%s: next apunta a una definicion que no existe '%s'" % [id, next_id])
		for branch: Variant in def.get("branches", []):
			for next_id: Variant in (branch as Dictionary).get("next", []):
				if not defs.has(String(next_id)):
					problems.append("%s: rama con next desconocido '%s'" % [id, next_id])
		for quest_id: Variant in (def.get("prerequisites", {}) as Dictionary).get("quests_done", []):
			if not defs.has(String(quest_id)):
				problems.append("%s: prerrequisito desconocido '%s'" % [id, quest_id])
	for table_id: String in (_data["tables"] as Dictionary):
		problems.append_array(RewardGenerator.validate_table(table_id, (_data["tables"] as Dictionary)[table_id]))
	var secret_ids := {}
	for secret: Dictionary in _data["secrets"]:
		var sid := String(secret.get("id", ""))
		if sid.is_empty() or secret_ids.has(sid):
			problems.append("secreto sin id o repetido '%s'" % sid)
		secret_ids[sid] = true
		var effect: Dictionary = secret.get("effect", {})
		if effect.has("start_quest") and not defs.has(String(effect["start_quest"])):
			problems.append("secreto %s: inicia una mision que no existe" % sid)
		if effect.has("reward") and not (_data["tables"] as Dictionary).has(String(effect["reward"])):
			problems.append("secreto %s: tabla de recompensa desconocida" % sid)
		if (secret.get("conditions", {}) as Dictionary).is_empty():
			problems.append("secreto %s: sin condiciones" % sid)
	# Los ciclos de cadena (a -> b -> a) no se permiten.
	for id: String in defs:
		var path: Array = [id]
		if _chain_loops(defs, id, path):
			problems.append("%s: la cadena de next forma un ciclo" % id)
	return problems


static func _chain_loops(defs: Dictionary, id: String, path: Array) -> bool:
	for next_id: Variant in (defs[id] as Dictionary).get("next", []):
		if path.has(String(next_id)):
			return true
		if defs.has(String(next_id)):
			var longer := path.duplicate()
			longer.append(String(next_id))
			if _chain_loops(defs, String(next_id), longer):
				return true
	return false
