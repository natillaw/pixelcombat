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


static func npc_line(station: String) -> String:
	_ensure()
	return String((_data.get("npcs", {}) as Dictionary).get(station, ""))


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
