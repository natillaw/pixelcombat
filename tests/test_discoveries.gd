## Descubrimientos de los pisos: cofres, llaves y camara sellada, eventos con decision, notas y maldicion.
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
	_test_catalogs()
	_test_placement()
	_test_chest_and_vault()
	_test_events()
	_test_notes()
	_test_curse()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _floor_world(floor_number: int, seed_value: int = 20261110) -> CombatWorld:
	var world := CombatWorld.new(11)
	world.load_layout(TowerGenerator.generate(floor_number, seed_value, 1))
	return world


func _use(world: CombatWorld, object: Interactable) -> void:
	world.player.position = object.position + Vector2(10, 0)
	world.gather_node = object
	world.gather_left = 0.0
	world._gather_from = world.player.position
	world._gather_health = world.player.health
	world._step_gather(DT)


func _first(world: CombatWorld, kind: String) -> Interactable:
	for object: Interactable in world.interactables:
		if object.kind == kind and not object.done:
			return object
	return null


func _test_catalogs() -> void:
	_check(EventCatalog.note_count() >= 16, "hay %d notas de lore" % EventCatalog.note_count())
	for floor_number: int in range(1, 10):
		_check(EventCatalog.notes_for_floor(floor_number).size() >= 2, "piso %d tiene notas disponibles" % floor_number)
	_check(EventCatalog.events_for_floor(5).size() >= 5, "hay eventos para el piso 5")
	_check(StatusCatalog.has_status("curse"), "existe el estado maldicion")


func _test_placement() -> void:
	for floor_number: int in range(1, 11):
		var layout := TowerGenerator.generate(floor_number, 20261110, 1)
		var kinds := {}
		for spec: Dictionary in layout.interactables:
			kinds[String(spec["kind"])] = int(kinds.get(String(spec["kind"]), 0)) + 1
		if floor_number == 10:
			_check(not kinds.has("chest") and not kinds.has("note") and not kinds.has("event_option") and not kinds.has("vault"), "el piso 10 no lleva cofres, notas ni eventos")
			continue
		var features := FloorFeatures.for_floor(floor_number)
		_check(int(kinds.get("note", 0)) == mini(int(features.get("notes", 0)), 2), "piso %d: notas colocadas (%d)" % [floor_number, int(kinds.get("note", 0))])
		var chest_count := int((features.get("chests", {}) as Dictionary).get("wood", 0)) + int((features.get("chests", {}) as Dictionary).get("iron", 0))
		_check(int(kinds.get("chest", 0)) == chest_count, "piso %d: %d cofres" % [floor_number, chest_count])
		_check((int(kinds.get("vault", 0)) == 1 and int(kinds.get("key", 0)) == 1) == bool(features.get("vault", false)), "piso %d: camara y llave cuando toca" % floor_number)
		var events_placed := 0
		var groups := {}
		for spec: Dictionary in layout.interactables:
			if String(spec["kind"]) == "event_option":
				groups[String(spec["exclusive"])] = true
		events_placed = groups.size()
		_check(events_placed == int(features.get("events", 0)), "piso %d: %d eventos" % [floor_number, events_placed])


func _test_chest_and_vault() -> void:
	var world := _floor_world(5)
	var chest := _first(world, "chest")
	_check(chest != null, "el piso 5 tiene cofre")
	var gold := world.player.gold
	_use(world, chest)
	_check(chest.done and world.loot_drops.size() == 1 and world.player.gold > gold, "abrir un cofre suelta un objeto y da oro")
	var vault := _first(world, "vault")
	var key := _first(world, "key")
	_check(vault != null and key != null and vault.requires == "key", "hay camara sellada con llave")
	world.player.position = vault.position + Vector2(10, 0)
	_check(world.try_click(vault.position) == "needs", "sin llave la camara no se abre")
	_use(world, key)
	_check(world.keys_carried == 1, "recoger la llave la guarda")
	var drops := world.loot_drops.size()
	_use(world, vault)
	_check(vault.done and world.keys_carried == 0 and world.loot_drops.size() >= drops + 2, "la camara usa la llave y da 2 objetos")


func _test_events() -> void:
	var world := _floor_world(5)
	var options: Array = world.interactables.filter(func(o: Interactable) -> bool: return o.kind == "event_option")
	_check(options.size() >= 1, "hay un evento con opciones en el piso 5")
	var first: Interactable = options[0]
	var group: Array = options.filter(func(o: Interactable) -> bool: return o.exclusive == first.exclusive)
	var gold := world.player.gold
	world.player.add_gold(500)
	_use(world, first)
	if group.size() > 1:
		_check((group[1] as Interactable).done or first == group[1], "al elegir una opcion se cierran las demas")
	_check(first.done, "la opcion elegida queda usada")
	# Pagar sin oro: no se usa.
	var poor := CombatWorld.new(3)
	poor.load_layout(TowerGenerator.generate(5, 20261110, 1))
	var buy := Interactable.new("event_option", poor.player.position, "", 1.0)
	buy.effects = [{"type": "pay", "amount": 40}, {"type": "gold", "per_floor": 1}]
	poor.interactables.append(buy)
	var messages: Array = []
	poor.notice.connect(func(text: String) -> void: messages.append(text))
	poor.player.spend_gold(poor.player.gold)
	_use(poor, buy)
	_check(not buy.done and messages.size() == 1, "sin oro suficiente la opcion de pago no se consume y avisa")
	poor.player.add_gold(100)
	_use(poor, buy)
	_check(buy.done and poor.player.gold == 60 + int(round(1.0 * 5.0)), "con oro suficiente se paga (queda %d)" % poor.player.gold)
	# Emboscada.
	var ambush := Interactable.new("event_option", world.player.position, "", 1.0)
	ambush.effects = [{"type": "ambush", "count": 3}]
	world.interactables.append(ambush)
	var before := world.enemies.size()
	_use(world, ambush)
	_check(world.enemies.size() == before + 3, "la emboscada crea 3 enemigos")
	# Apuesta determinista: misma semilla, mismo resultado.
	var outcomes: Array = []
	for i: int in range(2):
		var w := CombatWorld.new(21)
		w.load_layout(TowerGenerator.generate(5, 20261110, 1))
		var gamble := Interactable.new("event_option", w.player.position, "", 1.0)
		gamble.effects = [{"type": "gamble", "chance": 0.5, "win": [{"type": "gold", "per_floor": 100}], "lose": [{"type": "ambush", "count": 2}]}]
		w.interactables.append(gamble)
		_use(w, gamble)
		outcomes.append([w.player.gold, w.enemies.size()])
	_check(outcomes[0] == outcomes[1], "la apuesta es determinista %s" % str(outcomes))


func _test_notes() -> void:
	var session := GameSession.new(CombatWorld.new(5), "")
	session.tower.complete(1)
	session.go_to_floor(1)
	var note := _first(session.world, "note")
	_check(note != null, "el piso 1 tiene una nota")
	var messages: Array = []
	session.message.connect(func(text: String) -> void: messages.append(text))
	_use(session.world, note)
	_check(note.done and session.notes_found() == 1, "leer una nota la cuenta (%d)" % session.notes_found())
	_check(messages.size() >= 2, "al leer se muestra el texto y el contador")


func _test_curse() -> void:
	var world := CombatWorld.new(9)
	world.player.position = Vector2(300, 300)
	world.player.health = world.player.max_health
	var base := world.player.take_damage(100.0)
	world.player.health = world.player.max_health
	world.player.apply_status("curse", 30.0, 0.5)
	var cursed := world.player.take_damage(100.0)
	_check(cursed > base * 1.3, "la maldicion aumenta el dano recibido (%.1f -> %.1f)" % [base, cursed])
