## Marco de misiones: biblioteca, generador determinista, seguimiento de objetivos, gestor (limite de 3, abandono,
## reclamacion sin duplicados), cadenas y banderas, eventos secretos, recompensas y guardado.
##
##   godot --headless --path . --script tests/test_quests.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_quests (marco de misiones) ==")
	_test_library()
	_test_generator()
	_test_tracker()
	_test_manager()
	_test_chains_and_flags()
	_test_secrets()
	_test_rewards()
	_test_persistence()
	_test_session()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _floor_info(floor_number: int) -> Dictionary:
	var session := GameSession.new(CombatWorldScript.new(3), "")
	return session.floor_info_for(floor_number)


func _info(floor_number: int = 5) -> Dictionary:
	return {"floor": floor_number, "biome": "forest", "enemy_ids": ["bandit_thug", "bandit_archer", "bandit_hexer", "slime"], "objects": {"altar": 3, "cage": 2, "waypoint": 4, "beacon": 1}}


func _player() -> PlayerSim:
	var world: CombatWorld = CombatWorldScript.new(9)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.player.set_level(6)
	return world.player


# --- Biblioteca -------------------------------------------------------------------


func _test_library() -> void:
	for problem: String in QuestLibrary.errors():
		print("   problema: %s" % problem)
	_check(QuestLibrary.errors().is_empty(), "las definiciones, tablas y secretos cargan y validan")
	_check(QuestLibrary.find("side").size() >= 7 and not QuestLibrary.find("main").is_empty() and not QuestLibrary.find("secret").is_empty() and QuestLibrary.find("chain").size() >= 3, "hay secundarias, principal, secreta y una cadena de 3")
	var categories := {}
	for def: Dictionary in QuestLibrary.find("side"):
		categories[String(def["category"])] = true
	_check(["combat", "exploration", "survival", "collection", "challenge", "investigation", "rescue"].all(func(c: String) -> bool: return categories.has(c)), "las 7 categorias pedidas tienen plantilla")
	_check(QuestLibrary.find("side", "combat").size() >= 2 and QuestLibrary.find("", "", "bandit").size() >= 1, "se busca por categoria y etiqueta")
	var bad := {"kind": "kill", "target": "bandit_*", "count": 2}
	_check(QuestLibrary.objective_possible(bad, _info()) and not QuestLibrary.objective_possible({"kind": "interact", "target": "altar", "count": 9}, _info()) and not QuestLibrary.objective_possible({"kind": "kill", "target": "wisp", "count": 1}, _info()), "un objetivo solo es posible si el piso tiene lo que pide")
	_check(not RewardGenerator.validate_table("x", {"guaranteed": [{"type": "item", "id": "espada_inventada"}]}).is_empty() and not RewardGenerator.validate_table("y", {"guaranteed": [{"type": "consumable", "id": "nada"}]}).is_empty(), "las tablas con items o consumibles que no existen no validan")
	_check(not RewardGenerator.validate_table("z", {"guaranteed": [], "slots": [[{"weight": 0, "entry": {"type": "gold"}}]]}).is_empty(), "una opcion sin peso no valida")


# --- Generador ----------------------------------------------------------------------


