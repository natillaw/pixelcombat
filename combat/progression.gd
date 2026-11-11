## Progression — curva de niveles y crecimiento de stats, desde `data/progression.json`.
##
## Esquema:
##   max_level: nivel maximo
##   xp_curve: {base, exponent}  XP para pasar del nivel L al L+1 =
##             round(base * L ^ exponent)
##   classes: { <clase>: {<stat>_per_level: n, ...} } con strength, agility,
##            stamina, intellect y armor; crecimiento por nivel sobre los stats
##            base del nivel 1 (cada clase solo lista los que crecen)
class_name Progression
extends RefCounted

const PATH := "res://data/progression.json"

static var _data: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


static func max_level() -> int:
	_ensure_loaded()
	return int(_data.get("max_level", 1))


## XP necesaria para subir de `level` a `level + 1` (0 si ya es el nivel maximo).
static func xp_to_next(level: int) -> int:
	_ensure_loaded()
	if level >= max_level() or level < 1:
		return 0
	var curve: Dictionary = _data.get("xp_curve", {})
	return maxi(1, int(round(float(curve.get("base", 100.0)) * pow(float(level), float(curve.get("exponent", 1.0))))))


## XP total acumulada para llegar a `level` desde el nivel 1.
static func total_xp_for_level(level: int) -> int:
	var total := 0
	for current: int in range(1, mini(level, max_level())):
		total += xp_to_next(current)
	return total


## Crecimiento por nivel de una clase ({} si no existe).
static func growth(class_id: String) -> Dictionary:
	_ensure_loaded()
	var classes: Dictionary = _data.get("classes", {})
	if not classes.has(class_id):
		return {}
	return (classes[class_id] as Dictionary).duplicate(true)


static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


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
	var data: Dictionary = parsed
	if not _is_number(data.get("max_level")) or float(data["max_level"]) < 1.0:
		_errors.append("max_level debe ser >= 1")
	var curve: Variant = data.get("xp_curve")
	if not (curve is Dictionary) or not _is_number((curve as Dictionary).get("base")) or float(curve["base"]) <= 0.0 or not _is_number((curve as Dictionary).get("exponent")) or float(curve["exponent"]) <= 0.0:
		_errors.append("xp_curve necesita base > 0 y exponent > 0")
	var classes: Variant = data.get("classes")
	if not (classes is Dictionary) or (classes as Dictionary).is_empty():
		_errors.append("falta 'classes'")
	else:
		for class_id: String in classes:
			var growth_data: Variant = classes[class_id]
			if not (growth_data is Dictionary):
				_errors.append("classes.%s no es un objeto" % class_id)
				continue
			if (growth_data as Dictionary).is_empty():
				_errors.append("classes.%s no define ningun crecimiento" % class_id)
			for field: String in growth_data:
				if not field.ends_with("_per_level") or not _is_number((growth_data as Dictionary)[field]) or float(growth_data[field]) < 0.0:
					_errors.append("classes.%s.%s debe ser un numero >= 0 (campos *_per_level)" % [class_id, field])
	_data = data


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
