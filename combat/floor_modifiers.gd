## FloorModifiers — modificadores de piso y afijos de elite, de `data/floor_modifiers.json`.
##
## Todo se elige de forma determinista a partir de la semilla (nunca con el RNG de la simulacion).
class_name FloorModifiers
extends RefCounted

const PATH := "res://data/floor_modifiers.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func modifier(id: String) -> Dictionary:
	_ensure_loaded()
	var entry: Dictionary = (_data.get("modifiers", {}) as Dictionary).get(id, {})
	if entry.is_empty():
		return {}
	var out := entry.duplicate(true)
	out["id"] = id
	return out


## Modificador del piso: {} si no toca. `chance` sale de floor_features.json; el piso 10 y la ciudad nunca llevan.
static func pick(floor_number: int, world_seed: int, chance: float) -> Dictionary:
	_ensure_loaded()
	if chance <= 0.0 or floor_number < 2 or floor_number > 9:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, floor_number, "modifier"])
	if rng.randf() >= chance:
		return {}
	var ids: Array = (_data.get("modifiers", {}) as Dictionary).keys()
	ids.sort()
	return modifier(String(ids[rng.randi_range(0, ids.size() - 1)]))


static func affix(id: String) -> Dictionary:
	_ensure_loaded()
	return ((_data.get("elite_affixes", {}) as Dictionary).get(id, {}) as Dictionary).duplicate(true)


static func affix_ids() -> Array:
	_ensure_loaded()
	var ids: Array = (_data.get("elite_affixes", {}) as Dictionary).keys()
	ids.sort()
	return ids


## Afijo de un elite segun su sitio (sin RNG): "" si no lleva. Solo pisos 2-9.
static func pick_affix(floor_number: int, position: Vector2, enemy_id: String) -> String:
	_ensure_loaded()
	if floor_number < 2 or floor_number > 9:
		return ""
	var h := absi(hash([int(position.x), int(position.y), enemy_id, floor_number]))
	if float(h % 100) / 100.0 >= float(_data.get("affix_chance", 0.0)):
		return ""
	var ids := affix_ids()
	return String(ids[(h / 100) % ids.size()])


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed
