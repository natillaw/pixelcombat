## Consumibles, taberna, mercader, banco y gremio (encargos e instructor).
##
##   godot --headless --path . --script tests/test_services.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")
const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_services (consumibles, taberna, mercader, banco y gremio) ==")
	_test_catalog()
	_test_consumables()
	_test_food_effects()
	_test_drops()
	_test_tavern()
	_test_merchant_and_bank()
	_test_trainer()
	_test_bounties()
	_test_class_sets()
	_test_tomes()
	_test_item_icons()
	_test_resource_sprites()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _player(level: int = 6) -> PlayerSim:
	var world: CombatWorld = CombatWorldScript.new(11)
	world.setup_arena(Rect2(0, 0, 900, 600))
	# Arquero: sus skills de mundo se aprenden con la instructora (las del guerrero estan en libros).
	world.player.safe_zone = true
	world.player.switch_class("archer")
	world.player.safe_zone = false
	world.player.set_level(level)
	return world.player


func _step(world: CombatWorld, ticks: int, actions: Dictionary = {}) -> void:
	for i: int in range(ticks):
		var message: InputMessage = InputMessageScript.new()
		message.tick = 0
		message.peer_id = 1
		message.aim_dir = Vector2.RIGHT
		message.actions = actions.duplicate()
		world.submit_input(message)
		world.step(DT)


func _test_catalog() -> void:
	for error: String in ConsumableCatalog.errors():
		print("   error: %s" % error)
	_check(ConsumableCatalog.errors().is_empty() and ConsumableCatalog.ids().size() >= 6, "consumables.json valido (%d consumibles)" % ConsumableCatalog.ids().size())
	var potions := 0
	var foods := 0
	for id: String in ConsumableCatalog.ids():
		var kind := String(ConsumableCatalog.item(id)["kind"])
		potions += 1 if kind == "potion" else 0
		foods += 1 if kind == "food" else 0
	_check(potions >= 3 and foods >= 3, "hay pociones y comida (%d y %d)" % [potions, foods])
	var cook_ok := true
	for id: String in ConsumableCatalog.cookable_ids():
		cook_ok = cook_ok and not ConsumableCatalog.cook_cost(id, 1).is_empty()
	_check(cook_ok, "toda receta de cocina tiene materiales")


func _test_consumables() -> void:
	var world: CombatWorld = CombatWorldScript.new(11)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var player := world.player
	_check(player.add_consumable("health_potion", 3) == 3 and player.consumable_count("health_potion") == 3, "se guardan pociones fuera de la mochila")
	_check(player.add_consumable("health_potion", 99) == ConsumableCatalog.max_stack() - 3, "hay un tope de pila")
	player.consumables["health_potion"] = 3
	_check(player.use_consumable("health_potion") == "full", "con la vida llena no se gasta")
	player.health = player.max_health * 0.2
	_check(player.use_consumable("health_potion") == "" and player.health > player.max_health * 0.55 and player.consumable_count("health_potion") == 2, "la pocion cura el 40 %")
	_check(player.use_consumable("health_potion") == "cooldown", "y tienen enfriamiento compartido")
	_step(world, int(ConsumableCatalog.potion_cooldown() * 60.0) + 5)
	_check(player.potion_cooldown_left == 0.0, "el enfriamiento pasa")
	player.health = player.max_health * 0.1
	_step(world, 1, {"quick_health": true})
	_check(player.consumable_count("health_potion") == 1 and player.health > player.max_health * 0.4, "la tecla rapida usa la pocion")
	player.resource.current_amount = 0.0
	player.add_consumable("resource_potion", 1)
	player.potion_cooldown_left = 0.0
	_check(player.use_quick("resource") == "" and player.resource.get_current() > 0.0, "el elixir recupera recurso")
	_check(player.use_consumable("herb_bread") == "none", "sin existencias no se usa")
	var saved := player.export_state()
	var other := _player(1)
	other.import_state(saved)
	_check(other.consumable_count("health_potion") == 1, "los consumibles se guardan y se cargan")


