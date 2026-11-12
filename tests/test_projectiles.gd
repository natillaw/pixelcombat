## Proyectiles (Mage, Archer y el abanico del Rogue): vuelo, impacto, perforacion,
## explosion, abanico, carga manteniendo el boton, limites y determinismo.
##
##   godot --headless --path . --script tests/test_projectiles.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_projectiles ==")
	_test_flight_and_hit()
	_test_range_and_bounds()
	_test_obstacle_stops_it()
	_test_pierce()
	_test_explosion()
	_test_fan_of_projectiles()
	_test_hold_makes_it_stronger_and_longer()
	_test_resource_cap_is_shared_by_a_volley()
	_test_does_not_hit_the_dead_or_the_caster()
	_test_determinism_and_reset()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_flight_and_hit() -> void:
	var world := _make("mage", 1, [Vector2(150, 0)])
	var spawned: Array = []
	var launched: Array = []
	world.projectile_spawned.connect(func(p: ProjectileSim) -> void: spawned.append(p))
	world.player.projectiles_launched.connect(func(skill: Dictionary, _d: Vector2) -> void: launched.append(skill["id"]))
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, damage: float, _c: bool, _p: Vector2) -> void: hits.append([target, damage]))
	_step(world, 1, _input({"m1": true}))
	_check(world.projectiles.is_empty(), "no hay proyectil durante el windup")
	_step(world, 10, _input({}))
	_check(spawned.size() == 1 and world.projectiles.size() == 1, "al acabar el windup sale un proyectil")
	_check(launched == [&"arcane_bolt"], "projectiles_launched avisa una vez por salva")
	var projectile: ProjectileSim = spawned[0]
	var x_before := projectile.position.x
	_step(world, 6, _input({}))
	var expected_step := float(SkillCatalog.skill(&"arcane_bolt")["projectile"]["speed"]) * DT * 6.0
	_check(absf((projectile.position.x - x_before) - expected_step) < 0.5, "vuela en linea recta a su velocidad (%.1f px en 6 ticks)" % (projectile.position.x - x_before))
	_step(world, 60, _input({}))
	_check(hits.size() == 1 and hits[0][0] == world.dummies[0], "golpea al blanco que cruza")
	_check(float(hits[0][1]) > 0.0 and not projectile.alive, "hace dano y muere (sin perforar)")
	_check(world.projectiles.is_empty(), "el mundo lo retira")


func _test_range_and_bounds() -> void:
	var world := _make("archer", 1, [])
	var projectile := _fire(world, "m1")
	var range_total := float(SkillCatalog.skill(&"quick_shot")["projectile"]["range"])
	_check(is_equal_approx(_total_range(projectile), range_total), "tiene el alcance de su skill (%.0f px)" % _total_range(projectile))
	_step(world, 90, _input({}))
	_check(not projectile.alive and projectile.travelled <= range_total + 0.01, "muere al agotar su alcance (%.0f px)" % projectile.travelled)

	var edge_world := _make("archer", 1, [])
	edge_world.player.position = Vector2(edge_world.bounds.end.x - 30.0, 300.0)
	var edge_projectile := _fire(edge_world, "m1")
	_step(edge_world, 30, _input({}))
	_check(not edge_projectile.alive and edge_projectile.travelled < range_total, "muere al salir de la arena")


func _test_obstacle_stops_it() -> void:
	var world: CombatWorld = CombatWorldScript.new(5)
	world.setup_arena(Rect2(0, 0, 900, 600), [{"position": Vector2(540, 300), "radius": 21.0}])
	world.player.switch_class("archer")
	var dummy := world.add_dummy(Vector2(640, 300), false)
	_step(world, 1, _input({"m1": true}))
	_step(world, 80, _input({}))
	_check(is_equal_approx(dummy.health, dummy.max_health), "un pilar entre medias detiene la flecha")


func _test_pierce() -> void:
	# Ice Lance perfora 2 (golpea 3 en total); Quick Shot no perfora.
	var world := _make("mage", 10, [Vector2(60, 0), Vector2(110, 0), Vector2(160, 0), Vector2(210, 0)])
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(target))
	world.player.resource.current_amount = 100.0
	_step(world, 1, _input({"s3": true}))
	_step(world, 80, _input({}))
	_check(hits.size() == 3, "Ice Lance perfora 2: golpea a 3 de 4 en fila (%d)" % hits.size())
	_check(hits[0] == world.dummies[0] and hits[2] == world.dummies[2], "y en orden de aparicion")
	var control := _make("archer", 1, [Vector2(60, 0), Vector2(110, 0)])
	var control_hits: Array = []
	control.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: control_hits.append(target))
	_step(control, 1, _input({"m1": true}))
	_step(control, 60, _input({}))
	_check(control_hits.size() == 1, "Quick Shot no perfora: golpea solo al primero")


