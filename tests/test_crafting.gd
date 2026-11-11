## Crafting: catalogo de recetas, comprobaciones (materiales, oro, tier, mochila,
## zona segura), resultado determinista, tiers desbloqueados por la torre, puertas
## de los talleres de la ciudad y guardado.
##
##   godot --headless --path . --script tests/test_crafting.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const SAVE_PATH := "user://test_crafting_save.json"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_crafting (recetas y talleres) ==")
	_test_catalog()
	_test_coverage()
	_test_craft_rules()
	_test_craft_result()
	_test_tiers_and_session()
	_test_buildings()
	_test_save()
	SaveGame.delete(SAVE_PATH)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _player_with(materials: Dictionary, gold: int) -> PlayerSim:
	var world: CombatWorld = CombatWorldScript.new(90)
	world.setup_arena(Rect2(0, 0, 900, 600))
	for id: String in materials:
		world.player.add_material(id, int(materials[id]))
	world.player.add_gold(gold)
	return world.player


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_catalog() -> void:
	_check(RecipeCatalog.errors().is_empty(), "recipes.json valido: %s" % str(RecipeCatalog.errors()))
	_check(RecipeCatalog.station_ids() == ["blacksmith", "alchemist", "carpenter", "tailor", "tavern"], "las estaciones son los edificios de la ciudad")
	var city_ids: Array = Layouts.CITY_BUILDINGS.map(func(b: Dictionary) -> String: return String(b["id"]))
	_check(city_ids == RecipeCatalog.station_ids(), "cada edificio de la ciudad es una estacion")
	var bad := {"stations": [{"id": "a", "name": "A"}], "recipes": [{"id": "r", "station": "b", "item": "nada", "cost": {"oro": 1}, "gold": -1, "quality_bonus": 1}]}
	_check(RecipeCatalog.validate(bad).size() >= 4, "una receta con estacion, item, material y oro invalidos no valida")
	var recipe := RecipeCatalog.recipe("forge_iron_sword")
	_check(RecipeCatalog.cost_at(recipe, 1) == {"ore_t1": 6, "wood_t1": 1} and RecipeCatalog.cost_at(recipe, 4) == {"ore_t4": 6, "wood_t4": 1}, "el coste usa materiales del tier elegido")
	_check(RecipeCatalog.gold_at(recipe, 1) == 20 and RecipeCatalog.gold_at(recipe, 6) == 50, "el oro crece con el tier")


func _test_coverage() -> void:
	var by_item := {}
	for recipe: Dictionary in RecipeCatalog.recipes():
		by_item[String(recipe["item"])] = true
	var all_craftable := true
	for entry: Dictionary in ItemCatalog.items():
		if not by_item.has(String(entry["id"])):
			all_craftable = false
	_check(all_craftable, "cada item base se puede fabricar")
	var every_class := true
	for class_id: String in ClassCatalog.all_ids():
		var weapon_recipe := false
		for recipe: Dictionary in RecipeCatalog.recipes():
			if ItemCatalog.can_equip_base(String(recipe["item"]), class_id) and String(ItemCatalog.item(String(recipe["item"]))["slot"]) == "weapon":
				weapon_recipe = true
		if not weapon_recipe:
			every_class = false
	_check(every_class, "cada clase puede fabricarse su arma")
	var gatherable_or_loot := true
	for recipe: Dictionary in RecipeCatalog.recipes():
		for kind_id: String in recipe["cost"]:
			if not MaterialCatalog.kind_ids().has(kind_id):
				gatherable_or_loot = false
	_check(gatherable_or_loot, "todas las recetas usan materiales que existen")
	_check(RecipeCatalog.recipes_for("tavern").is_empty() and not RecipeCatalog.recipes_for("tailor").is_empty(), "la taberna aun no tiene recetas")


func _test_craft_rules() -> void:
	var rng := _rng(1)
	var player := _player_with({"ore_t1": 6, "wood_t1": 1}, 20)
	_check(Crafting.reason(player, "no_existe", 1, 1) == "unknown", "receta desconocida")
	_check(Crafting.reason(player, "forge_iron_sword", 2, 1) == "tier" and Crafting.reason(player, "forge_iron_sword", 0, 1) == "tier", "no se fabrica en un tier no abierto")
	_check(Crafting.reason(player, "forge_iron_sword", 1, 1) == "", "con todo lo necesario se puede")
	var poor := _player_with({"ore_t1": 5, "wood_t1": 1}, 99)
	_check(Crafting.reason(poor, "forge_iron_sword", 1, 1) == "materials", "faltan materiales")
	var broke := _player_with({"ore_t1": 6, "wood_t1": 1}, 19)
	_check(Crafting.reason(broke, "forge_iron_sword", 1, 1) == "gold", "falta oro")
	var wrong_tier := _player_with({"ore_t1": 6, "wood_t1": 1}, 99)
	_check(Crafting.reason(wrong_tier, "forge_iron_sword", 2, 5) == "materials", "los materiales de otro tier no valen")
	var full := _player_with({"ore_t1": 6, "wood_t1": 1}, 99)
	for i: int in range(ItemCatalog.bag_size()):
		full.add_item({"id": "iron_sword", "rarity": "common", "tier": 1, "stats": {"strength": 2.0}})
	_check(Crafting.reason(full, "forge_iron_sword", 1, 1) == "full", "mochila llena")
	var away := _player_with({"ore_t1": 6, "wood_t1": 1}, 99)
	away.safe_zone = false
	_check(Crafting.reason(away, "forge_iron_sword", 1, 1) == "busy", "no se fabrica en un piso")
	var before := poor.materials.duplicate()
	var result := Crafting.craft(poor, rng, "forge_iron_sword", 1, 1)
	_check(not bool(result["ok"]) and poor.materials == before and poor.gold == 99 and poor.bag.is_empty(), "un fallo no gasta nada")