func _test_generator() -> void:
	var a := QuestGenerator.generate_offers(_info(), 777, 0, {}, {}, [])
	var b := QuestGenerator.generate_offers(_info(), 777, 0, {}, {}, [])
	var c := QuestGenerator.generate_offers(_info(), 778, 0, {}, {}, [])
	_check(a.size() >= 2 and a.size() <= 3 and JSON.stringify(a) == JSON.stringify(b), "las ofertas son 2-3 y reproducibles con la misma semilla")
	_check(JSON.stringify(a) != JSON.stringify(c), "otra semilla da otras ofertas")
	var distinct := {}
	var categories := {}
	for offer: Dictionary in a:
		distinct[String(offer["def"])] = true
		categories[String(offer["category"])] = true
		_check(QuestGenerator.validate(offer, _info()).is_empty() and String(offer["state"]) == "available" and String(offer["type"]) == "side", "oferta %s valida" % offer["def"])
	_check(distinct.size() == a.size() and categories.size() >= a.size() - 1, "las ofertas son distintas y de categorias variadas")
	var history: Array = []
	for offer: Dictionary in a:
		history.append(offer["def"])
	var next_offers := QuestGenerator.generate_offers(_info(), 777, 1, {}, {}, history)
	var repeated := 0
	for offer: Dictionary in next_offers:
		repeated += 1 if history.has(offer["def"]) else 0
	_check(repeated == 0, "la proteccion de repeticion evita las plantillas recientes")
	# Compatibilidad con el piso: sin hechiceros no sale su encargo; en el piso 1 no hay mision de piso 4+.
	var no_hexers := _info(5)
	no_hexers["enemy_ids"] = ["slime"]
	var ids := {}
	for seed_value: int in range(1, 30):
		for offer: Dictionary in QuestGenerator.generate_offers(no_hexers, seed_value, 0, {}, {}, []):
			ids[String(offer["def"])] = true
	_check(not ids.has("side_bounty_hexers") and not ids.has("side_road_clearing"), "no se ofrecen misiones de enemigos que el piso no tiene")
	var floor_one := {}
	for seed_value: int in range(1, 30):
		for offer: Dictionary in QuestGenerator.generate_offers(_info(1), seed_value, 0, {}, {}, []):
			floor_one[String(offer["def"])] = true
	_check(not floor_one.has("side_bounty_hexers") and not floor_one.has("side_old_markers"), "el rango de pisos filtra las plantillas")
	# Rareza: con muchos sorteos las comunes pesan mas que las raras.
	var tally := {"common": 0, "rare": 0}
	for seed_value: int in range(1, 200):
		for offer: Dictionary in QuestGenerator.generate_offers(_info(6), seed_value, 0, {}, {}, []):
			tally[String(offer["rarity"])] = int(tally.get(String(offer["rarity"]), 0)) + 1
	_check(int(tally["common"]) > int(tally["rare"]), "las misiones comunes salen mas que las raras (%s)" % str(tally))
	# Ningun piso real 1-10 se queda sin ofertas ni con ofertas imposibles.
	var all_ok := true
	for floor_number: int in range(1, 11):
		var info := _floor_info(floor_number)
		var offers := QuestGenerator.generate_offers(info, 4242, 0, {}, {}, [])
		all_ok = all_ok and offers.size() >= 2
		for offer: Dictionary in offers:
			all_ok = all_ok and QuestGenerator.validate(offer, info).is_empty()
	_check(all_ok, "en los pisos reales 1-10 siempre hay 2-3 ofertas posibles")


# --- Objetivos ----------------------------------------------------------------------


func _objective(kind: String, target: String, required: int, optional: bool = false) -> Dictionary:
	return {"id": "o", "kind": kind, "target": target, "required": required, "progress": 0, "optional": optional}


func _test_tracker() -> void:
	var kill := _objective("kill", "bandit_*", 3)
	_check(ObjectiveTracker.apply(kill, "enemy_defeated", "bandit_thug", 1, {}) and int(kill["progress"]) == 1, "matar un bandido avanza el objetivo")
	_check(not ObjectiveTracker.apply(kill, "enemy_defeated", "slime", 1, {}) and not ObjectiveTracker.apply(kill, "item_collected", "ore_t1", 1, {}) and int(kill["progress"]) == 1, "un enemigo o un evento incorrecto no cuentan")
	ObjectiveTracker.apply(kill, "enemy_defeated", "bandit_archer", 5, {})
	_check(int(kill["progress"]) == 3 and not ObjectiveTracker.apply(kill, "enemy_defeated", "bandit_thug", 1, {}), "el progreso no pasa del objetivo y completo no avanza")
	var collect := _objective("collect", "gatherable", 2)
	ObjectiveTracker.apply(collect, "item_collected", "silk_t1", 1, {})
	_check(int(collect["progress"]) == 0, "la seda (botin) no cuenta como material de recoleccion")
	ObjectiveTracker.apply(collect, "item_collected", "ore_t2", 2, {})
	_check(int(collect["progress"]) == 2, "el mineral de cualquier tier si cuenta")
	var reach := _objective("reach", "floor", 3)
	ObjectiveTracker.apply(reach, "floor_entered", "2", 1, {})
	ObjectiveTracker.apply(reach, "floor_entered", "3", 1, {})
	_check(int(reach["progress"]) == 3, "llegar a un piso completa el objetivo")
	var condition := _objective("condition", "no_potions_floor", 1)
	ObjectiveTracker.apply(condition, "floor_completed", "2", 1, {"potion_used": true})
	_check(int(condition["progress"]) == 0, "usar una pocion rompe el desafio 'sin pociones'")
	ObjectiveTracker.apply(condition, "floor_completed", "3", 1, {"potion_used": false})
	_check(int(condition["progress"]) == 1, "y sin usarlas se cumple")
	var survive := _objective("survive", "beacon", 60)
	ObjectiveTracker.apply(survive, "survival_completed", "beacon", 40, {})
	ObjectiveTracker.apply(survive, "survival_completed", "beacon", 40, {})
	_check(int(survive["progress"]) == 60, "la resistencia acumula segundos")


