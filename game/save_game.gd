## SaveGame — guardado de la partida en un JSON (version 1).
##
## Guarda lo que no se puede regenerar: el progreso del personaje (clase activa,
## nivel, XP y loadout de cada clase) y el de la torre (semilla del mundo, pisos
## completados y visitas). Los pisos en si no se guardan: `TowerGenerator` los
## recrea igual desde su numero y la semilla, y los enemigos reaparecen siempre.
class_name SaveGame
extends RefCounted

const VERSION := 1
const DEFAULT_PATH := "user://savegame.json"


static func write(path: String, player: PlayerSim, tower: TowerState) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var data := {"version": VERSION, "player": player.export_state(), "tower": tower.to_dict()}
	file.store_string(JSON.stringify(data, "\t"))
	return true


## Devuelve {} si no hay archivo o no se entiende.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return {}
	var data: Dictionary = json.data
	if int(data.get("version", 0)) != VERSION:
		return {}
	if not (data.get("player") is Dictionary) or not (data.get("tower") is Dictionary):
		return {}
	return data


static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