func _test_food_effects() -> void:
	var world: CombatWorld = CombatWorldScript.new(12)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var player := world.player
	player.add_consumable("hunters_stew", 1)
	player.add_consumable("silk_tea", 1)
	player.add_consumable("herb_bread", 1)
	var dummy := world.add_dummy(player.position + Vector2(50, 0), false)
	_step(world, 1, {"m1": true})
	_step(world, 40)
	var plain := dummy.max_health - dummy.health
	_check(player.use_consumable("hunters_stew") == "" and player.statuses.has("might"), "el estofado da +dano")
	var dummy2 := world.add_dummy(player.position + Vector2(50, 20), false)
	_step(world, 60)
	_step(world, 1, {"m1": true})
	_step(world, 40)
	_check(plain > 0.0 and dummy2.max_health - dummy2.health > 0.0, "(preparacion) los ataques hacen dano")
	_check(player.use_consumable("silk_tea") == "" and player.statuses.speed_mult() > 1.05, "la infusion da velocidad (%.2f)" % player.statuses.speed_mult())
	player.use_consumable("herb_bread")
	player.health = player.max_health * 0.5
	var before := player.health
	_step(world, 60 * 12)
	_check(player.health > before + player.max_health * 0.15, "el pan acelera la regeneracion fuera de combate (%.0f -> %.0f)" % [before, player.health])
	player.reset()
	_check(player.statuses.has("might") and player.statuses.has("haste") and player.statuses.has("fed"), "la comida dura aunque cambies de piso")
	player.statuses.clear()
	_check(not player.statuses.has("might"), "(se puede limpiar)")


func _test_drops() -> void:
	var world: CombatWorld = CombatWorldScript.new(13)
	world.setup_arena(Rect2(0, 0, 900, 600))
	for i: int in range(120):
		world.add_enemy(&"slime", Vector2(100 + i, 100)).take_damage(1.0e9)
	_check(world.player.consumable_count("health_potion") >= 1 and world.player.consumable_count("health_potion") < 20, "los enemigos sueltan pociones a veces (%d de 120)" % world.player.consumable_count("health_potion"))
	var boss_world: CombatWorld = CombatWorldScript.new(13)
	boss_world.setup_arena(Rect2(0, 0, 900, 600))
	boss_world.add_enemy(&"bandit_rask", Vector2(300, 300)).take_damage(1.0e9)
	_check(boss_world.player.consumable_count("health_potion") >= 2, "un jefe siempre suelta pociones")


func _test_tavern() -> void:
	var player := _player()
	var price := int(ConsumableCatalog.item("health_potion")["price"])
	_check(not bool(Services.buy_consumable(player, "health_potion")["ok"]), "sin oro no se compra")
	player.add_gold(price * 2)
	_check(bool(Services.buy_consumable(player, "health_potion")["ok"]) and player.consumable_count("health_potion") == 1 and player.gold == price, "comprar cobra y entrega")
	_check(not bool(Services.buy_consumable(player, "greater_health_potion")["ok"]), "lo que no se vende no se compra (solo se cocina)")
	var no_materials := Services.cook(player, "herb_bread", 1)
	_check(not bool(no_materials["ok"]) and String(no_materials["reason"]) == "materials", "cocinar pide materiales")
	player.add_material("herb_t1", 5)
	_check(bool(Services.cook(player, "herb_bread", 1)["ok"]) and player.consumable_count("herb_bread") == 1 and player.material_count("herb_t1") == 3, "cocinar gasta materiales y da la comida")
	var broke := _player()
	_check(not bool(Services.rest(broke)["ok"]), "descansar cuesta oro")
	player.health = player.max_health * 0.3
	player.add_gold(100)
	var rested := Services.rest(player, 2)
	_check(bool(rested["ok"]) and is_equal_approx(player.health, player.max_health) and player.statuses.has("fed") and not String(rested["rumor"]).is_empty(), "descansar cura, da comida y cuenta un rumor")


