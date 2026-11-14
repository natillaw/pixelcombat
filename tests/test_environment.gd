## Entorno de los pisos: peligros del suelo (fango, pinchos, charcos), barriles que explotan y contenido por piso.
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
	_test_mud_slows_and_spikes_hurt()
	_test_barrels()
	_test_floor_content()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _flat_world() -> CombatWorld:
	var world := CombatWorld.new(7)
	world.player.position = Vector2(300, 300)
	return world


func _test_catalogs() -> void:
	for id: String in ["mud", "spikes", "poison_pool"]:
		var def := HazardCatalog.hazard(id)
		_check(not def.is_empty() and (def["radius"] as Array).size() == 2, "peligro '%s' definido" % id)
	_check(FloorFeatures.has_features(1) and FloorFeatures.has_features(9) and not FloorFeatures.has_features(10), "los pisos 1-9 llevan extras y el 10 no")


func _test_mud_slows_and_spikes_hurt() -> void:
	var world := _flat_world()
	world._spawn_hazard({"kind": "mud", "position": world.player.position, "radius": 60.0})
	world._spawn_hazard({"kind": "spikes", "position": world.player.position + Vector2(400, 0), "radius": 40.0})
	var health := world.player.health
	for i: int in range(90):
		world.step(DT)
	_check(world.player.statuses.has("slow"), "pisar fango ralentiza")
	_check(world.player.health >= health, "el fango no hace dano")
	world.player.position = world.player.position + Vector2(400, 0)
	for i: int in range(120):
		world.step(DT)
	_check(world.player.health < health, "los pinchos hacen dano (%.0f -> %.0f)" % [health, world.player.health])
	# Tambien dana a los enemigos que pasan por encima.
	var enemy := world.add_enemy(&"slime", world.player.position + Vector2(5, 5))
	var enemy_health := enemy.health
	for i: int in range(120):
		world.step(DT)
	_check(enemy.health < enemy_health, "los pinchos tambien danan a los enemigos")


func _test_barrels() -> void:
	var world := _flat_world()
	var barrel := world.add_enemy(&"barrel_explosive", world.player.position + Vector2(40, 0))
	var near := world.add_enemy(&"slime", world.player.position + Vector2(55, 10))
	var health := world.player.health
	var near_health := near.health
	var xp := world.player.xp
	barrel.take_damage(1.0e6)
	_check(not barrel.alive, "el barril se rompe")
	_check(world.player.health < health, "la explosion dana al jugador cercano")
	_check(near.health < near_health, "la explosion dana a los enemigos cercanos")
	_check(world.player.xp == xp and world.loot_drops.is_empty(), "un barril no da XP ni botin")
	# Cadena: un barril cercano explota tambien.
	var world2 := _flat_world()
	var first := world2.add_enemy(&"barrel_explosive", world2.player.position + Vector2(400, 0))
	var second := world2.add_enemy(&"barrel_explosive", world2.player.position + Vector2(450, 0))
	first.take_damage(1.0e6)
	_check(not second.alive, "los barriles explosivos encadenan")
	# Barril de aceite: deja una zona de fuego que dana.
	var world3 := _flat_world()
	var oil := world3.add_enemy(&"barrel_oil", world3.player.position + Vector2(20, 0))
	var before := world3.zones.size()
	oil.take_damage(1.0e6)
	_check(world3.zones.size() > before, "el barril de aceite deja una zona de fuego")
	var oil_health := world3.player.health
	for i: int in range(120):
		world3.step(DT)
	_check(world3.player.health < oil_health, "el fuego de aceite dana al que se queda dentro")
	# Un barril sin tocar no hace nada.
	var world4 := _flat_world()
	var calm := world4.add_enemy(&"barrel_explosive", world4.player.position + Vector2(30, 0))
	for i: int in range(300):
		world4.step(DT)
	_check(calm.alive and calm.state == EnemySim.State.IDLE, "un barril quieto no ataca ni se mueve")


func _test_floor_content() -> void:
	var hazard_total := 0
	var hazard_wanted := 0
	var floors_with_barrels := 0
	var floors_without_barrels := 0
	var outside_camp := 0
	for floor_number: int in range(1, 11):
		for seed_value: int in [20261110, 7, 99, 4242, 31337, 555]:
			var layout := TowerGenerator.generate(floor_number, seed_value, 1)
			var barrels: Array = layout.enemies.filter(func(e: Dictionary) -> bool: return String(e["id"]).begins_with("barrel_"))
			if floor_number == 10:
				_check(layout.hazards.is_empty() and barrels.is_empty(), "el piso 10 (seed %d) no lleva peligros ni barriles" % seed_value)
				continue
			var wanted := 0
			for kind: String in FloorFeatures.for_floor(floor_number).get("hazards", {}):
				wanted += int(FloorFeatures.for_floor(floor_number)["hazards"][kind])
			hazard_wanted += wanted
			hazard_total += layout.hazards.size()
			if barrels.is_empty():
				floors_without_barrels += 1
			else:
				floors_with_barrels += 1
			for barrel: Dictionary in barrels:
				var near := false
				for camp: Dictionary in layout.camps:
					if String(camp["kind"]) == "camp" and (camp["position"] as Vector2).distance_to(barrel["position"]) <= 260.0:
						near = true
				if not near:
					outside_camp += 1
			var ok := true
			for hazard: Dictionary in layout.hazards:
				ok = ok and layout.grid.is_walkable_point(hazard["position"])
			if not ok:
				_check(false, "piso %d seed %d: un peligro cae en suelo no andable" % [floor_number, seed_value])
	_check(hazard_total > 0 and hazard_total < hazard_wanted, "los peligros son probabilisticos (%d de %d posibles)" % [hazard_total, hazard_wanted])
	_check(floors_with_barrels > 0 and floors_without_barrels > 0, "hay pisos con barriles (%d) y sin ellos (%d)" % [floors_with_barrels, floors_without_barrels])
	_check(outside_camp == 0, "los barriles solo salen dentro de campamentos")
	var a := TowerGenerator.generate(6, 20261110, 1)
	var b := TowerGenerator.generate(6, 20261110, 1)
	_check(a.hazards.size() == b.hazards.size() and a.camps.size() == b.camps.size(), "la generacion es determinista")
