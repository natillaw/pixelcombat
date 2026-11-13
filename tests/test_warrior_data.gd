## Contrato de datos del Warrior contra los documentos de diseño.
##
##   godot --headless --path . --script tests/test_warrior_data.gd
##
## Verifica que WarriorKit siga siendo una traducción fiel de CLASES_V2.md:
## 15 habilidades, sin variantes/builds, costes y cooldowns válidos, y los
## números clave de la identidad Warrior.
extends SceneTree

const CLASES_DOC := "res://docs/design/CLASES_V2.md"
const EVOLUCIONES_DOC := "res://docs/design/EVOLUCIONES_V1.md"
const WARRIOR_DOC := "res://docs/design/WARRIOR.md"

## Skills del Skill Book jugables hoy (data/skills/warrior.json). Al implementar
## una nueva, se anade aqui: este contrato fija que nada se marca jugable sin
## estar en el catalogo.
const IMPLEMENTED_SKILLS := ["cleaving_strike", "piercing_thrust", "crushing_blow", "ground_stomp", "charge", "rend", "war_cry", "shockwave", "iron_counter", "whirlwind", "throwing_axe", "execute", "second_wind"]

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_warrior_data (design contract) ==")

	_test_design_documents()
	_test_skill_book_shape()
	_test_no_variants()
	_test_identity_numbers()
	_test_roles()

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_design_documents() -> void:
	var clases := _read(CLASES_DOC)
	_check(not clases.is_empty(), "CLASES_V2.md exists and is readable")
	_check(clases.contains("Warrior"), "the design doc defines the Warrior")
	_check(clases.contains("Vengeful Fury"), "the design doc keeps Vengeful Fury")
	_check(clases.contains("Sword Slash") and clases.contains("Heavy Strike"), "the design doc keeps M1/M2 names")
	_check(clases.contains("Iron Counter") and clases.contains("War God's Descent"), "the design doc keeps Special/Ultimate names")

	var evoluciones := _read(EVOLUCIONES_DOC)
	_check(not evoluciones.is_empty(), "EVOLUCIONES_V1.md exists and is readable")

	var warrior_doc := _read(WARRIOR_DOC)
	_check(not warrior_doc.is_empty(), "WARRIOR.md exists and is readable")
	_check(warrior_doc.contains("Sword Slash") and warrior_doc.contains("Heavy Strike"), "WARRIOR.md documents both basics")


func _test_skill_book_shape() -> void:
	var book := WarriorKit.get_skill_book()
	_check(book.size() == 13, "the Skill Book lists 13 skills (3 retired for mechanic tests + Q/E/R + world pool)")

	var ids: Dictionary = {}
	for entry: Dictionary in book:
		var id := String(entry["id"])
		_check(not ids.has(id), "unique id: %s" % id)
		ids[id] = true
		_check(id == id.to_lower() and not id.contains(" "), "%s uses snake_case" % id)
		_check(int(entry["cost"]) >= 0 and int(entry["cost"]) <= 30, "%s costs between 0 and 30 Rage" % id)
		_check(float(entry["cooldown"]) >= 4.0 and float(entry["cooldown"]) <= 30.0 and int(entry["unlock_level"]) <= 10, "%s cooldown is between 4 and 30 s and unlocks by level 10" % id)
		_check(bool(entry["implemented"]) == IMPLEMENTED_SKILLS.has(id), "%s is playable only if listed in IMPLEMENTED_SKILLS" % id)

	_check(WarriorKit.all_ids().size() == book.size(), "all_ids matches the Skill Book")


func _test_no_variants() -> void:
	var implemented := 0
	implemented += 1 if bool(WarriorKit.M1["implemented"]) else 0
	implemented += 1 if bool(WarriorKit.M2["implemented"]) else 0
	implemented += 1 if bool(WarriorKit.PASSIVE["implemented"]) else 0

	_check(implemented == 3, "first slice implements exactly M1, M2 and the passive")
	_check(not WarriorKit.SPECIAL.has("variant") and not WarriorKit.SPECIAL.has("variants"), "Special has no variant field")
	_check(not WarriorKit.ULTIMATE.has("variant") and not WarriorKit.ULTIMATE.has("variants"), "Ultimate has no variant field")

	for entry: Dictionary in WarriorKit.get_skill_book():
		_check(not entry.has("variant") and not entry.has("variants"), "%s has no variant field" % entry["id"])
		_check(not entry.has("build") and not entry.has("builds"), "%s has no build field" % entry["id"])


func _test_identity_numbers() -> void:
	_check(is_equal_approx(float(WarriorKit.M1["damage_mult"]), 1.0), "M1 is the baseline damage")
	_check(is_equal_approx(float(WarriorKit.M2["damage_mult"]), 2.1), "M2 keeps its 2.1x multiplier")
	_check(is_equal_approx(float(WarriorKit.PASSIVE["window"]), 4.0), "Vengeful Fury lasts 4 s")
	_check(is_equal_approx(float(WarriorKit.PASSIVE["bonus"]), 0.30), "Vengeful Fury grants +30%")
	_check(is_equal_approx(float(WarriorKit.SPECIAL["cost"]), 30.0), "Iron Counter costs 30 Rage")
	_check(is_equal_approx(float(WarriorKit.ULTIMATE["charge"]), 100.0), "War God's Descent needs full charge")
	_check(is_equal_approx(float(WarriorKit.M2["resource_gain"]), 14.0), "M2 keeps its 14 Rage gain")
	_check(is_equal_approx(float(WarriorKit.M1["resource_gain"]), 8.0), "M1 keeps its 8 Rage gain")


func _test_roles() -> void:
	# El kit del Guerrero mantiene herramientas de cada papel: dano, control, mejora y defensa (contragolpe).
	var damage := 0
	var control := 0
	var support := 0
	var defense := 0
	for entry: Dictionary in WarriorKit.get_skill_book():
		var role := String(entry["role"])
		damage += 1 if role.contains("Daño") or role.contains("Burst") or role.contains("dano") else 0
		control += 1 if role.contains("Control") else 0
		support += 1 if (role.contains("Mejora") or role.contains("Apoyo")) else 0
		defense += 1 if (role.contains("Defensa") or role.contains("Contraataque") or role.contains("contra")) else 0
	_check(damage >= 3, "Warrior has multiple damage tools")
	_check(control >= 2, "Warrior has control tools")
	_check(support >= 1, "Warrior has a support/buff tool")
	_check(defense >= 1 or WarriorKit.SPECIAL["id"] == &"iron_counter", "Warrior keeps a counter tool")


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
