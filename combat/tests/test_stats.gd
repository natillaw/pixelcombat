## Test headless de stats y recurso de clase (ISSUE P1.2).
##
##   godot --headless --path . --script combat/tests/test_stats.gd
##
extends SceneTree

const CharacterStatsScript: GDScript = preload("res://combat/stats.gd")
const StatModifierScript: GDScript = preload("res://combat/modifier.gd")
const ClassResourceScript: GDScript = preload("res://combat/class_resource.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_stats (P1.2) ==")

	# 1. Test Stat System & Modifiers (Additive -> Multiplicative -> Cap)
	var stats = CharacterStatsScript.new()
	stats.set_base_stat(&"strength", 10.0, 0.0, 100.0)

	# Añadir buff plano (+5) y debuff plano (-3) -> aditivo = 10 + 5 - 3 = 12
	stats.add_modifier(&"strength", StatModifierScript.new(StatModifierScript.Type.FLAT, 5.0))
	stats.add_modifier(&"strength", StatModifierScript.new(StatModifierScript.Type.FLAT, -3.0))

	# Añadir buff percentual (+10% -> 0.10) -> (10 + 5 - 3) * 1.10 = 12 * 1.10 = 13.2
	stats.add_modifier(&"strength", StatModifierScript.new(StatModifierScript.Type.PERCENT, 0.10))

	var final_str = stats.get_stat(&"strength")
	_check(is_equal_approx(final_str, 13.2), "stat modifiers calculated correctly (additive -> multiplicative -> cap)")

	# 2. Test Derived Stat Formula (1 Strength = 2 AP)
	# strength = 13.2 -> AP = 26.4
	_check(is_equal_approx(stats.get_attack_power(), 26.4), "attack power derived formula (1 Strength = 2 AP) is correct")

	# 3. Test Class Resource (Fury)
	var fury = ClassResourceScript.new()
	fury.max_amount = 100.0

	fury.generate(40.0)
	_check(is_equal_approx(fury.get_current(), 40.0), "resource generated correctly")

	var consumed = fury.consume(15.0)
	_check(consumed and is_equal_approx(fury.get_current(), 25.0), "resource consumed correctly")

	# Generar más allá del max (100)
	fury.generate(200.0)
	_check(fury.is_full() and is_equal_approx(fury.get_current(), 100.0), "resource clamped to max (100)")

	var consumed_all = fury.consume_all()
	_check(is_equal_approx(consumed_all, 100.0) and is_equal_approx(fury.get_current(), 0.0), "consume_all drains resource completely")

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
