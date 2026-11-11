## StatusCatalog — estados alterados, cargados desde `data/statuses.json`.
##
## Esquema:
##   id, name, kind ("control" | "damage"), description, color [r, g, b, a]
##   max_duration: tope de duracion de una aplicacion (s)
##   max_strength (opcional): tope de la fuerza (slow: fraccion de velocidad perdida)
##   tick (solo kind "damage"): cada cuantos segundos aplica el dano continuo
##   immune_after: segundos de inmunidad tras terminar el estado (limita los
##                 controles encadenados; 0 = sin inmunidad)
class_name StatusCatalog
extends RefCounted

const PATH := "res://data/statuses.json"
const KINDS := ["control", "damage"]

static var _statuses: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


## Copia de la definicion de un estado, o {} si no existe.
static func status(id: String) -> Dictionary:
	_ensure_loaded()
	if not _statuses.has(id):
		return {}
	return (_statuses[id] as Dictionary).duplicate(true)


static func has_status(id: String) -> bool:
	_ensure_loaded()
	return _statuses.has(id)


static func all_ids() -> Array[String]:
	_ensure_loaded()
	var ids: Array[String] = []
	for id: String in _statuses:
		ids.append(id)
	return ids


static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_statuses = {}
	_errors = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary) or not (parsed as Dictionary).get("statuses") is Array:
		_errors.append("%s: JSON invalido o sin lista 'statuses'" % PATH)
		return
	for raw: Variant in (parsed as Dictionary)["statuses"]:
		if not (raw is Dictionary):
			_errors.append("una entrada de statuses no es un objeto")
			continue
		var entry: Dictionary = raw
		var problems := validate(entry)
		for problem: String in problems:
			_errors.append("[%s]: %s" % [str(entry.get("id", "?")), problem])
		if problems.is_empty():
			_statuses[String(entry["id"])] = entry


static func validate(entry: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for field: String in ["id", "name", "description"]:
		if not (entry.get(field) is String) or String(entry[field]).is_empty():
			problems.append("falta el texto '%s'" % field)
	if not KINDS.has(entry.get("kind")):
		problems.append("kind debe ser control o damage")
	if not _is_number(entry.get("max_duration")) or float(entry["max_duration"]) <= 0.0:
		problems.append("max_duration debe ser > 0")
	if entry.has("max_strength") and (not _is_number(entry["max_strength"]) or float(entry["max_strength"]) <= 0.0):
		problems.append("max_strength debe ser > 0")
	if not _is_number(entry.get("immune_after")) or float(entry["immune_after"]) < 0.0:
		problems.append("immune_after debe ser >= 0")
	if entry.get("kind") == "damage" and (not _is_number(entry.get("tick")) or float(entry["tick"]) <= 0.0):
		problems.append("un estado de dano necesita tick > 0")
	var color: Variant = entry.get("color")
	if not (color is Array) or (color as Array).size() != 4:
		problems.append("color debe ser [r, g, b, a]")
	return problems


## Valida una lista `on_hit` de una skill o ataque: [{id, duration, strength?}].
static func validate_on_hit(on_hit: Variant) -> Array[String]:
	var problems: Array[String] = []
	if not (on_hit is Array) or (on_hit as Array).is_empty():
		return ["'on_hit' debe ser una lista no vacia"]
	for effect: Variant in on_hit:
		if not (effect is Dictionary):
			problems.append("un efecto de on_hit no es un objeto")
			continue
		var spec: Dictionary = effect
		var id := String(spec.get("id", ""))
		if not has_status(id):
			problems.append("estado desconocido '%s'" % id)
			continue
		if not _is_number(spec.get("duration")) or float(spec["duration"]) <= 0.0:
			problems.append("%s: duration debe ser > 0" % id)
		var definition := status(id)
		if definition.has("max_strength") or definition["kind"] == "damage":
			if not _is_number(spec.get("strength")) or float(spec["strength"]) <= 0.0:
				problems.append("%s: strength debe ser > 0" % id)
	return problems


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
