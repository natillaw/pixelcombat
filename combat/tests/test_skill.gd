## Test headless de habilidades data-driven (ISSUE P1.3).
##
##   godot --headless --path . --script combat/tests/test_skill.gd
##
extends SceneTree

const SkillScript: GDScript = preload("res://combat/skill.gd")
const SkillRunnerScript: GDScript = preload("res://combat/skill_runner.gd")
const DamageEffectScript: GDScript = preload("res://combat/damage_effect.gd")
const ClassResourceScript: GDScript = preload("res://combat/class_resource.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_skill (P1.3) ==")

	var skill = SkillScript.new()
	skill.id = &"heavy_swing"
	skill.display_name = "Heavy Swing"
	skill.slot = SkillScript.Slot.M1
	skill.cooldown = 0.0
	skill.resource_generation = 10

	var dmg_effect = DamageEffectScript.new()
	dmg_effect.base_damage = 30.0
	skill.effects.append(dmg_effect)

	var fury = ClassResourceScript.new()
	fury.max_amount = 100.0

	var runner = SkillRunnerScript.new()

	# Ejecutar skill que genera 10 de recurso y hace 30 de daño
	var executed = runner.execute(skill, null, null, fury)
	_check(executed, "skill executed successfully")
	_check(is_equal_approx(fury.get_current(), 10.0), "skill generated 10 resource correctly")

	# Skill con coste de recurso (ej. F - EX skill que cuesta 25)
	var ex_skill = SkillScript.new()
	ex_skill.id = &"iron_guard"
	ex_skill.resource_cost = 25
	ex_skill.is_ex = true

	# Falla por falta de recursos (tenemos 10, necesitamos 25)
	var can_exec = runner.can_execute(ex_skill, fury)
	_check(not can_exec, "skill execution prevented when resource is insufficient")

	# Generar suficiente recurso
	fury.generate(20.0) # total 30
	_check(runner.can_execute(ex_skill, fury), "skill can execute when resource is sufficient")

	executed = runner.execute(ex_skill, null, null, fury)
	_check(executed, "ex skill executed successfully")
	_check(is_equal_approx(fury.get_current(), 5.0), "resource correctly consumed (30 - 25 = 5)")

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
