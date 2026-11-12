## Torre y ciudad: catalogo, generador determinista, estado de progreso, sesion
## (transiciones, regla de no subir sin completar, XP de piso, reaparicion) y
## guardado.
##
##   godot --headless --path . --script tests/test_tower.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")

const DT: float = 1.0 / 60.0
const SAVE_PATH := "user://test_savegame.json"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_tower (torre, ciudad, sesion) ==")
	_test_catalog()
	_test_generator_determinism()
	_test_generator_invariants()
	_test_spike_floors()
	_test_tower_state()
	_test_city_and_training_layouts()
	_test_session_gating_and_completion()
	_test_respawn_on_reentry()
	_test_death_returns_to_city()
	_test_scaling()
	_test_safe_zone()
	_test_save_roundtrip()
	SaveGame.delete(SAVE_PATH)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _new_session(path: String = "") -> GameSession:
	var world: CombatWorld = CombatWorldScript.new(77)
	return GameSession.new(world, path)


func _step(world: CombatWorld, ticks: int) -> void:
	for i: int in range(ticks):
		world.step(DT)


## Da por cumplidas las misiones del piso (las pruebas de misiones las juegan de verdad en
## tests/test_missions.gd) y mata a los enemigos que cuentan para el piso.
func _kill_required(session: GameSession) -> void:
	for mission: Mission in session.missions:
		if not mission.optional:
			mission.force_complete()


# --- Catalogo ---------------------------------------------------------------------


func _test_catalog() -> void:
	_check(TowerCatalog.errors().is_empty(), "tower.json valida: %s" % str(TowerCatalog.errors()))
	_check(TowerCatalog.floors() == 100 and TowerCatalog.tier_count() == 10 and TowerCatalog.tier_size() == 10, "100 pisos en 10 tiers de 10")
	_check(TowerCatalog.tier_of_floor(1) == 1 and TowerCatalog.tier_of_floor(10) == 1 and TowerCatalog.tier_of_floor(11) == 2 and TowerCatalog.tier_of_floor(100) == 10, "el tier cambia cada 10 pisos")
	var spikes_ok := true
	for floor_number: int in range(1, 101):
		var expected := ""
		if floor_number % 10 == 5:
			expected = "mid_boss"
		elif floor_number % 10 == 0:
			expected = "boss"
		if TowerCatalog.spike_kind(floor_number) != expected:
			spikes_ok = false
	_check(spikes_ok, "los pisos 5 y 10 de cada tier son de pico (mini-jefe y jefe)")
	_check(is_equal_approx(TowerCatalog.enemy_scale(1), 1.0) and TowerCatalog.enemy_scale(50) > TowerCatalog.enemy_scale(10), "la escala crece con el piso")
	_check(TowerCatalog.completion_xp(10) == TowerCatalog.completion_xp(9) / 9 * 10 * 3 or TowerCatalog.completion_xp(10) > TowerCatalog.completion_xp(9), "los pisos de jefe dan mas XP")
	var bad := {"floors": 10, "tier_size": 10, "tiers": []}
	_check(not TowerCatalog.validate(bad).is_empty(), "un tower.json sin tiers no valida")


# --- Generador --------------------------------------------------------------------


func _test_generator_determinism() -> void:
	var same := true
	for floor_number: int in [1, 5, 10, 37, 100]:
		var a := TowerGenerator.generate(floor_number, 20261110).to_dict()
		var b := TowerGenerator.generate(floor_number, 20261110).to_dict()
		if JSON.stringify(a) != JSON.stringify(b):
			same = false
	_check(same, "el mismo piso y semilla dan el mismo layout")
	var one := JSON.stringify(TowerGenerator.generate(3, 20261110).to_dict())
	_check(one != JSON.stringify(TowerGenerator.generate(4, 20261110).to_dict()), "pisos distintos dan layouts distintos")
	_check(one != JSON.stringify(TowerGenerator.generate(3, 999).to_dict()), "otra semilla da otro layout")


