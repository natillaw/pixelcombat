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
##   unlock_level: nivel del personaje al que se desbloquea (entero >= 1)
##   Opcionales:
##   consumes_vengeful: gasta la pasiva Vengeful Fury al lanzarse
##   charges: {max, recharge} reserva de cargas que se gasta una por uso y se
##            recupera una cada `recharge` s (el basico M1, estilo Drakantos)
##   hold: {max, damage_bonus, range_bonus} mantener el boton tras el windup
##         carga la skill hasta `max` s; da hasta +damage_bonus de dano y
##         +range_bonus de alcance (proporcional a lo mantenido)
##   ult_gain, ult_cap: Ultimate Charge que da cada golpe y tope por lanzamiento
##   charge: Ultimate Charge que gasta al lanzarse (la ultimate usa 100)
##   anchor: "self" (defecto) o "aim_leap" (salta leap_distance px hacia el cursor
##           durante el windup y golpea alli)
##   leap_distance: distancia del salto (obligatoria con aim_leap)
##   center_radius, center_mult: zona central con mas dano (forma circle)
##   stance: {arc, counter_recovery} la fase active es una postura: bloquea el
##           primer golpe frontal (dentro de `arc` grados), lo anula y lanza el
##           contraataque con la forma de la skill; luego recupera en
##           counter_recovery s. Si nadie golpea, expira con su recovery normal
##   telegraph: dibuja la zona durante el windup
##   uncancelable: la esquiva no puede cancelarla
class_name SkillCatalog
extends RefCounted

const SKILLS_DIR := "res://data/skills/"
const SHAPES := ["cone", "line", "circle"]
const KINDS := ["basic", "skill", "special", "ultimate"]
const SLOTS := ["M1", "M2", "S", "SPECIAL", "ULTIMATE"]
const TIME_FIELDS := ["windup", "active", "recovery", "cooldown"]
const NUMBER_FIELDS := ["cost", "damage_mult", "rage_gain", "rage_cap", "max_targets"]
const STRING_FIELDS := ["id", "name", "slot", "kind", "shape", "anim", "hud_label"]
const OPTIONAL_NUMBERS := ["ult_gain", "ult_cap", "charge", "leap_distance", "center_radius", "center_mult"]
const OPTIONAL_BOOLS := ["consumes_vengeful", "telegraph", "uncancelable"]
const ANCHORS := ["self", "aim_leap"]

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
	var unlock: Variant = entry.get("unlock_level")
	if not _is_number(unlock) or float(unlock) < 1.0 or float(unlock) != floorf(float(unlock)):
		problems.append("'unlock_level' debe ser un entero >= 1")
	if entry.has("stance"):
		var stance: Variant = entry["stance"]
		if not (stance is Dictionary) or not _is_number((stance as Dictionary).get("arc")) or float(stance["arc"]) <= 0.0 or float(stance["arc"]) > 360.0 or not _is_number((stance as Dictionary).get("counter_recovery")) or float(stance["counter_recovery"]) < 0.0:
			problems.append("'stance' necesita arc entre 0 y 360 y counter_recovery >= 0")
	for field: String in OPTIONAL_NUMBERS:
		if entry.has(field) and (not _is_number(entry[field]) or float(entry[field]) < 0.0):
			problems.append("'%s' debe ser un numero >= 0" % field)
	for field: String in OPTIONAL_BOOLS:
		if entry.has(field) and not (entry[field] is bool):
			problems.append("'%s' debe ser true/false" % field)
	if entry.has("charges"):
		var charges: Variant = entry["charges"]
		if not (charges is Dictionary) or not _is_number((charges as Dictionary).get("max")) or float(charges["max"]) < 1.0 or not _is_number((charges as Dictionary).get("recharge")) or float(charges["recharge"]) <= 0.0:
			problems.append("'charges' necesita max >= 1 y recharge > 0")
	if entry.has("hold"):
		var hold: Variant = entry["hold"]
		if not (hold is Dictionary) or not _is_number((hold as Dictionary).get("max")) or float(hold["max"]) <= 0.0 or not _is_number((hold as Dictionary).get("damage_bonus")) or float(hold["damage_bonus"]) < 0.0 or not _is_number((hold as Dictionary).get("range_bonus")) or float(hold["range_bonus"]) < 0.0:
			problems.append("'hold' necesita max > 0, damage_bonus >= 0 y range_bonus >= 0")
	var anchor: Variant = entry.get("anchor", "self")
	if not (anchor is String) or not ANCHORS.has(anchor):
		problems.append("anchor desconocido '%s' (self o aim_leap)" % str(anchor))
	elif anchor == "aim_leap" and (not _is_number(entry.get("leap_distance")) or float(entry["leap_distance"]) <= 0.0):
		problems.append("aim_leap requiere 'leap_distance' > 0")
	if entry.has("center_mult") != entry.has("center_radius"):
		problems.append("'center_radius' y 'center_mult' van juntos")
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
