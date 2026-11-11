## SkillCatalog — catálogo de skills ejecutables, cargado desde `data/skills/*.json`.
##
## Añadir una skill es añadir un objeto al JSON de su clase; no requiere código
## nuevo mientras use una forma existente (cone, line, circle). `validate()`
## comprueba el esquema y lo ejecuta `tests/test_skill_catalog.gd` sobre todos
## los archivos, así que un dato mal escrito falla en CI.
##
## Esquema (todos los tiempos en segundos, distancias en px):
##   id, name, slot ("M1", "M2", "S", "SPECIAL", "ULTIMATE"), kind, role,
##   description, hud_label, anim, implemented
##   windup, active, recovery, cooldown, cost, damage_mult
##   rage_gain, rage_cap, max_targets (0 = sin limite)
##   move: {windup, active, recovery}  factor de velocidad en cada fase (0..1)
##   shape: "cone" (range, arc) | "line" (range, width) | "circle" (range)
##   consumes_vengeful (opcional): gasta la pasiva Vengeful Fury al lanzarse
class_name SkillCatalog
extends RefCounted

const SKILLS_DIR := "res://data/skills/"
const SHAPES := ["cone", "line", "circle"]
const KINDS := ["basic", "skill", "special", "ultimate"]
const SLOTS := ["M1", "M2", "S", "SPECIAL", "ULTIMATE"]
const TIME_FIELDS := ["windup", "active", "recovery", "cooldown"]
const NUMBER_FIELDS := ["cost", "damage_mult", "rage_gain", "rage_cap", "max_targets"]
const STRING_FIELDS := ["id", "name", "slot", "kind", "shape", "anim", "hud_label"]

static var _skills: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


## Copia profunda de una skill, o {} si no existe.
static func skill(id: StringName) -> Dictionary:
	_ensure_loaded()
	if not _skills.has(id):
		return {}
	return (_skills[id] as Dictionary).duplicate(true)


static func has_skill(id: StringName) -> bool:
	_ensure_loaded()
	return _skills.has(id)


static func all_ids() -> Array[StringName]:
	_ensure_loaded()
	var ids: Array[StringName] = []
	for id: StringName in _skills:
		ids.append(id)
	return ids


## Errores de carga y de esquema acumulados (vacio si todo esta bien).
static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_skills = {}
	_errors = []
	var dir := DirAccess.open(SKILLS_DIR)
	if dir == null:
		_errors.append("no se puede abrir %s" % SKILLS_DIR)
		return
	var files: Array[String] = []
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			files.append(file_name)
	files.sort()
	for file_name: String in files:
		_load_file(SKILLS_DIR + file_name)


static func _load_file(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not (parsed as Dictionary).get("skills") is Array:
		_errors.append("%s: JSON invalido o sin lista 'skills'" % path)
		return
	for raw: Variant in (parsed as Dictionary)["skills"]:
		if not (raw is Dictionary):
			_errors.append("%s: entrada que no es un objeto" % path)
			continue
		var entry: Dictionary = raw
		var problems := validate(entry)
		for problem: String in problems:
			_errors.append("%s [%s]: %s" % [path, str(entry.get("id", "?")), problem])
		if not problems.is_empty():
			continue
		var id := StringName(String(entry["id"]))
		if _skills.has(id):
			_errors.append("%s: id duplicado '%s'" % [path, id])
			continue
		var stored := entry.duplicate(true)
		stored["id"] = id
		_skills[id] = stored


## Lista de problemas del esquema para una skill (vacia si es valida).
static func validate(entry: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for field: String in STRING_FIELDS:
		if not _is_text(entry.get(field)) or String(entry[field]).is_empty():
			problems.append("falta el texto '%s'" % field)
	for field: String in TIME_FIELDS:
		if not _is_number(entry.get(field)) or float(entry[field]) < 0.0:
			problems.append("'%s' debe ser un numero >= 0" % field)
	for field: String in NUMBER_FIELDS:
		if not _is_number(entry.get(field)) or float(entry[field]) < 0.0:
			problems.append("'%s' debe ser un numero >= 0" % field)
	if _is_number(entry.get("damage_mult")) and float(entry["damage_mult"]) <= 0.0:
		problems.append("'damage_mult' debe ser > 0")
	if not (entry.get("implemented") is bool):
		problems.append("'implemented' debe ser true/false")
	if entry.get("kind") is String and not KINDS.has(entry["kind"]):
		problems.append("kind desconocido '%s'" % entry["kind"])
	if entry.get("slot") is String and not SLOTS.has(entry["slot"]):
		problems.append("slot desconocido '%s'" % entry["slot"])
	var move: Variant = entry.get("move")
	if not (move is Dictionary):
		problems.append("falta 'move' {windup, active, recovery}")
	else:
		for phase: String in ["windup", "active", "recovery"]:
			var factor: Variant = (move as Dictionary).get(phase)
			if not _is_number(factor) or float(factor) < 0.0 or float(factor) > 1.0:
				problems.append("move.%s debe estar entre 0 y 1" % phase)
	_validate_shape(entry, problems)
	return problems


static func _validate_shape(entry: Dictionary, problems: Array[String]) -> void:
	var shape: Variant = entry.get("shape")
	if not (shape is String) or not SHAPES.has(shape):
		problems.append("forma desconocida '%s' (cone, line o circle)" % str(shape))
		return
	if not _is_number(entry.get("range")) or float(entry["range"]) <= 0.0:
		problems.append("'range' debe ser un numero > 0")
	if shape == "cone":
		if not _is_number(entry.get("arc")) or float(entry["arc"]) <= 0.0 or float(entry["arc"]) > 360.0:
			problems.append("cone: 'arc' debe estar entre 0 y 360")
	elif shape == "line":
		if not _is_number(entry.get("width")) or float(entry["width"]) <= 0.0:
			problems.append("line: 'width' debe ser un numero > 0")


static func _is_number(value: Variant) -> bool:
	return value is float or value is int


static func _is_text(value: Variant) -> bool:
	return value is String or value is StringName