func _test_craft_result() -> void:
	var player := _player_with({"hide_t1": 20, "herb_t1": 10}, 200)
	var result := Crafting.craft(player, _rng(7), "sew_leather_vest", 1, 1)
	_check(bool(result["ok"]) and player.bag.size() == 1, "se fabrica y va a la mochila")
	var item: Dictionary = result["item"]
	_check(String(item["id"]) == "leather_vest" and int(item["tier"]) == 1 and ItemCatalog.is_valid_item(item), "el item es el de la receta, del tier pedido y valido")
	_check(player.material_count("hide_t1") == 14 and player.gold == 186, "gasta los materiales y el oro")
	var a := Crafting.craft(_player_with({"hide_t1": 6}, 50), _rng(3), "sew_leather_vest", 1, 1)
	var b := Crafting.craft(_player_with({"hide_t1": 6}, 50), _rng(3), "sew_leather_vest", 1, 1)
	_check(JSON.stringify(a["item"]) == JSON.stringify(b["item"]), "el resultado es determinista con la misma semilla")
	var deep := _player_with({"hide_t4": 6}, 200)
	var deep_item: Dictionary = Crafting.craft(deep, _rng(3), "sew_leather_vest", 4, 4)["item"]
	var tier1_item: Dictionary = a["item"]
	_check(int(deep_item["tier"]) == 4 and float(deep_item["stats"]["armor"]) > float(tier1_item["stats"]["armor"]) * 1.4 or String(deep_item["rarity"]) != String(tier1_item["rarity"]), "un tier mayor da mas stats")
	var rare_count := 0
	var drop_rng := _rng(11)
	var craft_rng := _rng(11)
	var crafted_rare := 0
	for i: int in range(4000):
		if ItemCatalog.rarity_rank(ItemGen.roll_rarity(drop_rng, 0.0)) >= 2:
			rare_count += 1
		if ItemCatalog.rarity_rank(ItemGen.roll_rarity(craft_rng, 1.0)) >= 2:
			crafted_rare += 1
	_check(crafted_rare > rare_count, "fabricar favorece las rarezas altas frente a un enemigo normal")


func _test_tiers_and_session() -> void:
	var session := GameSession.new(CombatWorldScript.new(5), "")
	_check(session.max_craft_tier() == 1, "al empezar solo se fabrica en el tier 1")
	for n: int in range(1, 11):
		session.tower.complete(n)
	_check(session.max_craft_tier() == 2, "abrir el piso 11 desbloquea el tier 2")
	for n: int in range(11, 101):
		session.tower.complete(n)
	_check(session.max_craft_tier() == 10, "con la torre completa se fabrica hasta el tier 10")
	var s2 := GameSession.new(CombatWorldScript.new(6), "")
	s2.world.player.add_material("hide_t2", 10)
	s2.world.player.add_gold(500)
	_check(not bool(s2.craft("sew_leather_cap", 2)["ok"]), "no se fabrica en un tier aun cerrado")
	for n: int in range(1, 11):
		s2.tower.complete(n)
	_check(bool(s2.craft("sew_leather_cap", 2)["ok"]), "al abrir el tier se puede")


func _test_buildings() -> void:
	var session := GameSession.new(CombatWorldScript.new(8), "")
	var opened: Array = []
	var messages: Array = []
	session.building_opened.connect(func(station: String) -> void: opened.append(station))
	session.message.connect(func(text: String) -> void: messages.append(text))
	for portal: Dictionary in session.layout.portals:
		if String(portal["id"]) == "door_blacksmith":
			session.world.player.position = portal["position"]
	session.try_interact()
	_check(opened == ["blacksmith"] and session.layout.kind == FloorLayout.KIND_CITY, "la puerta de la herreria abre su taller")
	for portal: Dictionary in session.layout.portals:
		if String(portal["id"]) == "door_tavern":
			session.world.player.position = portal["position"]
	session.try_interact()
	_check(opened.size() == 1 and messages.size() == 1, "la taberna aun avisa de que viene pronto")
	var stations_ok := true
	for station: String in ["blacksmith", "alchemist", "carpenter", "tailor"]:
		if RecipeCatalog.recipes_for(station).is_empty():
			stations_ok = false
	_check(stations_ok, "los cuatro talleres tienen recetas")


func _test_save() -> void:
	SaveGame.delete(SAVE_PATH)
	var session := GameSession.new(CombatWorldScript.new(9), SAVE_PATH)
	session.world.player.add_material("hide_t1", 10)
	session.world.player.add_gold(100)
	var result := session.craft("sew_leather_vest", 1)
	_check(bool(result["ok"]) and FileAccess.file_exists(SAVE_PATH), "fabricar guarda la partida")
	var loaded := GameSession.new(CombatWorldScript.new(9), SAVE_PATH)
	_check(loaded.world.player.bag.size() == 1 and loaded.world.player.material_count("hide_t1") == 4 and loaded.world.player.gold == 86, "item, materiales y oro se restauran")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
