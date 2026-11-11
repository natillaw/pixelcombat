## Niveles, XP y skills por nivel (Fase 1.6): curva, desbloqueos, equipar y
## cooldown por skill.
##
##   godot --headless --path . --script tests/test_progression.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_progression (niveles y skills por nivel) ==")
	_test_curve()
	_test_data_consistency()
	_test_level_one_has_no_skills()
	_test_unlocks_by_level()
	_test_one_grant_many_levels()
	_test_stat_growth_and_heal()
	_test_level_down()
	_test_set_loadout_respects_levels()
	_test_equip_reasons()
	_test_equip_moves_and_unequips()
	_test_cooldown_follows_the_skill()
	_test_xp_from_kills()
	_test_max_level()
	_test_debug_actions()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# --- Datos -------------------------------------------------------------------


func _test_curve() -> void:
	for error: String in Progression.errors():
		print("   error de carga: %s" % error)
	_check(Progression.errors().is_empty(), "data/progression.json carga sin errores")
	_check(Progression.max_level() == 60, "el nivel maximo es 60")
	_check(Progression.xp_to_next(1) == 60, "subir del nivel 1 al 2 cuesta 60 XP")
	var increasing := true
	for level: int in range(1, 59):
		if Progression.xp_to_next(level + 1) <= Progression.xp_to_next(level):
			increasing = false
	_check(increasing, "cada nivel cuesta mas XP que el anterior")
	_check(Progression.xp_to_next(60) == 0, "en el nivel maximo ya no hay siguiente")
	_check(Progression.total_xp_for_level(1) == 0, "el nivel 1 no acumula XP")
	_check(Progression.total_xp_for_level(3) == Progression.xp_to_next(1) + Progression.xp_to_next(2), "total_xp_for_level suma los tramos")
	_check(not Progression.growth("warrior").is_empty() and Progression.growth("no_existe").is_empty(), "el crecimiento se define por clase")


func _test_data_consistency() -> void:
	for id: StringName in SkillCatalog.all_ids():
		var level: Variant = SkillCatalog.skill(id)["unlock_level"]
		_check((level is float or level is int) and float(level) >= 1.0, "%s tiene unlock_level >= 1" % id)
	_check(int(WarriorKit.M1["unlock_level"]) == 1 and int(WarriorKit.M2["unlock_level"]) == 1, "M1 y M2 estan desde el nivel 1")
	for entry: Dictionary in WarriorKit.get_skill_book():
		var id: StringName = entry["id"]
		var unlock_at := int(entry["unlock_level"])
		_check(unlock_at >= 2 and unlock_at <= Progression.max_level(), "%s: unlock_level %d dentro de rango" % [id, unlock_at])
		if SkillCatalog.has_skill(id):
			_check(int(SkillCatalog.skill(id)["unlock_level"]) == unlock_at, "%s: unlock_level del kit = catalogo" % id)
	_check(int(WarriorKit.SPECIAL["unlock_level"]) > 1 and int(WarriorKit.ULTIMATE["unlock_level"]) > 1, "Special y Ultimate no estan desde el nivel 1")
	for id: StringName in EnemyCatalog.all_ids():
		var xp := float(EnemyCatalog.enemy(id)["stats"]["xp"])
		_check(xp > 0.0 and xp <= 100.0, "%s da XP razonable (%d)" % [id, int(xp)])


# --- Desbloqueos ----------------------------------------------------------------


func _test_level_one_has_no_skills() -> void:
	var warrior := _warrior()
	_check(warrior.level == 1 and warrior.xp == 0, "el Warrior empieza en el nivel 1 sin XP")
	_check(warrior.loadout.has("M1") and warrior.loadout.has("M2"), "en el nivel 1 solo tiene M1 y M2")
	for slot: String in ["S1", "S2", "S3", "S4", "S5", "SPECIAL", "ULTIMATE"]:
		_check(not warrior.loadout.has(slot), "el slot %s esta vacio en el nivel 1" % slot)
	_check(is_equal_approx(warrior.stats.get_stat(&"strength"), 20.0), "los stats del nivel 1 no cambian")


