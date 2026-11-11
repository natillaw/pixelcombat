## RecipeCatalog — estaciones de crafting y recetas, desde `data/recipes.json`.
##
## Esquema:
##   stations: [{id, name}] (los edificios de la ciudad; una sin recetas aun no abre)
##   gold_per_tier_scale: si el oro de cada receta crece con el tier como los items
##   recipes: [{id, station, item, cost: {tipo_de_material: unidades}, gold,
##              quality_bonus}]; `item` es un item base de data/items.json y el
##              tier del resultado lo elige el jugador (hasta el que tenga abierto en
##              la torre); `quality_bonus` empuja la rareza como en el botin
class_name RecipeCatalog
extends RefCounted

const PATH := "res://data/recipes.json"

static var _data: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func station_ids() -> Array:
	_ensure_loaded()
	return (_data.get("stations", []) as Array).map(func(s: Dictionary) -> String: return String(s["id"]))


static func station_name(id: String) -> String:
	_ensure_loaded()
	for entry: Variant in _data.get("stations", []):
		if String((entry as Dictionary)["id"]) == id:
			return String((entry as Dictionary)["name"])
	return id


static func recipes_for(station: String) -> Array:
	_ensure_loaded()
	var out: Array = []
	for entry: Variant in _data.get("recipes", []):
		if String((entry as Dictionary)["station"]) == station:
			out.append((entry as Dictionary).duplicate(true))
	return out


static func recipe(id: String) -> Dictionary:
	_ensure_loaded()
	for entry: Variant in _data.get("recipes", []):
		if String((entry as Dictionary)["id"]) == id:
			return (entry as Dictionary).duplicate(true)
	return {}


static func recipes() -> Array:
	_ensure_loaded()
	return (_data.get("recipes", []) as Array).duplicate(true)


## Coste concreto de una receta en un tier: {material_id: unidades}.
static func cost_at(recipe_data: Dictionary, tier: int) -> Dictionary:
	var out: Dictionary = {}
	for kind_id: String in recipe_data["cost"]:
		out[MaterialCatalog.material_id(kind_id, tier)] = int(recipe_data["cost"][kind_id])
	return out


static func gold_at(recipe_data: Dictionary, tier: int) -> int:
	_ensure_loaded()
	var base := float(recipe_data["gold"])
	if bool(_data.get("gold_per_tier_scale", true)):
		base *= ItemCatalog.tier_multiplier(tier)
	return int(round(base))


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
	var stations: Array = []
	for entry: Variant in data.get("stations", []):
		if entry is Dictionary and not String((entry as Dictionary).get("id", "")).is_empty() and not String((entry as Dictionary).get("name", "")).is_empty():
			stations.append(String((entry as Dictionary)["id"]))
		else:
			problems.append("una estacion necesita id y name")
	if stations.is_empty():
		problems.append("falta la lista 'stations'")
	var seen: Array = []
	for entry: Variant in data.get("recipes", []):
		if not (entry is Dictionary):
			problems.append("una receta no es un objeto")
			continue
		var spec: Dictionary = entry
		var id := String(spec.get("id", ""))
		if id.is_empty() or seen.has(id):
			problems.append("receta sin id o duplicada: '%s'" % id)
		seen.append(id)
		if not stations.has(String(spec.get("station", ""))):
			problems.append("%s: estacion desconocida" % id)
		if not ItemCatalog.has_item(String(spec.get("item", ""))):
			problems.append("%s: item desconocido '%s'" % [id, str(spec.get("item", ""))])
		var cost: Variant = spec.get("cost")
		if not (cost is Dictionary) or (cost as Dictionary).is_empty():
			problems.append("%s: falta cost" % id)
		else:
			for kind_id: Variant in cost:
				if not MaterialCatalog.kind_ids().has(String(kind_id)) or not _is_number((cost as Dictionary)[kind_id]) or int((cost as Dictionary)[kind_id]) < 1:
					problems.append("%s: coste invalido '%s'" % [id, str(kind_id)])
		if not _is_number(spec.get("gold")) or float(spec["gold"]) < 0.0:
			problems.append("%s: gold debe ser >= 0" % id)
		if not _is_number(spec.get("quality_bonus")) or float(spec["quality_bonus"]) < 0.0:
			problems.append("%s: quality_bonus debe ser >= 0" % id)
	if (data.get("recipes", []) as Array).is_empty():
		problems.append("falta la lista 'recipes'")
	return problems


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
