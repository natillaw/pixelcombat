## EventCatalog — eventos con decision de los pisos (`data/events.json`) y notas de lore (`data/notes.json`).
class_name EventCatalog
extends RefCounted

const EVENTS_PATH := "res://data/events.json"
const NOTES_PATH := "res://data/notes.json"

static var _events: Array = []
static var _notes: Array = []
static var _loaded: bool = false


static func events_for_floor(floor_number: int) -> Array:
	_ensure_loaded()
	return _events.filter(func(e: Dictionary) -> bool: return floor_number >= int(e.get("min_floor", 1)) and floor_number <= int(e.get("max_floor", 99)))


static func event(id: String) -> Dictionary:
	_ensure_loaded()
	for entry: Dictionary in _events:
		if String(entry["id"]) == id:
			return entry.duplicate(true)
	return {}


static func notes_for_floor(floor_number: int) -> Array:
	_ensure_loaded()
	return _notes.filter(func(n: Dictionary) -> bool: return int(n["floor"]) == floor_number)


static func note(id: String) -> Dictionary:
	_ensure_loaded()
	for entry: Dictionary in _notes:
		if String(entry["id"]) == id:
			return entry.duplicate(true)
	return {}


static func note_count() -> int:
	_ensure_loaded()
	return _notes.size()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var events: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	if events is Dictionary and (events as Dictionary).get("events") is Array:
		_events = (events as Dictionary)["events"]
	var notes: Variant = JSON.parse_string(FileAccess.get_file_as_string(NOTES_PATH))
	if notes is Dictionary and (notes as Dictionary).get("notes") is Array:
		_notes = (notes as Dictionary)["notes"]
