## Modificadores de piso y afijos de elite: deterministas, solo pisos 2-9, con efecto real en los enemigos.
extends SceneTree

var _checks: int = 0
var _failures: int = 0
const DT := 1.0 / 60.0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("   %s %s" % ["ok  " if ok else "FAIL", label])


func _init() -> void:
	_test_picking()
	_test_modifier_effects()
	_test_affixes()
	_test_layout_integration()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_picking() -> void:
	_check(FloorModifiers.pick(1, 5, 1.0).is_empty() and FloorModifiers.pick(10, 5, 1.0).is_empty(), "los pisos 1 y 10 nunca llevan modificador")
	_check(FloorModifiers.pick(5, 5, 0.0).is_empty(), "con probabilidad 0 no hay modificador")
	var seen := {}
	for seed_value: int in range(200):
		var mod := FloorModifiers.pick(5, seed_value, 1.0)
		seen[String(mod["id"])] = true
	_check(seen.size() >= 4, "con probabilidad 1 salen varios modificadores distintos (%d)" % seen.size())
	_check(FloorModifiers.pick(5, 77, 1.0) == FloorModifiers.pick(5, 77, 1.0), "el modificador es determinista")
	var hits := 0
	for seed_value: int in range(400):
		hits += 0 if FloorModifiers.pick(5, seed_value, 0.3).is_empty() else 1
	_check(hits > 70 and hits < 170, "con probabilidad 0,3 salen ~30 %% (%d de 400)" % hits)
	_check(FloorModifiers.pick_affix(1, Vector2(10, 10), "bandit_thug") == "" and FloorModifiers.pick_affix(10, Vector2(10, 10), "bandit_thug") == "", "los pisos 1 y 10 no dan afijos")
	var with_affix := 0
	for i: int in range(200):
		with_affix += 0 if FloorModifiers.pick_affix(5, Vector2(i * 13, i * 7), "bandit_thug") == "" else 1
	_check(with_affix > 100 and with_affix < 180, "~70 %% de los elites llevan afijo (%d de 200)" % with_affix)


func _world(modifier: Dictionary) -> CombatWorld:
	var world := CombatWorld.new(5)
	var layout := TowerGenerator.generate(5, 20261110, 1)
	layout.modifier = modifier
	layout.enemies = []
	world.load_layout(layout)
	return world


func _test_modifier_effects() -> void:
	var base_world := _world({})
	var base := base_world.spawn_from_spec({"id": &"bandit_thug", "position": Vector2(400, 400), "required": false}, 1.0)
	var tough_world := _world(FloorModifiers.modifier("tough"))
	var tough := tough_world.spawn_from_spec({"id": &"bandit_thug", "position": Vector2(400, 400), "required": false}, 1.0)
	_check(tough.max_health > base.max_health * 1.25, "Piel dura: mas vida (%.0f -> %.0f)" % [base.max_health, tough.max_health])
	_check(tough.xp_reward(false) > base.xp_reward(false), "Piel dura: mas XP")
	var fast_world := _world(FloorModifiers.modifier("fast_foes"))
	var fast := fast_world.spawn_from_spec({"id": &"bandit_thug", "position": Vector2(400, 400), "required": false}, 1.0)
	_check(fast.speed_boost > 1.15, "Enemigos veloces: mas velocidad")
	var barrel := tough_world.spawn_from_spec({"id": &"barrel_explosive", "position": Vector2(450, 400), "required": false}, 1.0)
	_check(barrel.max_health < 40.0, "los modificadores no tocan a los barriles")


func _test_affixes() -> void:
	var world := _world({})
	var swift := world.spawn_from_spec({"id": &"bandit_thug", "position": Vector2(400, 400), "required": false, "elite": true, "affix": "swift"}, 1.0)
	_check(swift.elite and swift.speed_boost > 1.2 and swift.affix_name() == "Veloz", "afijo Veloz")
	var shield := world.spawn_from_spec({"id": &"bandit_thug", "position": Vector2(500, 400), "required": false, "elite": true, "affix": "shielded"}, 1.0)
	_check(shield.statuses.has("shield"), "afijo Escudado: lleva escudo")
	var health := shield.health
	shield.take_damage(50.0)
	_check(shield.health == health, "el escudo absorbe los primeros golpes")
	var poison := world.spawn_from_spec({"id": &"bandit_thug", "position": Vector2(600, 400), "required": false, "elite": true, "affix": "venomous"}, 1.0)
	var venom := false
	for attack: Dictionary in poison.data["attacks"]:
		for effect: Dictionary in attack.get("on_hit", []):
			venom = venom or String(effect["id"]) == "poison"
	_check(venom, "afijo Venenoso: sus golpes envenenan")
	world.player.position = Vector2(900, 900)
	var boom := world.spawn_from_spec({"id": &"bandit_thug", "position": Vector2(920, 900), "required": false, "elite": true, "affix": "explosive"}, 1.0)
	var player_health := world.player.health
	boom.take_damage(1.0e7)
	_check(world.player.health < player_health, "afijo Explosivo: al morir dana a quien tenga cerca")
	var plain := world.spawn_from_spec({"id": &"bandit_thug", "position": Vector2(1500, 1500), "required": false}, 1.0)
	_check(plain.affix == "" and not plain.data.has("on_death"), "un enemigo normal no lleva afijo")
	_check(world.spawn_from_spec({"id": &"bandit_thug", "position": Vector2(1500, 1600), "required": false, "elite": true, "affix": "no_existe"}, 1.0).affix == "", "un afijo desconocido se ignora")


func _test_layout_integration() -> void:
	var with_modifier := 0
	var affixes := 0
	for floor_number: int in range(1, 11):
		for seed_value: int in [20261110, 7, 99]:
			var layout := TowerGenerator.generate(floor_number, seed_value, 1)
			if floor_number == 10 or floor_number == 1:
				_check(layout.modifier.is_empty(), "piso %d seed %d: sin modificador" % [floor_number, seed_value]) if seed_value == 20261110 else null
			with_modifier += 0 if layout.modifier.is_empty() else 1
			for spec: Dictionary in layout.enemies:
				if spec.has("affix"):
					affixes += 1
					if floor_number == 10 or floor_number == 1:
						_check(false, "piso %d lleva afijo" % floor_number)
	_check(with_modifier >= 3, "se generan pisos con modificador (%d de 30)" % with_modifier)
	_check(affixes >= 1, "se generan elites con afijo (%d)" % affixes)
	var a := TowerGenerator.generate(6, 20261110, 1)
	var b := TowerGenerator.generate(6, 20261110, 1)
	_check(a.modifier == b.modifier and a.enemies.size() == b.enemies.size(), "la generacion con modificadores es determinista")
	_check(float(TowerGenerator.generate(7, 1, 1).features.get("darkness", 0.0)) >= 0.4, "el piso 7 es oscuro")
