## Items y rarezas: catalogo, generacion determinista, botin, mochila, equipo (stats
## reales en PlayerSim), restricciones y guardado.
##
##   godot --headless --path . --script tests/test_items.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const SAVE_PATH := "user://test_items_save.json"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_items (items, rarezas, botin) ==")
	_test_catalog()
	_test_generation()
	_test_rarity_distribution()
	_test_loot_rules()
	_test_bag_and_equip()
	_test_gear_changes_stats()
	_test_class_rules()
	_test_drops_in_world()
	_test_enemy_tables()
	_test_ground_loot()
	_test_sell_and_gold()
	_test_floor_chest()
	_test_save_roundtrip()
	SaveGame.delete(SAVE_PATH)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _new_player() -> PlayerSim:
	var world: CombatWorld = CombatWorldScript.new(11)
	world.setup_arena(Rect2(0, 0, 900, 600))
	return world.player


func _test_catalog() -> void:
	_check(ItemCatalog.errors().is_empty(), "items.json valido: %s" % str(ItemCatalog.errors()))
	_check(ItemCatalog.rarity_ids() == ["common", "uncommon", "rare", "epic", "unique", "legendary"], "seis rarezas de peor a mejor (con la Unica antes de la Legendaria)")
	var every_slot := true
	for slot: String in ItemCatalog.slots():
		if ItemCatalog.items_for(slot).is_empty():
			every_slot = false
	_check(every_slot, "cada ranura tiene items")
	var every_class_weapon := true
	for class_id: String in ClassCatalog.all_ids():
		if ItemCatalog.items_for("weapon", class_id).is_empty():
			every_class_weapon = false
	_check(every_class_weapon, "cada clase tiene al menos un arma")
	_check(ItemCatalog.tier_multiplier(1) == 1.0 and ItemCatalog.tier_multiplier(11) > ItemCatalog.tier_multiplier(2), "el multiplicador de tier crece")
	var bad := {"bag_size": 0, "tier_scale": 0.3, "rarities": [], "slots": [], "items": [], "affixes": [], "loot": {}}
	_check(not ItemCatalog.validate(bad).is_empty(), "un items.json roto no valida")
	var nonmonotonic := ItemCatalog.rarities()
	nonmonotonic[3]["stat_mult"] = 0.5
	var data := {"bag_size": 10, "tier_scale": 0.3, "rarities": nonmonotonic, "slots": [{"id": "weapon", "name": "x"}], "items": [{"id": "a", "name": "a", "slot": "weapon", "stats": {"strength": 1}}], "affixes": [{"stat": "strength", "min": 1, "max": 2}], "loot": {"normal_chance": 0.1, "boss_chance": 1, "rarity_bonus": {}}}
	_check(not ItemCatalog.validate(data).is_empty(), "una rareza que baja de stat_mult no valida")


func _test_generation() -> void:
	var a := ItemGen.roll_item(_rng(5), 1, "rare")
	var b := ItemGen.roll_item(_rng(5), 1, "rare")
	_check(JSON.stringify(a) == JSON.stringify(b), "misma semilla, mismo item")
	_check(JSON.stringify(a) != JSON.stringify(ItemGen.roll_item(_rng(6), 1, "rare")), "otra semilla, otro item")
	var valid := true
	for i: int in range(300):
		var item := ItemGen.roll_item(_rng(i), 1 + i % 10)
		if not ItemCatalog.is_valid_item(item):
			valid = false
	_check(valid, "300 items aleatorios son validos")
	var common := ItemGen.roll_item(_rng(1), 1, "common", "chest", "", "leather_vest")
	var legendary := ItemGen.roll_item(_rng(1), 1, "legendary", "chest", "", "leather_vest")
	_check(float(common["stats"]["armor"]) == 8.0 and common["stats"].size() == 2, "un comun trae exactamente los stats base")
	_check(float(legendary["stats"]["armor"]) >= 8.0 * 2.3 - 0.1, "un legendario multiplica los stats base")
	var deep := ItemGen.roll_item(_rng(1), 11, "common", "", "", "leather_vest")
	_check(float(deep["stats"]["armor"]) > float(common["stats"]["armor"]) * 1.2, "un item de tier alto da mas stats")
	var affix_ok := true
	for rarity: Dictionary in ItemCatalog.rarities():
		var item := ItemGen.roll_item(_rng(3), 1, String(rarity["id"]), "", "", "bone_ring")
		var base := ItemCatalog.item("bone_ring")
		# Hasta 1 stat base + tantos afijos como pida la rareza.
		if (item["stats"] as Dictionary).size() > (base["stats"] as Dictionary).size() + int(rarity["affixes"]):
			affix_ok = false
	_check(affix_ok, "no hay mas afijos que los de la rareza")
	var weapon := ItemGen.roll_item(_rng(9), 1, "common", "weapon", "mage")
	_check(String(weapon["id"]) == "oak_staff", "el filtro de clase da el arma de esa clase")