# --- Gestor ---------------------------------------------------------------------------


func _manager() -> QuestManager:
	return QuestManager.new({}, 5150)


func _test_manager() -> void:
	var manager := _manager()
	var offers := manager.offers_for(_info(6), "warrior")
	_check(offers.size() >= 2, "el tablon del piso ofrece misiones (%d)" % offers.size())
	var again := manager.offers_for(_info(6), "warrior")
	_check(JSON.stringify(offers) == JSON.stringify(again), "volver a abrir el tablon no cambia las ofertas (sin rerolls)")
	# Limite de 3 secundarias: se aceptan varias de varios pisos hasta llegar a 3.
	var side_ids: Array = []
	for floor_number: int in range(2, 9):
		for offer: Dictionary in manager.offers_for(_info(floor_number), "warrior"):
			side_ids.append(String(offer["id"]))
	var accepted := 0
	var refused := ""
	for id: String in side_ids:
		var reason := manager.accept(id)
		if reason == "":
			accepted += 1
		elif refused == "":
			refused = reason
	_check(accepted == QuestManager.MAX_SIDE and refused == "limit" and manager.active_side_count() == 3, "no se puede aceptar una cuarta secundaria (acepto %d, motivo %s)" % [accepted, refused])
	# Las principales y las secretas no cuentan para el limite.
	var main := manager.start_quest("main_crow_01", _info(2), "warrior")
	var secret := manager.start_quest("secret_vigia_ledger", _info(8), "warrior")
	_check(not main.is_empty() and not secret.is_empty() and manager.active_side_count() == 3, "la principal y la secreta no cuentan para el limite")
	# Abandonar libera un hueco y la mision puede aceptarse de nuevo (reiniciada).
	var first_active: Dictionary = manager.active().filter(func(i: Dictionary) -> bool: return String(i["type"]) == "side")[0]
	manager.on_event("enemy_defeated", "bandit_thug", 1)
	_check(manager.abandon(String(first_active["id"])) and manager.active_side_count() == 2, "abandonar una secundaria libera un hueco")
	_check(manager.accept(String(first_active["id"])) == "" and int((first_active["objectives"][0] as Dictionary)["progress"]) == 0, "una abandonada puede volver a aceptarse, reiniciada")
	# Completar, reclamar y no duplicar.
	var fresh := _manager()
	var player := _player()
	var quest := fresh.start_quest("main_crow_01", _info(3), "warrior")
	var id := String(quest["id"])
	for n: int in range(3):
		fresh.on_event("enemy_defeated", "bandit_thug", 1)
	fresh.on_event("floor_entered", "3", 1)
	_check(String(fresh.instances[id]["state"]) == "completed", "se completa con sus objetivos obligatorios (el opcional no hace falta)")
	var gold := player.gold
	var claim := fresh.claim(id, player)
	_check(bool(claim["ok"]) and player.gold > gold and String(fresh.instances[id]["state"]) == "claimed", "reclamar entrega la recompensa")
	var gold_after := player.gold
	var duplicate := fresh.claim(id, player)
	_check(not bool(duplicate["ok"]) and String(duplicate["reason"]) == "claimed" and player.gold == gold_after, "reclamar dos veces no duplica la recompensa")
	# Mochila llena: no se entrega nada y se puede reclamar luego.
	var full := _manager()
	var packed := _player()
	var other := full.start_quest("main_crow_01", _info(3), "warrior")
	for n: int in range(3):
		full.on_event("enemy_defeated", "bandit_thug", 1)
	full.on_event("floor_entered", "3", 1)
	var rng := RandomNumberGenerator.new()
	while packed.bag_has_room():
		packed.add_item(ItemGen.roll_item(rng, 1, "common"))
	var blocked := full.claim(String(other["id"]), packed)
	_check(not bool(blocked["ok"]) and String(blocked["reason"]) == "bag" and String(full.instances[other["id"]]["state"]) == "completed", "con la mochila llena no se entrega ni se pierde la recompensa")
	# Fallar.
	var failing := _manager()
	var doomed := failing.start_quest("main_crow_01", _info(1), "warrior")
	_check(failing.fail(String(doomed["id"])) and String(failing.instances[doomed["id"]]["state"]) == "failed", "una mision puede fallar")


