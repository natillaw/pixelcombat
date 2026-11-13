## Musica por zona y momento: prioridades, pistas que existen y cambios segun el estado del juego.
##
##   godot --headless --path . --script tests/test_music.gd
extends SceneTree

const CombatWorldScript := preload("res://game/sim/combat_world.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_music ==")
	for track: String in MusicDirector.TRACKS:
		_check(ResourceLoader.exists(MusicDirector.DIR + track + ".ogg"), "existe la pista %s" % track)
	_check(MusicDirector.choose({"kind": "city"}) == "town", "ciudad: town")
	_check(MusicDirector.choose({"kind": "floor", "tier": 1}) == "explore", "piso del tier 1: explore")
	_check(MusicDirector.choose({"kind": "floor", "tier": 3}) == "dungeon", "piso de tier alto: dungeon")
	_check(MusicDirector.choose({"kind": "floor", "combat": true}) == "battle", "combate: battle")
	_check(MusicDirector.choose({"kind": "floor", "combat": true, "boss": true}) == "boss", "jefe gana al combate")
	_check(MusicDirector.choose({"kind": "floor", "boss": true, "victory": true}) == "results", "la victoria gana al jefe")
	_check(MusicDirector.choose({"kind": "floor", "victory": true, "dead": true}) == "", "morir apaga la musica")
	_check(MusicDirector.choose({"kind": "floor", "dead": true, "menu": true}) == "title", "el menu manda sobre todo")

	var world := CombatWorldScript.new(11)
	var session := GameSession.new(world, "")
	var director := MusicDirector.new()
	director.bind(world, session)
	session.go_to_city()
	director.evaluate(1.0)
	_check(director.current_track == "town", "en la ciudad suena town (%s)" % director.current_track)
	session.tower.complete(1)
	world.player.safe_zone = false
	session._enter(TowerGenerator.generate(2, 20261110, 1), false)
	director.evaluate(1.0)
	_check(director.current_track == "explore", "en un piso suena explore (%s)" % director.current_track)
	# Un enemigo en guardia cerca: combate; al alejarse, vuelve tras COMBAT_HOLD.
	var enemy: EnemySim = world.enemies[0]
	enemy.position = world.player.position + Vector2(100, 0)
	enemy.state = EnemySim.State.CHASE
	director.evaluate(1.0)
	_check(director.current_track == "battle", "con un enemigo en guardia suena battle (%s)" % director.current_track)
	enemy.state = EnemySim.State.IDLE
	director.evaluate(2.0)
	_check(director.current_track == "battle", "el combate se sostiene un rato")
	director.evaluate(5.0)
	_check(director.current_track == "explore", "y vuelve a explore sin enemigos (%s)" % director.current_track)
	session.floor_completed.emit(2, 100)
	director.evaluate(1.0)
	_check(director.current_track == "results", "al completar el piso suena results (%s)" % director.current_track)
	director.evaluate(20.0)
	_check(director.current_track == "explore", "tras unos segundos vuelve el ambiente")
	world.player.health = 0.0
	world.player.alive = false
	director.evaluate(1.0)
	_check(director.current_track == "", "muerto: silencio")
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
