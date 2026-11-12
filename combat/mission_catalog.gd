## MissionCatalog — plantillas de mision de los pisos, desde `data/missions.json`.
##
## Esquema:
##   missions: [{id, kind, name, desc, weight, tier_min, xp_mult, count?: [min, max],
##               seconds?: [min, max], channel?}]
##     kinds: clear, hunt, slay, collect, activate, explore, rescue, destroy, survive, relic
##     `desc` admite {count}, {enemy}, {material}, {names}, {seconds}
##   optional: {chance, chance_first_floors, scale, xp_mult, chest_bonus, pool}
##   spike_mid: pisos x5 (mision doble con dos mini-jefes): time_limit_chance,
##     time_limit_seconds [min, max], optional_chance, primary_pool
##   spike_boss: pisos x10: variants (seals, gauntlet, elites), boss_boost [vida, dano],
##     seals [min, max], gauntlet_seconds [min, max], optional_chance
##   camps / nodes: densidad del contenido ambiental
class_name MissionCatalog
extends RefCounted

const PATH := "res://data/missions.json"
const KINDS := ["clear", "hunt", "slay", "collect", "activate", "explore", "rescue", "destroy", "survive", "relic"]
const BOSS_VARIANTS := ["seals", "gauntlet", "elites"]

static var _data: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func missions() -> Array:
	_ensure_loaded()
	return (_data.get("missions", []) as Array).duplicate(true)


static func mission(id: String) -> Dictionary:
	_ensure_loaded()
	for entry: Variant in _data.get("missions", []):
		if String((entry as Dictionary)["id"]) == id:
			return (entry as Dictionary).duplicate(true)
	return {}


static func config(key: String) -> Dictionary:
	_ensure_loaded()
	return (_data.get(key, {}) as Dictionary).duplicate(true)


## Plantillas elegibles en un tier, con su peso.
static func eligible(tier: int, pool: Array = []) -> Array:
	var out: Array = []
	for entry: Dictionary in missions():
		if int(entry["tier_min"]) > tier:
			continue
		if not pool.is_empty() and not pool.has(String(entry["id"])):
			continue
		out.append(entry)
	return out


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
	var ids: Array = []
	var list: Variant = data.get("missions")
	if not (list is Array) or (list as Array).is_empty():
		problems.append("falta la lista 'missions'")
		return problems
	for entry: Variant in list:
		if not (entry is Dictionary):
			problems.append("una mision no es un objeto")
			continue
		var spec: Dictionary = entry
		var id := String(spec.get("id", ""))
		if id.is_empty() or ids.has(id):
			problems.append("mision sin id o duplicada: '%s'" % id)
		ids.append(id)
		if not KINDS.has(String(spec.get("kind", ""))):
			problems.append("%s: kind desconocido" % id)
		for field: String in ["name", "desc"]:
			if String(spec.get(field, "")).is_empty():
				problems.append("%s: falta '%s'" % [id, field])
		for field: String in ["weight", "tier_min", "xp_mult"]:
			if not _is_number(spec.get(field)) or float(spec[field]) <= 0.0:
				problems.append("%s: %s debe ser > 0" % [id, field])
		for field: String in ["count", "seconds"]:
			if spec.has(field) and not _is_range(spec[field]):
				problems.append("%s: %s debe ser [min, max]" % [id, field])
		var kind := String(spec.get("kind", ""))
		if ["hunt", "slay", "collect", "activate", "explore", "rescue", "destroy"].has(kind) and not spec.has("count"):
			problems.append("%s: la mision '%s' necesita count" % [id, kind])
		if kind == "survive" and not spec.has("seconds"):
			problems.append("%s: la resistencia necesita seconds" % id)
	var optional: Variant = data.get("optional")
	if not (optional is Dictionary) or not (((optional as Dictionary).get("pool")) is Array):
		problems.append("falta 'optional' con su pool")
	else:
		for pool_id: Variant in (optional as Dictionary)["pool"]:
			if not ids.has(String(pool_id)):
				problems.append("optional.pool: mision desconocida '%s'" % str(pool_id))
	var mid: Variant = data.get("spike_mid")
	if not (mid is Dictionary) or not _is_range((mid as Dictionary).get("time_limit_seconds")) or not ((mid as Dictionary).get("primary_pool") is Array):
		problems.append("spike_mid necesita time_limit_seconds y primary_pool")
	else:
		for pool_id: Variant in (mid as Dictionary)["primary_pool"]:
			if not ids.has(String(pool_id)) or String(pool_id) == "clear":
				problems.append("spike_mid.primary_pool: mision invalida '%s'" % str(pool_id))
	var boss: Variant = data.get("spike_boss")
	if not (boss is Dictionary) or not ((boss as Dictionary).get("variants") is Array) or not _is_boost((boss as Dictionary).get("boss_boost")) or not _is_range((boss as Dictionary).get("seals")) or not _is_range((boss as Dictionary).get("gauntlet_seconds")):
		problems.append("spike_boss necesita variants, boss_boost, seals y gauntlet_seconds")
	else:
		for variant: Variant in (boss as Dictionary)["variants"]:
			if not BOSS_VARIANTS.has(String(variant)):
				problems.append("spike_boss: variante desconocida '%s'" % str(variant))
	for key: String in ["camps", "nodes"]:
		if not (data.get(key) is Dictionary):
			problems.append("falta '%s'" % key)
	return problems


## [multiplicador de vida, multiplicador de dano], ambos >= 1.
static func _is_boost(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2 and _is_number((value as Array)[0]) and _is_number((value as Array)[1]) and float((value as Array)[0]) >= 1.0 and float((value as Array)[1]) >= 1.0


static func _is_range(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2 and _is_number((value as Array)[0]) and _is_number((value as Array)[1]) and float((value as Array)[1]) >= float((value as Array)[0])


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
