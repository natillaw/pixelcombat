## Recoleccion y materiales: catalogo, nodos en los pisos, recolectar con clic
## (alcance, canalizacion, interrupciones, rendimiento), botin de materiales de los
## enemigos, reaparicion al reentrar y guardado.
##
##   godot --headless --path . --script tests/test_gathering.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const DT: float = 1.0 / 60.0
const SAVE_PATH := "user://test_gather_save.json"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_gathering (recoleccion y materiales) ==")
	_test_catalog()
	_test_nodes_in_layouts()
	_test_gather_flow()
	_test_gather_interruptions()
	_test_yield()
	_test_monster_materials()
	_test_respawn_and_tiers()
	_test_save()
	SaveGame.delete(SAVE_PATH)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _world_with_node(kind: String = "ore", tier: int = 1) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(21)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.player.position = Vector2(300, 300)
	world.resource_nodes.append(ResourceNode.new(kind, tier, Vector2(330, 300)))
	return world


func _run_ticks(world: CombatWorld, seconds: float) -> void:
	for i: int in range(int(ceil(seconds / DT))):
		world.step(DT)


func _click(world: CombatWorld, point: Vector2) -> String:
	var press := InputMessage.new()
	press.actions = {"pickup": true}
	press.target_pos = point
	world.submit_input(press)
	world.step(DT)
	var release := InputMessage.new()
	release.actions = {"pickup": false}
	world.submit_input(release)
	return ""


func _test_catalog() -> void:
	_check(MaterialCatalog.errors().is_empty(), "materials.json valido: %s" % str(MaterialCatalog.errors()))
	_check(MaterialCatalog.kind_ids() == ["ore", "herb", "wood", "hide", "chitin", "silk", "essence"], "siete tipos de material")
	_check(MaterialCatalog.gatherable_kinds() == ["ore", "herb", "wood"], "mineral, hierba y madera se recolectan; cuero, quitina, seda y esencia son botin de animales")
	_check(MaterialCatalog.tier_count() == TowerCatalog.tier_count(), "hay un material de cada tipo por cada tier de la torre")
	_check(MaterialCatalog.material_id("ore", 3) == "ore_t3" and MaterialCatalog.parse("ore_t3") == {"kind": "ore", "tier": 3}, "los ids de material se forman y se leen")
	_check(MaterialCatalog.is_valid("hide_t10") and not MaterialCatalog.is_valid("hide_t11") and not MaterialCatalog.is_valid("oro_t1") and not MaterialCatalog.is_valid("ore") and not MaterialCatalog.is_valid("ore_t0"), "los ids invalidos se rechazan")
	_check(MaterialCatalog.display_name("ore_t1") == "Mineral de cobre" and MaterialCatalog.display_name("ore_t2") != MaterialCatalog.display_name("ore_t1"), "cada tier tiene su nombre")
	var bad := {"kinds": [{"id": "ore", "source": "mine", "names": ["a"]}, {"id": "herb", "source": "herbalism", "names": ["a", "b"], "gather_seconds": 1}], "gather_yield": {"min": 1, "max": 2, "bonus_chance": 0.1}}
	_check(not MaterialCatalog.validate(bad).is_empty(), "un materials.json con tiers desiguales o sin gather_seconds no valida")