func _test_explosion() -> void:
	# Fireball: dano directo al primero y 0,8 de dano de explosion a los cercanos.
	var world := _make("mage", 2, [Vector2(120, 0), Vector2(120, 40), Vector2(120, 200)])
	_fix_damage(world)
	var damages: Dictionary = {}
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, damage: float, _c: bool, _p: Vector2) -> void: damages[target] = damage)
	world.player.resource.current_amount = 100.0
	_step(world, 1, _input({"s1": true}))
	_step(world, 90, _input({}))
	var direct: float = damages.get(world.dummies[0], -1.0)
	var splash: float = damages.get(world.dummies[1], -1.0)
	_check(direct > 0.0 and splash > 0.0, "el impacto y la explosion golpean")
	_check(absf(splash / direct - float(SkillCatalog.skill(&"fireball")["projectile"]["explode"]["mult"])) < 0.01, "la explosion hace el 0,8 del impacto directo (x%.2f)" % (splash / direct))
	_check(not damages.has(world.dummies[2]), "el que esta fuera del radio no recibe nada")
	_check(world.projectiles.is_empty(), "el proyectil explosivo muere al explotar")


func _test_fan_of_projectiles() -> void:
	var world := _make("archer", 2, [])
	world.player.resource.current_amount = 100.0
	var directions: Array = []
	world.projectile_spawned.connect(func(p: ProjectileSim) -> void: directions.append(p.direction))
	_step(world, 1, _input({"s1": true}))
	_step(world, 20, _input({}))
	var spec: Dictionary = SkillCatalog.skill(&"multishot")["projectile"]
	_check(directions.size() == int(spec["count"]), "Multishot lanza %d flechas" % int(spec["count"]))
	if directions.size() == int(spec["count"]):
		var half := float(spec["spread"]) * 0.5
		_check(absf(rad_to_deg(Vector2.RIGHT.angle_to(directions[0])) + half) < 0.5 and absf(rad_to_deg(Vector2.RIGHT.angle_to(directions[4])) - half) < 0.5, "abren un abanico de +-%.0f grados" % half)
		_check(directions[2].is_equal_approx(Vector2.RIGHT), "la central va recta")


func _test_hold_makes_it_stronger_and_longer() -> void:
	var tap := _m2_projectile("mage", 1)
	var full := _m2_projectile("mage", 120)
	_check(tap != null and full != null, "(preparacion) ambos M2 lanzan proyectil")
	if tap != null and full != null:
		var bonus := float(SkillCatalog.skill(&"charged_arcane_blast")["hold"]["damage_bonus"])
		_check(absf(full.damage_mult / tap.damage_mult - (1.0 + bonus)) < 0.01, "mantener el boton sube el dano del proyectil (x%.2f)" % (full.damage_mult / tap.damage_mult))
		var range_bonus := float(SkillCatalog.skill(&"charged_arcane_blast")["hold"]["range_bonus"])
		_check(absf(_total_range(full) / _total_range(tap) - (1.0 + range_bonus)) < 0.01, "y su alcance (x%.2f)" % (_total_range(full) / _total_range(tap)))
	var archer_full := _m2_projectile("archer", 120)
	var archer_tap := _m2_projectile("archer", 1)
	_check(archer_full != null and archer_tap != null and _total_range(archer_full) > _total_range(archer_tap), "el Charged Shot del Archer tambien llega mas lejos cargado")


func _test_resource_cap_is_shared_by_a_volley() -> void:
	# Cinco dummies, una flecha para cada uno: la salva no pasa del tope de carga.
	var offsets: Array = []
	for i: int in range(5):
		var angle := deg_to_rad(-25.0 + 12.5 * float(i))
		offsets.append(Vector2.from_angle(angle) * 100.0)
	var world := _make("archer", 2, offsets)
	world.player.resource.current_amount = 100.0
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(target))
	_step(world, 1, _input({"s1": true}))
	_step(world, 80, _input({}))
	_check(hits.size() == 5, "las cinco flechas aciertan (%d)" % hits.size())
	var spec := SkillCatalog.skill(&"multishot")
	_check(absf(world.player.ultimate_charge - float(spec["ult_cap"]) * float(world.player.class_def["ult_charge"]["hit_scale"])) < 10.0 and world.player.ultimate_charge >= float(spec["ult_cap"]) * float(world.player.class_def["ult_charge"]["hit_scale"]) - 0.01, "la carga de Ultimate de la salva se limita a ult_cap (mas los criticos) (%.1f)" % world.player.ultimate_charge)


