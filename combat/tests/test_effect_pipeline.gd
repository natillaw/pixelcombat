## Test headless del pipeline de efectos (ISSUE P1.1).
##
##   godot --headless --path . --script combat/tests/test_effect_pipeline.gd
##
extends SceneTree

const EffectPipelineScript: GDScript = preload("res://combat/effect_pipeline.gd")
const EffectContextScript: GDScript = preload("res://combat/effect_context.gd")
const DamageEffectScript: GDScript = preload("res://combat/damage_effect.gd")
const HealEffectScript: GDScript = preload("res://combat/heal_effect.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_effect_pipeline (P1.1) ==")

	# 1. Test Damage Effect with signals
	var pipeline1 = EffectPipelineScript.new()
	var dmg_effect = DamageEffectScript.new()
	dmg_effect.base_damage = 35.0
	var ctx_dmg = EffectContextScript.new()

	var state = { "pre": false, "post": false }

	pipeline1.on_pre_effect.connect(func(_ctx) -> void:
		state.pre = true
	)
	pipeline1.on_post_effect.connect(func(_ctx) -> void:
		state.post = true
	)

	pipeline1.process_effect(dmg_effect, ctx_dmg)

	_check(state.pre, "on_pre_effect signal emitted")
	_check(state.post, "on_post_effect signal emitted")
	_check(ctx_dmg.effect_type == "damage", "effect type is damage")
	_check(ctx_dmg.amount == 35.0, "damage amount correctly applied")

	# 2. Test Heal Effect
	var pipeline2 = EffectPipelineScript.new()
	var heal_effect = HealEffectScript.new()
	heal_effect.base_heal = 20.0
	var ctx_heal = EffectContextScript.new()

	pipeline2.process_effect(heal_effect, ctx_heal)
	_check(ctx_heal.effect_type == "heal", "effect type is heal")
	_check(ctx_heal.amount == 20.0, "heal amount correctly applied")

	# 3. Test Cancellation hook (pre-effect cancel)
	var pipeline3 = EffectPipelineScript.new()
	var ctx_cancel = EffectContextScript.new()
	pipeline3.on_pre_effect.connect(func(ctx) -> void:
		ctx.cancelled = true
	)

	pipeline3.process_effect(dmg_effect, ctx_cancel)
	_check(ctx_cancel.amount == 0.0, "cancelled effect does not apply amount")

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
