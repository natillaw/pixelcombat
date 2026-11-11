## Humo de la escena principal: monta el juego completo (arena, actores, HUD,
## paneles), recorre ciudad, patio y un piso de la torre, y comprueba que los
## actores se crean y se limpian al cambiar de escenario. No dibuja (headless); sirve
## para detectar errores de script que los tests de simulacion no ven.
##
##   godot --headless --path . res://tests/test_scene_smoke.tscn
extends Node

const MainScene := preload("res://game/main.tscn")

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_scene_smoke (escena principal) ==")
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await _frames(5)
	var world: CombatWorld = main.get("world")
	var session: GameSession = main.get("session")
	var arena: Arena = main.get("arena")
	_check(session.layout.kind == FloorLayout.KIND_CITY and arena.portal_markers.size() == session.layout.portals.size(), "la ciudad se monta con sus portales")

	session.go_to_training()
	await _frames(5)
	_check(arena.dummy_actors.size() == 3 and arena.enemy_actors.size() == 7, "el patio crea sus actores")
	var nodes: Array = arena.get_children().filter(func(c: Node) -> bool: return c.name == "Entities")[0].get_children().filter(func(c: Node) -> bool: return c is Arena.ResourceActor)
	_check(nodes.size() == 3, "el patio dibuja sus tres nodos de recoleccion")

	world.player.set_level(5)
	_check(session.go_to_floor(1), "se entra al piso 1")
	await _frames(5)
	_check(arena.enemy_actors.size() == world.enemies.size() and arena.dummy_actors.is_empty(), "el piso reemplaza los actores del patio")

	# Recolectar un nodo y recoger botin con clics reales sobre el mundo.
	var node: ResourceNode = world.resource_nodes[0]
	for enemy: EnemySim in world.enemies:
		enemy.take_damage(1.0e9)
	var reasons: Array = []
	world.gather_interrupted.connect(func(_n: ResourceNode, why: String) -> void: reasons.append(why))
	world.player.position = node.position + Vector2(20, 0)
	_check(world.try_click(node.position) == "", "se puede empezar a recolectar un nodo del piso")
	for i: int in range(150):
		world.step(1.0 / 60.0)
	await _frames(3)
	_check(node.depleted and world.player.material_count(node.material_id()) >= 1, "el nodo se agota y da materiales %s" % str(reasons))

	var drop := LootDrop.new(ItemGen.roll_item(RandomNumberGenerator.new(), 1, "epic"), world.player.position + Vector2(10, 0))
	var bag_before := world.player.bag.size()
	world.loot_drops.append(drop)
	world.loot_spawned.emit(drop)
	await _frames(3)
	drop.age = 1.0
	_check(world.try_click(drop.position) == "" and world.player.bag.size() == bag_before + 1, "se recoge el botin del suelo con clic")
	await _frames(3)

	session.go_to_city()
	await _frames(5)
	_check(arena.enemy_actors.is_empty() and world.loot_drops.is_empty(), "volver a la ciudad limpia los actores")

	# Paneles: taller de crafting e inventario se abren y dibujan sin errores.
	var crafting: CraftingPanel = main.get("crafting_panel")
	world.player.add_material("hide_t1", 12)
	world.player.add_gold(100)
	crafting.open("tailor")
	await _frames(3)
	_check(crafting.is_open and TickManager.is_paused(), "el taller se abre y pausa el juego")
	var bag_before_craft := world.player.bag.size()
	crafting._craft()
	await _frames(2)
	_check(world.player.bag.size() == bag_before_craft + 1, "fabricar desde el panel anade el item")
	crafting.close()
	var actor_key: String = main.arena.player_actor._look_key
	world.player.equip_from_bag(world.player.bag.size() - 1)
	await _frames(3)
	_check(main.arena.player_actor._look_key != actor_key and world.player.equipment.size() == 1, "equipar un item recompone el sprite del jugador")
	_check(not crafting.is_open and not TickManager.is_paused(), "cerrar el taller reanuda el juego")
	var inventory: InventoryPanel = main.get("inventory_panel")
	inventory._toggle()
	await _frames(3)
	_check(inventory.is_open, "el inventario se abre con materiales y botin")
	inventory._toggle()

	main.queue_free()
	await _frames(2)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
