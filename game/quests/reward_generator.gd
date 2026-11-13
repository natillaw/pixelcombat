## RewardGenerator — genera el paquete de recompensa de una mision a partir de una tabla de data/quests/reward_tables.json.
##
## Es PURO: no toca el inventario ni el progreso del jugador (de eso se encarga RewardManager). Con la misma
## semilla y el mismo contexto sale siempre el mismo paquete, y el paquete se guarda en la instancia de la mision
## para que recargar la partida o volver a abrir el tablon no permita rehacer las recompensas.
##
## Paquete: {table, seed, gold, xp, items: [item], consumables: {id: n}, materials: {id: n}, tomes, flags: [], unlocks: []}
class_name RewardGenerator
extends RefCounted

const ENTRY_TYPES := ["gold", "xp", "item", "consumable", "material", "skill_tome", "flag", "unlock"]


## `context`: {floor, tier, rarity (de la mision), class_id}.
static func generate(context: Dictionary, table_id: String, seed_value: int) -> Dictionary:
	var package := {"table": table_id, "seed": seed_value, "gold": 0, "xp": 0, "items": [], "consumables": {}, "materials": {}, "tomes": 0, "flags": [], "unlocks": []}
	var table := QuestLibrary.table(table_id)
	if table.is_empty():
		return package
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for entry: Dictionary in table.get("guaranteed", []):
		_apply(package, entry, context, rng)
	for slot: Variant in table.get("slots", []):
		var choices: Array = slot
		var total := 0.0
		for choice: Dictionary in choices:
			total += float(choice["weight"])
		var roll := rng.randf() * total
		for choice: Dictionary in choices:
			roll -= float(choice["weight"])
			if roll <= 0.0:
				_apply(package, choice["entry"], context, rng)
				break
	return package


static func _scale(entry: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> int:
	var base := rng.randi_range(int(entry.get("min", 1)), int(entry.get("max", entry.get("min", 1))))
	var floor_mult := 1.0 + float(entry.get("scale_floor", 0.0)) * float(maxi(int(context.get("floor", 1)) - 1, 0))
	return maxi(1, int(round(float(base) * floor_mult * QuestLibrary.rarity_mult(String(context.get("rarity", "common"))))))


static func _apply(package: Dictionary, entry: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> void:
	var tier := maxi(int(context.get("tier", 1)), 1)
	match String(entry["type"]):
		"gold":
			package["gold"] = int(package["gold"]) + _scale(entry, context, rng)
		"xp":
			package["xp"] = int(package["xp"]) + _scale(entry, context, rng)
		"item":
			var rarity := String(entry.get("rarity", "common"))
			var item: Dictionary
			if entry.has("id"):
				item = ItemGen.roll_item(rng, tier, rarity, "", "", String(entry["id"]))
			else:
				var slots := ItemCatalog.slots()
				var slot := String(slots[rng.randi_range(0, slots.size() - 1)]) if String(entry.get("slot", "any")) == "any" else String(entry["slot"])
				item = ItemGen.roll_item(rng, tier, rarity, slot, String(context.get("class_id", "")))
			(package["items"] as Array).append(item)
		"consumable":
			var id := String(entry["id"])
			(package["consumables"] as Dictionary)[id] = int((package["consumables"] as Dictionary).get(id, 0)) + _scale(entry, context, rng)
		"material":
			var material_id := MaterialCatalog.material_id(String(entry["kind"]), tier)
			(package["materials"] as Dictionary)[material_id] = int((package["materials"] as Dictionary).get(material_id, 0)) + _scale(entry, context, rng)
		"skill_tome":
			package["tomes"] = int(package["tomes"]) + int(entry.get("min", 1))
		"flag":
			(package["flags"] as Array).append(String(entry["flag"]))
		"unlock":
			(package["unlocks"] as Array).append(String(entry["id"]))


## Problemas de una tabla: tipos validos, ids de item/consumible/material que existen, pesos y rangos.
static func validate_table(table_id: String, table: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var entries: Array = (table.get("guaranteed", []) as Array).duplicate()
	for slot: Variant in table.get("slots", []):
		if not (slot is Array) or (slot as Array).is_empty():
			problems.append("tabla %s: un slot vacio" % table_id)
			continue
		for choice: Variant in slot:
			if not (choice is Dictionary) or float((choice as Dictionary).get("weight", 0.0)) <= 0.0 or not ((choice as Dictionary).get("entry") is Dictionary):
				problems.append("tabla %s: una opcion sin peso o sin entrada" % table_id)
			else:
				entries.append((choice as Dictionary)["entry"])
	if entries.is_empty():
		problems.append("tabla %s: vacia" % table_id)
	for entry: Variant in entries:
		if not (entry is Dictionary) or not ENTRY_TYPES.has(String((entry as Dictionary).get("type", ""))):
			problems.append("tabla %s: tipo de entrada invalido" % table_id)
			continue
		var spec: Dictionary = entry
		if spec.has("min") and spec.has("max") and int(spec["min"]) > int(spec["max"]):
			problems.append("tabla %s: min > max" % table_id)
		match String(spec["type"]):
			"item":
				if spec.has("id") and not ItemCatalog.has_item(String(spec["id"])):
					problems.append("tabla %s: el item '%s' no existe (no se generan items inventados)" % [table_id, spec["id"]])
				if spec.has("rarity") and not ItemCatalog.rarity_ids().has(String(spec["rarity"])):
					problems.append("tabla %s: rareza invalida" % table_id)
			"consumable":
				if not ConsumableCatalog.has(String(spec.get("id", ""))):
					problems.append("tabla %s: el consumible '%s' no existe" % [table_id, spec.get("id", "")])
			"material":
				if not MaterialCatalog.kind_ids().has(String(spec.get("kind", ""))):
					problems.append("tabla %s: material desconocido" % table_id)
	return problems


## Problemas de un paquete generado (items validos, cantidades no negativas).
static func validate(package: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if int(package.get("gold", 0)) < 0 or int(package.get("xp", 0)) < 0:
		problems.append("cantidades negativas")
	for item: Variant in package.get("items", []):
		if not ItemCatalog.is_valid_item(item):
			problems.append("item invalido en el paquete")
	for id: Variant in package.get("consumables", {}):
		if not ConsumableCatalog.has(String(id)) or int(package["consumables"][id]) < 1:
			problems.append("consumible invalido")
	for id: Variant in package.get("materials", {}):
		if not MaterialCatalog.is_valid(String(id)) or int(package["materials"][id]) < 1:
			problems.append("material invalido")
	return problems
