## Test de los datos canónicos del Warrior (WarriorKit) y de las fórmulas base.
##
##   godot --headless --path . --script combat/tests/test_warrior.gd
##
## Sale con código 0 si todo pasa, 1 si algo falla.
extends SceneTree

const SkillScript: GDScript = preload("res://combat/skill.gd")
const SkillRunnerScript: GDScript = preload("res://combat/skill_runner.gd")
const StatsScript: GDScript = preload("res://combat/stats.gd")

## Skills del Skill Book jugables hoy (data/skills/warrior.json). Al implementar
## una nueva, se anade aqui: este contrato fija que nada se marca jugable sin
## estar en el catalogo.
const IMPLEMENTED_SKILLS := ["cleaving_strike", "piercing_thrust"]

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_warrior (PixelCombat - Warrior data) ==")

	_test_identity_and_resource()
	_test_basics()
	_test_passive()
	_test_special_and_ultimate()
	_test_skill_book()
	_test_stats_formulas()
	_test_skill_runner()

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_identity_and_resource() -> void:
	_check(WarriorKit.CLASS_ID == "warrior", "class id is warrior")
	_check(WarriorKit.CLASS_NAME == "Warrior", "class display name is Warrior")
	_check(WarriorKit.RESOURCE_NAME == "Rage", "class resource is Rage")
	_check(is_equal_approx(WarriorKit.MAX_RAGE, 100.0), "Rage caps at 100")

	var rage := WarriorKit.create_rage_resource()
	_check(rage != null, "rage resource is created")
	_check(is_zero_approx(rage.get_current()), "Rage starts empty")
	_check(is_equal_approx(rage.max_amount, 100.0), "rage resource max is 100")
	_check(rage.resource_name == "Rage", "rage resource keeps its name")


func _test_basics() -> void:
	var basics := WarriorKit.get_basics()
	_check(basics.has("M1") and basics.has("M2"), "M1 and M2 exist")

	var m1: Dictionary = basics["M1"]
	var m2: Dictionary = basics["M2"]
	_check(String(m1["slot"]) == "M1", "M1 is bound to slot M1")
	_check(String(m2["slot"]) == "M2", "M2 is bound to slot M2")
	_check(String(m1["kind"]) == "basic" and String(m2["kind"]) == "basic", "both basics are kind=basic")
	_check(bool(m1["implemented"]) and bool(m2["implemented"]), "M1 and M2 are implemented in the first slice")

	for skill: Dictionary in [m1, m2]:
		_check(float(skill["windup"]) > 0.0, "%s has windup" % skill["name"])
		_check(float(skill["active"]) > 0.0, "%s has active frames" % skill["name"])
		_check(float(skill["recovery"]) > 0.0, "%s has recovery" % skill["name"])
		_check(float(skill["range"]) > 0.0, "%s has range" % skill["name"])
		_check(float(skill["arc"]) > 0.0, "%s has an arc" % skill["name"])
		_check(float(skill["damage_mult"]) > 0.0, "%s deals damage" % skill["name"])
		_check(float(skill["rage_gain"]) > 0.0, "%s generates Rage" % skill["name"])
		_check(float(skill["rage_cap"]) >= float(skill["rage_gain"]), "%s rage cap covers its gain" % skill["name"])

	var m1_total := float(m1["windup"]) + float(m1["active"]) + float(m1["recovery"])
	var m2_total := float(m2["windup"]) + float(m2["active"]) + float(m2["recovery"])
	_check(m2_total > m1_total, "Heavy Strike is slower than Sword Slash")
	_check(float(m2["damage_mult"]) > float(m1["damage_mult"]), "Heavy Strike hits harder than Sword Slash")
	_check(float(m2["rage_gain"]) >= float(m1["rage_gain"]), "Heavy Strike generates at least as much Rage")

	basics["M1"]["name"] = "mutated"
	_check(WarriorKit.M1["name"] == "Sword Slash", "get_basics returns a defensive copy")


