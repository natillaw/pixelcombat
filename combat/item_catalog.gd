## ItemCatalog — rarezas, ranuras, items base, afijos y botin, desde `data/items.json`.
##
## Esquema:
##   bag_size, tier_scale: tamano de la mochila y +X de stats por tier (0.30 = +30 %)
##   rarities: [{id, name, color [r,g,b], stat_mult, affixes, weight}] de peor a mejor
##   slots: [{id, name}]
##   items: [{id, name, slot, classes?, stats: {stat: valor}}]; `classes` restringe quien
##          puede equiparlo (las armas); sin el campo, todas las clases
##   affixes: [{stat, min, max}] bonus aleatorios (tantos como `affixes` de la rareza)
##   (rarities y items llevan `value_mult` / `value`: precio de venta)
##   loot: {normal_chance, boss_chance, gold_per_xp, rarity_bonus: {origen: bonus}}; el bonus
##          multiplica el peso de cada rareza por (1 + bonus x posicion)
## `look` (opcional) en un item base: {slot, piece, variants} es la capa LPC que el item
## muestra en el personaje (ver ClassLook); sin `look` (anillos) no se ve.
## Un item concreto es un Diccionario {id, rarity, tier, stats} (ver ItemGen).
class_name ItemCatalog
extends RefCounted

const PATH := "res://data/items.json"
## Stats que un item puede dar (los que PlayerSim sabe sumar).
const STATS := ["strength", "agility", "stamina", "intellect", "armor", "crit_chance", "attack_power_bonus", "spell_power_bonus", "weapon_min", "weapon_max"]

static var _data: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func bag_size() -> int:
	_ensure_loaded()
	return int(_data.get("bag_size", 40))


static func tier_multiplier(tier: int) -> float:
	_ensure_loaded()
	return 1.0 + float(_data.get("tier_scale", 0.3)) * float(maxi(tier - 1, 0))


static func rarities() -> Array:
	_ensure_loaded()
	return (_data.get("rarities", []) as Array).duplicate(true)


static func rarity_ids() -> Array:
	return rarities().map(func(r: Dictionary) -> String: return String(r["id"]))


static func rarity(id: String) -> Dictionary:
	_ensure_loaded()
	for entry: Variant in _data.get("rarities", []):
		if String((entry as Dictionary)["id"]) == id:
			return (entry as Dictionary).duplicate(true)
	return {}


## Posicion de la rareza (0 = la peor).
static func rarity_rank(id: String) -> int:
	return rarity_ids().find(id)


static func rarity_color(id: String) -> Color:
	var spec := rarity(id)
	if spec.is_empty():
		return Color.WHITE
	var c: Array = spec["color"]
	return Color(float(c[0]), float(c[1]), float(c[2]))


## Oro que da vender el item: valor base x multiplicador de rareza x multiplicador de tier.
static func sell_value(entry: Dictionary) -> int:
	var base := item(String(entry.get("id", "")))
	var spec := rarity(String(entry.get("rarity", "common")))
	if base.is_empty() or spec.is_empty():
		return 0
	return maxi(1, int(round(float(base["value"]) * float(spec["value_mult"]) * tier_multiplier(int(entry.get("tier", 1))))))


static func slots() -> Array:
	_ensure_loaded()
	return (_data.get("slots", []) as Array).map(func(s: Dictionary) -> String: return String(s["id"]))


static func slot_name(id: String) -> String:
	_ensure_loaded()
	for entry: Variant in _data.get("slots", []):
		if String((entry as Dictionary)["id"]) == id:
			return String((entry as Dictionary)["name"])
	return id


static func has_item(id: String) -> bool:
	return not item(id).is_empty()


static func item(id: String) -> Dictionary:
	_ensure_loaded()
	for entry: Variant in _data.get("items", []):
		if String((entry as Dictionary)["id"]) == id:
			return (entry as Dictionary).duplicate(true)
	return {}


static func items() -> Array:
	_ensure_loaded()
	return (_data.get("items", []) as Array).duplicate(true)


