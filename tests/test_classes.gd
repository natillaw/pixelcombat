## Las cuatro clases (Warrior, Rogue, Mage, Archer): datos, recursos, stats, cambio
## de clase con progreso propio y aspecto LPC.
##
##   godot --headless --path . --script tests/test_classes.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0
const EXPECTED_ORDER := ["warrior", "rogue", "mage", "archer"]

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_classes (las 4 clases) ==")
	_test_catalogs_load()
	_test_every_class_is_complete()
	_test_looks_build()
	_test_switch_class_rules()
	_test_progress_is_per_class()
	_test_resources()
	_test_stats_and_damage_types()
	_test_wrong_class_and_unlocks()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# --- Datos -------------------------------------------------------------------


func _test_catalogs_load() -> void:
	for error: String in ClassCatalog.errors() + SkillCatalog.errors() + Progression.errors():
		print("   error de carga: %s" % error)
	_check(ClassCatalog.errors().is_empty() and SkillCatalog.errors().is_empty() and Progression.errors().is_empty(), "las clases, las skills y la progresion cargan sin errores")
	_check(ClassCatalog.all_ids() == EXPECTED_ORDER, "hay 4 clases en el orden Warrior, Rogue, Mage, Archer")
	_check(not ClassCatalog.has_class("cleric") and ClassCatalog.class_def("cleric").is_empty(), "Cleric queda fuera de alcance")
	var bad := ClassCatalog.class_def("rogue")
	bad["resource"]["kind"] = "fury"
	_check(not ClassCatalog.validate(bad).is_empty(), "rechaza un recurso desconocido")
	var no_regen := ClassCatalog.class_def("mage")
	no_regen["resource"]["regen_per_second"] = 0.0
	_check(not ClassCatalog.validate(no_regen).is_empty(), "Energy y Mana necesitan regeneracion")
	var bad_stat := ClassCatalog.class_def("archer")
	bad_stat["main_stat"] = "luck"
	_check(not ClassCatalog.validate(bad_stat).is_empty(), "rechaza un atributo principal desconocido")


func _test_every_class_is_complete() -> void:
	var seen_ids: Dictionary = {}
	for class_id: String in ClassCatalog.all_ids():
		var def := ClassCatalog.class_def(class_id)
		var ids := SkillCatalog.ids_for_class(class_id)
		var slots: Dictionary = {}
		var normal := 0
		for id: StringName in ids:
			var skill := SkillCatalog.skill(id)
			_check(not seen_ids.has(id), "%s: el id es unico entre clases" % id)
			seen_ids[id] = true
			_check(bool(skill["implemented"]), "%s: esta implementada" % id)
			slots[String(skill["slot"])] = true
			if String(skill["slot"]) == "S":
				normal += 1
		_check(slots.has("M1") and slots.has("M2") and (slots.has("SPECIAL") or class_id == "warrior") and slots.has("ULTIMATE"), "%s tiene M1, M2, Special (salvo el guerrero, que ya no lo usa) y Ultimate" % class_id)
		_check(normal >= 2, "%s tiene al menos 2 skills normales (%d)" % [class_id, normal])
		for slot: String in def["default_loadout"]:
			var skill_id := StringName(String(def["default_loadout"][slot]))
			_check(SkillCatalog.has_skill(skill_id) and String(SkillCatalog.skill(skill_id)["class"]) == class_id, "%s: el default de %s existe y es de la clase" % [class_id, slot])
		_check(int(SkillCatalog.skill(StringName(String(def["default_loadout"]["M1"])))["unlock_level"]) == 1, "%s: M1 desde el nivel 1" % class_id)
		for entry: Dictionary in ClassCatalog.planned(class_id):
			_check(not SkillCatalog.has_skill(StringName(String(entry["id"]))), "%s: %s sigue prevista (no duplicada en el catalogo)" % [class_id, entry["id"]])
		# El Special cuesta 30 del recurso y la Ultimate usa la barra de carga.
		for id: StringName in ids:
			var skill := SkillCatalog.skill(id)
			if String(skill["slot"]) == "SPECIAL":
				_check(is_equal_approx(float(skill["cost"]), WarriorKit.SPECIAL_COST), "%s: el Special cuesta %d" % [id, int(WarriorKit.SPECIAL_COST)])
			if String(skill["slot"]) == "ULTIMATE":
				_check(is_equal_approx(float(skill["charge"]), WarriorKit.ULTIMATE_CHARGE_MAX), "%s: la Ultimate usa %d de carga" % [id, int(WarriorKit.ULTIMATE_CHARGE_MAX)])