func _test_nodes_in_layouts() -> void:
	var ok := true
	var reason := ""
	for floor_number: int in [1, 2, 3, 5, 10, 20, 40, 77, 100]:
		var layout := TowerGenerator.generate(floor_number, 20261110)
		var ambient := layout.resources.filter(func(n: Dictionary) -> bool: return not bool(n.get("rich", false)))
		if ambient.size() < 5 or ambient.size() > 12:
			ok = false
			reason = "piso %d: %d nodos ambientales" % [floor_number, ambient.size()]
		for spec: Dictionary in layout.resources:
			var cell := layout.grid.world_to_cell(spec["position"])
			if not MaterialCatalog.gatherable_kinds().has(String(spec["kind"])) or not layout.bounds().has_point(spec["position"]) or layout.grid.blocks_move(cell.x, cell.y):
				ok = false
				reason = "piso %d: nodo invalido" % floor_number
			if (spec["position"] as Vector2).distance_to(layout.player_spawn) < 100.0:
				ok = false
				reason = "piso %d: nodo pegado a la entrada" % floor_number
	_check(ok, "los pisos de muestra traen nodos validos y alcanzables (%s)" % reason)
	_check(JSON.stringify(TowerGenerator.generate(7, 3).to_dict()["resources"]) == JSON.stringify(TowerGenerator.generate(7, 3).to_dict()["resources"]), "los nodos son deterministas")
	_check(Layouts.city().resources.is_empty() and Layouts.training().resources.size() == 3, "la ciudad no tiene nodos y el patio tiene tres de practica")
	var session := GameSession.new(CombatWorldScript.new(1), "")
	session.go_to_floor(1)
	_check(session.world.resource_nodes.size() == session.layout.resources.size() and session.world.resource_nodes[0].tier == 1, "load_layout crea los nodos con el tier del piso")


func _test_gather_flow() -> void:
	var world := _world_with_node()
	var started: Array = []
	var done: Array = []
	world.gather_started.connect(func(n: ResourceNode) -> void: started.append(n))
	world.resource_gathered.connect(func(n: ResourceNode, id: String, amount: int) -> void: done.append([id, amount]))
	var node: ResourceNode = world.resource_nodes[0]
	_check(world.target_at(Vector2(335, 305)) == node and world.target_at(Vector2(500, 500)) == null, "el cursor encuentra el nodo cercano")
	_check(world.in_reach(node), "el nodo esta al alcance")
	world.player.position = Vector2(100, 100)
	_check(world.try_click(node.position) == "far" and world.gather_node == null, "desde lejos no se empieza")
	world.player.position = Vector2(300, 300)
	_check(world.try_click(Vector2(600, 100)) == "none", "un clic en vacio no hace nada")
	_check(world.try_click(node.position) == "" and world.gather_node == node and started.size() == 1, "clic cerca empieza a recolectar")
	_check(world.try_click(node.position) == "busy", "no se puede empezar otra mientras se recolecta")
	_run_ticks(world, node.gather_seconds() - 0.3)
	_check(done.is_empty() and not node.depleted and world.gather_node == node, "aun no ha terminado antes de tiempo")
	_run_ticks(world, 0.5)
	_check(done.size() == 1 and node.depleted and world.gather_node == null, "al terminar el tiempo se agota el nodo")
	_check(String(done[0][0]) == "ore_t1" and int(done[0][1]) >= 1 and world.player.material_count("ore_t1") == int(done[0][1]), "da materiales del tipo y tier del nodo")
	_check(world.target_at(node.position) == null and world.try_click(node.position) == "none", "un nodo agotado ya no se puede clicar")
	# Por el input real: el clic mantenido empieza una sola vez.
	var again := _world_with_node("herb", 2)
	_click(again, again.resource_nodes[0].position)
	_check(again.gather_node != null, "el clic por InputMessage tambien recolecta")


func _test_gather_interruptions() -> void:
	var cases := {"moved": 0, "hit": 1, "attack": 2, "dodge": 3, "dead": 4}
	var results := {}
	for label: String in cases:
		var world := _world_with_node()
		world.player.safe_zone = true
		world.player.switch_class("rogue")
		world.player.safe_zone = false
		var reasons: Array = []
		world.gather_interrupted.connect(func(_n: ResourceNode, why: String) -> void: reasons.append(why))
		world.try_click(world.resource_nodes[0].position)
		_run_ticks(world, 0.3)
		match int(cases[label]):
			0:
				world.player.position += Vector2(20, 0)
			1:
				world.player.take_damage(5.0)
			2:
				var press := InputMessage.new()
				press.actions = {"m1": true}
				press.aim_dir = Vector2.RIGHT
				world.submit_input(press)
			3:
				var press := InputMessage.new()
				press.actions = {"dodge": true}
				press.move_dir = Vector2.ZERO
				press.aim_dir = Vector2.RIGHT
				world.submit_input(press)
			4:
				world.player.take_damage(1.0e9)
		world.step(DT)
		world.step(DT)
		results[label] = reasons.size() == 1 and world.gather_node == null and not (world.resource_nodes[0] as ResourceNode).depleted and world.player.materials.is_empty()
	_check(bool(results["moved"]), "moverse cancela la recoleccion sin dar nada")
	_check(bool(results["hit"]), "recibir dano la cancela")
	_check(bool(results["attack"]), "atacar la cancela")
	_check(bool(results["dodge"]), "esquivar la cancela")
	_check(bool(results["dead"]), "morir la cancela")
	var world := _world_with_node()
	world.try_click(world.resource_nodes[0].position)
	_run_ticks(world, 0.5)
	world.gather_interrupted.connect(func(_n: ResourceNode, _why: String) -> void: pass)
	var node: ResourceNode = world.resource_nodes[0]
	world.gather_node = null
	_check(world.try_click(node.position) == "" and world.gather_left > node.gather_seconds() - 0.1, "tras cancelar se puede reintentar desde cero")


