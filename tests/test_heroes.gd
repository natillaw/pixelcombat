## Heroes invocados: otros Despiertos en la ciudad cuyas pistas son verdad (alijo real en el piso, donde dijeron) y cuyas
## frases cambian al encontrarlo; el lore de invocacion en la introduccion.
extends SceneTree

var _checks: int = 0
var _failures: int = 0
const DT := 1.0 / 60.0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("   %s %s" % ["ok  " if ok else "FAIL", label])


func _init() -> void:
	_test_data_and_lore()
	_test_caches_are_real()
	_test_found_loop()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _heroes() -> Array:
	return Residents.all().filter(func(e: Dictionary) -> bool: return e.has("hint"))


func _test_data_and_lore() -> void:
	_check(Residents.validate().is_empty(), "residents.json valido con los heroes: %s" % str(Residents.validate()))
	_check(_heroes().size() >= 6, "hay %d heroes invocados en la ciudad" % _heroes().size())
	var worlds := {}
	for hero: Dictionary in _heroes():
		worlds[String(hero["origin"])] = true
	_check(worlds.size() == _heroes().size(), "cada heroe viene de un mundo distinto")
	var intro_text := ""
	for page: Dictionary in Lore.intro_pages():
		intro_text += String(page["text"]) + " "
	_check(intro_text.contains("otros mundos") and intro_text.contains("No eres el unico") and intro_text.contains("Despiertos"), "la introduccion cuenta que eres un invocado entre muchos")
	var city := Layouts.city()
	var in_city := city.npcs.filter(func(n: Dictionary) -> bool: return String(n["id"]).begins_with("res_")).size()
	_check(in_city == Residents.all().size(), "todos los residentes (%d) estan en la ciudad" % in_city)
	var rumor_text := ""
	for i: int in range(30):
		rumor_text += Lore.rumor(i, []) + " "
	_check(rumor_text.contains("Kaito") and rumor_text.contains("Lysa") and rumor_text.contains("Tob"), "la taberna comenta los alijos de los heroes")


func _test_caches_are_real() -> void:
	for hero: Dictionary in _heroes():
		var floor_number := int(hero["hint"]["floor"])
		var where := String(hero["hint"]["where"])
		for seed_value: int in [20261110, 7, 99]:
			var layout := TowerGenerator.generate(floor_number, seed_value, 1)
			var caches := layout.interactables.filter(func(o: Dictionary) -> bool: return String(o["kind"]) == "cache" and String(o.get("hero", "")) == String(hero["id"]))
			_check(caches.size() == 1, "%s: su alijo esta en el piso %d (seed %d)" % [hero["id"], floor_number, seed_value])
			if caches.is_empty():
				continue
			var cache: Dictionary = caches[0]
			var at: Vector2 = cache["position"]
			var reachable := layout.grid.reachable_from(layout.grid.world_to_cell(layout.player_spawn))
			var cell := layout.grid.world_to_cell(at)
			_check(reachable[cell.y * layout.grid.cols + cell.x] == 1, "%s: el alijo es alcanzable" % hero["id"])
			var actual := String(cache["where"])
			match actual:
				"camp":
					var near := false
					for camp: Dictionary in layout.camps:
						near = near or (String(camp["kind"]) == "camp" and (camp["position"] as Vector2).distance_to(at) <= 130.0)
					_check(near, "%s: esta junto a un campamento" % hero["id"])
				"hazard":
					var near_hazard := false
					for hazard: Dictionary in layout.hazards:
						near_hazard = near_hazard or (hazard["position"] as Vector2).distance_to(at) <= float(hazard["radius"]) + 70.0
					_check(near_hazard, "%s: esta junto a una trampa" % hero["id"])
				"far":
					_check(at.distance_to(layout.player_spawn) > 600.0, "%s: esta lejos de la entrada" % hero["id"])
			# Lo que dijo debe cumplirse: si prometio "campamento" o "trampa" y no hubo, cayo a "far" (y la pista lo dice).
			_check(actual == where or actual == "far", "%s: el alijo cumple lo prometido (%s)" % [hero["id"], actual])
	for floor_number: int in [1, 10]:
		var layout := TowerGenerator.generate(floor_number, 20261110, 1)
		_check(layout.interactables.filter(func(o: Dictionary) -> bool: return String(o["kind"]) == "cache").is_empty(), "el piso %d no lleva alijos" % floor_number)


func _test_found_loop() -> void:
	var session := GameSession.new(CombatWorld.new(41), "")
	for n: int in range(1, 3):
		session.tower.complete(n)
	session.go_to_floor(2)
	var cache: Interactable = null
	for object: Interactable in session.world.interactables:
		if object.kind == "cache":
			cache = object
	_check(cache != null, "el piso 2 tiene el macuto de Kaito")
	var kaito := Residents.find("kaito")
	var before := Residents.line_for(kaito, 0, 1, session.tower.flags)
	_check(before.contains("piso 2"), "antes de encontrarlo Kaito da la pista del piso 2")
	session.world.player.position = cache.position + Vector2(10, 0)
	session.world.gather_node = cache
	session.world.gather_left = 0.0
	session.world._gather_from = session.world.player.position
	session.world._gather_health = session.world.player.health
	session.world._step_gather(DT)
	_check(cache.done and session.tower.has_flag("hero_kaito_found"), "abrir el macuto marca la bandera")
	_check(session.world.loot_drops.size() >= 1, "el macuto da un objeto")
	var after := Residents.line_for(kaito, 0, 0, session.tower.flags)
	_check(after.contains("Lo encontraste"), "despues Kaito lo reconoce: %s" % after)
	var other := Residents.line_for(Residents.find("lysa"), 0, 1, session.tower.flags)
	_check(other.contains("piso 3"), "los demas siguen con su pista")
