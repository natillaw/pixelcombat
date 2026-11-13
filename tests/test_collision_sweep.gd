## Barrido de colisiones: en muchos pisos, el jugador entra libre, nada importante esta enterrado en muros u
## obstaculos y ningun enemigo despierta encima de la entrada.
##
##   godot --headless --path . --script tests/test_collision_sweep.gd
extends SceneTree

const CombatWorldScript := preload("res://game/sim/combat_world.gd")
const VISITS := 8
## Cuanto puede moverse un punto al resolver colisiones antes de considerarlo "enterrado" (px).
const BURIED := 22.0
## Distancia minima de un enemigo despierto a la entrada (px).
const SAFE_SPAWN := 180.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_collision_sweep ==")
	var buried_objects: Array[String] = []
	var buried_enemies: Array[String] = []
	var bad_spawn: Array[String] = []
	var crowded_spawn: Array[String] = []
	var total := 0
	for floor_number: int in range(1, 11):
		for visit: int in range(1, VISITS + 1):
			total += 1
			var world := CombatWorldScript.new(visit)
			var session := GameSession.new(world, "")
			world.player.safe_zone = false
			var layout := TowerGenerator.generate(floor_number, 20261110, visit)
			session._enter(layout, false)
			var label := "piso %d visita %d" % [floor_number, visit]
			var spawn := layout.player_spawn
			if world.resolve_position(spawn, PlayerSim.RADIUS).distance_to(spawn) > 6.0:
				bad_spawn.append(label)
			for enemy: EnemySim in world.enemies:
				var moved := world.resolve_position(enemy.position, enemy.radius, enemy).distance_to(enemy.position)
				if moved > BURIED * 2.0:
					buried_enemies.append("%s %s (%.0f px)" % [label, str(enemy.def_id), moved])
				if enemy.position.distance_to(spawn) < SAFE_SPAWN and not enemy.summoned:
					crowded_spawn.append("%s %s" % [label, str(enemy.def_id)])
			var reach := world.grid.reachable_from(world.grid.world_to_cell(spawn))
			for object: Interactable in world.interactables:
				if not _usable_from_outside(world, reach, object.position):
					buried_objects.append("%s %s sin sitio libre donde usarlo" % [label, object.kind])
			for node: ResourceNode in world.resource_nodes:
				# Las vetas y arboles son obstaculos por si mismos: solo se comprueba que no esten dentro de un muro.
				var node_cell := world.grid.world_to_cell(node.position)
				if world.grid.blocks_move(node_cell.x, node_cell.y):
					buried_objects.append("%s nodo %s en un muro" % [label, node.kind])
	print("   %d pisos revisados" % total)
	_check(bad_spawn.is_empty(), "el jugador entra libre en todos los pisos (%s)" % str(bad_spawn.slice(0, 3)))
	_check(buried_objects.is_empty(), "ningun objeto de mision, hoguera ni veta esta enterrado (%d: %s)" % [buried_objects.size(), str(buried_objects.slice(0, 3))])
	_check(buried_enemies.is_empty(), "ningun enemigo nace enterrado (%d: %s)" % [buried_enemies.size(), str(buried_enemies.slice(0, 3))])
	_check(crowded_spawn.is_empty(), "ningun enemigo nace a menos de %d px de la entrada (%d: %s)" % [int(SAFE_SPAWN), crowded_spawn.size(), str(crowded_spawn.slice(0, 3))])
	# Ciudad: spawn, portales y residentes libres.
	var city := Layouts.city()
	var city_world := CombatWorldScript.new(1)
	var city_session := GameSession.new(city_world, "")
	city_session._enter(city, true)
	_check(city_world.resolve_position(city.player_spawn, PlayerSim.RADIUS).distance_to(city.player_spawn) < 6.0, "el jugador entra libre en la ciudad")
	var city_buried := 0
	for portal: Dictionary in city.portals:
		if String(portal["id"]).begins_with("talk_") or String(portal["id"]).begins_with("door_"):
			continue
		if city_world.resolve_position(portal["position"], PlayerSim.RADIUS).distance_to(portal["position"]) > BURIED:
			city_buried += 1
	_check(city_buried == 0, "los portales de la ciudad no estan enterrados (%d)" % city_buried)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


## Hay un punto libre y alcanzable a distancia de uso (44 px) del objeto: el jugador puede ponerse a usarlo.
func _usable_from_outside(world: CombatWorld, reach: PackedByteArray, point: Vector2) -> bool:
	var cell := world.grid.world_to_cell(point)
	if world.grid.blocks_move(cell.x, cell.y):
		return false
	for i: int in range(12):
		var candidate := point + Vector2.from_angle(TAU * float(i) / 12.0) * 44.0
		if world.resolve_position(candidate, PlayerSim.RADIUS).distance_to(candidate) > 3.0:
			continue
		var candidate_cell := world.grid.world_to_cell(candidate)
		if world.grid.in_bounds(candidate_cell.x, candidate_cell.y) and reach[candidate_cell.y * world.grid.cols + candidate_cell.x] == 1:
			return true
	return false


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