func _test_yield() -> void:
	var spec := MaterialCatalog.gather_yield()
	var low := 999
	var high := 0
	for seed_value: int in range(60):
		var world: CombatWorld = CombatWorldScript.new(seed_value)
		world.setup_arena(Rect2(0, 0, 900, 600))
		world.player.position = Vector2(300, 300)
		world.resource_nodes.append(ResourceNode.new("wood", 1, Vector2(330, 300)))
		world.try_click(Vector2(330, 300))
		_run_ticks(world, 2.0)
		var got := world.player.material_count("wood_t1")
		low = mini(low, got)
		high = maxi(high, got)
	_check(low >= int(spec["min"]) and high <= int(spec["max"]) + 1 and high > low, "el rendimiento varia entre %d y %d (+1 de bonus)" % [int(spec["min"]), int(spec["max"])])
	var same_a := _world_with_node()
	var same_b := _world_with_node()
	for w: CombatWorld in [same_a, same_b]:
		w.try_click(w.resource_nodes[0].position)
		_run_ticks(w, 2.5)
	_check(same_a.player.materials == same_b.player.materials, "la recoleccion es determinista")


func _test_monster_materials() -> void:
	var world: CombatWorld = CombatWorldScript.new(60)
	world.setup_arena(Rect2(0, 0, 900, 600))
	for i: int in range(200):
		world.add_enemy(&"beetle", Vector2(300, 300)).take_damage(1.0e9)
	_check(world.player.material_count("chitin_t1") > 60 and world.player.material_count("chitin_t1") > world.player.material_count("hide_t1") * 2, "el Beetle suelta sobre todo quitina del tier 1")
	var bats: CombatWorld = CombatWorldScript.new(61)
	bats.setup_arena(Rect2(0, 0, 900, 600))
	for i: int in range(200):
		bats.add_enemy(&"bat", Vector2(300, 300)).take_damage(1.0e9)
	_check(bats.player.material_count("hide_t1") > 60, "el Bat suelta cuero")
	var boss: CombatWorld = CombatWorldScript.new(62)
	boss.setup_arena(Rect2(0, 0, 900, 600))
	boss.add_enemy(&"brood_beetle", Vector2(300, 300)).take_damage(1.0e9)
	_check(boss.player.material_count("chitin_t1") >= 3 and boss.player.material_count("hide_t1") >= 3, "un jefe siempre suelta de ambos y en cantidad")
	var summoned_world: CombatWorld = CombatWorldScript.new(63)
	summoned_world.setup_arena(Rect2(0, 0, 900, 600))
	for i: int in range(40):
		var minion := summoned_world.add_enemy(&"beetle", Vector2(300, 300))
		minion.summoned = true
		minion.take_damage(1.0e9)
	_check(summoned_world.player.materials.is_empty(), "las crias invocadas no sueltan materiales")
	var enemy_ok := true
	for id: Variant in EnemyCatalog.all_ids():
		for kind_id: Variant in EnemyCatalog.enemy(StringName(String(id))).get("materials", {}):
			if not MaterialCatalog.kind_ids().has(String(kind_id)):
				enemy_ok = false
	_check(enemy_ok, "las tablas de materiales de los enemigos usan tipos conocidos")
	var floor_session := GameSession.new(CombatWorldScript.new(64), "")
	floor_session.tower.complete(1)
	floor_session.tower.complete(2)
	floor_session.go_to_floor(3)
	_check(floor_session.world.resource_nodes.size() > 0 and (floor_session.world.resource_nodes[0] as ResourceNode).tier == 1, "los pisos 1-10 dan materiales del tier 1")
	TowerCatalog.playable_override = 100
	for n: int in range(3, 11):
		floor_session.tower.complete(n)
	floor_session.go_to_floor(11)
	_check((floor_session.world.resource_nodes[0] as ResourceNode).tier == 2, "el piso 11 da materiales del tier 2")
	TowerCatalog.playable_override = -1