func _test_unlocks_by_level() -> void:
	var warrior := _warrior()
	var unlocked: Array = []
	warrior.leveled_up.connect(func(_level: int, ids: Array) -> void: unlocked.append(ids))
	warrior.set_level(2)
	_check(warrior.loadout.has("S2") and warrior.loadout["S2"]["id"] == &"piercing_thrust", "el nivel 2 desbloquea Piercing Thrust (en su slot S2)")
	_check(not warrior.loadout.has("S1"), "Cleaving Strike sigue bloqueada en el nivel 2")
	warrior.set_level(4)
	_check(warrior.loadout.has("S1") and warrior.loadout["S1"]["id"] == &"cleaving_strike", "el nivel 4 desbloquea Cleaving Strike (S1)")
	warrior.set_level(6)
	_check(warrior.loadout.has("SPECIAL"), "el nivel 6 desbloquea el Special")
	_check(not warrior.loadout.has("ULTIMATE"), "la Ultimate sigue bloqueada en el nivel 6")
	warrior.set_level(8)
	_check(warrior.loadout.has("ULTIMATE"), "el nivel 8 desbloquea la Ultimate")
	_check(unlocked.size() == 4, "cada subida emite leveled_up (%d)" % unlocked.size())
	_check(unlocked[0] == [&"piercing_thrust"] and unlocked[1] == [&"cleaving_strike"], "leveled_up lista las skills nuevas")


func _test_one_grant_many_levels() -> void:
	var warrior := _warrior()
	var events: Array = []
	warrior.leveled_up.connect(func(level: int, ids: Array) -> void: events.append([level, ids]))
	warrior.grant_xp(Progression.total_xp_for_level(8) + 10)
	_check(warrior.level == 8 and warrior.xp == 10, "una gran cantidad de XP sube varios niveles (nivel %d, xp %d)" % [warrior.level, warrior.xp])
	_check(events.size() == 1 and events[0][0] == 8, "se emite un solo leveled_up con el nivel final")
	var ids: Array = events[0][1] if not events.is_empty() else []
	_check(ids == [&"piercing_thrust", &"cleaving_strike", &"iron_counter", &"war_gods_descent"], "y lista todas las skills desbloqueadas por orden de nivel")
	_check(warrior.loadout.has("S1") and warrior.loadout.has("S2") and warrior.loadout.has("SPECIAL") and warrior.loadout.has("ULTIMATE"), "todas quedan equipadas")
	_check(warrior.xp_to_next() == Progression.xp_to_next(8), "xp_to_next refleja el nivel actual")


func _test_stat_growth_and_heal() -> void:
	var warrior := _warrior()
	warrior.set_level(10)
	var growth := Progression.growth("warrior")
	_check(is_equal_approx(warrior.stats.get_stat(&"strength"), 20.0 + 9.0 * float(growth["strength_per_level"])), "la fuerza crece por nivel (%.1f)" % warrior.stats.get_stat(&"strength"))
	_check(warrior.max_health > 280.0, "la vida maxima sube con el nivel (%d)" % int(warrior.max_health))
	warrior.take_damage(100.0, Vector2(50, 0), false)
	_check(warrior.health < warrior.max_health, "el Warrior recibe dano")
	warrior.grant_xp(Progression.xp_to_next(10))
	_check(warrior.level == 11 and is_equal_approx(warrior.health, warrior.max_health), "subir de nivel cura del todo")


func _test_level_down() -> void:
	var warrior := _warrior()
	warrior.set_level(10)
	warrior.set_level(3)
	_check(warrior.loadout.has("S2") and not warrior.loadout.has("S1") and not warrior.loadout.has("SPECIAL") and not warrior.loadout.has("ULTIMATE"), "bajar de nivel retira las skills que dejan de estar desbloqueadas")
	warrior.reset_progression()
	_check(warrior.level == 1 and not warrior.loadout.has("S2"), "reset_progression vuelve al nivel 1")
	_check(is_equal_approx(warrior.stats.get_stat(&"strength"), 20.0), "y a los stats base")


func _test_set_loadout_respects_levels() -> void:
	var warrior := _warrior()
	warrior.set_loadout({"M1": &"warrior_m1", "S1": &"cleaving_strike", "ULTIMATE": &"war_gods_descent"})
	_check(warrior.loadout.has("M1") and not warrior.loadout.has("S1") and not warrior.loadout.has("ULTIMATE"), "set_loadout ignora skills bloqueadas por nivel")
	warrior.set_level(10)
	warrior.set_loadout({"S4": &"cleaving_strike", "S2": &"iron_counter"})
	_check(warrior.loadout.has("S4") and not warrior.loadout.has("S2"), "set_loadout respeta que la skill quepa en el slot")


# --- Equipar -----------------------------------------------------------------