func _test_merchant_and_bank() -> void:
	var a := Services.merchant_stock(777, 3, 1)
	var b := Services.merchant_stock(777, 3, 1)
	var c := Services.merchant_stock(777, 4, 1)
	_check(a.size() == Services.MERCHANT_STOCK and JSON.stringify(a) == JSON.stringify(b) and JSON.stringify(a) != JSON.stringify(c), "las existencias son deterministas y cambian con el progreso")
	var player := _player()
	var price := int((a[0] as Dictionary)["price"])
	_check(price > ItemCatalog.sell_value((a[0] as Dictionary)["item"]) and not bool(Services.buy_stock(player, a, 0)["ok"]), "comprar cuesta mas de lo que se paga al vender y pide oro")
	player.add_gold(price)
	_check(bool(Services.buy_stock(player, a, 0)["ok"]) and player.bag.size() == 1 and bool((a[0] as Dictionary)["sold"]), "comprar equipo lo mete en la mochila")
	_check(not bool(Services.buy_stock(player, a, 0)["ok"]), "no se compra dos veces")
	_check(bool(Services.bank_deposit(player, 0)["ok"]) and player.bag.is_empty() and player.bank.size() == 1, "el banco guarda items")
	var saved := player.export_state()
	var other := _player(1)
	other.import_state(saved)
	_check(other.bank.size() == 1, "el alijo se guarda y se carga")
	_check(bool(Services.bank_withdraw(player, 0)["ok"]) and player.bank.is_empty() and player.bag.size() == 1, "y se retira")
	for i: int in range(PlayerSim.BANK_SIZE):
		player.bank.append(player.bag[0])
	_check(String(Services.bank_deposit(player, 0)["reason"]) == "full", "el alijo tiene tope")


func _test_trainer() -> void:
	var player := _player(12)
	var offers := Services.trainer_offers(player)
	_check(offers.size() >= 3, "la instructora ofrece skills de mundo (%d)" % offers.size())
	var id := String(offers[0]["id"])
	_check(not bool(Services.learn_skill(player, id)["ok"]), "aprender cuesta oro")
	player.add_gold(1000)
	var gold := player.gold
	_check(bool(Services.learn_skill(player, id)["ok"]) and player.learned_skills.has(id) and player.gold < gold, "aprender cobra y ensena la skill")
	_check(Services.trainer_offers(player).size() == offers.size() - 1 and not bool(Services.learn_skill(player, id)["ok"]), "ya no se vuelve a ofrecer")


func _test_bounties() -> void:
	var first := Bounties.offers(555, 0, 1)
	var again := Bounties.offers(555, 0, 1)
	var next := Bounties.offers(555, 1, 1)
	_check(first.size() == 3 and JSON.stringify(first) == JSON.stringify(again) and JSON.stringify(first) != JSON.stringify(next), "el tablon ofrece 3 encargos deterministas que cambian al cobrar")
	var templates := {}
	for offer: Dictionary in first:
		templates[offer["template"]] = true
	_check(templates.size() == 3, "los 3 encargos son distintos")
	var world: CombatWorld = CombatWorldScript.new(14)
	var session := GameSession.new(world, "")
	var player := world.player
	player.set_level(6)
	var kill_offer := {"template": "t1", "kind": "kill_group", "name": "Prueba", "text": "x", "count": 2, "progress": 0, "gold": 50, "xp": 40, "consumable": "health_potion", "group": "bandit_", "enemy": "", "material": ""}
	var collect_offer := {"template": "t2", "kind": "collect", "name": "Reunir", "text": "x", "count": 3, "progress": 0, "gold": 30, "xp": 10, "consumable": "", "group": "", "enemy": "", "material": "silk"}
	var floors_offer := {"template": "t3", "kind": "clear_floors", "name": "Subir", "text": "x", "count": 1, "progress": 0, "gold": 20, "xp": 10, "consumable": "", "group": "", "enemy": "", "material": ""}
	_check(Bounties.accept(player, kill_offer) and Bounties.accept(player, collect_offer) and Bounties.accept(player, floors_offer), "se aceptan hasta 3 encargos")
	_check(not Bounties.accept(player, kill_offer) and not Bounties.accept(player, first[0]), "no se pasa del maximo ni se repite")
	var messages: Array = []
	session.message.connect(func(text: String) -> void: messages.append(text))
	world.add_enemy(&"bandit_thug", Vector2(300, 300)).take_damage(1.0e9)
	world.add_enemy(&"slime", Vector2(320, 300)).take_damage(1.0e9)
	_check(int(player.bounties[0]["progress"]) == 1, "matar un bandido avanza el encargo (y una bestia no)")
	world.add_enemy(&"bandit_archer", Vector2(340, 300)).take_damage(1.0e9)
	_check(int(player.bounties[0]["progress"]) == 2 and not messages.is_empty(), "al completarlo avisa")
	player.add_material("silk_t1", 2)
	player.add_material("ore_t1", 5)
	_check(int(player.bounties[1]["progress"]) == 2, "los materiales cuentan por tipo")
	player.add_material("silk_t2", 4)
	_check(int(player.bounties[1]["progress"]) == 3, "de cualquier tier, sin pasar del objetivo")
	var gold := player.gold
	var xp := player.xp
	var serial := player.bounty_serial
	_check(Bounties.turn_in(player, 0) and player.gold == gold + 50 and player.xp > xp and player.consumable_count("health_potion") >= 1 and player.bounty_serial == serial + 1, "cobrar da oro, XP y el consumible, y renueva el tablon")
	_check(not Bounties.turn_in(player, 1), "un encargo sin acabar no se cobra (el de piso sigue en 0)")
	var saved := player.export_state()
	var other := _player(1)
	other.import_state(saved)
	_check(other.bounties.size() == 2 and other.bounty_serial == serial + 1 and other.bounties_done == 1, "los encargos se guardan y se cargan")


