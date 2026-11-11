## Test headless de la clase Rogue y sus 7 habilidades (Phase 2).
##
##   godot --headless --path . --script combat/tests/test_rogue.gd
##
extends SceneTree

const RogueFactoryScript: GDScript = preload("res://combat/rogue_factory.gd")
const SkillRunnerScript: GDScript = preload("res://combat/skill_runner.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_rogue (Phase 2 - Rogue) ==")

	var rogue_res = RogueFactoryScript.create_rogue_resource()
	var skills = RogueFactoryScript.get_rogue_skills()
	var runner = SkillRunnerScript.new()

	_check(rogue_res != null, "rogue resource created successfully")
	_check(is_equal_approx(rogue_res.get_current(), 100.0), "initial energy is 100")
	_check(rogue_res.get_combo_points() == 0, "initial combo points is 0")
	_check(skills.size() == 7, "rogue has all 7 core ability slots (M1, M2, Space, Q, E, R, F)")

	# Consume some energy first to test generation
	rogue_res.consume(50.0)
	_check(is_equal_approx(rogue_res.get_current(), 50.0), "energy consumed to 50")

	# 1. Test M1 (Quick Strike) - Generates 20 Energy, 1 Combo Point
	var m1 = skills["M1"]
	_check(runner.execute(m1, null, null, rogue_res), "M1 executed successfully")
	_check(is_equal_approx(rogue_res.get_current(), 70.0), "M1 generated 20 Energy (50 + 20 = 70)")
	rogue_res.add_combo_point(1)
	_check(rogue_res.get_combo_points() == 1, "Combo point added (total: 1)")

	# 2. Test E (Ambush) - Costs 10 Energy, generates 1 Combo Point
	var e_skill = skills["E"]
	_check(runner.can_execute(e_skill, rogue_res), "can execute E with 70 Energy")
	_check(runner.execute(e_skill, null, null, rogue_res), "E executed successfully")
	_check(is_equal_approx(rogue_res.get_current(), 60.0), "E consumed 10 Energy (70 - 10 = 60)")
	rogue_res.add_combo_point(1)
	_check(rogue_res.get_combo_points() == 2, "Combo points total: 2")

	# 3. Test M2 (Eviscerate) - Finisher costs 30 Energy, consumes combo points
	var m2 = skills["M2"]
	_check(runner.can_execute(m2, rogue_res), "can execute M2 with 60 Energy")
	_check(runner.execute(m2, null, null, rogue_res), "M2 executed successfully")
	_check(is_equal_approx(rogue_res.get_current(), 30.0), "M2 consumed 30 Energy (60 - 30 = 30)")
	var consumed_cp = rogue_res.consume_combo_points()
	_check(consumed_cp == 2, "M2 consumed 2 combo points")
	_check(rogue_res.get_combo_points() == 0, "Combo points reset to 0")

	# 4. Test Q (Stealth) - Generates 30 Energy
	var q_skill = skills["Q"]
	_check(runner.execute(q_skill, null, null, rogue_res), "Q executed successfully")
	_check(is_equal_approx(rogue_res.get_current(), 60.0), "Q generated 30 Energy (30 + 30 = 60)")

	# 5. Test Space (Shadowstep) - Costs 15 Energy
	var space_skill = skills["SPACE"]
	_check(runner.execute(space_skill, null, null, rogue_res), "Space (Shadowstep) executed successfully")
	_check(is_equal_approx(rogue_res.get_current(), 45.0), "Space consumed 15 Energy (60 - 15 = 45)")

	# 6. Test R (Blade Flurry) - Costs 40 Energy
	rogue_res.generate(50.0) # 45 + 50 = 95
	var r_skill = skills["R"]
	_check(runner.execute(r_skill, null, null, rogue_res), "R executed successfully")
	_check(is_equal_approx(rogue_res.get_current(), 55.0), "R consumed 40 Energy (95 - 40 = 55)")

	# 7. Test F (Assassination Ultimate) - Costs 100 Energy (fails if < 100, passes at 100)
	var f_skill = skills["F"]
	_check(not runner.can_execute(f_skill, rogue_res), "Ultimate prevented when energy is insufficient (55 < 100)")
	rogue_res.current_amount = 100.0
	_check(runner.can_execute(f_skill, rogue_res), "Ultimate can execute with 100 Energy")
	_check(runner.execute(f_skill, null, null, rogue_res), "Ultimate executed successfully")
	_check(is_equal_approx(rogue_res.get_current(), 0.0), "Ultimate consumed all 100 Energy")

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
