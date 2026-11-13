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
const SLOT_COUNT := 3


## Archivo de la ranura `index` (1..SLOT_COUNT). PIXELCOMBAT_SLOT_DIR cambia la carpeta (tests).
static func slot_path(index: int) -> String:
	var dir := OS.get_environment("PIXELCOMBAT_SLOT_DIR")
	return "%s/save_%d.json" % [dir if not dir.is_empty() else "user:/", index]


## Copia el guardado antiguo (una sola ranura) a la ranura 1 si esta aun no existe.
static func migrate_legacy() -> void:
	if not FileAccess.file_exists(slot_path(1)) and FileAccess.file_exists(DEFAULT_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(DEFAULT_PATH), ProjectSettings.globalize_path(slot_path(1)))


## Resumen de una ranura para el menu: {exists, name, class_id, level, floor}.
static func summary(path: String) -> Dictionary:
	var data := read(path)
	if data.is_empty():
		return {"exists": false}
	var player: Dictionary = data["player"]
	var character: Dictionary = player.get("character", {})
	var class_id := String(player.get("class_id", "warrior"))
	var progress: Dictionary = (player.get("progress", {}) as Dictionary).get(class_id, {})
	var tower := TowerState.from_dict(data["tower"])
	return {"exists": true, "created": bool(character.get("created", false)), "name": String(character.get("name", "Despierto")), "class_id": class_id, "level": int(progress.get("level", 1)), "floor": tower.highest_unlocked()}


## Ranura mas reciente con personaje (la que abre "Continuar"), o 0.
static func latest_slot() -> int:
	var best := 0
	var best_time := 0
	for index: int in range(1, SLOT_COUNT + 1):
		var path := slot_path(index)
		if FileAccess.file_exists(path) and bool(summary(path).get("created", false)):
			var modified := FileAccess.get_modified_time(path)
			if modified >= best_time:
				best_time = modified
				best = index
	return best


## Guarda de forma segura: escribe un archivo temporal, conserva el guardado anterior como `.bak` y solo
## entonces reemplaza el bueno (un corte a mitad de escritura ya no deja la partida a medias).
static func write(path: String, player: PlayerSim, tower: TowerState) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	var data := {"version": VERSION, "player": player.export_state(), "tower": tower.to_dict()}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) == OK


## Devuelve {} si no hay archivo o no se entiende; si el guardado esta roto, prueba con la copia `.bak`.
static func read(path: String) -> Dictionary:
	var data := _read_file(path)
	if data.is_empty() and FileAccess.file_exists(path + ".bak"):
		data = _read_file(path + ".bak")
	return data


static func _read_file(path: String) -> Dictionary:
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
	for candidate: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
