## QuestGenerator — crea QuestInstance (misiones concretas) a partir de definiciones (plantillas).
##
## Pipeline de generate_offers: info del piso -> definiciones compatibles (rango, bioma, enemigos y objetos del piso,
## prerrequisitos y banderas) -> proteccion de repeticion (plantillas y categorias recientes) -> pesos de rareza ->
## parametros de los objetivos (cantidades) -> recompensa (RewardGenerator con semilla guardada) -> validacion ->
## instancias. Todo con semillas deterministas (SeedManager): el mismo piso, partida y contador dan las mismas ofertas.
class_name QuestGenerator
extends RefCounted

const MAX_KILL := 20
const MAX_COLLECT := 15
const MAX_SURVIVE := 120


## Las ofertas del tablon de un piso (hasta `count`), como instancias sin id (el gestor se lo pone).
static func generate_offers(floor_info: Dictionary, run_seed: int, serial: int, flags: Dictionary, done: Dictionary, history: Array, class_id: String = "", count: int = 3) -> Array:
	var rng := SeedManager.rng([run_seed, "offers", int(floor_info["floor"]), serial])
	var pool: Array = []
	for def: Dictionary in QuestLibrary.find("side"):
		if QuestLibrary.compatible(def, floor_info, flags, done) and (not done.has(String(def["id"])) or bool(def.get("repeatable", false))):
			pool.append(def)
	var rules := QuestLibrary.repetition()
	var recent_templates: Array = history.slice(maxi(history.size() - int(rules.get("recent_templates", 4)), 0))
	var recent_categories: Array = []
	for id: Variant in history.slice(maxi(history.size() - int(rules.get("recent_categories", 2)), 0)):
		recent_categories.append(String(QuestLibrary.definition(String(id)).get("category", "")))
	var fresh := pool.filter(func(def: Dictionary) -> bool: return not recent_templates.has(String(def["id"])) and not recent_categories.has(String(def["category"])))
	# La proteccion de repeticion no deja el tablon vacio: si no quedan suficientes, se relaja.
	if fresh.size() < count:
		fresh = pool.filter(func(def: Dictionary) -> bool: return not recent_templates.has(String(def["id"])))
	if fresh.size() < count:
		fresh = pool
	var offers: Array = []
	var used_categories: Array = []
	var candidates := fresh.duplicate()
	while offers.size() < count and not candidates.is_empty():
		var preferred := candidates.filter(func(def: Dictionary) -> bool: return not used_categories.has(String(def["category"])))
		var from: Array = preferred if not preferred.is_empty() else candidates
		var chosen := _weighted(from, rng)
		candidates.erase(chosen)
		var instance := instantiate(chosen, floor_info, SeedManager.seed_for([run_seed, "quest", chosen["id"], int(floor_info["floor"]), serial]), class_id)
		if validate(instance, floor_info).is_empty():
			offers.append(instance)
			used_categories.append(String(chosen["category"]))
	return offers


static func _weighted(defs: Array, rng: RandomNumberGenerator) -> Dictionary:
	var weights := QuestLibrary.rarity_weights()
	var total := 0.0
	for def: Dictionary in defs:
		total += float(weights.get(String(def["rarity"]), 1.0))
	var roll := rng.randf() * total
	for def: Dictionary in defs:
		roll -= float(weights.get(String(def["rarity"]), 1.0))
		if roll <= 0.0:
			return def
	return defs[defs.size() - 1]


## Una instancia de `def` para el piso: cantidades concretas, texto resuelto y recompensa ya generada y guardada.
static func instantiate(def: Dictionary, floor_info: Dictionary, seed_value: int, class_id: String = "") -> Dictionary:
	var rng := SeedManager.rng([seed_value, "params"])
	var objectives: Array = []
	var shown := 0
	for spec: Dictionary in def["objectives"]:
		var count: Variant = spec.get("count", 1)
		var required := rng.randi_range(int((count as Array)[0]), int((count as Array)[1])) if count is Array else int(count)
		objectives.append({"id": String(spec["id"]), "kind": String(spec["kind"]), "target": String(spec["target"]), "required": required, "progress": 0, "optional": bool(spec.get("optional", false))})
		if shown == 0 and not bool(spec.get("optional", false)):
			shown = required
	var tier := TowerCatalog.tier_of_floor(int(floor_info["floor"]))
	var package := RewardGenerator.generate({"floor": int(floor_info["floor"]), "tier": tier, "rarity": String(def["rarity"]), "class_id": class_id}, String(def["rewards"]), SeedManager.seed_for([seed_value, "reward"]))
	return {
		"id": "", "def": String(def["id"]), "type": String(def["type"]), "category": String(def["category"]), "rarity": String(def["rarity"]),
		"title": String(def["title"]), "desc": String(def["desc"]).replace("{count}", str(shown)), "floor": int(floor_info["floor"]),
		"seed": seed_value, "state": "available", "objectives": objectives, "rewards": package, "reward_claimed": false,
		"accepted_at": -1, "completed_at": -1,
	}


## Problemas de una instancia generada (lista vacia = se puede completar): cantidades razonables y objetos del piso.
static func validate(instance: Dictionary, floor_info: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var objects: Dictionary = floor_info.get("objects", {})
	var mandatory := 0
	for objective: Dictionary in instance["objectives"]:
		var required := int(objective["required"])
		if required < 1:
			problems.append("cantidad invalida")
		if not bool(objective["optional"]):
			mandatory += 1
		match String(objective["kind"]):
			"kill":
				if required > MAX_KILL:
					problems.append("demasiados enemigos")
				var matching := 0
				for id: Variant in floor_info.get("enemy_ids", []):
					if QuestLibrary.target_matches_enemy(String(objective["target"]), String(id)):
						matching += 1
				if matching == 0:
					problems.append("el piso no tiene enemigos compatibles")
			"collect":
				if required > MAX_COLLECT:
					problems.append("demasiados materiales")
			"survive":
				if required > MAX_SURVIVE or int(objects.get("beacon", 0)) < 1:
					problems.append("resistencia imposible")
			"interact", "discover":
				if int(objects.get(String(objective["target"]), 0)) < required:
					problems.append("el piso no tiene objetos suficientes (%s)" % objective["target"])
	if mandatory == 0:
		problems.append("sin objetivos obligatorios")
	problems.append_array(RewardGenerator.validate(instance["rewards"]))
	return problems
