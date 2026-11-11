## MaterialCatalog — materiales de recoleccion y botin, desde `data/materials.json`.
##
## Esquema:
##   kinds: [{id, name, source, names: [un nombre por tier], gather_seconds?}]
##          `source`: "mine", "herbalism" o "woodcutting" (nodos del mundo) o "monster"
##          (botin de enemigos). `gather_seconds` es lo que cuesta recolectar un nodo.
##   gather_yield: {min, max, bonus_chance} unidades por nodo
## Un material concreto se identifica como "<tipo>_t<tier>" (ore_t1, hide_t3...).
class_name MaterialCatalog
extends RefCounted

const PATH := "res://data/materials.json"

static var _data: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func kind_ids() -> Array:
	_ensure_loaded()
	return (_data.get("kinds", []) as Array).map(func(k: Dictionary) -> String: return String(k["id"]))


static func kind(id: String) -> Dictionary:
	_ensure_loaded()
	for entry: Variant in _data.get("kinds", []):
		if String((entry as Dictionary)["id"]) == id:
			return (entry as Dictionary).duplicate(true)
	return {}


## Tipos que se recolectan en nodos del mundo (no los de botin).
static func gatherable_kinds() -> Array:
	_ensure_loaded()
	var out: Array = []
	for entry: Variant in _data.get("kinds", []):
		if String((entry as Dictionary)["source"]) != "monster":
			out.append(String((entry as Dictionary)["id"]))
	return out


static func gather_yield() -> Dictionary:
	_ensure_loaded()
	return (_data.get("gather_yield", {}) as Dictionary).duplicate()


static func material_id(kind_id: String, tier: int) -> String:
	return "%s_t%d" % [kind_id, tier]


## {kind, tier} de un id de material, o {} si no es valido.
static func parse(id: String) -> Dictionary:
	var parts := id.split("_t")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return {}
	var spec := kind(parts[0])
	var tier := int(parts[1])
	if spec.is_empty() or tier < 1 or tier > (spec["names"] as Array).size():
		return {}
	return {"kind": parts[0], "tier": tier}


static func is_valid(id: String) -> bool:
	return not parse(id).is_empty()


static func display_name(id: String) -> String:
	var parsed := parse(id)
	if parsed.is_empty():
		return id
	return String(kind(String(parsed["kind"]))["names"][int(parsed["tier"]) - 1])


static func tier_count() -> int:
	_ensure_loaded()
	var count := 0
	for entry: Variant in _data.get("kinds", []):
		count = maxi(count, ((entry as Dictionary)["names"] as Array).size())
	return count


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {}
	_errors = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		_errors.append("%s: JSON invalido" % PATH)
		return
	var problems := validate(parsed)
	for problem: String in problems:
		_errors.append(problem)
	if problems.is_empty():
		_data = parsed


static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var kinds: Variant = data.get("kinds")
	if not (kinds is Array) or (kinds as Array).is_empty():
		problems.append("falta la lista 'kinds'")
		return problems
	var seen: Array = []
	var tiers := -1
	for entry: Variant in kinds:
		if not (entry is Dictionary):
			problems.append("un tipo de material no es un objeto")
			continue
		var spec: Dictionary = entry
		var id := String(spec.get("id", ""))
		if id.is_empty() or seen.has(id) or id.contains("_"):
			problems.append("tipo sin id, duplicado o con '_': '%s'" % id)
		seen.append(id)
		if not ["mine", "herbalism", "woodcutting", "monster"].has(String(spec.get("source", ""))):
			problems.append("%s: source desconocido" % id)
		if not (spec.get("names") is Array) or (spec["names"] as Array).is_empty():
			problems.append("%s: faltan names" % id)
		else:
			if tiers < 0:
				tiers = (spec["names"] as Array).size()
			elif tiers != (spec["names"] as Array).size():
				problems.append("%s: debe tener un nombre por tier (%d)" % [id, tiers])
		if String(spec.get("source", "")) != "monster" and (not _is_number(spec.get("gather_seconds")) or float(spec["gather_seconds"]) <= 0.0):
			problems.append("%s: gather_seconds debe ser > 0" % id)
	var yield_data: Variant = data.get("gather_yield")
	if not (yield_data is Dictionary) or not _is_number((yield_data as Dictionary).get("min")) or not _is_number((yield_data as Dictionary).get("max")) or int(yield_data["min"]) < 1 or int(yield_data["max"]) < int(yield_data["min"]) or not _is_number((yield_data as Dictionary).get("bonus_chance")):
		problems.append("gather_yield necesita min >= 1, max >= min y bonus_chance")
	return problems


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
