## Lore — textos del mundo desde `data/lore.json`: la introduccion del creador de
## personaje, la presentacion de cada clase, el tier en el que estas, lo que dicen los PNJ.
class_name Lore
extends RefCounted

const PATH := "res://data/lore.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed


static func data() -> Dictionary:
	_ensure()
	return _data


static func intro_pages() -> Array:
	_ensure()
	return (_data.get("intro", []) as Array).duplicate(true)


static func class_blurb(class_id: String) -> Dictionary:
	_ensure()
	return ((_data.get("classes", {}) as Dictionary).get(class_id, {"tagline": "", "text": ""}) as Dictionary).duplicate()


static func tier_blurb(tier: int) -> Dictionary:
	_ensure()
	var tiers: Array = _data.get("tiers", [])
	if tier < 1 or tier > tiers.size():
		return {"name": "", "text": ""}
	return (tiers[tier - 1] as Dictionary).duplicate()


## Lo que dice el PNJ de `station`. `stage` (0 al empezar, 1 tras el piso 5, 2 tras el piso 9, 3 tras vencer
## a Garrick) elige la linea; una cadena suelta vale para todas las etapas.
static func npc_line(station: String, stage: int = 0) -> String:
	_ensure()
	var entry: Variant = (_data.get("npcs", {}) as Dictionary).get(station, "")
	if entry is Array:
		var lines: Array = entry
		return "" if lines.is_empty() else String(lines[clampi(stage, 0, lines.size() - 1)])
	return String(entry)


## Un rumor de la taberna (el indice da vueltas por la lista). `flags` anade los rumores que solo existen
## cuando se han cumplido esos hitos (rumors_after).
static func rumor(index: int, flags: Array = []) -> String:
	_ensure()
	var rumors: Array = (_data.get("rumors", []) as Array).duplicate()
	for flag: Variant in flags:
		rumors.append_array((_data.get("rumors_after", {}) as Dictionary).get(String(flag), []))
	if rumors.is_empty():
		return ""
	return String(rumors[posmod(index, rumors.size())])


## Ficha narrativa de un piso: {floor, name, tone, role, entry, clue, bandits, beasts} o {} si no tiene.
static func floor_info(floor_number: int) -> Dictionary:
	_ensure()
	for entry: Variant in _data.get("floors", []):
		if int((entry as Dictionary)["floor"]) == floor_number:
			return (entry as Dictionary).duplicate(true)
	return {}


## Titulo de entrada: "Piso 3 - El Primer Campamento" (o solo "Piso 3" si no tiene ficha).
static func floor_title(floor_number: int) -> String:
	var info := floor_info(floor_number)
	return "Piso %d" % floor_number if info.is_empty() else "Piso %d - %s" % [floor_number, String(info["name"])]


## Linea de un jefe o elite: kind = "enter" | "phase" | "death". "" si no tiene.
static func boss_line(def_id: String, kind: String) -> String:
	_ensure()
	return String(((_data.get("dialogue", {}) as Dictionary).get(def_id, {}) as Dictionary).get(kind, ""))


## Pantalla de cierre de un tier: {title, text} o {}.
static func tier_closing(tier: int) -> Dictionary:
	_ensure()
	return ((_data.get("tier_closing", {}) as Dictionary).get(str(tier), {}) as Dictionary).duplicate()


static func text(key: String) -> String:
	_ensure()
	return String(_data.get(key, ""))


## Problemas del archivo (lista vacia = bien): paginas, clases, tiers y PNJ completos.
static func errors() -> Array[String]:
	_ensure()
	var problems: Array[String] = []
	if (_data.get("intro", []) as Array).size() < 4:
		problems.append("la introduccion necesita al menos 4 paginas")
	for page: Variant in _data.get("intro", []):
		if not (page is Dictionary) or String((page as Dictionary).get("title", "")).is_empty() or String((page as Dictionary).get("text", "")).length() < 80:
			problems.append("una pagina de la introduccion no tiene titulo o es demasiado corta")
	for class_id: String in ClassCatalog.all_ids():
		var blurb := class_blurb(class_id)
		if String(blurb["tagline"]).is_empty() or String(blurb["text"]).length() < 40:
			problems.append("falta el texto de la clase %s" % class_id)
	if (_data.get("tiers", []) as Array).size() != TowerCatalog.tier_count():
		problems.append("debe haber un texto por cada tier (%d)" % TowerCatalog.tier_count())
	for station: String in RecipeCatalog.station_ids():
		if npc_line(station).is_empty():
			problems.append("el PNJ de %s no dice nada" % station)
	return problems


## Problemas de la narrativa del tier 1 (pisos 1-10, jefes, PNJ por etapa, cierre y rumores).
static func narrative_errors() -> Array[String]:
	_ensure()
	var problems: Array[String] = []
	var banned := ["rio", "montana", "pantano", "mina", "desierto", "lago", "cascada", "volcan"]
	var seen_names := {}
	for floor_number: int in range(1, 11):
		var info := floor_info(floor_number)
		if info.is_empty():
			problems.append("el piso %d no tiene ficha narrativa" % floor_number)
			continue
		for field: String in ["name", "tone", "role", "entry", "clue"]:
			if String(info.get(field, "")).length() < 4:
				problems.append("piso %d: falta '%s'" % [floor_number, field])
		if seen_names.has(String(info.get("name", ""))):
			problems.append("piso %d: nombre repetido" % floor_number)
		seen_names[String(info.get("name", ""))] = true
		for id: Variant in info.get("bandits", []) + info.get("beasts", []):
			if not EnemyCatalog.has_enemy(StringName(String(id))):
				problems.append("piso %d: enemigo desconocido %s" % [floor_number, id])
		var text := (String(info.get("name", "")) + " " + String(info.get("entry", "")) + " " + String(info.get("role", ""))).to_lower()
		for word: String in banned:
			if (" " + text + " ").contains(" " + word + " ") or text.contains(word + "s "):
				problems.append("piso %d: el texto promete geografia (%s), pero el tier comparte un solo bioma" % [floor_number, word])
	for id: String in ["bandit_rask", "bandit_veyra", "bandit_garrick", "bandit_deserter"]:
		if not EnemyCatalog.has_enemy(StringName(id)):
			problems.append("jefe desconocido %s" % id)
		for kind: String in ["enter", "phase", "death"]:
			if boss_line(id, kind).is_empty():
				problems.append("%s: falta la linea '%s'" % [id, kind])
	for station: String in ["blacksmith", "alchemist", "carpenter", "tailor", "tavern", "guild", "merchant", "bank"]:
		var entry: Variant = (_data.get("npcs", {}) as Dictionary).get(station)
		if not (entry is Array) or (entry as Array).size() != 4:
			problems.append("el PNJ %s necesita 4 lineas (etapas 0-3)" % station)
	if tier_closing(1).is_empty():
		problems.append("falta el cierre del tier 1")
	if rumor(0).is_empty() or (_data.get("rumors", []) as Array).size() < 8:
		problems.append("faltan rumores")
	return problems