func _test_looks_build() -> void:
	var index: Dictionary = LpcComposer.index()["pieces"]
	for class_id: String in ClassCatalog.all_ids():
		var equipment := ClassLook.equipment(class_id)
		for slot: String in equipment:
			if slot == "_items":
				continue
			var piece := String(equipment[slot][0])
			_check(index.has(piece), "%s: la pieza LPC %s esta importada" % [class_id, piece])
		var frames := ClassLook.frames(class_id)
		_check(frames != null and frames.has_animation("walk_down") and frames.has_animation("combat_idle_down"), "%s: el aspecto compone sus animaciones" % class_id)
	_check(ClassLook.frames("archer").has_animation("shoot_down"), "el Archer tiene la animacion de disparo")
	_check(ClassLook.frames("mage").has_animation("spellcast_down"), "el Mage tiene la animacion de hechizo")


# --- Cambio de clase ------------------------------------------------------------


func _test_switch_class_rules() -> void:
	var world := _world()
	var player: PlayerSim = world.player
	var changes: Array = []
	player.class_changed.connect(func(id: String) -> void: changes.append(id))
	_check(player.class_id == "warrior" and player.resource_kind == "rage", "se empieza como Warrior con Rage")
	_check(player.switch_class("cleric") == "unknown", "una clase desconocida se rechaza")
	_check(player.switch_class("warrior") == "" and changes.is_empty(), "cambiar a la clase actual no hace nada")
	_check(player.switch_class("rogue") == "" and changes == ["rogue"], "cambiar de clase emite class_changed")
	_check(player.class_id == "rogue" and player.resource_kind == "energy" and player.resource.resource_name == "Energy", "el Rogue usa Energy")
	_check(is_equal_approx(player.resource_amount(), 100.0), "la Energy empieza llena")
	_check(player.loadout.has("M1") and player.loadout["M1"]["id"] == &"twin_fang", "el Rogue lleva Twin Fang en M1")
	_check(not player.loadout.has("S1"), "y ninguna skill normal en el nivel 1")
	_check(is_equal_approx(player.health, player.max_health), "el cambio deja la vida llena")
	# No se cambia a mitad de un ataque.
	_step(world, 1, _input({"m1": true}))
	_check(player.state != PlayerSim.AttackState.IDLE, "(preparacion) el Rogue esta atacando")
	_check(player.switch_class("mage") == "busy" and player.class_id == "rogue", "no se puede cambiar de clase atacando")


func _test_progress_is_per_class() -> void:
	var world := _world()
	var player: PlayerSim = world.player
	player.set_level(6)
	player.unequip("S1")
	player.switch_class("mage")
	_check(player.level == 1 and player.xp == 0, "el Mage empieza en el nivel 1")
	player.grant_xp(30)
	player.switch_class("warrior")
	_check(player.level == 6, "el Warrior conserva su nivel (%d)" % player.level)
	_check(player.loadout.has("S2") and player.loadout.has("ULTIMATE") and not player.loadout.has("S1"), "y su loadout, incluido el hueco que vacie")
	player.switch_class("mage")
	_check(player.level == 1 and player.xp == 30, "el Mage conserva su XP (%d)" % player.xp)
	player.switch_class("rogue")
	player.set_level(4)
	_check(player.loadout.has("S1") and player.loadout["S1"]["id"] == &"fan_of_knives" and player.loadout.has("S2"), "las skills del Rogue se desbloquean por nivel (S1 nv 2, S2 nv 4)")


# --- Recursos ----------------------------------------------------------------------


func _test_resources() -> void:
	var world := _world()
	var player: PlayerSim = world.player
	player.switch_class("rogue")
	player.resource.current_amount = 20.0
	_step(world, 60, _input({}))
	_check(absf(player.resource_amount() - 32.0) < 0.5, "la Energy se regenera sola (12/s): %.1f" % player.resource_amount())
	_step(world, 600, _input({}))
	_check(is_equal_approx(player.resource_amount(), 100.0), "y no pasa del maximo")

	player.switch_class("mage")
	player.resource.current_amount = 50.0
	_step(world, 60, _input({}))
	_check(absf(player.resource_amount() - 54.0) < 0.5, "el Mana se regenera despacio (4/s): %.1f" % player.resource_amount())

	# El Rogue no gana recurso al golpear ni al recibir dano, y no tiene pasiva.
	player.switch_class("rogue")
	var dummy := world.add_dummy(player.position + Vector2(40, 0), false)
	player.resource.current_amount = 50.0
	var before := player.resource_amount()
	player.take_damage(10.0, player.position + Vector2(60, 0), false)
	_check(player.resource_amount() <= before + 0.01, "recibir dano no da Energy")
	_check(not player.vengeful_active, "el Rogue no tiene Vengeful Fury")
	_check(dummy.alive, "(sanidad) el muneco sigue vivo")

	# El Warrior conserva sus reglas de Rage.
	player.switch_class("warrior")
	player.resource.current_amount = 0.0
	player.take_damage(20.0, player.position + Vector2(60, 0), false)
	_check(player.resource_amount() > 0.0 and not player.vengeful_active, "el Warrior sigue ganando Rage al recibir dano (Vengeful Fury ahora exige bloquear)")

	# Sin recursos suficientes la skill se deniega por "resource".
	var world2 := _world()
	world2.player.switch_class("rogue")
	world2.player.set_level(2)
	world2.player.resource.current_amount = 10.0
	var denied: Array = []
	world2.player.skill_denied.connect(func(slot: String, reason: String) -> void: denied.append([slot, reason]))
	_step(world2, 1, _input({"s1": true}))
	_check(denied.size() == 1 and denied[0][1] == "resource", "Ambush sin Energy suficiente se deniega por recurso")


