## Pisos con historia (2-9): dos misiones principales con su texto de lore, siempre resolubles.
##
##   godot --headless --path . --script tests/test_story_floors.gd
extends SceneTree

const SEED := 20261110
const EXPECTED := {
	2: ["slay", "explore"],
	3: ["kill_group", "slay"],
	4: ["interact", "slay"],
	6: ["relic", "slay"],
	7: ["interact", "explore"],
	8: ["survive", "kill_group"],
	9: ["explore", "kill_group"],
}

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_story_floors ==")
	for floor_number: int in EXPECTED:
		var kinds: Array = EXPECTED[floor_number]
		var always_two := true
		var always_valid := true
		var texts_ok := true
		for visit: int in range(1, 11):
			var layout := TowerGenerator.generate(floor_number, SEED, visit)
			var mains: Array = (layout.mission_plan["missions"] as Array).filter(func(m: Dictionary) -> bool: return not bool(m["optional"]))
			if mains.size() != kinds.size():
				always_two = false
			else:
				for i: int in range(kinds.size()):
					if String((mains[i] as Dictionary)["kind"]) != String(kinds[i]):
						always_two = false
			if not MissionGen.check(layout).is_empty():
				always_valid = false
			for mission: Dictionary in layout.mission_plan["missions"]:
				if String(mission["desc"]).contains("{") or String(mission["desc"]).length() < 20 or String(mission["title"]).is_empty():
					texts_ok = false
		_check(always_two, "piso %d: siempre %d misiones principales (%s)" % [floor_number, kinds.size(), ", ".join(kinds)])
		_check(always_valid, "piso %d: todas sus misiones se pueden cumplir (10 visitas)" % floor_number)
		_check(texts_ok, "piso %d: titulo y texto de cada mision completos" % floor_number)
	var titles: Dictionary = {}
	for floor_number: int in EXPECTED:
		var layout := TowerGenerator.generate(floor_number, SEED, 1)
		for mission: Dictionary in layout.mission_plan["missions"]:
			if not bool(mission["optional"]):
				titles[String(mission["title"])] = true
	_check(titles.size() >= 14, "los pisos 2-9 no repiten misiones principales (%d distintas)" % titles.size())
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