func _test_respawn_and_tiers() -> void:
	var session := GameSession.new(CombatWorldScript.new(70), "")
	session.go_to_floor(1)
	var world := session.world
	var node: ResourceNode = world.resource_nodes[0]
	for enemy: EnemySim in world.enemies:
		enemy.take_damage(1.0e9)
	var stand := node.position + Vector2(44, 0)
	for offset: Vector2 in [Vector2(44, 0), Vector2(-44, 0), Vector2(0, 44), Vector2(0, -44)]:
		if world.resolve_position(node.position + offset, PlayerSim.RADIUS).distance_to(node.position + offset) < 0.5:
			stand = node.position + offset
			break
	world.player.position = stand
	world.try_click(node.position)
	_run_ticks(world, 3.0)
	_check(node.depleted, "se agota un nodo del piso")
	var count := world.resource_nodes.size()
	session.go_to_city()
	session.go_to_floor(1)
	var fresh := session.world.resource_nodes.filter(func(n: ResourceNode) -> bool: return not n.depleted)
	_check(session.world.resource_nodes.size() == count and fresh.size() == count, "al reentrar el piso los nodos vuelven")
	session.restart()
	_check(session.world.resource_nodes.size() == count and not (session.world.resource_nodes[0] as ResourceNode).depleted, "reiniciar el piso tambien repone los nodos")


func _test_save() -> void:
	SaveGame.delete(SAVE_PATH)
	var session := GameSession.new(CombatWorldScript.new(80), SAVE_PATH)
	session.world.player.add_material("ore_t1", 7)
	session.world.player.add_material("hide_t2", 3)
	var events: Array = []
	session.world.player.materials_changed.connect(func() -> void: events.append(1))
	session.world.player.add_material("herb_t1", 2)
	_check(not events.is_empty(), "cambiar materiales avisa")
	session.world.player.add_material("nada_t1", 5)
	session.world.player.add_material("ore_t1", -2)
	_check(session.world.player.material_count("nada_t1") == 0 and session.world.player.material_count("ore_t1") == 7, "no se anaden materiales invalidos ni cantidades negativas")
	session.autosave()
	var loaded := GameSession.new(CombatWorldScript.new(80), SAVE_PATH)
	_check(loaded.world.player.materials == session.world.player.materials, "los materiales se guardan y se restauran")
	var data := session.world.player.export_state()
	data["materials"]["roto_t9"] = 4
	data["materials"]["ore_t1"] = 0
	var fresh: CombatWorld = CombatWorldScript.new(81)
	fresh.player.import_state(data)
	_check(not fresh.player.materials.has("roto_t9") and not fresh.player.materials.has("ore_t1") and fresh.player.material_count("hide_t2") == 3, "al cargar se descartan materiales invalidos o a cero")
	var player := fresh.player
	_check(player.has_materials({"hide_t2": 3}) and not player.has_materials({"hide_t2": 4}), "has_materials compara con lo que hay")
	_check(player.spend_materials({"hide_t2": 2}) and player.material_count("hide_t2") == 1 and not player.spend_materials({"hide_t2": 2}) and player.material_count("hide_t2") == 1, "gastar es todo o nada")
	_check(player.spend_materials({"hide_t2": 1}) and not player.materials.has("hide_t2"), "al gastar todo desaparece la entrada")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
