## Residents — los habitantes de la ciudad con los que se puede hablar (data/residents.json).
##
## Datos y logica pura: la ciudad crea un PNJ + un portal "talk:<id>" por residente y la sesion
## responde con `line_for`. Las frases cambian con la etapa de la historia (TowerState.story_stage).
class_name Residents
extends RefCounted

const PATH := "res://data/residents.json"

## Vestuario LPC por oficio (todas las piezas existen en lpc_index.json).
const OUTFITS := {
	"guard": {"chest": ["armour_plate", "steel"], "legs": ["pants", "charcoal"], "feet": ["boots_basic", "black"], "head": ["helmet_barbuta", "steel"], "main_hand": ["weapon_arming", "default"]},
	"guard_f": {"chest": ["armour_plate", "steel"], "legs": ["pants", "charcoal"], "feet": ["boots_basic", "black"], "head": ["helmet_barbuta", "steel"], "main_hand": ["weapon_arming", "default"]},
	"bard": {"chest": ["shirt_longsleeve", "navy"], "legs": ["pants_dyed", "navy"], "feet": ["boots_basic", "leather"], "bag": ["cape", "maroon"]},
	"elder": {"chest": ["shirt_longsleeve", "tan"], "legs": ["pants", "brown"], "feet": ["shoes_basic", "leather"]},
	"kid": {"chest": ["shirt_longsleeve", "tan"], "legs": ["pants", "brown"], "feet": ["shoes_basic", "leather"]},
	"vendor": {"chest": ["shirt_longsleeve", "tan"], "legs": ["pants_dyed", "walnut"], "feet": ["shoes_basic", "leather"]},
	"hunter": {"chest": ["armour_leather", "walnut_iron"], "legs": ["pants", "brown"], "feet": ["boots_basic", "leather"], "head": ["hood", "forest"], "main_hand": ["weapon_bow", "default"]},
	"wounded": {"chest": ["chainmail", "iron"], "legs": ["pants", "charcoal"], "feet": ["boots_basic", "black"]},
	"seer": {"chest": ["shirt_longsleeve", "navy"], "legs": ["pants_dyed", "navy"], "feet": ["shoes_basic", "leather"], "head": ["hood", "maroon"], "main_hand": ["weapon_staff", "default"]},
	"scout": {"chest": ["armour_leather", "black_iron"], "legs": ["pants", "charcoal"], "feet": ["boots_basic", "black"], "head": ["hood", "brown"]},
}
const FACES: Array[String] = ["up", "down", "left", "right"]

static var _cache: Array = []


static func all() -> Array:
	if _cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_cache = (parsed as Dictionary).get("residents", [])
	return _cache


static func find(id: String) -> Dictionary:
	for entry: Variant in all():
		if String((entry as Dictionary)["id"]) == id:
			return entry
	return {}


## Aspecto LPC determinista del residente (misma semilla, mismo personaje).
static func look_of(entry: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry.get("seed", 1))
	var look := LpcWardrobe.random_look(rng)
	var outfit := String(entry["outfit"])
	if outfit == "guard_f" or outfit == "seer":
		look["body"] = "female"
		look["head"] = "head_human_female"
		look["beard"] = ""
	elif outfit == "guard" or outfit == "elder" or outfit == "hunter":
		look["body"] = "male"
		look["head"] = "head_human_male"
	if outfit == "elder":
		look["hair_color"] = "white"
		if String(look["beard"]) == "":
			look["beard"] = "beard_trimmed"
	elif outfit == "kid":
		look["beard"] = ""
	return look


## Frase de `entry` para la etapa `stage` (la mas reciente hasta ella), rotando con `visit`.
static func line_for(entry: Dictionary, stage: int, visit: int = 0, flags: Dictionary = {}) -> String:
	# Un heroe cuyo alijo ya has encontrado habla de ello.
	var found_flag := String(entry.get("found_flag", ""))
	if found_flag != "" and bool(flags.get(found_flag, false)):
		var found: Array = entry.get("lines_found", [])
		if not found.is_empty():
			return String(found[visit % found.size()])
	var lines: Dictionary = entry.get("lines", {})
	for s: int in range(stage, -1, -1):
		var options: Variant = lines.get(str(s), [])
		if options is Array and not (options as Array).is_empty():
			return String((options as Array)[visit % (options as Array).size()])
	return ""


## Errores del archivo de datos (vacio = valido); lo usa el test.
static func validate() -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	var cells: Dictionary = {}
	for entry_value: Variant in all():
		var entry: Dictionary = entry_value
		var id := String(entry.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("id vacio o repetido: '%s'" % id)
		ids[id] = true
		if String(entry.get("name", "")) == "":
			errors.append("%s: sin nombre" % id)
		if not OUTFITS.has(String(entry.get("outfit", ""))):
			errors.append("%s: vestuario desconocido '%s'" % [id, String(entry.get("outfit", ""))])
		if not FACES.has(String(entry.get("face", "down"))):
			errors.append("%s: orientacion desconocida" % id)
		var cell: Variant = entry.get("cell")
		if not (cell is Array) or (cell as Array).size() != 2:
			errors.append("%s: cell invalida" % id)
		else:
			var key := "%d,%d" % [int(cell[0]), int(cell[1])]
			if cells.has(key):
				errors.append("%s: casilla repetida %s" % [id, key])
			cells[key] = true
		if line_for(entry, 0).is_empty():
			errors.append("%s: sin frases para la etapa 0" % id)
		if entry.has("hint"):
			var hint: Dictionary = entry["hint"]
			if int(hint.get("floor", 0)) < 1 or int(hint.get("floor", 0)) > 9 or not ["camp", "far", "hazard"].has(String(hint.get("where", ""))):
				errors.append("%s: pista invalida (piso 1-9, camp|far|hazard)" % id)
			if not entry.has("cache") or String(entry.get("found_flag", "")).is_empty() or (entry.get("lines_found", []) as Array).is_empty():
				errors.append("%s: una pista necesita cache, found_flag y lines_found" % id)
			elif not String(entry["lines"]["0"][1]).contains("piso %d" % int(hint["floor"])):
				errors.append("%s: la pista de la etapa 0 debe nombrar el piso %d" % [id, int(hint["floor"])])
	return errors