func _test_passive() -> void:
	_check(bool(WarriorKit.PASSIVE["implemented"]), "Vengeful Fury is implemented")
	_check(String(WarriorKit.PASSIVE["name"]) == "Vengeful Fury", "passive keeps its design name")
	_check(is_equal_approx(float(WarriorKit.PASSIVE["window"]), 4.0), "passive window is 4 seconds")
	_check(is_equal_approx(float(WarriorKit.PASSIVE["bonus"]), 0.30), "passive grants +30% Heavy Strike damage")


func _test_special_and_ultimate() -> void:
	_check(is_equal_approx(float(WarriorKit.SPECIAL["cost"]), 30.0), "Special costs 30 Rage")
	_check(float(WarriorKit.SPECIAL["cooldown"]) > 0.0, "Special has a cooldown")
	_check(bool(WarriorKit.SPECIAL["implemented"]), "Special (Iron Counter) is playable")
	_check(is_equal_approx(float(WarriorKit.ULTIMATE["charge"]), 100.0), "Ultimate charges to 100")
	_check(bool(WarriorKit.ULTIMATE["implemented"]), "Ultimate is playable (data/skills/warrior.json)")


func _test_skill_book() -> void:
	var book := WarriorKit.get_skill_book()
	_check(book.size() == 15, "Skill Book has 15 entries")

	var seen: Dictionary = {}
	for entry: Dictionary in book:
		var id := String(entry["id"])
		_check(not seen.has(id), "skill id is unique: %s" % id)
		seen[id] = true
		for key: String in ["name", "role", "description"]:
			_check(not String(entry[key]).is_empty(), "%s has %s" % [id, key])
		_check(int(entry["cost"]) > 0, "%s costs Rage" % id)
		_check(int(entry["cost"]) <= int(WarriorKit.MAX_RAGE), "%s is affordable" % id)
		_check(float(entry["cooldown"]) > 0.0, "%s has a cooldown" % id)
		_check(bool(entry["implemented"]) == IMPLEMENTED_SKILLS.has(id), "%s implemented flag matches the playable set" % id)

	_check(WarriorKit.all_ids().size() == 15, "all_ids returns the 15 ids")

	var roles := ""
	for entry: Dictionary in book:
		roles += String(entry["role"]) + " "
	for keyword: String in ["Daño", "Defensa", "Movilidad", "Control", "Apoyo"]:
		_check(roles.contains(keyword), "Skill Book covers the %s role" % keyword)


func _test_stats_formulas() -> void:
	var stats: CharacterStats = StatsScript.new()
	stats.set_base_stat(&"strength", 20.0)
	stats.set_base_stat(&"attack_power_bonus", 10.0)
	stats.set_base_stat(&"weapon_min", 10.0)
	stats.set_base_stat(&"weapon_max", 20.0)
	stats.set_base_stat(&"weapon_speed", 2.0)
	stats.set_base_stat(&"crit_chance", 1.7)

	_check(is_equal_approx(stats.get_attack_power(), 50.0), "1 Strength = 2 Attack Power plus bonus")
	_check(is_equal_approx(stats.get_weapon_damage(), 15.0 + 50.0 / 14.0 * 2.0), "weapon damage formula")
	_check(is_equal_approx(stats.get_crit_chance(), 1.0), "crit chance is clamped to 1.0")


func _test_skill_runner() -> void:
	var skill: Skill = SkillScript.new()
	skill.id = &"warrior_test"
	skill.resource_generation = 8
	var rage := WarriorKit.create_rage_resource()
	var runner: SkillRunner = SkillRunnerScript.new()
	_check(runner.execute(skill, null, null, rage), "SkillRunner executes a data skill")
	_check(is_equal_approx(rage.get_current(), 8.0), "SkillRunner generates Rage")

	skill.resource_cost = 999
	_check(not runner.execute(skill, null, null, rage), "SkillRunner rejects unaffordable skills")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
