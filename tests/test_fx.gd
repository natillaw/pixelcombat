## Efectos visuales: la biblioteca es valida (hojas que existen, referencias correctas), cada
## habilidad implementada y cada suceso importante tienen efecto, todos se pueden montar como
## animacion y un FxSprite se reproduce y se libera.
##
##   godot --headless --path . --script tests/test_fx.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_fx (efectos visuales) ==")
	_check(FxLibrary.errors().is_empty(), "fx.json valido: %s" % str(FxLibrary.errors().slice(0, 3)))
	var ids := FxLibrary.effect_ids()
	_check(ids.size() >= 120, "la biblioteca trae %d efectos (PVFX Foundry y Pixel Spell & Combat FX)" % ids.size())
	var groups := {}
	for id: String in ids:
		groups[id.split("/")[0]] = true
	for group: String in ["melee", "impacts", "projectiles", "status", "arcane", "fire", "ice", "lightning", "holy", "shadow", "nature", "explosions", "smoke", "kit"]:
		_check(groups.has(group), "hay efectos de %s" % group)
	var all_build := true
	for id: String in ids:
		var frames := FxLibrary.frames(id)
		var spec := FxLibrary.effect(id)
		if frames.get_frame_count(&"play") != int(spec["count"]):
			all_build = false
	_check(all_build, "todos los efectos se montan como animacion con su numero de fotogramas")
	var missing: Array = []
	for skill_id: StringName in SkillCatalog.all_ids():
		if bool(SkillCatalog.skill(skill_id).get("implemented", false)) and FxLibrary.skill_fx(String(skill_id)).is_empty():
			missing.append(String(skill_id))
	_check(missing.is_empty(), "cada habilidad implementada tiene su efecto (faltan %s)" % str(missing))
	for event: String in ["level_up", "dodge", "pickup", "gather", "boss_phase", "enemy_death", "boss_death", "status_stun", "status_slow", "status_poison", "interact_altar", "interact_seal", "interact_cage", "interact_relic", "interact_relic_altar", "interact_beacon", "interact_waypoint"]:
		_check(not FxLibrary.event_fx(event).is_empty(), "el suceso %s tiene efecto" % event)
	var holder := Node2D.new()
	root.add_child(holder)
	var sprite := FxSprite.new()
	holder.add_child(sprite)
	sprite.setup("impacts/hit-spark", 1.0, 0.0, Color.WHITE, 0.0)
	_check(sprite.is_playing() and sprite.material != null, "un FxSprite se reproduce en aditivo")
	await create_timer(1.5).timeout
	_check(not is_instance_valid(sprite) or sprite.is_queued_for_deletion(), "y se libera al terminar")
	var looped := FxSprite.new()
	holder.add_child(looped)
	looped.setup("status/stun-stars", 1.0, 0.0, Color.WHITE, 0.3)
	await create_timer(0.6).timeout
	_check(not is_instance_valid(looped) or looped.is_queued_for_deletion(), "un efecto en bucle dura los segundos pedidos")
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
