## Mecanicas propias de Rogue, Mage y Archer: dash, golpes multiples, zona marcada
## con el cursor, mejora del siguiente ataque y evasion con contraataque.
##
##   godot --headless --path . --script tests/test_class_skills.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_class_skills (mecanicas por clase) ==")
	_test_rogue_dashes()
	_test_blade_flurry_strikes()
	_test_death_sentence()
	_test_perfect_evasion()
	_test_mage_overload_buff()
	_test_arcane_explosion()
	_test_cataclysm_marked_zone()
	_test_deadeye_buff_and_expiry()
	_test_rain_of_arrows()
	_test_costs_per_resource()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# --- Rogue -------------------------------------------------------------------


func _test_rogue_dashes() -> void:
	var world := _make("rogue", 2, [Vector2(160, 0)])
	var start := world.player.position
	_step(world, 1, _input({"m2": true}))
	_step(world, 40, _input({}))
	var cross := float(SkillCatalog.skill(&"cross_cut")["leap_distance"])
	_check(absf(world.player.position.x - start.x - cross) < 1.0, "Cross Cut se lanza hacia delante %.0f px" % cross)
	var world2 := _make("rogue", 2, [])
	var start2 := world2.player.position
	_step(world2, 1, _input({"s1": true}))
	_step(world2, 60, _input({}))
	_check(absf(world2.player.position.x - start2.x - float(SkillCatalog.skill(&"ambush")["leap_distance"])) < 1.0, "Ambush salta 120 px")


func _test_blade_flurry_strikes() -> void:
	var world := _make("rogue", 4, [Vector2(40, 0)])
	_fix_damage(world)
	var damages: Array = []
	var ticks: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void:
		damages.append(damage)
		ticks.append(world.tick))
	world.player.resource.current_amount = 100.0
	_step(world, 1, _input({"s2": true}))
	_step(world, 60, _input({}))
	var strikes := int(SkillCatalog.skill(&"blade_flurry")["strikes"]["count"])
	_check(damages.size() == strikes, "Blade Flurry golpea %d veces al mismo blanco (%d)" % [strikes, damages.size()])
	if damages.size() == strikes:
		var interval_ticks := int(round(float(SkillCatalog.skill(&"blade_flurry")["strikes"]["interval"]) / DT))
		_check(int(ticks[1]) - int(ticks[0]) == interval_ticks and int(ticks[2]) - int(ticks[1]) == interval_ticks, "separados por el intervalo de la skill (%d ticks)" % interval_ticks)
		_check(is_equal_approx(float(damages[0]), float(damages[1])) and is_equal_approx(float(damages[1]), float(damages[2])), "con el mismo dano (final_mult 1)")
	# El tope de carga de Ultimate por lanzamiento se respeta aunque haya varios golpes.
	var cap := float(SkillCatalog.skill(&"blade_flurry")["ult_cap"])
	_check(world.player.ultimate_charge <= cap + 0.001, "la carga de Ultimate no pasa del tope por lanzamiento (%.1f <= %.1f)" % [world.player.ultimate_charge, cap])


func _test_death_sentence() -> void:
	var world := _make("rogue", 8, [Vector2(190, 0)])
	_fix_damage(world)
	var damages: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void: damages.append(damage))
	world.player.ultimate_charge = 100.0
	var origin := world.player.position
	_step(world, 1, _input({"ultimate": true}))
	var landing: Vector2 = world.player.attack_point
	_check(landing.is_equal_approx(origin + Vector2.RIGHT * float(SkillCatalog.skill(&"death_sentence")["leap_distance"])), "Death Sentence marca el punto de aterrizaje")
	_step(world, 90, _input({}))
	var spec: Dictionary = SkillCatalog.skill(&"death_sentence")["strikes"]
	_check(damages.size() == int(spec["count"]), "encadena %d cortes (%d)" % [int(spec["count"]), damages.size()])
	if damages.size() == int(spec["count"]):
		_check(is_equal_approx(float(damages[0]), float(damages[3])), "los cuatro primeros son iguales")
		_check(absf(float(damages[4]) / float(damages[0]) - float(spec["final_mult"])) < 0.01, "el ultimo pega x%.1f" % (float(damages[4]) / float(damages[0])))
	_check(world.player.position.is_equal_approx(landing), "y el Rogue se queda donde aterrizo")