static func affixes() -> Array:
	_ensure_loaded()
	return (_data.get("affixes", []) as Array).duplicate(true)


static func loot() -> Dictionary:
	_ensure_loaded()
	return (_data.get("loot", {}) as Dictionary).duplicate(true)


## Items base de una ranura que `class_id` puede equipar ("" = sin filtrar clase).
static func items_for(slot: String, class_id: String = "") -> Array:
	var out: Array = []
	for entry: Dictionary in items():
		if String(entry["slot"]) != slot:
			continue
		if class_id != "" and not can_equip_base(String(entry["id"]), class_id):
			continue
		out.append(entry)
	return out


static func can_equip_base(item_id: String, class_id: String) -> bool:
	var base := item(item_id)
	if base.is_empty():
		return false
	if not base.has("classes"):
		return true
	return (base["classes"] as Array).has(class_id)


## Nombre para mostrar: "Raro Espada de hierro".
static func display_name(entry: Dictionary) -> String:
	var base := item(String(entry.get("id", "")))
	if base.is_empty():
		return "?"
	var prefix := String(rarity(String(entry.get("rarity", "common")))["name"]) if rarity(String(entry.get("rarity", "common"))).has("name") else ""
	return String(base["name"]) if prefix == "" or String(entry.get("rarity", "common")) == "common" else "%s (%s)" % [base["name"], prefix]


## Capa LPC que muestra un item concreto: [slot_visual, [pieza, variante]] o [] si no se
## ve. La variante sube con la rareza (cada tres rangos pasa a la siguiente).
static func look_layer(entry: Dictionary) -> Array:
	var base := item(String(entry.get("id", "")))
	if base.is_empty() or not base.has("look"):
		return []
	var look: Dictionary = base["look"]
	var variants: Array = look["variants"]
	var pick := mini(variants.size() - 1, maxi(rarity_rank(String(entry.get("rarity", "common"))), 0) / 3)
	return [String(look["slot"]), [String(look["piece"]), String(variants[pick])]]


## Un item concreto es valido si su base existe, su rareza existe y solo trae stats conocidos.
static func is_valid_item(entry: Variant) -> bool:
	if not (entry is Dictionary):
		return false
	var dict: Dictionary = entry
	if not has_item(String(dict.get("id", ""))) or rarity_rank(String(dict.get("rarity", ""))) < 0 or not (dict.get("stats") is Dictionary):
		return false
	for stat: Variant in (dict["stats"] as Dictionary):
		if not STATS.has(String(stat)):
			return false
	return true