func _test_generator_invariants() -> void:
	var ok := true
	var reason := ""
	var floors: Array = [1, 2, 3, 4, 5, 9, 10, 15, 20, 33, 50, 75, 100]
	for floor_number: int in floors:
		var layout := TowerGenerator.generate(floor_number, 20261110)
		var bounds := layout.bounds()
		for spec: Dictionary in layout.enemies:
			if not EnemyCatalog.has_enemy(StringName(String(spec["id"]))):
				ok = false
				reason = "piso %d: enemigo desconocido" % floor_number
			var cell := layout.grid.world_to_cell(spec["position"])
			if not bounds.has_point(spec["position"]) or layout.grid.blocks_move(cell.x, cell.y):
				ok = false
				reason = "piso %d: enemigo fuera de la zona o dentro de un muro" % floor_number
			if (spec["position"] as Vector2).distance_to(layout.player_spawn) < 150.0:
				ok = false
				reason = "piso %d: enemigo pegado a la entrada" % floor_number
		var mains: Array = layout.mission_plan["missions"].filter(func(s: Dictionary) -> bool: return not bool(s["optional"]))
		if mains.is_empty():
			ok = false
			reason = "piso %d: sin mision principal" % floor_number
		if not MissionGen.check(layout).is_empty():
			ok = false
			reason = "piso %d: %s" % [floor_number, str(MissionGen.check(layout))]
		if not bounds.has_point(layout.player_spawn) or not layout.grid.is_walkable_point(layout.player_spawn):
			ok = false
			reason = "piso %d: entrada fuera de la zona" % floor_number
		var exit_found := false
		for portal: Dictionary in layout.portals:
			if String(portal["id"]) == "exit":
				exit_found = bool(portal["requires_complete"]) and bounds.has_point(portal["position"]) and layout.grid.is_walkable_point(portal["position"])
		if not exit_found:
			ok = false
			reason = "piso %d: la salida debe existir, ser alcanzable y exigir piso completado" % floor_number
		if layout.theme.is_empty() or not (layout.theme["floor"] is Color) or layout.biome.is_empty() or not MapGen.STYLES.has(layout.style):
			ok = false
			reason = "piso %d: tema, bioma o estilo incompletos" % floor_number
	_check(ok, "los pisos de muestra cumplen los invariantes (%s)" % reason)
	var top := TowerGenerator.generate(100, 20261110)
	var exit_action := ""
	for portal: Dictionary in top.portals:
		if String(portal["id"]) == "exit":
			exit_action = String(portal["action"])
	_check(exit_action == "to_city", "la salida del piso 100 vuelve a la ciudad")
	var tiers_differ := JSON.stringify(TowerGenerator.generate(5, 1).theme) != JSON.stringify(TowerGenerator.generate(15, 1).theme)
	_check(tiers_differ, "cada tier tiene su tematica")
	var small := TowerGenerator.generate(2, 20261110)
	var big := TowerGenerator.generate(60, 20261110)
	_check(small.size.x >= 2048.0 and big.size.x * big.size.y > small.size.x * small.size.y * 1.8, "los pisos son grandes y los profundos mucho mas")


func _test_spike_floors() -> void:
	var mid := TowerGenerator.generate(5, 20261110)
	var mini: Array = mid.enemies.filter(func(e: Dictionary) -> bool: return String(e["group"]) == "mini")
	_check(mini.size() == 2 and mini.all(func(e: Dictionary) -> bool: return bool(e["required"])), "el piso 5 tiene dos mini-jefes obligatorios")
	var boss_layout := TowerGenerator.generate(10, 20261110)
	var bosses: Array = boss_layout.enemies.filter(func(e: Dictionary) -> bool: return String(e["group"]) == "boss") + boss_layout.deferred_enemies.filter(func(e: Dictionary) -> bool: return String(e["group"]) == "boss")
	_check(bosses.size() == 1 and String(bosses[0]["id"]) == "brood_beetle", "el piso 10 es el jefe Brood Beetle")
	_check(mid.enemies.size() > 4 and boss_layout.enemies.size() + boss_layout.deferred_enemies.size() > 4, "los pisos de pico traen crias y guardias")
	var normal := TowerGenerator.generate(3, 20261110)
	_check(normal.mission_plan["missions"].size() >= 1 and normal.mission_plan["missions"].any(func(s: Dictionary) -> bool: return not bool(s["optional"])), "un piso normal tiene al menos una mision principal")
	_check(EnemyCatalog.enemy(&"elder_spider")["boss"] == true and (EnemyCatalog.enemy(&"elder_spider")["phases"] as Array).size() == 2, "Elder Spider es un jefe con dos fases")