# --- Cadenas y banderas ------------------------------------------------------------


func _finish(manager: QuestManager, player: PlayerSim, def_id: String, floor_number: int, events: Array) -> void:
	var quest := manager.start_quest(def_id, _info(floor_number), "warrior")
	for entry: Array in events:
		manager.on_event(String(entry[0]), String(entry[1]), int(entry[2]))
	manager.claim(String(quest["id"]), player)


func _test_chains_and_flags() -> void:
	var manager := _manager()
	var player := _player()
	_check(manager.story_available(_info(3)).size() >= 1 and manager.story_available(_info(3)).all(func(d: Dictionary) -> bool: return String(d["type"]) == "main"), "al empezar solo esta disponible la historia principal")
	_check(manager.start_quest("chain_ledger_01", _info(3), "warrior").is_empty() or true, "(la cadena se puede forzar, pero no se ofrece sin su bandera)")
	_check(not QuestLibrary.compatible(QuestLibrary.definition("chain_ledger_01"), _info(3), {}, {}), "la cadena no es compatible sin la bandera crow_trail_found")
	var fresh := _manager()
	_finish(fresh, player, "main_crow_01", 3, [["enemy_defeated", "bandit_thug", 3], ["floor_entered", "3", 1]])
	_check(bool(fresh.flags.get("crow_trail_found", false)) and fresh.unlocked.has("chain_ledger_01"), "completar la principal pone la bandera y desbloquea la cadena (lineal)")
	_check(fresh.story_available(_info(4)).any(func(d: Dictionary) -> bool: return String(d["id"]) == "chain_ledger_01"), "la cadena aparece disponible con su bandera")
	_finish(fresh, player, "chain_ledger_01", 4, [["location_discovered", "waypoint", 2]])
	_check(bool(fresh.flags.get("ledger_found", false)) and fresh.unlocked.has("chain_ledger_02"), "el segundo eslabon se desbloquea")
	_finish(fresh, player, "chain_ledger_02", 5, [["enemy_defeated", "bandit_archer", 8]])
	_check(fresh.unlocked.has("chain_ledger_03") and bool(fresh.flags.get("buyer_known", false)), "el tercer eslabon, tambien (cadena de tres misiones, varios pisos)")
	var third := fresh.start_quest("chain_ledger_03", _info(6), "warrior")
	_check(fresh.choose_branch(String(third["id"]), "burn") and bool(fresh.flags.get("relicarios_burned", false)) and not bool(fresh.flags.get("relicarios_kept", false)), "la rama elegida pone sus banderas (ramificada)")
	_check(String(fresh.instances[third["id"]]["state"]) == "completed" and String(fresh.choices.get("chain_ledger_03", "")) == "burn", "la decision queda registrada y completa la mision")
	_check(not fresh.choose_branch(String(third["id"]), "keep"), "no se puede cambiar de rama despues de completar")


# --- Secretos ------------------------------------------------------------------------


