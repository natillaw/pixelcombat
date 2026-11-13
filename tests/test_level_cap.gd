## Tope de nivel por piso: no puedes ser de mas nivel que el piso mas alto desbloqueado.
##
##   godot --headless --path . --script tests/test_level_cap.gd
extends SceneTree

const CombatWorldScript := preload("res://game/sim/combat_world.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_level_cap ==")
	var player := PlayerSim.new()
	player.level_cap = 3
	player.grant_xp(100000)
	_check(player.level == 3, "con tope 3 el nivel no pasa de 3 (%d)" % player.level)
	_check(player.xp < Progression.xp_to_next(3), "y la barra queda sin llenar del todo (%d)" % player.xp)
	player.level_cap = 5
	player.grant_xp(1)
	_check(player.level >= 4, "al subir el tope se retoma la XP guardada (nivel %d)" % player.level)
	var free := PlayerSim.new()
	free.grant_xp(10 ** 7)
	_check(free.level == Progression.max_level(), "sin tope se llega al nivel maximo")

	var session := GameSession.new(CombatWorldScript.new(11), "")
	session.world.player.safe_zone = false
	session._enter(TowerGenerator.generate(1, 20261110, 1, ["clear"]), false)
	_check(session.world.player.level_cap == 1, "en el piso 1 el tope es 1")
	session.world.player.grant_xp(100000)
	_check(session.world.player.level == 1, "matar en el piso 1 no sube de nivel (%d)" % session.world.player.level)
	session._complete_floor()
	_check(session.world.player.level_cap == 2, "al completar el piso 1 el tope pasa a 2")
	_check(session.world.player.level == 2, "y la XP guardada sube a nivel 2 (%d)" % session.world.player.level)
	# Los pisos pagan casi un nivel: ritmo de la mision principal.
	for floor_number: int in range(1, 10):
		var share := float(TowerCatalog.completion_xp(floor_number)) / float(Progression.xp_to_next(floor_number))
		_check(share >= 0.7 and share <= 1.4, "piso %d: la XP de piso es %d %% del coste del nivel" % [floor_number, int(share * 100.0)])
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
