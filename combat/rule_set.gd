## RuleSet — modos de reglas del juego (data/rules.json): aventura (PvE) y arena (PvP).
##
## En PvP el personaje se normaliza: nivel fijo, sin equipo, sin consumibles, sin skills de mundo y sin XP.
## Asi dos jugadores de la misma clase tienen exactamente los mismos stats y skills, vengan de donde vengan.
## La simulacion lee estas reglas (PlayerSim.enter_rules); la presentacion no las toca.
class_name RuleSet
extends RefCounted

const PATH := "res://data/rules.json"
const KEYS: Array[String] = ["normalized", "level", "allow_gear", "allow_consumables", "allow_xp", "allow_world_skills"]

static var _modes: Dictionary = {}


static func _load() -> void:
	if not _modes.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_modes = (parsed as Dictionary).get("modes", {})


static func has_mode(mode: String) -> bool:
	_load()
	return _modes.has(mode)


static func rules(mode: String) -> Dictionary:
	_load()
	return (_modes.get(mode, _modes.get("pve", {})) as Dictionary)


static func modes() -> Array:
	_load()
	return _modes.keys()


## Errores del archivo de datos (vacio = valido).
static func errors() -> Array[String]:
	_load()
	var problems: Array[String] = []
	for mode: String in ["pve", "pvp"]:
		if not _modes.has(mode):
			problems.append("falta el modo %s" % mode)
	for mode: String in _modes:
		var entry: Dictionary = _modes[mode]
		for key: String in KEYS:
			if not entry.has(key):
				problems.append("%s: falta '%s'" % [mode, key])
		if bool(entry.get("normalized", false)) and (int(entry.get("level", 0)) < 1 or int(entry.get("level", 0)) > Progression.max_level()):
			problems.append("%s: un modo normalizado necesita un nivel entre 1 y %d" % [mode, Progression.max_level()])
	return problems