func _test_perfect_evasion() -> void:
	var world := _make("rogue", 6, [])
	world.player.resource.current_amount = 100.0
	_step(world, 1, _input({"special": true}))
	_step(world, 4, _input({}))
	_check(world.player.stance_active(), "Perfect Evasion abre su ventana")
	var health := world.player.health
	var from_behind := world.player.position + Vector2(-50, 0)
	_check(is_zero_approx(world.player.take_damage(30.0, from_behind, false)) and is_equal_approx(world.player.health, health), "evita golpes desde cualquier direccion (arco 360)")
	_check(world.player.empower_mult > 1.0, "y mejora el siguiente ataque")
	_check(world.player.empower_seconds_left() > 4.5, "durante unos 5 s (%.1f)" % world.player.empower_seconds_left())

	# La mejora se consume en el siguiente ataque y lo potencia por su multiplicador.
	var plain := _damage_of_first_hit("rogue", 6, "m1", false)
	var empowered := _damage_of_first_hit("rogue", 6, "m1", true)
	var mult := float(SkillCatalog.skill(&"perfect_evasion")["stance"]["empower"]["mult"])
	_check(absf(empowered / plain - mult) < 0.01, "el siguiente ataque pega x%.1f (x%.2f)" % [mult, empowered / plain])


## Dano del primer golpe de `action`; con `empower` la mejora ya esta activa.
func _damage_of_first_hit(class_id: String, level: int, action: String, empower: bool) -> float:
	var world := _make(class_id, level, [Vector2(44, 0)])
	_fix_damage(world)
	if empower:
		world.player.empower_mult = float(SkillCatalog.skill(&"perfect_evasion")["stance"]["empower"]["mult"])
		world.player.empower_until_tick = world.player.tick + 600
	var damages: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void: damages.append(damage))
	_step(world, 1, _input({action: true}))
	_step(world, 60, _input({}))
	if empower:
		_check(world.player.empower_mult == 1.0, "(preparacion) la mejora se consume al atacar")
	return float(damages[0]) if not damages.is_empty() else -1.0


# --- Mage --------------------------------------------------------------------


func _test_mage_overload_buff() -> void:
	var world := _make("mage", 6, [Vector2(150, 0)])
	_fix_damage(world)
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void: hits.append(damage))
	world.player.resource.current_amount = 100.0
	_step(world, 1, _input({"special": true}))
	_check(absf(world.player.resource_amount() - (100.0 - 30.0)) < 0.5, "Arcane Overload cuesta 30 de Mana")
	_step(world, 60, _input({}))
	_check(hits.is_empty() and world.projectiles.is_empty(), "no hace dano ni lanza nada por si misma")
	var buff: Dictionary = SkillCatalog.skill(&"arcane_overload")["buff"]
	_check(is_equal_approx(world.player.empower_mult, float(buff["next_damage_mult"])), "deja una mejora x%.1f" % float(buff["next_damage_mult"]))
	var plain := _bolt_damage(false)
	var boosted := _bolt_damage(true)
	_check(absf(boosted / plain - float(buff["next_damage_mult"])) < 0.01, "el siguiente hechizo pega x%.1f (x%.2f)" % [float(buff["next_damage_mult"]), boosted / plain])
	# No se acumula: lanzarla otra vez refresca, no multiplica.
	world.player.resource.current_amount = 100.0
	world.player.cooldowns.clear()
	_step(world, 1, _input({"special": true}))
	_step(world, 30, _input({}))
	_check(is_equal_approx(world.player.empower_mult, float(buff["next_damage_mult"])), "no se acumula con la propia mejora")


func _bolt_damage(buffed: bool) -> float:
	var world := _make("mage", 6, [Vector2(120, 0)])
	_fix_damage(world)
	if buffed:
		world.player.resource.current_amount = 100.0
		_step(world, 1, _input({"special": true}))
		_step(world, 40, _input({}))
	var damages: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void: damages.append(damage))
	_step(world, 1, _input({"m1": true}))
	_step(world, 60, _input({}))
	return float(damages[0]) if not damages.is_empty() else -1.0


func _test_arcane_explosion() -> void:
	var world := _make("mage", 4, [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40), Vector2(150, 0)])
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(target))
	world.player.resource.current_amount = 100.0
	_step(world, 1, _input({"s2": true}))
	_step(world, 40, _input({}))
	_check(hits.size() == 4 and not hits.has(world.dummies[4]), "Arcane Explosion golpea en las cuatro direcciones y no al lejano")


func _test_cataclysm_marked_zone() -> void:
	var world := _make("mage", 8, [Vector2(230, 0), Vector2(45, 0)])
	_fix_damage(world)
	var damages: Dictionary = {}
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, damage: float, _c: bool, _p: Vector2) -> void: damages[target] = damage)
	world.player.ultimate_charge = 100.0
	var start := world.player.position
	_step(world, 1, _input({"ultimate": true}))
	var spec := SkillCatalog.skill(&"cataclysm")
	_check(world.player.attack_point.is_equal_approx(start + Vector2.RIGHT * float(spec["point_distance"])), "Cataclysm marca la zona %.0f px hacia el cursor" % float(spec["point_distance"]))
	_step(world, 30, _input({}))
	_check(world.player.position.is_equal_approx(start), "el Mage no se mueve mientras canaliza")
	_step(world, 90, _input({}))
	_check(damages.has(world.dummies[0]), "golpea lo que hay en la zona marcada")
	_check(not damages.has(world.dummies[1]), "y no lo que esta junto al Mage fuera de la zona")
	_check(world.player.ultimate_charge == 0.0, "gasta la barra de Ultimate")