## Cada clase puede fabricarse un set completo de tier 1 (arma, cabeza, pecho, piernas, pies, anillo) con al menos
## 2 opciones por ranura, y el set mas barato cabe en lo que se recolecta en los pisos 1-10.
func _test_class_sets() -> void:
	var yield_by_kind := _tier1_yield()
	print("   rendimiento esperado de los pisos 1-10: %s" % str(yield_by_kind))
	for class_id: String in ClassCatalog.all_ids():
		var cheapest := {}
		var options_ok := true
		for slot: String in ItemCatalog.slots():
			var best_cost := {}
			var best_total := 1000000
			var options := 0
			for recipe: Dictionary in RecipeCatalog.recipes():
				var item := ItemCatalog.item(String(recipe["item"]))
				if String(item["slot"]) != slot or not ItemCatalog.can_equip_base(String(item["id"]), class_id):
					continue
				options += 1
				var total := 0
				for kind: String in recipe["cost"]:
					total += int(recipe["cost"][kind])
				if total < best_total:
					best_total = total
					best_cost = recipe["cost"]
			options_ok = options_ok and options >= 2
			for kind: String in best_cost:
				cheapest[kind] = int(cheapest.get(kind, 0)) + int(best_cost[kind])
		_check(options_ok, "%s: cada ranura tiene al menos 2 opciones de crafteo" % class_id)
		var fits := true
		for kind: String in cheapest:
			if float(cheapest[kind]) > float(yield_by_kind.get(kind, 0.0)) * 0.6:
				fits = false
				print("   el set de %s pide %d de %s y los pisos 1-10 dan ~%d" % [class_id, cheapest[kind], kind, int(yield_by_kind.get(kind, 0.0))])
		_check(fits, "%s: el set completo mas barato (%s) cabe en lo recolectable en 10 pisos" % [class_id, str(cheapest)])


## Materiales esperados al recorrer los pisos 1-10 una vez: nodos de recoleccion (con su rendimiento medio) y botin de enemigos.
func _tier1_yield() -> Dictionary:
	var out := {}
	var gather := MaterialCatalog.gather_yield()
	var per_node := (float(gather["min"]) + float(gather["max"])) * 0.5 + float(gather["bonus_chance"])
	for floor_number: int in range(1, 11):
		var layout := TowerGenerator.generate(floor_number, 20261110, 1)
		for node: Dictionary in layout.resources:
			out[String(node["kind"])] = float(out.get(String(node["kind"]), 0.0)) + per_node * (2.0 if bool(node.get("rich", false)) else 1.0)
		for spec: Dictionary in layout.enemies:
			var table: Dictionary = EnemyCatalog.enemy(StringName(String(spec["id"]))).get("materials", {})
			for kind: String in table:
				out[kind] = float(out.get(kind, 0.0)) + float(table[kind]) * 1.5
	return out