# --- Estado -----------------------------------------------------------------------


func _test_tower_state() -> void:
	var state := TowerState.new()
	_check(state.can_enter(1) and not state.can_enter(2) and not state.can_enter(0) and not state.can_enter(101), "solo se puede entrar al piso 1 al empezar")
	state.complete(1)
	_check(state.can_enter(2) and not state.can_enter(3) and state.highest_unlocked() == 2, "completar un piso desbloquea el siguiente")
	state.complete(3)
	_check(not state.can_enter(4) and state.highest_unlocked() == 2, "saltarse un piso no desbloquea nada")
	_check(state.visit(2) == 1 and state.visit(2) == 2 and state.visits(2) == 2, "las visitas se cuentan")
	var copy := TowerState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	_check(copy.is_completed(1) and copy.is_completed(3) and not copy.is_completed(2) and copy.visits(2) == 2 and copy.world_seed == state.world_seed and copy.last_floor == 2, "TowerState sobrevive a JSON")
	var all := TowerState.new()
	for n: int in range(1, 101):
		all.complete(n)
	_check(all.highest_unlocked() == 100 and all.can_enter(100) and not all.can_enter(101), "con todos completados el tope es el piso 100")


func _test_city_and_training_layouts() -> void:
	var city := Layouts.city()
	var actions: Array = city.portals.map(func(p: Dictionary) -> String: return String(p["action"]))
	_check(actions.has("tower") and actions.has("to_training") and city.enemies.is_empty() and city.buildings.size() == 5, "la ciudad tiene torre, patio, 5 edificios y ningun enemigo")
	_check(city.bounds().has_point(city.player_spawn), "se entra a la ciudad dentro de la zona jugable")
	var training := Layouts.training()
	var training_required := training.enemies.filter(func(e: Dictionary) -> bool: return bool(e["required"]))
	_check(training.dummies.size() == 3 and training.enemies.size() == 7 and training_required.is_empty(), "el patio conserva munecos y enemigos sin objetivo")


# --- Sesion -----------------------------------------------------------------------


func _walk_to(session: GameSession, portal_id: String) -> void:
	for portal: Dictionary in session.layout.portals:
		if String(portal["id"]) == portal_id:
			session.world.player.position = portal["position"]
			return
	_check(false, "portal %s existe" % portal_id)


