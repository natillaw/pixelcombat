## TowerState — progreso del jugador en la torre (lo que se guarda en disco).
##
## Un piso se identifica por su numero y la semilla del mundo (TowerGenerator es
## determinista), asi que basta con recordar que pisos se han completado. Regla
## de la torre: no se puede entrar a un piso sin haber completado el anterior; los
## pisos completados se pueden volver a visitar (sus enemigos reaparecen siempre).
class_name TowerState
extends RefCounted

var world_seed: int = 20261110
## piso -> {completed: bool, visits: int}
var floors: Dictionary = {}
## Ultimo piso en el que estuvo el jugador (la puerta de la ciudad lo propone).
var last_floor: int = 1
## Banderas narrativas persistentes (hitos del mundo): rask_defeated, veyra_defeated, garrick_defeated...
var flags: Dictionary = {}
## El mini-jefe elite errante ya fue derrotado (solo aparece una vez por partida).
var elite_defeated: bool = false


## Piso en el que toca el elite errante, o 0 si no hay (ya derrotado o no tocaba).
func elite_floor() -> int:
	return 0 if elite_defeated else TowerCatalog.elite_floor(world_seed)


func set_flag(flag: String) -> void:
	flags[flag] = true


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


## Etapa narrativa (0 inicio, 1 tras el piso 5, 2 tras el piso 9, 3 tras vencer a Garrick): decide lo que dicen los PNJ.
func story_stage() -> int:
	if has_flag("garrick_defeated"):
		return 3
	if is_completed(9):
		return 2
	if is_completed(5):
		return 1
	return 0


func is_completed(floor_number: int) -> bool:
	return bool((floors.get(floor_number, {}) as Dictionary).get("completed", false))


func visits(floor_number: int) -> int:
	return int((floors.get(floor_number, {}) as Dictionary).get("visits", 0))


## Piso mas alto al que se puede entrar: el siguiente al ultimo completado de
## forma continua desde el 1.
func highest_unlocked() -> int:
	var n := 1
	while n < TowerCatalog.floors() and is_completed(n):
		n += 1
	return n


func completed_count() -> int:
	var count := 0
	for key: Variant in floors:
		if bool((floors[key] as Dictionary).get("completed", false)):
			count += 1
	return count


func can_enter(floor_number: int) -> bool:
	return floor_number >= 1 and floor_number <= TowerCatalog.floors() and floor_number <= highest_unlocked()


## Registra una entrada al piso; devuelve cuantas veces se ha entrado ya (1 = la
## primera vez).
func visit(floor_number: int) -> int:
	var entry: Dictionary = floors.get(floor_number, {"completed": false, "visits": 0})
	entry["visits"] = int(entry["visits"]) + 1
	floors[floor_number] = entry
	last_floor = floor_number
	return int(entry["visits"])


func complete(floor_number: int) -> void:
	var entry: Dictionary = floors.get(floor_number, {"completed": false, "visits": 0})
	entry["completed"] = true
	floors[floor_number] = entry


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in floors:
		out[str(key)] = (floors[key] as Dictionary).duplicate()
	return {"world_seed": world_seed, "last_floor": last_floor, "floors": out, "elite_defeated": elite_defeated, "flags": flags.duplicate()}


static func from_dict(data: Dictionary) -> TowerState:
	var state := TowerState.new()
	state.world_seed = int(data.get("world_seed", state.world_seed))
	state.last_floor = int(data.get("last_floor", 1))
	state.elite_defeated = bool(data.get("elite_defeated", false))
	for flag: Variant in (data.get("flags", {}) as Dictionary):
		state.flags[String(flag)] = bool(data["flags"][flag])
	var saved: Dictionary = data.get("floors", {})
	for key: Variant in saved:
		var entry: Dictionary = saved[key]
		state.floors[int(str(key))] = {"completed": bool(entry.get("completed", false)), "visits": int(entry.get("visits", 0))}
	return state