func _test_tomes() -> void:
	var player := _player(12)
	player.add_consumable("skill_tome", 2)
	var known := player.learned_skills.size()
	_check(player.use_consumable("skill_tome") == "" and player.learned_skills.size() == known + 1 and player.consumable_count("skill_tome") == 1, "un tomo ensena una skill de mundo")
	var first: String = player.learned_skills[player.learned_skills.size() - 1]
	_check(int(SkillCatalog.skill(StringName(first))["unlock_level"]) <= int(SkillCatalog.skill(StringName(String(player.learned_skills[0])))["unlock_level"]) + 100, "(la skill pertenece a la clase)")
	for offer: Dictionary in Services.trainer_offers(player):
		player.learn_skill(StringName(String(offer["id"])))
	player.add_consumable("skill_tome", 1)
	var before := player.consumable_count("skill_tome")
	var all_known := Services.trainer_offers(player).is_empty()
	_check(all_known and player.use_consumable("skill_tome") == "known" and player.consumable_count("skill_tome") == before, "si ya las conoces todas el tomo no se gasta")
	var drops := 0
	var garrick_world: CombatWorld = CombatWorldScript.new(31)
	garrick_world.setup_arena(Rect2(0, 0, 900, 600))
	garrick_world.add_enemy(&"bandit_garrick", Vector2(300, 300)).take_damage(1.0e9)
	_check(garrick_world.player.consumable_count("skill_tome") >= 1, "Garrick siempre suelta un tomo")
	for i: int in range(30):
		var w: CombatWorld = CombatWorldScript.new(40 + i)
		w.setup_arena(Rect2(0, 0, 900, 600))
		w.add_enemy(&"bandit_deserter", Vector2(300, 300)).take_damage(1.0e9)
		drops += w.player.consumable_count("skill_tome")
	_check(drops > 8 and drops < 28, "el elite suelta tomos a veces (%d de 30)" % drops)
	for id: String in ConsumableCatalog.ids():
		_check(SkillIcons.consumable(String(ConsumableCatalog.item(id)["icon"])) != null, "%s tiene icono" % id)


## Cada item base tiene su propio icono (su pieza LPC recortada; los anillos usan el de CraftPix).
func _test_item_icons() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var without: Array = []
	var too_big: Array = []
	var distinct := {}
	for entry: Dictionary in ItemCatalog.items():
		var piece := ItemGen.roll_item(rng, 1, "common", "", "", String(entry["id"]))
		var icon := ItemIcons.texture(piece, 28)
		if icon == null:
			without.append(entry["id"])
			continue
		if icon.get_width() > 36 or icon.get_height() > 36:
			too_big.append(entry["id"])
		distinct[String(entry["id"])] = [icon.get_width(), icon.get_height()]
	_check(without.is_empty(), "todos los items tienen icono propio (sin icono: %s)" % str(without))
	_check(too_big.is_empty(), "los iconos caben en su hueco (%s)" % str(too_big))
	var sword := ItemIcons.texture(ItemGen.roll_item(rng, 1, "common", "", "", "iron_sword"), 28)
	var bow := ItemIcons.texture(ItemGen.roll_item(rng, 1, "common", "", "", "short_bow"), 28)
	_check(sword != null and bow != null and sword.get_image().get_data() != bow.get_image().get_data(), "cada arma tiene su propio dibujo")


## Los nodos de recoleccion usan sprites de las hojas LPC (rocas, hierba con flores, arboles y tocones), no poligonos.
func _test_resource_sprites() -> void:
	for kind: String in ["ore", "herb", "wood"]:
		var ok := true
		for seed_value: int in range(0, 12):
			for depleted: bool in [false, true]:
				var parts := ResourceSprites.parts(kind, seed_value, depleted)
				ok = ok and not parts.is_empty()
				for part: Dictionary in parts:
					ok = ok and part["texture"] != null and (part["texture"] as Texture2D).get_width() > 2
		_check(ok, "%s: el nodo se dibuja con sprites del pack (agotado o no)" % kind)
	var tree := ResourceSprites.parts("wood", 1, false)
	var stump := ResourceSprites.parts("wood", 1, true)
	_check(not tree.is_empty() and not stump.is_empty() and (stump[0]["texture"] as Texture2D).get_height() < (tree[0]["texture"] as Texture2D).get_height(), "al agotar un arbol queda su tocon")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
