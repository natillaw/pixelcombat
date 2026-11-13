## Plantilla de enemigos del tier 1: cada piso 1-9 tiene variedad de "verbos" y el piso 10 no cambia.
extends SceneTree

var _checks: int = 0
var _failures: int = 0

const NEW_IDS := ["carrion_crow", "acid_slime", "bandit_brute", "bandit_sapper", "bandit_shaman"]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("   %s %s" % ["ok  " if ok else "FAIL", label])


func _init() -> void:
	var tier: Dictionary = TowerCatalog.tier(1)
	for entry: Dictionary in tier["pool"]:
		_check(EnemyCatalog.has_enemy(StringName(String(entry["id"]))), "el enemigo del pool '%s' existe" % entry["id"])
	var floor10_ids: Array = []
	for entry: Dictionary in MissionGen.pool_for_floor(tier, 10):
		floor10_ids.append(String(entry["id"]))
	for id: String in NEW_IDS:
		_check(not floor10_ids.has(id), "%s no aparece en el piso 10 (el jefe no cambia)" % id)
	var previous := 0
	for floor_number: int in range(1, 10):
		var ids: Array = MissionGen.pool_for_floor(tier, floor_number).map(func(e: Dictionary) -> String: return String(e["id"]))
		var shapes := {}
		var roles := {}
		for id: String in ids:
			var data := EnemyCatalog.enemy(StringName(id))
			roles[String(data["role"])] = true
			for attack: Dictionary in data["attacks"]:
				shapes[String(attack["shape"])] = true
		_check(ids.size() >= previous, "piso %d: el pool (%d) no se reduce respecto al anterior" % [floor_number, ids.size()])
		previous = ids.size()
		if floor_number >= 4:
			_check(roles.size() >= 8, "piso %d: al menos 8 roles distintos (%d)" % [floor_number, roles.size()])
			_check(shapes.size() >= 4, "piso %d: al menos 4 formas de ataque distintas (%d)" % [floor_number, shapes.size()])
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)
