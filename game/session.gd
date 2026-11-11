## GameSession — a donde esta el jugador y como se mueve entre escenarios.
##
## Une el mundo de simulacion (`CombatWorld`), el progreso de la torre
## (`TowerState`) y el guardado. Decide la ciudad, el patio y los pisos; aplica la
## regla de la torre (no se sube sin completar el piso) y concede la XP de piso.
## Vive fuera del tick: solo reacciona a `tick_advanced` y a las peticiones del
## jugador (interactuar, reiniciar), y cambia el mundo con `load_layout()`.
class_name GameSession
extends RefCounted

signal location_changed(layout: FloorLayout)
signal floor_completed(floor_number: int, xp: int)
signal message(text: String)

## Ticks que pasan tras morir en un piso antes de volver a la ciudad (2,5 s).
const DEATH_RETURN_TICKS := 150

var world: CombatWorld
var tower: TowerState
var layout: FloorLayout
var save_path: String = ""
## Piso al que lleva la puerta de la torre (se cambia con floor_prev/next).
var selected_floor: int = 1

var _floor_done: bool = false
var _dead_ticks: int = 0


## `p_save_path` vacio desactiva el guardado (tests). Si existe un guardado, lo
## carga y empieza en la ciudad.
func _init(p_world: CombatWorld, p_save_path: String = "") -> void:
	world = p_world
	tower = TowerState.new()
	save_path = p_save_path
	if not save_path.is_empty():
		var data := SaveGame.read(save_path)
		if not data.is_empty():
			world.player.import_state(data["player"])
			tower = TowerState.from_dict(data["tower"])
	selected_floor = clampi(tower.last_floor, 1, tower.highest_unlocked())
	world.tick_advanced.connect(_on_tick)
	go_to_city()


func go_to_city() -> void:
	_enter(Layouts.city(), true)
	selected_floor = clampi(tower.last_floor, 1, tower.highest_unlocked())
	autosave()


func go_to_training() -> void:
	_enter(Layouts.training(), true)


## Entra al piso; devuelve false (y avisa) si el anterior no esta completado.
func go_to_floor(floor_number: int) -> bool:
	if not tower.can_enter(floor_number):
		message.emit("Completa el piso %d para subir." % tower.highest_unlocked())
		return false
	var visit := tower.visit(floor_number)
	_enter(TowerGenerator.generate(floor_number, tower.world_seed), false)
	_floor_done = false
	if visit > 1:
		message.emit("Piso %d: los enemigos han vuelto." % floor_number)
	return true


## Vuelve a empezar el escenario actual (tecla R): enemigos vivos y jugador curado.
func restart() -> void:
	_enter(layout, layout.kind != FloorLayout.KIND_FLOOR)
	_floor_done = false


func select_floor(delta: int) -> void:
	if layout.kind != FloorLayout.KIND_CITY:
		return
	selected_floor = clampi(selected_floor + delta, 1, tower.highest_unlocked())


## Portal mas cercano al que el jugador llega (o null).
func nearest_portal() -> Variant:
	var best: Variant = null
	var best_distance := INF
	for portal: Dictionary in layout.portals:
		var distance: float = world.player.position.distance_to(portal["position"])
		if distance <= float(portal["radius"]) + PlayerSim.RADIUS and distance < best_distance:
			best = portal
			best_distance = distance
	return best


## Un portal con `requires_complete` solo funciona con el piso completado.
func portal_active(portal: Dictionary) -> bool:
	return not bool(portal.get("requires_complete", false)) or _floor_done


## Texto para el aviso de interaccion junto al portal.
func portal_prompt(portal: Dictionary) -> String:
	var label := String(portal["label"])
	if String(portal["action"]) == "tower":
		label = "Torre - piso %d (</> cambian)" % selected_floor
	if not portal_active(portal):
		return "%s (completa el piso)" % label
	return "E: %s" % label


func try_interact() -> void:
	if not world.player.alive:
		return
	var portal: Variant = nearest_portal()
	if portal == null:
		return
	if not portal_active(portal):
		message.emit("Completa el piso para usar la salida.")
		return
	var action := String(portal["action"])
	match action:
		"to_city":
			go_to_city()
		"to_training":
			go_to_training()
		"tower":
			go_to_floor(selected_floor)
		"next_floor":
			go_to_floor(layout.floor_number + 1)
		_:
			if action.begins_with("building:"):
				message.emit("%s: proximamente." % String(portal["label"]))


func objective_text() -> String:
	match layout.kind:
		FloorLayout.KIND_FLOOR:
			if _floor_done:
				return "Piso completado - sube por la salida"
			return String(layout.objective.get("label", ""))
		FloorLayout.KIND_CITY:
			return "Entra a la torre (E) en el centro"
		_:
			return "Practica el combate"


func is_floor_done() -> bool:
	return _floor_done


func autosave() -> void:
	if not save_path.is_empty():
		SaveGame.write(save_path, world.player, tower)


func _enter(new_layout: FloorLayout, safe: bool) -> void:
	layout = new_layout
	world.player.safe_zone = safe
	_dead_ticks = 0
	world.load_layout(new_layout)
	for enemy: EnemySim in world.enemies:
		enemy.respawns = layout.kind != FloorLayout.KIND_FLOOR
	location_changed.emit(new_layout)


func _on_tick(_tick_number: int) -> void:
	if layout == null or layout.kind != FloorLayout.KIND_FLOOR:
		return
	if not world.player.alive:
		_dead_ticks += 1
		if _dead_ticks >= DEATH_RETURN_TICKS:
			message.emit("Has caido: vuelves a la ciudad.")
			go_to_city()
		return
	if _floor_done:
		return
	for enemy: EnemySim in world.enemies:
		if enemy.required and not enemy.summoned and enemy.alive:
			return
	_complete_floor()


func _complete_floor() -> void:
	_floor_done = true
	var floor_number := layout.floor_number
	var first_time := not tower.is_completed(floor_number)
	var xp := TowerCatalog.completion_xp(floor_number) if first_time else 0
	tower.complete(floor_number)
	if xp > 0:
		world.player.grant_xp(xp, world.player.position)
	floor_completed.emit(floor_number, xp)
	autosave()