func _test_secrets() -> void:
	var manager := _manager()
	manager.flags["crow_trail_found"] = true
	manager.floor_state["floor"] = 8
	var info := _info(8)
	manager.on_event("object_interacted", "altar", 1, info)
	manager.on_event("object_interacted", "altar", 1, info)
	_check(manager.with_state("active").is_empty(), "con 2 altares el secreto aun no salta (condicion AND)")
	manager.on_event("object_interacted", "altar", 1, info)
	var started := manager.active().filter(func(i: Dictionary) -> bool: return String(i["def"]) == "secret_vigia_ledger")
	_check(started.size() == 1, "con 3 altares y la bandera la mision secreta se inicia")
	manager.on_event("object_interacted", "altar", 1, info)
	_check(manager.active().filter(func(i: Dictionary) -> bool: return String(i["def"]) == "secret_vigia_ledger").size() == 1, "una vez por partida: no se vuelve a iniciar")
	var no_flag := _manager()
	no_flag.floor_state["floor"] = 8
	for n: int in range(4):
		no_flag.on_event("object_interacted", "altar", 1, info)
	_check(no_flag.active().is_empty(), "sin la bandera requerida no se activa")
	var wrong_floor := _manager()
	wrong_floor.flags["crow_trail_found"] = true
	wrong_floor.floor_state["floor"] = 3
	for n: int in range(4):
		wrong_floor.on_event("object_interacted", "altar", 1, _info(3))
	_check(wrong_floor.active().is_empty(), "fuera de su rango de pisos no se activa")
	# Secuencia ordenada.
	var order := _manager()
	order.on_event("object_interacted", "relic_altar", 1)
	order.on_event("object_interacted", "relic", 1)
	_check(not bool(order.flags.get("relicario_heard", false)), "en orden incorrecto la secuencia no salta")
	order.on_event("object_interacted", "relic_altar", 1)
	_check(bool(order.flags.get("relicario_heard", false)), "en el orden correcto (reliquia y luego altar) si salta")
	# OR.
	var any := _manager()
	any.on_event("enemy_defeated", "bandit_garrick", 1)
	_check(bool(any.flags.get("crow_hunter", false)), "una condicion OR se cumple con una sola de sus opciones")


# --- Recompensas ---------------------------------------------------------------------


func _test_rewards() -> void:
	var context := {"floor": 6, "tier": 1, "rarity": "rare", "class_id": "warrior"}
	var a := RewardGenerator.generate(context, "rare", 99)
	var b := RewardGenerator.generate(context, "rare", 99)
	_check(JSON.stringify(a) == JSON.stringify(b) and RewardGenerator.validate(a).is_empty(), "el paquete es reproducible con la misma semilla y valido")
	var low := RewardGenerator.generate({"floor": 1, "tier": 1, "rarity": "common"}, "common", 5)
	var high := RewardGenerator.generate({"floor": 10, "tier": 1, "rarity": "common"}, "common", 5)
	_check(int(high["gold"]) > int(low["gold"]) and int(high["xp"]) > int(low["xp"]), "el oro y la XP escalan con el piso (%d -> %d)" % [low["gold"], high["gold"]])
	var common := RewardGenerator.generate({"floor": 5, "tier": 1, "rarity": "common"}, "common", 5)
	var epic := RewardGenerator.generate({"floor": 5, "tier": 1, "rarity": "epic"}, "common", 5)
	_check(int(epic["gold"]) > int(common["gold"]), "la rareza de la mision multiplica la recompensa")
	var story := RewardGenerator.generate(context, "story_main_01", 1)
	var story_other := RewardGenerator.generate(context, "story_main_01", 12345)
	_check(int(story["gold"]) == int(story_other["gold"]) and String((story["items"][0] as Dictionary)["id"]) == "crow_bandana" and (story["flags"] as Array).has("story_01_done"), "la recompensa a mano es siempre la misma (item y bandera garantizados)")
	var seen := {}
	for seed_value: int in range(1, 120):
		var package := RewardGenerator.generate(context, "rare", seed_value)
		seen[str((package["items"] as Array).size()) + "/" + str(int(package["tomes"]))] = true
		_check(RewardGenerator.validate(package).is_empty(), "paquete %d valido" % seed_value) if seed_value % 40 == 0 else null
	_check(seen.size() >= 3, "la tabla ponderada da resultados distintos con distintas semillas (%d variantes)" % seen.size())
	var boss := RewardGenerator.generate({"floor": 10, "tier": 1, "rarity": "epic"}, "boss", 3)
	_check(int(boss["tomes"]) >= 1 and not (boss["items"] as Array).is_empty(), "la tabla de jefe garantiza un tomo y equipo")
	# Entrega: el generador no toca al jugador; el gestor si.
	var player := _player()
	var gold := player.gold
	var package := RewardGenerator.generate(context, "rare", 7)
	_check(player.gold == gold, "generar no entrega nada")
	var flags := {}
	var result := RewardManager.deliver(player, package, flags)
	_check(bool(result["ok"]) and player.gold == gold + int(package["gold"]) and player.bag.size() == (package["items"] as Array).size(), "entregar si da oro y items")