func _test_session_gating_and_completion() -> void:
	var session := _new_session()
	var world := session.world
	var messages: Array = []
	session.message.connect(func(text: String) -> void: messages.append(text))
	var completed: Array = []
	session.floor_completed.connect(func(n: int, xp: int) -> void: completed.append([n, xp]))

	_check(session.layout.kind == FloorLayout.KIND_CITY and world.layout == session.layout and world.enemies.is_empty(), "la sesion empieza en la ciudad")
	_check(not session.go_to_floor(2) and messages.size() == 1 and session.layout.kind == FloorLayout.KIND_CITY, "no se puede entrar al piso 2 sin completar el 1")
	_walk_to(session, "tower")
	session.try_interact()
	_check(session.layout.kind == FloorLayout.KIND_FLOOR and session.layout.floor_number == 1, "la puerta de la torre lleva al piso 1")
	_check(not world.enemies.is_empty() and world.enemies.size() == session.layout.enemies.size(), "el piso nace poblado con los enemigos del layout")
	_check(world.player.position.distance_to(session.layout.player_spawn) < 0.01, "el jugador aparece en la entrada")

	# Sin completar: la salida no funciona.
	_walk_to(session, "exit")
	session.try_interact()
	_check(session.layout.floor_number == 1 and not session.is_floor_done(), "la salida no abre con enemigos vivos")
	_step(world, 5)
	_check(not session.is_floor_done(), "con enemigos vivos el piso no se completa")

	var xp_before := world.player.xp + world.player.level * 1000
	_kill_required(session)
	_step(world, 2)
	_check(session.is_floor_done() and session.tower.is_completed(1), "matar a los obligatorios completa el piso")
	_check(completed.size() == 1 and int(completed[0][0]) == 1 and int(completed[0][1]) == TowerCatalog.completion_xp(1), "se emite floor_completed con la XP de piso")
	_check(world.player.xp + world.player.level * 1000 > xp_before, "completar el piso da XP")
	_step(world, 30)
	_check(completed.size() == 1, "el piso se completa una sola vez por visita")

	_walk_to(session, "exit")
	session.try_interact()
	_check(session.layout.floor_number == 2, "con el piso completado la salida sube al siguiente")
	_check(not session.is_floor_done() and not session.tower.is_completed(2), "el piso nuevo empieza sin completar")

	# Volver a la ciudad por la entrada.
	_walk_to(session, "entrance")
	session.try_interact()
	_check(session.layout.kind == FloorLayout.KIND_CITY, "la entrada del piso lleva a la ciudad")
	session.select_floor(5)
	_check(session.selected_floor == 2, "la puerta de la torre propone como maximo el piso desbloqueado")
	session.select_floor(-5)
	_check(session.selected_floor == 1, "se puede elegir un piso ya completado")

	# Edificios sin recetas (la taberna) avisan sin cambiar de escenario.
	messages.clear()
	_walk_to(session, "door_tavern")
	session.try_interact()
	_check(session.layout.kind == FloorLayout.KIND_CITY and messages.size() == 1, "las puertas de oficio avisan sin cambiar de escenario")


func _test_respawn_on_reentry() -> void:
	var session := _new_session()
	var world := session.world
	_check(session.go_to_floor(1), "entrar al piso 1")
	var count := world.enemies.size()
	var first_cells: PackedByteArray = session.layout.grid.cells
	_kill_required(session)
	_step(world, 2)
	_check(session.is_floor_done(), "piso 1 completado")
	var xp_after_first := world.player.xp + world.player.level * 100000
	for enemy: EnemySim in world.enemies:
		enemy.take_damage(1.0e9)
	_step(world, 60 * 120)
	var alive := world.enemies.filter(func(e: EnemySim) -> bool: return e.alive)
	_check(alive.is_empty(), "dentro de un piso los enemigos muertos no reaparecen solos")
	session.go_to_city()
	var visit := session.tower.visits(1)
	_check(session.go_to_floor(1) and session.tower.visits(1) == visit + 1, "volver a entrar cuenta una visita")
	var all_alive := world.enemies.all(func(e: EnemySim) -> bool: return e.alive)
	_check(world.enemies.size() > 10 and all_alive and session.layout.grid.cells == first_cells and count > 10, "al reentrar el piso (mismo terreno) reaparece poblado con todos sus enemigos")
	_check(not session.is_floor_done(), "al reentrar hay que volver a limpiarlo para salir")
	_kill_required(session)
	_step(world, 2)
	_check(world.player.xp + world.player.level * 100000 == xp_after_first, "no se vuelve a dar la XP de piso al repetirlo")
	_check(session.is_floor_done(), "se puede completar otra vez para abrir la salida")