func _test_equip_reasons() -> void:
	var warrior := _warrior()
	_check(warrior.equip("S1", &"cleaving_strike") == "locked", "equipar una skill bloqueada devuelve locked")
	_check(warrior.equip("S1", &"no_existe") == "unknown", "una skill inexistente devuelve unknown")
	_check(warrior.equip("S9", &"piercing_thrust") == "slot", "un slot inexistente devuelve slot")
	warrior.set_level(10)
	_check(warrior.equip("SPECIAL", &"cleaving_strike") == "wrong_slot", "una skill normal no cabe en el slot Special")
	_check(warrior.equip("S1", &"iron_counter") == "wrong_slot", "el Special no cabe en un slot normal")
	_check(warrior.equip("M1", &"warrior_m2") == "wrong_slot", "M2 no cabe en el slot M1")
	var world := _world()
	world.player.set_level(10)
	world.player.resource.current_amount = 50.0
	_step(world, 1, _input({"s1": true}))
	_check(world.player.state != PlayerSim.AttackState.IDLE, "(preparacion) la skill esta en curso")
	_check(world.player.equip("S3", &"piercing_thrust") == "busy", "no se puede equipar mientras se ataca")
	_check(not world.player.can_edit_loadout(), "can_edit_loadout es falso en pleno ataque")


func _test_equip_moves_and_unequips() -> void:
	var warrior := _warrior()
	warrior.set_level(10)
	var changes: Array = []
	warrior.loadout_changed.connect(func() -> void: changes.append(true))
	_check(warrior.equip("S3", &"cleaving_strike") == "", "se puede equipar una skill desbloqueada en otro slot")
	_check(warrior.loadout.has("S3") and not warrior.loadout.has("S1"), "una skill ya equipada se mueve de slot, no se duplica")
	_check(changes.size() == 1, "equipar emite loadout_changed")
	_check(warrior.unequip("S3") and not warrior.loadout.has("S3"), "unequip vacia el slot")
	_check(not warrior.unequip("S3"), "vaciar un slot vacio no hace nada")
	_check(not warrior.unequip("M1") and warrior.loadout.has("M1"), "M1 no se puede vaciar")
	_check(not warrior.unequip("M2") and warrior.loadout.has("M2"), "M2 no se puede vaciar")


func _test_cooldown_follows_the_skill() -> void:
	var world := _world()
	world.player.set_level(10)
	world.player.resource.current_amount = 50.0
	_step(world, 1, _input({"s1": true}))
	_step(world, 60, _input({}))
	_check(world.player.state == PlayerSim.AttackState.IDLE, "(preparacion) el lanzamiento ha terminado")
	var left_before: float = world.player.attack_cooldown_left("S1")
	_check(left_before > 4.0, "Cleaving Strike esta en cooldown (%.1f s)" % left_before)
	_check(world.player.unequip("S1"), "se retira de S1")
	_check(world.player.equip("S4", &"cleaving_strike") == "", "y se equipa en S4")
	_check(world.player.attack_cooldown_left("S4") > 4.0, "el cooldown se conserva al cambiarla de slot (no se puede evadir cambiando el loadout)")


# --- XP ----------------------------------------------------------------------


func _test_xp_from_kills() -> void:
	var world := _world()
	var enemy := world.add_enemy(&"slime", world.player.position + Vector2(44, 0))
	enemy.health = 1.0
	var gained: Array = []
	world.player.xp_gained.connect(func(amount: int, _pos: Vector2) -> void: gained.append(amount))
	_step(world, 1, _input({"m1": true}))
	_step(world, 40, _input({}))
	_check(not enemy.alive, "el slime muere de un golpe")
	_check(gained == [int(enemy.data["stats"]["xp"])], "matarlo da su XP (%s)" % str(gained))
	_check(world.player.xp == int(enemy.data["stats"]["xp"]), "la XP se acumula en el Warrior")

	var world2 := _world()
	var dummy := world2.add_dummy(world2.player.position + Vector2(44, 0), false)
	dummy.health = 1.0
	_step(world2, 1, _input({"m1": true}))
	_step(world2, 40, _input({}))
	_check(not dummy.alive and world2.player.xp == 0, "matar un muneco de entrenamiento no da XP")


func _test_max_level() -> void:
	var warrior := _warrior()
	warrior.set_level(60)
	warrior.grant_xp(100000)
	_check(warrior.level == 60 and warrior.xp == 0, "en el nivel maximo la XP no se acumula")
	_check(warrior.xp_to_next() == 0, "y no hay siguiente nivel")


func _test_debug_actions() -> void:
	var world := _world()
	_step(world, 1, _input({"debug_level_up": true}))
	_check(world.player.level == 2, "F5 sube un nivel")
	_step(world, 30, _input({"debug_level_up": true}))
	_check(world.player.level == 2, "mantener F5 no sube mas niveles")
	_step(world, 1, _input({}))
	_step(world, 1, _input({"debug_level_up": true}))
	_check(world.player.level == 3, "soltar y volver a pulsar sube otro")
	_step(world, 1, _input({"debug_level_reset": true}))
	_check(world.player.level == 1, "F6 vuelve al nivel 1")


# --- Helpers ----------------------------------------------------------------


func _world() -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(8)
	world.setup_arena(Rect2(0, 0, 900, 600))
	return world


func _warrior() -> PlayerSim:
	return _world().player


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
