## Modos de reglas: en PvP el personaje se normaliza (mismo nivel, sin equipo, sin consumibles) y la aventura se conserva.
##
##   godot --headless --path . --script tests/test_rules.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _geared_player(class_id: String, level: int, seed_value: int) -> PlayerSim:
	var player := PlayerSim.new()
	player.switch_class(class_id)
	player.safe_zone = true
	player.set_level(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in range(40):
		player.add_item(ItemGen.roll_item(rng, 6, "", "", class_id, "", 2.0))
	var guard := 0
	while guard < 60:
		guard += 1
		var equipped := false
		for index: int in range(player.bag.size()):
			if player.equip_reason(index) == "":
				player.equip_from_bag(index)
				equipped = true
				break
		if not equipped:
			break
	player.add_consumable("health_potion", 3)
	return player


func _stat_line(player: PlayerSim) -> String:
	var parts: Array = []
	for stat: String in ["strength", "agility", "stamina", "intellect", "armor", "crit_chance", "weapon_min", "weapon_max"]:
		parts.append("%s=%.2f" % [stat, player.stats.get_stat(StringName(stat))])
	parts.append("hp=%.1f" % player.max_health)
	return ", ".join(parts)


func _loadout_ids(player: PlayerSim) -> Array:
	var ids: Array = []
	var slots: Array = player.loadout.keys()
	slots.sort()
	for slot: String in slots:
		ids.append("%s:%s" % [slot, String((player.loadout[slot] as Dictionary)["id"])])
	return ids


func _run() -> void:
	print("== test_rules ==")
	_check(RuleSet.errors().is_empty(), "rules.json es valido: %s" % str(RuleSet.errors()))
	_check(RuleSet.has_mode("pve") and RuleSet.has_mode("pvp") and not RuleSet.has_mode("otro"), "existen los modos pve y pvp")
	for class_id: String in ["warrior", "rogue", "mage", "archer"]:
		var veteran := _geared_player(class_id, 9, 11)
		var rookie := PlayerSim.new()
		rookie.switch_class(class_id)
		_check(veteran.equipment.size() >= 3, "%s: el veterano lleva equipo (%d piezas)" % [class_id, veteran.equipment.size()])
		var pve_power := veteran.max_health
		var veteran_line_before := _stat_line(veteran)
		_check(veteran.enter_rules("pvp") == "" and rookie.enter_rules("pvp") == "", "%s: ambos entran en PvP" % class_id)
		_check(_stat_line(veteran) == _stat_line(rookie), "%s: mismos stats en PvP\n        veterano: %s\n        novato:   %s" % [class_id, _stat_line(veteran), _stat_line(rookie)])
		_check(veteran.level == 10 and rookie.level == 10, "%s: los dos son de nivel 10" % class_id)
		_check(veteran.equipment.is_empty(), "%s: sin equipo en PvP" % class_id)
		_check(_loadout_ids(veteran) == _loadout_ids(rookie) and veteran.loadout.size() >= 5, "%s: mismo loadout completo (%d slots)" % [class_id, veteran.loadout.size()])
		_check(veteran.use_consumable("health_potion") == "rules", "%s: sin consumibles en PvP" % class_id)
		var xp_before := veteran.xp
		veteran.grant_xp(100000)
		_check(veteran.xp == xp_before and veteran.level == 10, "%s: la XP no cuenta en PvP" % class_id)
		veteran.bag.append(ItemGen.roll_item(RandomNumberGenerator.new(), 6, "", "", class_id, "", 2.0))
		_check(veteran.equip_reason(veteran.bag.size() - 1) == "rules", "%s: no se puede equipar en PvP" % class_id)
		_check(int(veteran.export_state()["progress"][class_id]["level"]) == 9, "%s: guardar durante la partida no pisa la aventura" % class_id)
		veteran.bag.pop_back()
		_check(veteran.enter_rules("pve") == "", "%s: vuelve a la aventura" % class_id)
		_check(veteran.level == 9 and veteran.equipment.size() >= 3 and veteran.consumable_count("health_potion") == 3, "%s: nivel, equipo y consumibles intactos" % class_id)
		_check(_stat_line(veteran) == veteran_line_before and is_equal_approx(veteran.max_health, pve_power), "%s: los stats de la aventura vuelven exactos" % class_id)
	_check(PlayerSim.new().enter_rules("no_existe") == "unknown", "un modo desconocido se rechaza")
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
