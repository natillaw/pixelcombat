## HazardCatalog — peligros fijos del suelo de los pisos, cargados de `data/hazards.json`.
##
## Cada uno es una zona del mundo (GroundZone owner "world") que no caduca: afecta por igual al jugador y a los
## enemigos. `radius` es [min, max]; `damage` es absoluto por tick.
class_name HazardCatalog
extends RefCounted

const PATH := "res://data/hazards.json"

static var _hazards: Dictionary = {}
static var _loaded: bool = false


static func hazard(id: String) -> Dictionary:
	_ensure_loaded()
	return (_hazards.get(id, {}) as Dictionary).duplicate(true)


static func all_ids() -> Array:
	_ensure_loaded()
	return _hazards.keys()


## Radio al azar dentro del rango del peligro.
static func roll_radius(id: String, rng: RandomNumberGenerator) -> float:
	var def := hazard(id)
	if def.is_empty():
		return 40.0
	var range_px: Array = def["radius"]
	return rng.randf_range(float(range_px[0]), float(range_px[1]))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("hazards") is Dictionary:
		_hazards = (parsed as Dictionary)["hazards"]
