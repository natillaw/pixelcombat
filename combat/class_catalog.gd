## ClassCatalog — definiciones de clase, cargadas desde `data/classes/*.json`.
##
## Una clase define su recurso (Rage, Energy o Mana), sus stats base, su atributo
## principal, su pasiva, su loadout por defecto, su apariencia LPC y el resto de
## habilidades previstas del Skill Book (`planned`, aun sin implementar). Las
## skills ejecutables de cada clase viven en `data/skills/<clase>.json` (campo
## `class`) y el crecimiento por nivel, en `data/progression.json`.
##
## Esquema:
##   id, order (orden en el selector), name, role, description
##   main_stat: "strength" | "agility" | "intellect" (da AP / Spell Power)
##   resource: {name, kind: "rage"|"energy"|"mana", max, start, regen_per_second}
##             rage sube al golpear y al recibir dano y decae fuera de combate;
##             energy y mana se regeneran solos (regen_per_second)
##   stats: strength, agility, stamina, intellect, armor, crit_chance,
##          weapon_min, weapon_max, weapon_speed
##   passive: "" o "vengeful_fury"
##   default_loadout: {M1, M2, S1.., SPECIAL, ULTIMATE: id de skill}; fija ademas
##          el slot preferido de cada skill al desbloquearla
##   look: {body, skin, eyes, head, hair, hair_color, beard, equipment}
##   planned: [{id, name, role, unlock_level, cost, cooldown, description}]
class_name ClassCatalog
extends RefCounted

const CLASSES_DIR := "res://data/classes/"
const MAIN_STATS := ["strength", "agility", "intellect"]
const RESOURCE_KINDS := ["rage", "energy", "mana"]
const PASSIVES := ["", "vengeful_fury"]
const STAT_FIELDS := ["strength", "agility", "stamina", "intellect", "armor", "crit_chance", "weapon_min", "weapon_max", "weapon_speed"]

static var _classes: Dictionary = {}
static var _order: Array[String] = []
static var _errors: Array[String] = []
static var _loaded: bool = false


## Copia profunda de la definicion de una clase, o {} si no existe.
static func class_def(id: String) -> Dictionary:
	_ensure_loaded()
	if not _classes.has(id):
		return {}
	return (_classes[id] as Dictionary).duplicate(true)


static func has_class(id: String) -> bool:
	_ensure_loaded()
	return _classes.has(id)


## Ids de clase en el orden del selector.
static func all_ids() -> Array[String]:
	_ensure_loaded()
	return _order.duplicate()


## Recurso de clase nuevo, listo para jugar (Rage a 0; Energy y Mana llenos).
static func create_resource(id: String) -> ClassResource:
	var def := class_def(id)
	var resource := ClassResource.new()
	if def.is_empty():
		return resource
	resource.resource_name = String(def["resource"]["name"])
	resource.max_amount = float(def["resource"]["max"])
	resource.min_amount = 0.0
	resource.current_amount = float(def["resource"]["start"])
	return resource


## Habilidades previstas y aun sin implementar del Skill Book de la clase. Para el
## Warrior salen de WarriorKit.SKILL_BOOK (las que no estan en el catalogo).
static func planned(id: String) -> Array:
	var def := class_def(id)
	var out: Array = []
	if id == "warrior":
		for entry: Dictionary in WarriorKit.get_skill_book():
			if not SkillCatalog.has_skill(StringName(String(entry["id"]))):
				out.append(entry)
		return out
	for entry: Variant in def.get("planned", []):
		var copy: Dictionary = (entry as Dictionary).duplicate(true)
		copy["implemented"] = false
		out.append(copy)
	return out


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
	_classes = {}
	_order = []
	_errors = []
	var dir := DirAccess.open(CLASSES_DIR)
	if dir == null:
		_errors.append("no se puede abrir %s" % CLASSES_DIR)
		return
	var files: Array[String] = []
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			files.append(file_name)
	files.sort()
	var entries: Array = []
	for file_name: String in files:
		var path := CLASSES_DIR + file_name
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary):
			_errors.append("%s: JSON invalido" % path)
			continue
		var def: Dictionary = parsed
		var problems := validate(def)
		for problem: String in problems:
			_errors.append("%s [%s]: %s" % [path, str(def.get("id", "?")), problem])
		if not problems.is_empty():
			continue
		if _classes.has(String(def["id"])):
			_errors.append("%s: id duplicado '%s'" % [path, def["id"]])
			continue
		_classes[String(def["id"])] = def
		entries.append(def)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["order"]) < float(b["order"]))
	for def: Dictionary in entries:
		_order.append(String(def["id"]))


## Lista de problemas del esquema de una clase (vacia si es valida).
static func validate(def: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for field: String in ["id", "name", "role", "description"]:
		if not _is_text(def.get(field)) or String(def[field]).is_empty():
			problems.append("falta el texto '%s'" % field)
	if not _is_number(def.get("order")) or float(def["order"]) < 1.0:
		problems.append("'order' debe ser >= 1")
	if not MAIN_STATS.has(def.get("main_stat")):
		problems.append("main_stat debe ser strength, agility o intellect")

	var resource: Variant = def.get("resource")
	if not (resource is Dictionary):
		problems.append("falta 'resource'")
	else:
		var spec: Dictionary = resource
		if not _is_text(spec.get("name")) or String(spec["name"]).is_empty():
			problems.append("resource.name es obligatorio")
		if not RESOURCE_KINDS.has(spec.get("kind")):
			problems.append("resource.kind debe ser rage, energy o mana")
		if not _is_number(spec.get("max")) or float(spec["max"]) <= 0.0:
			problems.append("resource.max debe ser > 0")
		if not _is_number(spec.get("start")) or float(spec["start"]) < 0.0:
			problems.append("resource.start debe ser >= 0")
		if not _is_number(spec.get("regen_per_second")) or float(spec["regen_per_second"]) < 0.0:
			problems.append("resource.regen_per_second debe ser >= 0")
		elif spec.get("kind") != "rage" and float(spec["regen_per_second"]) <= 0.0:
			problems.append("energy y mana necesitan regen_per_second > 0")

	var stats: Variant = def.get("stats")
	if not (stats is Dictionary):
		problems.append("falta 'stats'")
	else:
		for field: String in STAT_FIELDS:
			if not _is_number((stats as Dictionary).get(field)) or float(stats[field]) < 0.0:
				problems.append("stats.%s debe ser un numero >= 0" % field)
		if _is_number((stats as Dictionary).get("weapon_min")) and _is_number((stats as Dictionary).get("weapon_max")) and float(stats["weapon_max"]) < float(stats["weapon_min"]):
			problems.append("stats.weapon_max debe ser >= weapon_min")
		if _is_number((stats as Dictionary).get("weapon_speed")) and float(stats["weapon_speed"]) <= 0.0:
			problems.append("stats.weapon_speed debe ser > 0")

	if not (def.get("passive") is String) or not PASSIVES.has(def["passive"]):
		problems.append("passive debe ser \"\" o \"vengeful_fury\"")

	var loadout: Variant = def.get("default_loadout")
	if not (loadout is Dictionary):
		problems.append("falta 'default_loadout'")
	else:
		for slot: String in ["M1", "M2"]:
			if not _is_text((loadout as Dictionary).get(slot)):
				problems.append("default_loadout necesita %s" % slot)

	var look: Variant = def.get("look")
	if not (look is Dictionary):
		problems.append("falta 'look'")
	else:
		for field: String in ["body", "skin", "eyes", "head", "hair", "hair_color"]:
			if not _is_text((look as Dictionary).get(field)) or String(look[field]).is_empty():
				problems.append("look.%s es obligatorio" % field)
		var equipment: Variant = (look as Dictionary).get("equipment")
		if not (equipment is Dictionary):
			problems.append("falta look.equipment")
		else:
			for slot: String in equipment:
				var piece: Variant = (equipment as Dictionary)[slot]
				if not (piece is Array) or (piece as Array).size() != 2:
					problems.append("look.equipment.%s debe ser [pieza, variante]" % slot)

	if def.has("planned"):
		if not (def["planned"] is Array):
			problems.append("'planned' debe ser una lista")
		else:
			for entry: Variant in def["planned"]:
				if not (entry is Dictionary):
					problems.append("una entrada de 'planned' no es un objeto")
					continue
				for field: String in ["id", "name", "role", "description"]:
					if not _is_text((entry as Dictionary).get(field)) or String(entry[field]).is_empty():
						problems.append("planned: falta '%s'" % field)
				for field: String in ["unlock_level", "cost", "cooldown"]:
					if not _is_number((entry as Dictionary).get(field)) or float(entry[field]) < 0.0:
						problems.append("planned %s: '%s' debe ser >= 0" % [str((entry as Dictionary).get("id", "?")), field])
	return problems


static func _is_number(value: Variant) -> bool:
	return value is float or value is int


static func _is_text(value: Variant) -> bool:
	return value is String or value is StringName
