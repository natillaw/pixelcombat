## Duelos entre clases (PvP normalizado): el laboratorio es determinista y ninguna clase se sale de la banda.
##
##   godot --headless --path . --script tests/test_duels.gd
extends SceneTree

const ROUNDS := 20

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_duels ==")
	var first := DuelLab.duel("warrior", "mage", 7)
	var second := DuelLab.duel("warrior", "mage", 7)
	_check(first == second, "el mismo duelo da el mismo resultado")
	_check(String(first["winner"]) in ["a", "b", "draw"] and float(first["seconds"]) > 1.0, "el duelo termina (%s en %.0f s)" % [first["winner"], first["seconds"]])
	# Un duelo de verdad: los dos se hacen dano, no hay muerte instantanea ni duelos eternos.
	var seconds_total := 0.0
	var count := 0
	for pair: Array in [["warrior", "rogue"], ["mage", "archer"], ["rogue", "mage"]]:
		var result := DuelLab.duel(pair[0], pair[1], 3)
		seconds_total += float(result["seconds"])
		count += 1
		_check(float(result["hp_a"]) < 1.0 or float(result["hp_b"]) < 1.0, "%s vs %s: hay dano" % [pair[0], pair[1]])
	_check(seconds_total / float(count) >= 4.0 and seconds_total / float(count) <= 70.0, "los duelos duran entre 4 y 70 s de media (%.0f s)" % (seconds_total / float(count)))
	# Espejo (guerrero contra guerrero): al repartir los papeles de jugador principal y rival, ningun lado manda.
	var wins_a := 0
	for seed_value: int in range(20):
		if String(DuelLab.duel("warrior", "warrior", seed_value, 75.0, seed_value % 2 == 1)["winner"]) == "a":
			wins_a += 1
	_check(wins_a >= 7 and wins_a <= 13, "espejo (guerrero contra guerrero): %d de 20 para un lado" % wins_a)
	# Banda de balance: cada clase entre 35 y 65 % de victorias de media (objetivo de diseño 40-60, con margen de muestra).
	var result := DuelLab.matrix(ROUNDS)
	for class_id: String in result["classes"]:
		var average: float = result["average"][class_id]
		_check(average >= 0.35 and average <= 0.65, "%s: %d %% de victorias de media" % [class_id, int(round(average * 100.0))])
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