## Copia del item con los tipos que dejan los JSON arreglados (tier entero).
static func normalized(entry: Dictionary) -> Dictionary:
	var copy := entry.duplicate(true)
	copy["tier"] = int(copy.get("tier", 1))
	return copy


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
	if not _is_number(data.get("bag_size")) or float(data["bag_size"]) < 1.0:
		problems.append("bag_size debe ser >= 1")
	if not _is_number(data.get("tier_scale")) or float(data["tier_scale"]) < 0.0:
		problems.append("tier_scale debe ser >= 0")
	var rarity_ids_seen: Array = []
	var last_mult := 0.0
	var rarities_data: Variant = data.get("rarities")
	if not (rarities_data is Array) or (rarities_data as Array).is_empty():
		problems.append("falta la lista 'rarities'")
	else:
		for entry: Variant in rarities_data:
			if not (entry is Dictionary) or String((entry as Dictionary).get("id", "")).is_empty():
				problems.append("una rareza no tiene id")
				continue
			var spec: Dictionary = entry
			var id := String(spec["id"])
			if rarity_ids_seen.has(id):
				problems.append("rareza duplicada: %s" % id)
			rarity_ids_seen.append(id)
			if not (spec.get("color") is Array) or (spec["color"] as Array).size() < 3:
				problems.append("rareza %s: color debe ser [r, g, b]" % id)
			if not _is_number(spec.get("stat_mult")) or float(spec["stat_mult"]) < last_mult or float(spec["stat_mult"]) <= 0.0:
				problems.append("rareza %s: stat_mult debe ser > 0 y no bajar respecto a la anterior" % id)
			else:
				last_mult = float(spec["stat_mult"])
			if not _is_number(spec.get("affixes")) or int(spec["affixes"]) < 0:
				problems.append("rareza %s: affixes debe ser >= 0" % id)
			if not _is_number(spec.get("weight")) or float(spec["weight"]) <= 0.0:
				problems.append("rareza %s: weight debe ser > 0" % id)
			if not _is_number(spec.get("value_mult")) or float(spec["value_mult"]) <= 0.0:
				problems.append("rareza %s: value_mult debe ser > 0" % id)
	var slot_ids: Array = []
	for entry: Variant in data.get("slots", []):
		if entry is Dictionary:
			slot_ids.append(String((entry as Dictionary).get("id", "")))
	if slot_ids.is_empty():
		problems.append("falta la lista 'slots'")
	var item_ids: Array = []
	var slots_with_items: Array = []
	for entry: Variant in data.get("items", []):
		if not (entry is Dictionary):
			problems.append("un item no es un objeto")
			continue
		var spec: Dictionary = entry
		var id := String(spec.get("id", ""))
		if id.is_empty() or item_ids.has(id):
			problems.append("item sin id o duplicado: '%s'" % id)
		item_ids.append(id)
		if not slot_ids.has(String(spec.get("slot", ""))):
			problems.append("item %s: ranura desconocida" % id)
		else:
			slots_with_items.append(String(spec["slot"]))
		if not _is_number(spec.get("value")) or float(spec["value"]) <= 0.0:
			problems.append("item %s: value debe ser > 0" % id)
		if not (spec.get("stats") is Dictionary) or (spec["stats"] as Dictionary).is_empty():
			problems.append("item %s: necesita stats" % id)
		else:
			for stat: Variant in (spec["stats"] as Dictionary):
				if not STATS.has(String(stat)) or not _is_number((spec["stats"] as Dictionary)[stat]) or float((spec["stats"] as Dictionary)[stat]) <= 0.0:
					problems.append("item %s: stat invalido '%s'" % [id, str(stat)])
		if spec.has("look"):
			var look: Variant = spec["look"]
			if not (look is Dictionary) or not ["main_hand", "head", "chest", "legs", "feet"].has(String((look as Dictionary).get("slot", ""))) or String((look as Dictionary).get("piece", "")).is_empty() or not ((look as Dictionary).get("variants") is Array) or ((look as Dictionary)["variants"] as Array).is_empty():
				problems.append("item %s: look necesita slot, piece y variants" % id)
		if spec.has("classes") and (not (spec["classes"] is Array) or (spec["classes"] as Array).is_empty()):
			problems.append("item %s: classes debe ser una lista no vacia" % id)
	for slot_id: String in slot_ids:
		if not slots_with_items.has(slot_id):
			problems.append("la ranura %s no tiene ningun item" % slot_id)
	if not (data.get("affixes") is Array) or (data["affixes"] as Array).is_empty():
		problems.append("falta la lista 'affixes'")
	else:
		for entry: Variant in data["affixes"]:
			if not (entry is Dictionary) or not STATS.has(String((entry as Dictionary).get("stat", ""))) or not _is_number((entry as Dictionary).get("min")) or not _is_number((entry as Dictionary).get("max")) or float(entry["min"]) <= 0.0 or float(entry["max"]) < float(entry["min"]):
				problems.append("afijo invalido: %s" % str(entry))
	var loot_data: Variant = data.get("loot")
	if not (loot_data is Dictionary) or not _is_number((loot_data as Dictionary).get("normal_chance")) or not _is_number((loot_data as Dictionary).get("boss_chance")) or not ((loot_data as Dictionary).get("rarity_bonus") is Dictionary):
		problems.append("loot necesita normal_chance, boss_chance y rarity_bonus")
	return problems


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