func _test_rarity_distribution() -> void:
	var rng := _rng(2026)
	var counts := {}
	for i: int in range(20000):
		var rarity := ItemGen.roll_rarity(rng, 0.0)
		counts[rarity] = int(counts.get(rarity, 0)) + 1
	_check(counts["common"] > counts["uncommon"] and counts["uncommon"] > counts["rare"] and counts["rare"] > counts["epic"] and counts["epic"] > counts["legendary"], "cuanto mas rara, menos frecuente")
	_check(int(counts["common"]) > 11000 and int(counts["common"]) < 13000, "los comunes rondan el 60 %%")
	var boosted := {}
	var rng2 := _rng(2026)
	for i: int in range(20000):
		var rarity := ItemGen.roll_rarity(rng2, 3.0)
		boosted[rarity] = int(boosted.get(rarity, 0)) + 1
	_check(int(boosted.get("rare", 0)) > int(counts["rare"]) * 2 and int(boosted.get("common", 0)) > 0, "el bonus de jefe favorece las raras sin quitar las comunes")


func _test_loot_rules() -> void:
	var rng := _rng(77)
	var normal_drops := 0
	for i: int in range(5000):
		if not ItemGen.roll_drop(rng, 1, "normal").is_empty():
			normal_drops += 1
	_check(normal_drops > 800 and normal_drops < 1000, "un enemigo normal suelta alrededor del 18 %%")
	var boss_always := true
	for i: int in range(200):
		if ItemGen.roll_drop(rng, 1, "boss").is_empty():
			boss_always = false
	_check(boss_always, "un jefe siempre suelta algo")
	var chest := ItemGen.roll_chest(rng, 3, "boss")
	_check(not chest.is_empty() and int(chest["tier"]) == 3, "el cofre siempre da un item del tier del piso")


func _test_bag_and_equip() -> void:
	var player := _new_player()
	var sword := ItemGen.roll_item(_rng(1), 1, "common", "weapon", "warrior")
	var better := ItemGen.roll_item(_rng(2), 1, "epic", "weapon", "warrior")
	var changes: Array = []
	player.inventory_changed.connect(func() -> void: changes.append(1))
	_check(player.add_item(sword) and player.add_item(better) and player.bag.size() == 2, "los items entran en la mochila")
	_check(player.equip_from_bag(0) == "" and player.equipment.has("weapon") and player.bag.size() == 1, "equipar saca el item de la mochila")
	_check(player.equip_from_bag(0) == "" and player.bag.size() == 1 and String(player.bag[0]["rarity"]) == "common", "equipar sobre otro devuelve el anterior a la mochila")
	_check(player.unequip_gear("weapon") == "" and player.equipment.is_empty() and player.bag.size() == 2, "desequipar devuelve el item")
	_check(player.unequip_gear("weapon") == "unknown" and player.equip_from_bag(9) == "unknown", "ranuras e indices invalidos se rechazan")
	_check(player.discard_from_bag(0) and player.bag.size() == 1, "se puede tirar un item")
	_check(changes.size() >= 5, "cada cambio avisa con inventory_changed")
	var full_player := _new_player()
	var lost: Array = []
	full_player.bag_full.connect(func(item: Dictionary) -> void: lost.append(item))
	for i: int in range(ItemCatalog.bag_size()):
		full_player.add_item(sword.duplicate(true))
	_check(not full_player.add_item(sword) and lost.size() == 1 and full_player.bag.size() == ItemCatalog.bag_size(), "con la mochila llena el item se pierde y avisa")
	full_player.equip_from_bag(0)
	full_player.add_item(sword.duplicate(true))
	_check(full_player.unequip_gear("weapon") == "full", "no se desequipa con la mochila llena")