# --- Archer ------------------------------------------------------------------


func _test_deadeye_buff_and_expiry() -> void:
	var world := _make("archer", 6, [])
	world.player.resource.current_amount = 100.0
	_step(world, 1, _input({"special": true}))
	_step(world, 40, _input({}))
	var buff: Dictionary = SkillCatalog.skill(&"deadeye")["buff"]
	_check(is_equal_approx(world.player.empower_mult, float(buff["next_damage_mult"])), "Deadeye mejora el siguiente disparo x%.1f" % float(buff["next_damage_mult"]))
	var expired: Array = []
	world.player.buff_changed.connect(func(active: bool, _m: float, _s: float) -> void:
		if not active:
			expired.append(true))
	_step(world, int(float(buff["duration"]) * 60.0) + 30, _input({}))
	_check(world.player.empower_mult == 1.0 and expired.size() == 1, "la mejora caduca sola a los %.0f s sin usarla" % float(buff["duration"]))
	var shot := _projectile_mult(false)
	var boosted := _projectile_mult(true)
	_check(absf(boosted / shot - float(buff["next_damage_mult"])) < 0.01, "el proyectil mejorado lleva x%.1f de dano" % (boosted / shot))


func _projectile_mult(buffed: bool) -> float:
	var world := _make("archer", 6, [])
	if buffed:
		world.player.resource.current_amount = 100.0
		_step(world, 1, _input({"special": true}))
		_step(world, 40, _input({}))
	var spawned: Array = []
	world.projectile_spawned.connect(func(p: ProjectileSim) -> void: spawned.append(p))
	_step(world, 1, _input({"m1": true}))
	_step(world, 30, _input({}))
	return float(spawned[0].damage_mult) if not spawned.is_empty() else -1.0


func _test_rain_of_arrows() -> void:
	var world := _make("archer", 8, [Vector2(260, 0), Vector2(45, 0)])
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(target))
	world.player.ultimate_charge = 100.0
	_step(world, 1, _input({"ultimate": true}))
	_check(world.player.attack_point.is_equal_approx(world.player.position + Vector2.RIGHT * float(SkillCatalog.skill(&"rain_of_arrows")["point_distance"])), "Rain of Arrows marca su zona delante")
	_step(world, 150, _input({}))
	var strikes := int(SkillCatalog.skill(&"rain_of_arrows")["strikes"]["count"])
	var in_zone := hits.filter(func(t: Object) -> bool: return t == world.dummies[0]).size()
	_check(in_zone == strikes, "la lluvia golpea %d veces la zona marcada (%d)" % [strikes, in_zone])
	_check(not hits.has(world.dummies[1]), "y no a lo que esta fuera de ella")


# --- Costes ------------------------------------------------------------------


func _test_costs_per_resource() -> void:
	var world := _make("mage", 2, [])
	world.player.resource.current_amount = 20.0
	var denied: Array = []
	world.player.skill_denied.connect(func(slot: String, reason: String) -> void: denied.append([slot, reason]))
	_step(world, 1, _input({"s1": true}))
	_check(denied.size() == 1 and denied[0] == ["S1", "resource"], "Fireball sin Mana suficiente se deniega")
	_check(world.player.state == PlayerSim.AttackState.IDLE, "y no se lanza")
	world.player.resource.current_amount = 40.0
	_step(world, 2, _input({}))
	_step(world, 1, _input({"s1": true}))
	_check(world.player.state == PlayerSim.AttackState.WINDUP and absf(world.player.resource_amount() - 15.0) < 0.5, "con Mana suficiente se lanza y gasta 25")


# --- Helpers ----------------------------------------------------------------


func _make(class_id: String, level: int, offsets: Array) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(12)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.player.switch_class(class_id)
	world.player.set_level(level)
	LegacyKit.apply(world.player)
	for offset: Vector2 in offsets:
		world.add_dummy(world.player.position + offset, false)
	return world


func _fix_damage(world: CombatWorld) -> void:
	world.player.stats.set_base_stat(&"weapon_min", 10.0)
	world.player.stats.set_base_stat(&"weapon_max", 10.0)
	world.player.stats.set_base_stat(&"crit_chance", 0.0)


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
