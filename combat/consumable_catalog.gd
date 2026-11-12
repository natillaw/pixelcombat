## ConsumableCatalog — pociones y comida, desde `data/consumables.json`.
##
## Esquema de cada consumible: id, name, kind ("potion" | "food"), description, price (oro en la
## taberna/mercader, 0 = no se vende), value (oro al venderlo), effect y cook (receta de la
## taberna: {cost: {tipo de material: n}, gold}).
##   effect de pocion: heal_pct (fraccion de la vida maxima) y/o resource_pct (del recurso)
##   effect de comida: {status, duration, strength} (fed, might o haste; ver data/statuses.json)
##   quick (opcional): "health" | "resource" -> la tecla rapida de ese tipo la usa
class_name ConsumableCatalog
extends RefCounted

const PATH := "res://data/consumables.json"
const KINDS := ["potion", "food"]
const FOOD_STATUSES := ["fed", "might", "haste"]

static var _data: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func potion_cooldown() -> float:
	_ensure_loaded()
	return float(_data.get("potion_cooldown", 14.0))


static func max_stack() -> int:
	_ensure_loaded()
	return int(_data.get("max_stack", 20))


static func ids() -> Array:
	_ensure_loaded()
	return (_data.get("consumables", []) as Array).map(func(c: Dictionary) -> String: return String(c["id"]))


static func has(id: String) -> bool:
	return not item(id).is_empty()


static func item(id: String) -> Dictionary:
	_ensure_loaded()
	for entry: Variant in _data.get("consumables", []):
		if String((entry as Dictionary)["id"]) == id:
			return (entry as Dictionary).duplicate(true)
	return {}


## Consumibles de la tecla rapida `quick` ("health" o "resource"), de mejor a peor (el mejor primero).
static func quick_ids(quick: String) -> Array:
	_ensure_loaded()
	var found: Array = []
	for entry: Variant in _data.get("consumables", []):
		if String((entry as Dictionary).get("quick", "")) == quick:
			found.append(String((entry as Dictionary)["id"]))
	found.reverse()
	return found


static func sold_ids() -> Array:
	return ids().filter(func(id: String) -> bool: return int(item(id)["price"]) > 0)


static func cookable_ids() -> Array:
	return ids().filter(func(id: String) -> bool: return item(id).has("cook"))


## Materiales concretos (tier elegido) de la receta de cocina: {"herb_t1": 3}.
static func cook_cost(id: String, tier: int) -> Dictionary:
	var out: Dictionary = {}
	var cook: Dictionary = item(id).get("cook", {})
	for kind_id: String in cook.get("cost", {}):
		out[MaterialCatalog.material_id(kind_id, tier)] = int(cook["cost"][kind_id])
	return out


static func validate(entry: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for field: String in ["id", "name", "description"]:
		if not (entry.get(field) is String) or String(entry[field]).is_empty():
			problems.append("falta el texto '%s'" % field)
	if not KINDS.has(entry.get("kind")):
		problems.append("kind debe ser potion o food")
	for field: String in ["price", "value"]:
		if not _is_number(entry.get(field)) or float(entry[field]) < 0.0:
			problems.append("%s debe ser >= 0" % field)
	var effect: Variant = entry.get("effect")
	if not (effect is Dictionary) or (effect as Dictionary).is_empty():
		problems.append("falta 'effect'")
	elif entry.get("kind") == "food":
		var spec: Dictionary = effect
		if not FOOD_STATUSES.has(String(spec.get("status", ""))) or not StatusCatalog.has_status(String(spec.get("status", ""))):
			problems.append("la comida necesita un status valido (fed, might o haste)")
		if not _is_number(spec.get("duration")) or float(spec["duration"]) <= 0.0 or not _is_number(spec.get("strength")) or float(spec["strength"]) <= 0.0:
			problems.append("la comida necesita duration y strength > 0")
	elif entry.get("kind") == "potion":
		var spec: Dictionary = effect
		if not spec.has("heal_pct") and not spec.has("resource_pct"):
			problems.append("la pocion necesita heal_pct o resource_pct")
	if entry.has("cook"):
		var cook: Variant = entry["cook"]
		if not (cook is Dictionary) or not ((cook as Dictionary).get("cost") is Dictionary) or ((cook as Dictionary)["cost"] as Dictionary).is_empty() or not _is_number((cook as Dictionary).get("gold")):
			problems.append("cook necesita cost y gold")
		else:
			for kind_id: String in (cook as Dictionary)["cost"]:
				if not MaterialCatalog.kind_ids().has(kind_id):
					problems.append("cook usa un material desconocido '%s'" % kind_id)
	return problems


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("consumables") is Array):
		_errors.append("%s: JSON invalido" % PATH)
		return
	_data = parsed
	var seen := {}
	for raw: Variant in _data["consumables"]:
		if not (raw is Dictionary):
			_errors.append("entrada que no es un objeto")
			continue
		for problem: String in validate(raw):
			_errors.append("[%s]: %s" % [str((raw as Dictionary).get("id", "?")), problem])
		if seen.has((raw as Dictionary).get("id")):
			_errors.append("id duplicado '%s'" % str((raw as Dictionary).get("id")))
		seen[(raw as Dictionary).get("id")] = true


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