func _test_gear_changes_stats() -> void:
	var player := _new_player()
	var armor_before := player.stats.get_stat(&"armor")
	var damage_before := player.stats.get_weapon_damage()
	var crit_before := player.stats.get_crit_chance()
	player.set_level(5)
	var base_hp := player.max_health
	var ap_before := player.stats.get_attack_power()
	var armor_level := player.stats.get_stat(&"armor")
	player.add_item({"id": "iron_sword", "rarity": "rare", "tier": 1, "stats": {"weapon_min": 5.0, "weapon_max": 8.0, "strength": 4.0}})
	player.add_item({"id": "leather_vest", "rarity": "rare", "tier": 1, "stats": {"armor": 12.0, "stamina": 4.0}})
	player.add_item({"id": "copper_ring", "rarity": "rare", "tier": 1, "stats": {"crit_chance": 0.02}})
	player.health = player.max_health * 0.5
	player.equip_from_bag(0)
	player.equip_from_bag(0)
	player.equip_from_bag(0)
	_check(is_equal_approx(player.stats.get_stat(&"armor"), armor_level + 12.0), "la armadura del equipo se suma")
	_check(player.max_health > base_hp + 39.0 and player.max_health < base_hp + 41.0, "el vigor del equipo sube la vida maxima (+4 x 10)")
	_check(is_equal_approx(player.health / player.max_health, 0.5), "equipar conserva el porcentaje de vida")
	_check(player.stats.get_attack_power() > ap_before + 7.9, "la fuerza del equipo sube el poder de ataque")
	_check(player.stats.get_weapon_damage() > damage_before, "el arma sube el dano")
	_check(is_equal_approx(player.stats.get_crit_chance(), crit_before + 0.02), "el critico del equipo se suma")
	_check(player.armor_reduction() > armor_before / (armor_before + 100.0), "mas armadura reduce mas dano")
	player.unequip_gear("ring")
	player.unequip_gear("chest")
	_check(is_equal_approx(player.stats.get_stat(&"armor"), armor_level), "desequipar quita los stats")
	var mult_ok: bool = player.gear_stats().get("weapon_min", 0.0) == 5.0
	_check(mult_ok, "gear_stats suma lo equipado")


func _test_class_rules() -> void:
	var player := _new_player()
	player.add_item(ItemGen.roll_item(_rng(1), 1, "common", "weapon", "mage"))
	_check(player.equip_from_bag(0) == "class" and player.equipment.is_empty(), "un guerrero no equipa un baston")
	player.add_item(ItemGen.roll_item(_rng(1), 1, "common", "weapon", "warrior"))
	player.equip_from_bag(1)
	_check(player.equipment.has("weapon"), "el guerrero equipa su arma")
	player.switch_class("mage")
	_check(player.equipment.is_empty(), "cada clase tiene su propio equipo")
	_check(player.equip_from_bag(0) == "" and player.equipment.has("weapon"), "el mago equipa el baston")
	player.switch_class("warrior")
	_check(String(player.equipment["weapon"]["id"]) == "iron_sword", "al volver el guerrero conserva su arma")
	player.safe_zone = false
	player.add_item(ItemGen.roll_item(_rng(4), 1, "common", "head"))
	_check(player.equip_from_bag(player.bag.size() - 1) == "busy" and player.unequip_gear("weapon") == "busy", "en un piso no se cambia de equipo")