func _test_does_not_hit_the_dead_or_the_caster() -> void:
	var world := _make("archer", 1, [Vector2(80, 0)])
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(target))
	world.dummies[0].take_damage(100000.0)
	var health := world.player.health
	_step(world, 1, _input({"m1": true}))
	_step(world, 60, _input({}))
	_check(hits.is_empty() and is_equal_approx(world.player.health, health), "un blanco muerto no se golpea y el lanzador nunca recibe su propio proyectil")


func _test_determinism_and_reset() -> void:
	var a := _volley_snapshot(9)
	var b := _volley_snapshot(9)
	var c := _volley_snapshot(10)
	_check(a == b, "la misma semilla da la misma salva")
	_check(a != c, "otra semilla cambia criticos y danos")
	var world := _make("archer", 1, [])
	_fire(world, "m1")
	_check(world.projectiles.size() == 1, "(preparacion) hay un proyectil en vuelo")
	var removed: Array = []
	world.projectile_removed.connect(func(p: ProjectileSim) -> void: removed.append(p))
	world.reset()
	_check(world.projectiles.is_empty() and removed.size() == 1, "world.reset() retira los proyectiles en vuelo")
	_check(world.snapshot().has("projectiles"), "el snapshot lista los proyectiles")


func _volley_snapshot(seed_value: int) -> String:
	var world: CombatWorld = CombatWorldScript.new(seed_value)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.player.switch_class("archer")
	world.player.set_level(10)
	LegacyKit.apply(world.player)
	world.player.resource.current_amount = 100.0
	world.add_dummy(world.player.position + Vector2(120, 10), false)
	world.add_dummy(world.player.position + Vector2(160, -10), false)
	for i: int in range(240):
		world.submit_input(_input({"s1": i == 0, "m1": i > 40 and i % 50 < 20}))
		world.step(DT)
	return var_to_str(world.snapshot())


# --- Helpers ----------------------------------------------------------------


func _make(class_id: String, level: int, offsets: Array) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(5)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.player.switch_class(class_id)
	world.player.set_level(level)
	LegacyKit.apply(world.player)
	for offset: Vector2 in offsets:
		world.add_dummy(world.player.position + offset, false)
	return world


## Alcance total del proyectil (lo ya recorrido mas lo que le queda).
func _total_range(projectile: ProjectileSim) -> float:
	return projectile.range_left + projectile.travelled


func _fix_damage(world: CombatWorld) -> void:
	world.player.stats.set_base_stat(&"weapon_min", 10.0)
	world.player.stats.set_base_stat(&"weapon_max", 10.0)
	world.player.stats.set_base_stat(&"crit_chance", 0.0)


## Pulsa `action` y devuelve el primer proyectil que sale.
func _fire(world: CombatWorld, action: String) -> ProjectileSim:
	var spawned: Array = []
	world.projectile_spawned.connect(func(p: ProjectileSim) -> void: spawned.append(p))
	_step(world, 1, _input({action: true}))
	var guard := 0
	while spawned.is_empty() and guard < 90:
		_step(world, 1, _input({}))
		guard += 1
	return spawned[0] if not spawned.is_empty() else null


## Primer proyectil de un M2 mantenido `hold_ticks` ticks.
func _m2_projectile(class_id: String, hold_ticks: int) -> ProjectileSim:
	var world := _make(class_id, 1, [])
	_fix_damage(world)
	var spawned: Array = []
	world.projectile_spawned.connect(func(p: ProjectileSim) -> void: spawned.append(p))
	_step(world, hold_ticks, _input({"m2": true}))
	_step(world, 90, _input({}))
	return spawned[0] if not spawned.is_empty() else null


func _input(actions: Dictionary) -> InputMessage:
	var message: InputMessage = InputMessageScript.new()
	message.tick = 0
	message.peer_id = 1
	message.move_dir = Vector2.ZERO
	message.aim_dir = Vector2.RIGHT
	message.actions = actions.duplicate()
	return message


func _step(world: CombatWorld, ticks: int, message: InputMessage) -> void:
	for i: int in range(ticks):
		var copy: InputMessage = InputMessageScript.new()
		copy.tick = message.tick
		copy.peer_id = message.peer_id
		copy.move_dir = message.move_dir
		copy.aim_dir = message.aim_dir
		copy.actions = message.actions.duplicate()
		world.submit_input(copy)
		world.step(DT)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