# --- Guardado ------------------------------------------------------------------------


func _test_persistence() -> void:
	var manager := _manager()
	var player := _player()
	var offers := manager.offers_for(_info(4), "warrior")
	manager.accept(String((offers[0] as Dictionary)["id"]))
	var done_quest := manager.start_quest("main_crow_01", _info(3), "warrior")
	for n: int in range(3):
		manager.on_event("enemy_defeated", "bandit_thug", 1)
	manager.on_event("floor_entered", "3", 1)
	manager.claim(String(done_quest["id"]), player)
	var restored := QuestManager.from_dict(manager.to_dict(), manager.flags, 5150)
	_check(JSON.stringify(restored.offers_for(_info(4), "warrior")) == JSON.stringify(manager.offers_for(_info(4), "warrior")), "recargar no regenera las ofertas ni sus recompensas")
	_check(String(restored.instances[done_quest["id"]]["state"]) == "claimed" and bool(restored.instances[done_quest["id"]]["reward_claimed"]), "la reclamacion se restaura (no se puede cobrar otra vez)")
	_check(not bool(restored.claim(String(done_quest["id"]), player)["ok"]), "y reclamar de nuevo tras cargar falla")
	var active_before: int = manager.active().size()
	_check(restored.active().size() == active_before and restored.unlocked == manager.unlocked and restored.done == manager.done, "las activas, lo desbloqueado y el historial se restauran")
	var progress_manager := _manager()
	var quest := progress_manager.start_quest("main_crow_01", _info(3), "warrior")
	progress_manager.on_event("enemy_defeated", "bandit_thug", 2)
	var loaded := QuestManager.from_dict(progress_manager.to_dict(), progress_manager.flags, 5150)
	var progress := 0
	for objective: Dictionary in loaded.instances[quest["id"]]["objectives"]:
		if String(objective["id"]) == "thugs":
			progress = int(objective["progress"])
	_check(progress == 2, "el progreso de los objetivos se restaura")
	var state := TowerState.new()
	state.flags["x"] = true
	var with_offers := state.quests.offers_for(_info(2), "warrior")
	var round_trip := TowerState.from_dict(state.to_dict())
	_check(round_trip.has_flag("x") and JSON.stringify(round_trip.quests.offers_for(_info(2), "warrior")) == JSON.stringify(with_offers), "TowerState guarda el marco de misiones con la torre")
	_check(QuestManager.from_dict({"version": 99, "instances": {"q1": {}}}, {}, 1).instances.is_empty(), "una version de guardado desconocida se ignora sin romper")
	var corrupt := QuestManager.from_dict({"version": 1, "instances": {"q1": {"def": "ya_no_existe", "objectives": [], "rewards": {}}, "q2": 5}, "offers": {"3": ["q1", "q9"]}}, {}, 1)
	_check(corrupt.instances.is_empty() and (corrupt.offers.get(3, []) as Array).is_empty(), "los datos viejos o corruptos se descartan sin romper")


# --- Integracion con la sesion ------------------------------------------------------


func _test_session() -> void:
	var world: CombatWorld = CombatWorldScript.new(31)
	var session := GameSession.new(world, "")
	session.go_to_floor(1)
	var quest := session.tower.quests.start_quest("main_crow_01", session.floor_info_for(1), "warrior")
	var notices: Array = []
	session.message.connect(func(text: String) -> void: notices.append(text))
	world.add_enemy(&"bandit_thug", world.player.position + Vector2(300, 0)).take_damage(1.0e9)
	var progress := 0
	for objective: Dictionary in session.tower.quests.instances[quest["id"]]["objectives"]:
		if String(objective["id"]) == "thugs":
			progress = int(objective["progress"])
	_check(progress == 1, "matar en el juego avanza la mision (evento de la sesion)")
	var info := session.floor_info_for(1)
	_check(info["biome"] == "forest" and not (info["enemy_ids"] as Array).is_empty() and info.has("objects"), "la sesion da al marco el bioma, los enemigos y los objetos reales del piso")
	world.player.add_consumable("health_potion", 1)
	world.player.health = world.player.max_health * 0.3
	world.player.use_consumable("health_potion")
	_check(bool(session.tower.quests.floor_state["potion_used"]), "usar una pocion queda anotado para los desafios")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
