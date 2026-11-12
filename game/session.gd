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
signal chest_opened(item: Dictionary)
signal mission_completed(mission: Mission, xp: int)
signal floor_failed(reason: String)
## Se usa la puerta de un edificio con recetas (la UI abre su taller).
signal building_opened(station: String)
signal message(text: String)

## Ticks que pasan tras morir en un piso antes de volver a la ciudad (2,5 s).
const DEATH_RETURN_TICKS := 150

var world: CombatWorld
var tower: TowerState
var layout: FloorLayout
var save_path: String = ""
## Piso al que lleva la puerta de la torre (se cambia con floor_prev/next).
var selected_floor: int = 1

var missions: Array = []
## Segundos que quedan del limite de tiempo del piso (0 = sin limite).
var time_left: float = 0.0
var time_limit: float = 0.0
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
	world.enemy_killed.connect(_on_enemy_killed)
	go_to_city()


## Si hay que pasar por el creador de personaje (partida nueva).
func needs_character() -> bool:
	return not world.player.character_created


## Crea al personaje: nombre, clase y aspecto (la ropa es la basica de la clase). Guarda.
func create_character(new_name: String, class_id: String, appearance: Dictionary) -> void:
	world.player.safe_zone = true
	world.player.set_character(new_name, appearance)
	if ClassCatalog.has_class(class_id) and class_id != world.player.class_id:
		world.player.switch_class(class_id)
	autosave()
	message.emit("Despiertas en Albor, %s." % world.player.character_name)


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
	if TowerCatalog.position_in_tier(floor_number) == 1 and visit == 1:
		var blurb := Lore.tier_blurb(TowerCatalog.tier_of_floor(floor_number))
		message.emit("%s: %s" % [blurb["name"], blurb["text"]])
	_enter(TowerGenerator.generate(floor_number, tower.world_seed, visit, [], tower.elite_floor() == floor_number), false)
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
				var station := action.substr("building:".length())
				if RecipeCatalog.recipes_for(station).is_empty():
					message.emit("%s: proximamente." % String(portal["label"]))
				else:
					var line := Lore.npc_line(station)
					if not line.is_empty():
						message.emit(line)
					building_opened.emit(station)


## Tier mas alto con el que se puede fabricar: el del piso mas alto abierto en la torre.
func max_craft_tier() -> int:
	return TowerCatalog.tier_of_floor(tower.highest_unlocked())


## Fabrica una receta en un tier (ver Crafting.craft) y guarda la partida si sale bien.
func craft(recipe_id: String, tier: int) -> Dictionary:
	var result := Crafting.craft(world.player, world.loot_rng, recipe_id, tier, max_craft_tier())
	if bool(result["ok"]):
		autosave()
	return result


## Lineas de mision para el HUD: [{text, done, optional, ratio}].
func mission_lines() -> Array:
	return missions.map(func(m: Mission) -> Dictionary: return m.line())


func objective_text() -> String:
	match layout.kind:
		FloorLayout.KIND_FLOOR:
			if _floor_done:
				return "Piso completado - sube por la salida"
			return ""
		FloorLayout.KIND_CITY:
			return "Entra a la torre (E) en el centro"
		_:
			return "Practica el combate"


## El mini-jefe elite errante cae: no vuelve a aparecer en esta partida.
func _on_enemy_killed(enemy: EnemySim) -> void:
	var config := TowerCatalog.elite_boss()
	if not config.is_empty() and String(enemy.def_id) == String(config["id"]) and not enemy.summoned and not tower.elite_defeated:
		tower.elite_defeated = true
		message.emit("%s ha caido. No volvera a cruzarse en tu camino." % String(enemy.data["name"]))
		autosave()


func is_floor_done() -> bool:
	return _floor_done


func autosave() -> void:
	if not save_path.is_empty():
		SaveGame.write(save_path, world.player, tower)


func _enter(new_layout: FloorLayout, safe: bool) -> void:
	layout = new_layout
	world.player.safe_zone = safe
	_dead_ticks = 0
	for mission: Mission in missions:
		mission.unbind()
	missions = []
	world.load_layout(new_layout)
	for enemy: EnemySim in world.enemies:
		enemy.respawns = layout.kind != FloorLayout.KIND_FLOOR
	time_limit = 0.0
	time_left = 0.0
	if layout.kind == FloorLayout.KIND_FLOOR and not layout.mission_plan.is_empty():
		for spec: Dictionary in layout.mission_plan["missions"]:
			var mission := Mission.new(spec)
			mission.bind(world, layout)
			missions.append(mission)
		time_limit = float(layout.mission_plan.get("time_limit", 0.0))
		time_left = time_limit
	location_changed.emit(new_layout)


func _on_tick(_tick_number: int) -> void:
	if layout == null or layout.kind != FloorLayout.KIND_FLOOR:
		return
	if not world.player.alive:
		_dead_ticks += 1
		if _dead_ticks >= DEATH_RETURN_TICKS:
			message.emit(Lore.text("death"))
			go_to_city()
		return
	var delta := world.step_delta
	var mains_left := 0
	for mission: Mission in missions:
		mission.update(delta)
		if mission.done and not mission.rewarded:
			mission.rewarded = true
			_reward_mission(mission)
		if not mission.optional and not mission.done:
			mains_left += 1
	if _floor_done:
		return
	if not missions.is_empty() and mains_left == 0:
		_complete_floor()
		return
	if time_limit > 0.0:
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			message.emit("Se acabo el tiempo: la mision ha fallado.")
			floor_failed.emit("time")
			go_to_city()


## Recompensa de una mision opcional al cumplirla (las principales se pagan con el piso).
func _reward_mission(mission: Mission) -> void:
	var xp := 0
	if mission.optional:
		xp = int(round(float(TowerCatalog.completion_xp(layout.floor_number)) * 0.4 * mission.xp_mult()))
		world.player.grant_xp(xp, world.player.position)
		world.player.add_gold(8 * layout.floor_number + 10)
		var bonus := float(MissionCatalog.config("optional")["chest_bonus"])
		var item := ItemGen.roll_item(world.loot_rng, layout.tier, "", "", "", "", bonus)
		world.player.add_item(item)
	mission_completed.emit(mission, xp)


func _complete_floor() -> void:
	_floor_done = true
	var floor_number := layout.floor_number
	var first_time := not tower.is_completed(floor_number)
	var main_mult := 0.0
	var main_count := 0
	for mission: Mission in missions:
		if not mission.optional:
			main_mult += mission.xp_mult()
			main_count += 1
	var mult := main_mult / float(main_count) if main_count > 0 else 1.0
	var xp := int(round(float(TowerCatalog.completion_xp(floor_number)) * mult)) if first_time else 0
	tower.complete(floor_number)
	if xp > 0:
		world.player.grant_xp(xp, world.player.position)
	floor_completed.emit(floor_number, xp)
	if first_time:
		var chest := ItemGen.roll_chest(world.loot_rng, layout.tier, TowerCatalog.spike_kind(floor_number))
		world.player.add_item(chest)
		chest_opened.emit(chest)
	autosave()
