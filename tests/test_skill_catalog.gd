## Catalogo de skills por datos (Fase 1.3): esquema, ids y coherencia con el kit.
##
##   godot --headless --path . --script tests/test_skill_catalog.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_skill_catalog (skills por datos) ==")
	_test_loads_without_errors()
	_test_every_skill_is_valid()
	_test_kit_matches_catalog()
	_test_validator_rejects_bad_data()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_loads_without_errors() -> void:
	var errors := SkillCatalog.errors()
	for error: String in errors:
		print("   error de carga: %s" % error)
	_check(errors.is_empty(), "todos los JSON de data/skills cargan sin errores")
	_check(SkillCatalog.all_ids().size() >= 4, "el catalogo trae al menos 4 skills")
	_check(not SkillCatalog.has_skill(&"no_existe"), "una skill inexistente no esta en el catalogo")
	_check(SkillCatalog.skill(&"no_existe").is_empty(), "skill() de un id desconocido devuelve {}")


func _test_every_skill_is_valid() -> void:
	for id: StringName in SkillCatalog.all_ids():
		var entry := SkillCatalog.skill(id)
		var problems := SkillCatalog.validate(entry)
		_check(problems.is_empty(), "%s cumple el esquema %s" % [id, str(problems)])
		_check(String(id) == String(id).to_lower() and not String(id).contains(" "), "%s usa snake_case" % id)
		# La copia es independiente: tocarla no cambia el catalogo.
		entry["damage_mult"] = 999.0
		_check(float(SkillCatalog.skill(id)["damage_mult"]) != 999.0, "%s se devuelve como copia" % id)


## Las skills del Skill Book que ya son jugables deben tener en el kit el mismo
## coste y cooldown que en el catalogo (evita dos fuentes que se separen).
func _test_kit_matches_catalog() -> void:
	for entry: Dictionary in WarriorKit.get_skill_book():
		var id: StringName = entry["id"]
		if not bool(entry["implemented"]):
			_check(not SkillCatalog.has_skill(id), "%s no jugable no deberia estar en el catalogo" % id)
			continue
		_check(SkillCatalog.has_skill(id), "%s jugable existe en el catalogo" % id)
		var data := SkillCatalog.skill(id)
		_check(is_equal_approx(float(data["cost"]), float(entry["cost"])), "%s: coste del kit = catalogo" % id)
		_check(is_equal_approx(float(data["cooldown"]), float(entry["cooldown"])), "%s: cooldown del kit = catalogo" % id)
	_check(WarriorKit.M1["id"] == &"warrior_m1" and WarriorKit.M2["id"] == &"warrior_m2", "M1 y M2 salen del catalogo")


func _test_validator_rejects_bad_data() -> void:
	var good := SkillCatalog.skill(&"cleaving_strike")
	_check(SkillCatalog.validate(good).is_empty(), "la skill de referencia es valida")

	var bad_shape := good.duplicate(true)
	bad_shape["shape"] = "cubo"
	_check(not SkillCatalog.validate(bad_shape).is_empty(), "rechaza una forma desconocida")

	var no_arc := good.duplicate(true)
	no_arc.erase("arc")
	_check(not SkillCatalog.validate(no_arc).is_empty(), "un cone sin arc es invalido")

	var line := SkillCatalog.skill(&"piercing_thrust")
	line.erase("width")
	_check(not SkillCatalog.validate(line).is_empty(), "una line sin width es invalida")

	var negative := good.duplicate(true)
	negative["cooldown"] = -1.0
	_check(not SkillCatalog.validate(negative).is_empty(), "rechaza un cooldown negativo")

	var zero_damage := good.duplicate(true)
	zero_damage["damage_mult"] = 0.0
	_check(not SkillCatalog.validate(zero_damage).is_empty(), "rechaza damage_mult 0")

	var bad_move := good.duplicate(true)
	bad_move["move"] = {"windup": 2.0, "active": 0.1, "recovery": 0.1}
	_check(not SkillCatalog.validate(bad_move).is_empty(), "rechaza un factor de movimiento mayor que 1")

	var no_move := good.duplicate(true)
	no_move.erase("move")
	_check(not SkillCatalog.validate(no_move).is_empty(), "rechaza una skill sin move")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