# --- Stats y tipos de dano ----------------------------------------------------------


func _test_stats_and_damage_types() -> void:
	var world := _world()
	var player: PlayerSim = world.player
	_check(is_equal_approx(player.stats.get_attack_power(), 40.0), "Warrior: AP = 2 x Strength")
	player.switch_class("rogue")
	_check(is_equal_approx(player.stats.get_attack_power(), 40.0), "Rogue: AP = 2 x Agility (atributo principal)")
	player.switch_class("mage")
	_check(is_equal_approx(player.stats.get_spell_power(), 40.0), "Mage: Spell Power = 2 x Intellect")
	player.set_level(10)
	var growth := Progression.growth("mage")
	_check(is_equal_approx(player.stats.get_stat(&"intellect"), 20.0 + 9.0 * float(growth["intellect_per_level"])), "el Intellect del Mage crece por nivel")
	_check(player.max_health < 400.0, "el Mage es mas fragil que el Warrior (%d de vida en el nivel 10)" % int(player.max_health))

	# Dano magico: sube con Intellect, no con Strength; el fisico al reves.
	var magic_low := _first_hit_damage("mage", 1, 20.0)
	var magic_high := _first_hit_damage("mage", 1, 60.0)
	_check(magic_high > magic_low * 1.2, "el dano del Mage crece con Spell Power (%.1f -> %.1f)" % [magic_low, magic_high])
	var physical_low := _first_hit_damage("rogue", 1, 20.0)
	var physical_high := _first_hit_damage("rogue", 1, 60.0)
	_check(is_equal_approx(physical_low, physical_high), "el dano del Rogue no depende de Intellect")
	var expected := (10.0 + (20.0 * 2.0) / 14.0 * 2.0) * 0.9
	_check(absf(magic_low - expected) < 0.01, "Arcane Bolt = (base + SP/14 x velocidad) x 0.9 (%.2f vs %.2f)" % [magic_low, expected])


## Dano del primer golpe del M1 de `class_id` con el Intellect indicado, con dano de
## arma fijo y sin criticos.
func _first_hit_damage(class_id: String, level: int, intellect: float) -> float:
	var world := _world()
	var player: PlayerSim = world.player
	player.switch_class(class_id)
	player.set_level(level)
	player.stats.set_base_stat(&"weapon_min", 10.0)
	player.stats.set_base_stat(&"weapon_max", 10.0)
	player.stats.set_base_stat(&"crit_chance", 0.0)
	player.stats.set_base_stat(&"intellect", intellect)
	world.add_dummy(player.position + Vector2(40, 0), false)
	var damages: Array = []
	player.attack_hit.connect(func(_s: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void: damages.append(damage))
	_step(world, 1, _input({"m1": true}))
	_step(world, 60, _input({}))
	return float(damages[0]) if not damages.is_empty() else -1.0


# --- Skills de otras clases --------------------------------------------------------


func _test_wrong_class_and_unlocks() -> void:
	var world := _world()
	var player: PlayerSim = world.player
	player.set_level(10)
	_check(player.equip("S3", &"ambush") == "wrong_class", "una skill del Rogue no se puede equipar en el Warrior")
	player.switch_class("archer")
	player.set_level(10)
	_check(player.equip("S3", &"cleaving_strike") == "wrong_class", "ni una del Warrior en el Archer")
	_check(player.loadout.has("S1") and player.loadout["S1"]["id"] == &"crippling_arrow", "el Archer lleva Crippling Arrow en S1")
	_check(not player.loadout.has("S2") and player.equip("S2", &"multishot") == "not_learned", "Multishot es una skill de mundo: hay que aprenderla")
	_check(player.loadout.has("SPECIAL") and player.loadout["SPECIAL"]["id"] == &"deadeye", "y Deadeye de Special")
	_check(player.loadout.has("ULTIMATE") and player.loadout["ULTIMATE"]["id"] == &"rain_of_arrows", "y Rain of Arrows de Ultimate")


# --- Helpers ----------------------------------------------------------------


func _world() -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(31)
	world.setup_arena(Rect2(0, 0, 900, 600))
	return world


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