func _test_drops_in_world() -> void:
	var world: CombatWorld = CombatWorldScript.new(31)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var dropped: Array = []
	world.loot_dropped.connect(func(item: Dictionary, _position: Vector2) -> void: dropped.append(item))
	for i: int in range(300):
		var slime := world.add_enemy(&"slime", Vector2(300, 300))
		slime.take_damage(1.0e9)
	_check(dropped.size() > 25 and dropped.size() < 90, "matar enemigos normales suelta botin de vez en cuando (%d de 300)" % dropped.size())
	_check(world.loot_drops.size() == dropped.size() and world.player.bag.is_empty(), "el botin cae al suelo, no directo a la mochila")
	var boss_world: CombatWorld = CombatWorldScript.new(32)
	boss_world.setup_arena(Rect2(0, 0, 900, 600))
	var boss_drops: Array = []
	boss_world.loot_dropped.connect(func(item: Dictionary, _position: Vector2) -> void: boss_drops.append(item))
	boss_world.add_enemy(&"brood_beetle", Vector2(300, 300)).take_damage(1.0e9)
	_check(boss_drops.size() == 1, "el jefe siempre suelta botin")
	var summoned := boss_world.add_enemy(&"slime", Vector2(500, 300))
	summoned.summoned = true
	var before := boss_drops.size()
	for i: int in range(60):
		var minion := boss_world.add_enemy(&"slime", Vector2(500, 300))
		minion.summoned = true
		minion.take_damage(1.0e9)
	_check(boss_drops.size() == before, "las crias invocadas no sueltan botin")
	# El mismo mundo y las mismas muertes dan el mismo botin.
	var again: CombatWorld = CombatWorldScript.new(31)
	again.setup_arena(Rect2(0, 0, 900, 600))
	var repeat: Array = []
	again.loot_dropped.connect(func(item: Dictionary, _position: Vector2) -> void: repeat.append(item))
	for i: int in range(300):
		again.add_enemy(&"slime", Vector2(300, 300)).take_damage(1.0e9)
	_check(JSON.stringify(repeat) == JSON.stringify(dropped), "el botin es determinista")
	# Un piso profundo da items de su tier.
	var tower_session := GameSession.new(CombatWorldScript.new(8), "")
	tower_session.tower.complete(1)
	tower_session.go_to_floor(2)
	var floor_items: Array = []
	tower_session.world.loot_dropped.connect(func(item: Dictionary, _position: Vector2) -> void: floor_items.append(item))
	for i: int in range(80):
		tower_session.world.add_enemy(&"slime", Vector2(300, 300)).take_damage(1.0e9)
	var tier_ok := not floor_items.is_empty()
	for item: Dictionary in floor_items:
		if int(item["tier"]) != 1:
			tier_ok = false
	_check(tier_ok, "el tier del botin sale del piso")


func _test_enemy_tables() -> void:
	var table_ok := true
	var reason := ""
	for id: Variant in EnemyCatalog.all_ids():
		var data := EnemyCatalog.enemy(StringName(String(id)))
		var table: Dictionary = data.get("loot", {})
		for slot: Variant in table.get("slots", []):
			if not ItemCatalog.slots().has(String(slot)):
				table_ok = false
				reason = "%s: ranura %s" % [id, slot]
	_check(table_ok, "las tablas de botin de los enemigos usan ranuras validas (%s)" % reason)
	_check(EnemyCatalog.enemy(&"wisp")["loot"]["slots"] == ["ring"], "el Wisp tiene tabla propia (solo anillos)")
	var rng := _rng(90)
	var only_rings := true
	var drops := 0
	for i: int in range(400):
		var item := ItemGen.roll_drop(rng, 1, "normal", EnemyCatalog.enemy(&"wisp")["loot"])
		if item.is_empty():
			continue
		drops += 1
		if String(ItemCatalog.item(String(item["id"]))["slot"]) != "ring":
			only_rings = false
	_check(drops > 50 and drops < 120 and only_rings, "el Wisp solo suelta anillos y con su propia probabilidad (%d de 400)" % drops)
	var boss_slots := {}
	for i: int in range(200):
		var item := ItemGen.roll_drop(rng, 1, "boss", EnemyCatalog.enemy(&"brood_beetle")["loot"])
		boss_slots[String(ItemCatalog.item(String(item["id"]))["slot"])] = true
	_check(boss_slots.has("weapon") and boss_slots.has("chest") and boss_slots.has("ring") and not boss_slots.has("feet"), "el jefe solo suelta lo que dice su tabla y siempre suelta")


func _click(world: CombatWorld, point: Vector2) -> void:
	var press := InputMessage.new()
	press.actions = {"pickup": true}
	press.target_pos = point
	world.submit_input(press)
	world.step(1.0 / 60.0)
	var release := InputMessage.new()
	release.actions = {"pickup": false}
	world.submit_input(release)
	world.step(1.0 / 60.0)


