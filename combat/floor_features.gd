## FloorFeatures — contenido extra de cada piso (peligros, barriles, notas, eventos, cofres, oscuridad), de
## `data/floor_features.json`. Un piso sin entrada (el 10, la ciudad) no lleva nada extra.
class_name FloorFeatures
extends RefCounted

const PATH := "res://data/floor_features.json"

static var _floors: Dictionary = {}
static var _loaded: bool = false


static func for_floor(floor_number: int) -> Dictionary:
	_ensure_loaded()
	return (_floors.get(str(floor_number), {}) as Dictionary).duplicate(true)


static func has_features(floor_number: int) -> bool:
	_ensure_loaded()
	return _floors.has(str(floor_number))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("floors") is Dictionary:
		_floors = (parsed as Dictionary)["floors"]
