## Fugas de memoria: recargar pisos no debe acumular objetos (enemigo -> senal -> callable -> enemigo era un ciclo
## de RefCounted que perdia ~300 objetos por carga), y los PNJ de la ciudad solo componen las animaciones que usan.
##
##   godot --headless --path . --script tests/test_memory_leaks.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _objects() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


func _run() -> void:
	print("== test_memory_leaks ==")
	var world := CombatWorld.new(1)
	var session := GameSession.new(world, "")
	for n: int in range(1, 6):
		session.tower.complete(n)
	var layout := TowerGenerator.generate(5, 20261110, 1)
	world.load_layout(layout)                    # la primera carga crea cachés y objetos "fijos"
	await process_frame
	var baseline := _objects()
	for i: int in range(8):
		world.load_layout(layout)
	await process_frame
	var growth := _objects() - baseline
	_check(growth < 60, "8 recargas del mismo piso no acumulan objetos (+%d)" % growth)
	var before_enter := _objects()
	for i: int in range(6):
		session._enter(TowerGenerator.generate(5, 20261110, 1), false)
	await process_frame
	growth = _objects() - before_enter
	_check(growth < 400, "6 entradas a un piso (generar + cargar) no acumulan objetos (+%d)" % growth)
	# Los PNJ solo guardan idle y walk.
	var look := Residents.look_of(Residents.all()[0])
	var frames := LpcComposer.build_frames_for(look, "class.npc", Residents.OUTFITS["guard"], PackedStringArray(["idle", "walk"]))
	_check(frames.has_animation("idle_down") and frames.has_animation("walk_left"), "un PNJ tiene idle y walk")
	_check(not frames.has_animation("slash_down") and not frames.has_animation("spellcast_down"), "y no compone el resto de animaciones")
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