func _test_ground_loot() -> void:
	var world: CombatWorld = CombatWorldScript.new(50)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var spawned: Array = []
	var removed: Array = []
	world.loot_spawned.connect(func(drop: LootDrop) -> void: spawned.append(drop))
	world.loot_removed.connect(func(drop: LootDrop) -> void: removed.append(drop))
	var item := ItemGen.roll_item(_rng(1), 1, "rare")
	var drop := LootDrop.new(item, Vector2(600, 400))
	world.loot_drops.append(drop)
	world.player.position = Vector2(200, 200)
	for i: int in range(60):
		world.step(1.0 / 60.0)
	_check(world.loot_drops.size() == 1 and world.player.bag.is_empty(), "el botin no se recoge solo, ni estando cerca")
	world.player.position = Vector2(600, 420)
	for i: int in range(60):
		world.step(1.0 / 60.0)
	_check(world.loot_drops.size() == 1 and world.player.bag.is_empty(), "estar encima del item no lo recoge automaticamente")
	world.player.position = Vector2(200, 200)
	_click(world, Vector2(600, 400))
	_check(world.loot_drops.size() == 1 and world.try_click(Vector2(600, 400)) == "far", "con clic desde lejos no se recoge")
	_check(world.try_click(Vector2(100, 100)) == "none", "un clic donde no hay nada no hace nada")
	world.player.position = Vector2(600, 420)
	_click(world, Vector2(900, 100))
	_check(world.loot_drops.size() == 1, "un clic lejos del item no lo recoge aunque estes cerca")
	drop.age = 0.0
	_check(world.try_click(Vector2(600, 400)) == "wait", "un item recien caido aun no se puede coger")
	drop.age = 1.0
	_click(world, Vector2(610, 405))
	_check(world.loot_drops.is_empty() and world.player.bag.size() == 1 and removed.size() == 1, "clic sobre el item estando cerca lo recoge y avisa de que desaparece")
	# Cada pulsacion recoge una sola vez (flanco), no uno por tick.
	var two: CombatWorld = CombatWorldScript.new(55)
	two.setup_arena(Rect2(0, 0, 900, 600))
	two.player.position = Vector2(300, 300)
	two.loot_drops.append(LootDrop.new(item.duplicate(true), Vector2(300, 310)))
	two.loot_drops.append(LootDrop.new(item.duplicate(true), Vector2(300, 310)))
	for drop_entry: LootDrop in two.loot_drops:
		drop_entry.age = 1.0
	var held := InputMessage.new()
	held.actions = {"pickup": true}
	held.target_pos = Vector2(300, 310)
	for i: int in range(20):
		two.submit_input(held)
		two.step(1.0 / 60.0)
	_check(two.player.bag.size() == 1 and two.loot_drops.size() == 1, "mantener el clic recoge un solo item")
	# Mochila llena: se queda en el suelo y avisa.
	var full_world: CombatWorld = CombatWorldScript.new(51)
	full_world.setup_arena(Rect2(0, 0, 900, 600))
	for i: int in range(ItemCatalog.bag_size()):
		full_world.player.add_item(item.duplicate(true))
	var warnings: Array = []
	full_world.player.bag_full.connect(func(_it: Dictionary) -> void: warnings.append(1))
	full_world.loot_drops.append(LootDrop.new(item, Vector2(300, 300)))
	full_world.loot_drops[0].age = 1.0
	full_world.player.position = Vector2(300, 300)
	_click(full_world, Vector2(300, 300))
	_check(full_world.loot_drops.size() == 1 and warnings.size() == 1 and full_world.player.bag.size() == ItemCatalog.bag_size(), "con la mochila llena el clic avisa y el item sigue en el suelo")
	full_world.player.discard_from_bag(0)
	_click(full_world, Vector2(300, 300))
	_check(full_world.loot_drops.is_empty() and full_world.player.bag.size() == ItemCatalog.bag_size(), "al hacer sitio se puede recoger")
	# Caducidad y cambio de escenario.
	var timed: CombatWorld = CombatWorldScript.new(52)
	timed.setup_arena(Rect2(0, 0, 900, 600))
	timed.player.position = Vector2(50, 50)
	timed.loot_drops.append(LootDrop.new(item, Vector2(800, 500)))
	timed.loot_drops[0].age = LootDrop.LIFETIME - 0.01
	timed.step(1.0 / 60.0)
	_check(timed.loot_drops.is_empty(), "el botin del suelo caduca")
	var session := GameSession.new(CombatWorldScript.new(53), "")
	session.world.loot_drops.append(LootDrop.new(item, Vector2(300, 300)))
	session.go_to_training()
	_check(session.world.loot_drops.is_empty(), "al cambiar de escenario se borra el botin del suelo")
	var dead: CombatWorld = CombatWorldScript.new(54)
	dead.setup_arena(Rect2(0, 0, 900, 600))
	dead.loot_drops.append(LootDrop.new(item, dead.player.position))
	dead.player.take_damage(1.0e9)
	dead.loot_drops[0].age = 1.0
	_click(dead, dead.player.position)
	_check(dead.loot_drops.size() == 1, "un jugador muerto no recoge")