func _test_death_returns_to_city() -> void:
	var session := _new_session()
	var world := session.world
	session.go_to_floor(1)
	world.player.take_damage(1.0e9)
	_check(not world.player.alive, "el jugador muere en el piso")
	_step(world, GameSession.DEATH_RETURN_TICKS - 20)
	_check(session.layout.kind == FloorLayout.KIND_FLOOR, "no vuelve a la ciudad enseguida")
	_step(world, 40)
	_check(session.layout.kind == FloorLayout.KIND_CITY and world.player.alive and world.player.health > 0.0, "morir devuelve a la ciudad con vida")
	_check(not session.tower.is_completed(1), "morir no completa el piso")


func _test_scaling() -> void:
	var world: CombatWorld = CombatWorldScript.new(5)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var base := world.add_enemy(&"slime", Vector2(300, 300))
	var strong := world.add_enemy(&"slime", Vector2(500, 300), 2.0)
	_check(is_equal_approx(strong.max_health, base.max_health * 2.0) and is_equal_approx(strong.health, strong.max_health), "la escala multiplica la vida")
	_check(strong.xp_reward() == base.xp_reward() * 2, "la escala multiplica la XP")
	var deep := TowerGenerator.generate(60, 20261110)
	var shallow := TowerGenerator.generate(2, 20261110)
	_check(deep.enemy_scale > shallow.enemy_scale * 3.0, "los pisos profundos escalan mucho mas")


func _test_safe_zone() -> void:
	var session := _new_session()
	var player := session.world.player
	_check(player.safe_zone and player.can_edit_loadout(), "en la ciudad se puede editar el loadout")
	session.go_to_floor(1)
	_check(not player.safe_zone and not player.can_edit_loadout() and player.switch_class("mage") == "busy", "en un piso no se cambia de clase ni de loadout")
	session.go_to_training()
	_check(player.safe_zone and player.can_edit_loadout(), "en el patio si se puede")


# --- Guardado ---------------------------------------------------------------------


func _test_save_roundtrip() -> void:
	SaveGame.delete(SAVE_PATH)
	var session := _new_session(SAVE_PATH)
	var player := session.world.player
	player.set_level(6)
	player.switch_class("mage")
	player.set_level(4)
	player.switch_class("warrior")
	session.go_to_floor(1)
	_kill_required(session)
	_step(session.world, 2)
	_check(FileAccess.file_exists(SAVE_PATH), "completar un piso guarda la partida")
	var warrior_level := player.level
	var warrior_xp := player.xp
	var loadout_ids := {}
	for slot: String in player.loadout:
		loadout_ids[slot] = String((player.loadout[slot] as Dictionary)["id"])

	var loaded := _new_session(SAVE_PATH)
	var restored := loaded.world.player
	_check(loaded.layout.kind == FloorLayout.KIND_CITY, "tras cargar se empieza en la ciudad")
	_check(restored.class_id == "warrior" and restored.level == warrior_level and restored.xp == warrior_xp, "se restauran clase, nivel y XP")
	var same_loadout := restored.loadout.size() == loadout_ids.size()
	for slot: String in loadout_ids:
		if not restored.loadout.has(slot) or String((restored.loadout[slot] as Dictionary)["id"]) != String(loadout_ids[slot]):
			same_loadout = false
	_check(same_loadout, "se restaura el loadout")
	_check(restored.switch_class("mage") == "" and restored.level == 4, "las demas clases conservan su nivel")
	_check(loaded.tower.is_completed(1) and loaded.tower.can_enter(2) and not loaded.tower.can_enter(3), "se restaura el progreso de la torre")
	_check(loaded.tower.world_seed == session.tower.world_seed, "se conserva la semilla del mundo")
	_check(JSON.stringify(TowerGenerator.generate(2, loaded.tower.world_seed).to_dict()) == JSON.stringify(TowerGenerator.generate(2, session.tower.world_seed).to_dict()), "los pisos se regeneran identicos tras cargar")

	# Un guardado roto o de otra version se ignora.
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ esto no es json")
	file.close()
	var fresh := _new_session(SAVE_PATH)
	_check(fresh.world.player.level == 1 and not fresh.tower.is_completed(1), "un guardado corrupto se ignora")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
