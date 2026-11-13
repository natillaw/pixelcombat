## Pistas del tutorial (data/tutorial.json). Logica pura: elige que pista toca y rellena las
## teclas; el HUD la dibuja y marca la bandera en TowerState.flags para no repetirla.
class_name TutorialHints
extends RefCounted

const PATH := "res://data/tutorial.json"
const TRIGGERS: Array[String] = ["city", "floor_1", "first_damage", "first_item", "first_boss_bar"]

static var _cache: Array = []


static func tips() -> Array:
	if _cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_cache = (parsed as Dictionary).get("tips", [])
	return _cache


static func flag_for(tip: Dictionary) -> String:
	return "tut_%s" % String(tip["id"])


## Primera pista de `trigger` que aun no se ha visto (flags = TowerState.flags), o {}.
static func next_tip(trigger: String, flags: Dictionary) -> Dictionary:
	for tip: Variant in tips():
		var entry: Dictionary = tip
		if String(entry.get("when", "")) == trigger and not bool(flags.get(flag_for(entry), false)):
			return entry
	return {}


## Texto con {accion} cambiado por la tecla actual. `labeler` recibe el nombre de la accion.
static func render(text: String, labeler: Callable) -> String:
	var out := text
	var start := out.find("{")
	while start != -1:
		var end := out.find("}", start)
		if end == -1:
			break
		var action := out.substr(start + 1, end - start - 1)
		out = out.substr(0, start) + String(labeler.call(action)) + out.substr(end + 1)
		start = out.find("{", start)
	return out


## Errores del archivo de datos (vacio = valido); lo usa el test.
static func validate() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for tip: Variant in tips():
		var entry: Dictionary = tip
		var id := String(entry.get("id", ""))
		if id == "" or seen.has(id):
			errors.append("id vacio o repetido: '%s'" % id)
		seen[id] = true
		if not TRIGGERS.has(String(entry.get("when", ""))):
			errors.append("%s: disparador desconocido '%s'" % [id, String(entry.get("when", ""))])
		if String(entry.get("text", "")).length() < 10:
			errors.append("%s: texto vacio" % id)
	return errors