func _test_sell_and_gold() -> void:
	var player := _new_player()
	var common := {"id": "iron_sword", "rarity": "common", "tier": 1, "stats": {"strength": 2.0}}
	var legendary := {"id": "iron_sword", "rarity": "legendary", "tier": 1, "stats": {"strength": 2.0}}
	var deep := {"id": "iron_sword", "rarity": "common", "tier": 11, "stats": {"strength": 2.0}}
	_check(ItemCatalog.sell_value(common) == 20 and ItemCatalog.sell_value(legendary) == 1200 and ItemCatalog.sell_value(deep) == 80, "el precio sube con la rareza y el tier")
	player.add_item(common)
	player.add_item(legendary)
	var gold_events: Array = []
	player.gold_changed.connect(func(total: int) -> void: gold_events.append(total))
	_check(player.sell_from_bag(0) == 20 and player.gold == 20 and player.bag.size() == 1 and gold_events == [20], "vender da oro y quita el item")
	_check(player.sell_from_bag(5) == -1 and player.gold == 20, "vender un indice invalido no hace nada")
	player.safe_zone = false
	_check(player.sell_from_bag(0) == -1 and player.bag.size() == 1, "no se vende en un piso")
	player.safe_zone = true
	var world: CombatWorld = CombatWorldScript.new(40)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var slime := world.add_enemy(&"slime", Vector2(300, 300))
	var expected := int(round(float(slime.xp_reward()) * 0.35))
	slime.take_damage(1.0e9)
	_check(world.player.gold == expected and expected > 0, "los enemigos sueltan oro segun su XP")
	var data := player.export_state()
	var other := _new_player()
	other.import_state(data)
	_check(other.gold == player.gold, "el oro se guarda y se restaura")
	var unique_seen := false
	var rng := _rng(5)
	for i: int in range(3000):
		if ItemGen.roll_rarity(rng, 0.0) == "unique":
			unique_seen = true
	_check(unique_seen, "la rareza Unica puede salir")


func _test_floor_chest() -> void:
	var session := GameSession.new(CombatWorldScript.new(12), "")
	var chests: Array = []
	session.chest_opened.connect(func(item: Dictionary) -> void: chests.append(item))
	session.go_to_floor(1)
	var bag_before := session.world.player.bag.size()
	for enemy: EnemySim in session.world.enemies:
		if enemy.required:
			enemy.take_damage(1.0e9)
	session.world.step(1.0 / 60.0)
	session.world.step(1.0 / 60.0)
	_check(chests.size() == 1 and session.world.player.bag.size() >= bag_before + 1, "completar un piso abre un cofre con un item")
	session.go_to_city()
	session.go_to_floor(1)
	for enemy: EnemySim in session.world.enemies:
		if enemy.required:
			enemy.take_damage(1.0e9)
	session.world.step(1.0 / 60.0)
	session.world.step(1.0 / 60.0)
	_check(chests.size() == 1, "el cofre solo se abre la primera vez que se completa el piso")


func _test_save_roundtrip() -> void:
	SaveGame.delete(SAVE_PATH)
	var session := GameSession.new(CombatWorldScript.new(3), SAVE_PATH)
	var player := session.world.player
	player.add_item(ItemGen.roll_item(_rng(1), 2, "epic", "weapon", "warrior"))
	player.add_item(ItemGen.roll_item(_rng(2), 3, "rare", "chest"))
	player.add_item(ItemGen.roll_item(_rng(3), 1, "common", "ring"))
	player.equip_from_bag(0)
	player.equip_from_bag(0)
	var hp := player.max_health
	var bag_json := JSON.stringify(player.bag)
	var equip_json := JSON.stringify(player.equipment)
	session.autosave()
	var loaded := GameSession.new(CombatWorldScript.new(3), SAVE_PATH)
	var restored := loaded.world.player
	_check(JSON.stringify(restored.bag) == bag_json, "la mochila se restaura")
	_check(JSON.stringify(restored.equipment) == equip_json and is_equal_approx(restored.max_health, hp), "el equipo se restaura y cuenta para los stats")
	restored.switch_class("rogue")
	_check(restored.equipment.is_empty() and restored.bag.size() == player.bag.size(), "la mochila es compartida y el equipo es por clase tras cargar")
	# Un item corrupto o de un id que ya no existe se ignora al cargar.
	var data := player.export_state()
	data["bag"].append({"id": "no_existe", "rarity": "common", "tier": 1, "stats": {"armor": 99.0}})
	data["bag"].append({"id": "iron_sword", "rarity": "mitico", "tier": 1, "stats": {}})
	var fresh := _new_player()
	fresh.import_state(data)
	_check(fresh.bag.size() == player.bag.size(), "los items invalidos se descartan al cargar")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
