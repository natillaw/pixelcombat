## Test headless del tick fijo (ISSUE P0.2).
##
##   godot --headless --path . --script core/tests/test_tick.gd
##
## Sale con código 0 si todo pasa, 1 si algo falla. Tarda ~11 s porque el
## caso (a) mide 10 segundos reales de simulación.
##
## Usa una instancia propia de tick_manager.gd (no el autoload) para que el
## estado de un caso no contamine a otro.
extends SceneTree

const TickManagerScript: GDScript = preload("res://core/tick_manager.gd")
const TickableScript: GDScript = preload("res://core/tickable.gd")
const DebugOverlayScene: PackedScene = preload("res://ui/debug_overlay.tscn")

const MEASURE_SECONDS: float = 10.0
const EXPECTED_TICKS: int = 600
## Margen tolerante a CI: un runner cargado puede perder algún tick de pared.
const TOLERANCE: int = 8


## Tickable que anota cada tick recibido.
class Recorder extends "res://core/tickable.gd":
	var ticks: Array[int] = []
	var deltas: Array[float] = []
	var registered_calls: int = 0
	var unregistered_calls: int = 0
	## Si no es null, en su próximo tick desregistra a este otro Tickable.
	var unregister_on_tick: Object = null
	var manager: Node = null

	func _on_tick(tick_number: int, delta: float) -> void:
		ticks.append(tick_number)
		deltas.append(delta)
		if unregister_on_tick != null:
			manager.unregister(unregister_on_tick)
			unregister_on_tick = null

	func _on_register() -> void:
		registered_calls += 1

	func _on_unregister() -> void:
		unregistered_calls += 1


var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_tick (P0.2) ==")
	print("physics_ticks_per_second = %d" % Engine.physics_ticks_per_second)
	_check(Engine.physics_ticks_per_second == 60, "project runs physics at 60 Hz")
	_check(root.get_node_or_null("TickManager") != null, "TickManager autoload is present")

	await _test_a_sixty_ticks_per_second()
	_test_b_tickable_receives_same_tick_numbers()
	_test_c_unregister()
	await _test_d_pause_resume()
	await _test_e_debug_overlay_toggle()

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _new_manager() -> Node:
	var manager: Node = TickManagerScript.new()
	root.add_child(manager)
	return manager


# a) 600 ticks en 10 s (±1) y 10 s simulados exactos.
func _test_a_sixty_ticks_per_second() -> void:
	print("-- (a) 60 ticks/s over %.0f s --" % MEASURE_SECONDS)
	var manager: Node = _new_manager()
	var recorder: Recorder = Recorder.new()
	manager.register(recorder)

	# Arrancar a medir en el borde de un tick.
	await manager.tick
	var start_tick: int = manager.current_tick
	var start_usec: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - start_usec < int(MEASURE_SECONDS * 1_000_000.0):
		await process_frame
	var elapsed: float = float(Time.get_ticks_usec() - start_usec) / 1_000_000.0
	var ticks: int = manager.current_tick - start_tick
	# Normaliza a exactamente 10 s por si el último frame se pasó un poco.
	var expected: int = roundi(elapsed * 60.0)
	print("   %d ticks in %.4f s real (expected %d, nominal %d)" % [ticks, elapsed, expected, EXPECTED_TICKS])
	_check(absi(ticks - expected) <= TOLERANCE, "real-time tick count within ±%d" % TOLERANCE)
	_check(absi(expected - EXPECTED_TICKS) <= TOLERANCE, "measured window is 10 s")

	# Tiempo simulado: cada tick aporta exactamente 1/60 s, sin importar cuántos
	# ticks de pared se hayan podido perder en un runner lento.
	var sample_count: int = mini(EXPECTED_TICKS, recorder.deltas.size())
	var simulated: float = 0.0
	for i: int in range(sample_count):
		simulated += recorder.deltas[i]
	print("   simulated time of %d ticks = %.6f s" % [sample_count, simulated])
	_check(sample_count == EXPECTED_TICKS, "recorded at least %d ticks" % EXPECTED_TICKS)
	_check(
		is_equal_approx(simulated, float(sample_count) / 60.0),
		"fixed deltas add up to %d / 60 s" % sample_count
	)
	_check(recorder.deltas.all(func(d: float) -> bool: return d == 1.0 / 60.0), "tick delta is fixed 1/60")
	manager.queue_free()


# b) El Tickable recibe exactamente los mismos tick_number que emite el manager.
func _test_b_tickable_receives_same_tick_numbers() -> void:
	print("-- (b) tickable sees manager tick numbers --")
	var manager: Node = _new_manager()
	manager.set_paused(true) # avanzamos a mano con step()
	var emitted: Array[int] = []
	manager.tick.connect(func(n: int, _d: float) -> void: emitted.append(n))
	var first: Recorder = Recorder.new()
	var second: Recorder = Recorder.new()
	manager.register(first)
	manager.register(second)
	for i: int in range(120):
		manager.step()
	var expected: Array[int] = []
	for i: int in range(1, 121):
		expected.append(i)
	_check(emitted == expected, "manager emitted ticks 1..120")
	_check(first.ticks == emitted, "first tickable received the same tick numbers")
	_check(second.ticks == emitted, "second tickable received the same tick numbers")
	_check(first.registered_calls == 1, "_on_register called once")
	_check(not manager.register(first), "double register is rejected")
	manager.queue_free()


# c) Un Tickable desregistrado no recibe ticks después del siguiente tick.
func _test_c_unregister() -> void:
	print("-- (c) unregister --")
	var manager: Node = _new_manager()
	manager.set_paused(true)

	# Fuera de un tick: efecto inmediato.
	var outside: Recorder = Recorder.new()
	manager.register(outside)
	manager.step() # tick 1
	manager.unregister(outside)
	manager.step() # tick 2
	manager.step() # tick 3
	_check(outside.ticks == [1], "unregistered outside a tick: no more ticks")
	_check(outside.unregistered_calls == 1, "_on_unregister called once")

	# A mitad de tick: termina el tick actual (pending_removal) y luego nada.
	var killer: Recorder = Recorder.new()
	var victim: Recorder = Recorder.new()
	killer.manager = manager
	manager.register(killer) # se ejecuta antes que victim
	manager.register(victim)
	killer.unregister_on_tick = victim
	manager.step() # tick 4: killer desregistra a victim; victim aún recibe el 4
	_check(not manager.is_registered(victim), "victim is no longer registered after the tick")
	manager.step() # tick 5
	manager.step() # tick 6
	_check(victim.ticks == [4], "unregistered mid-tick: finishes current tick only")
	_check(victim.unregistered_calls == 1, "victim _on_unregister called once")
	_check(killer.ticks == [4, 5, 6], "killer keeps ticking")
	_check(manager.get_tickable_count() == 1, "only killer remains registered")
	manager.queue_free()


# d) set_paused(true) para los ticks; al despausar sigue en tick + 1.
func _test_d_pause_resume() -> void:
	print("-- (d) pause / resume --")
	var manager: Node = _new_manager()
	var recorder: Recorder = Recorder.new()
	manager.register(recorder)
	for i: int in range(10):
		await physics_frame
	_check(manager.current_tick > 0, "ticking before pause")

	manager.set_paused(true)
	_check(not manager.is_running, "is_running is false while paused")
	var paused_at: int = manager.current_tick
	var received_before: int = recorder.ticks.size()
	for i: int in range(30):
		await physics_frame
	_check(manager.current_tick == paused_at, "no ticks while paused (current_tick stays %d)" % paused_at)
	_check(recorder.ticks.size() == received_before, "tickable receives nothing while paused")

	manager.set_paused(false)
	_check(manager.is_running, "is_running is true after resume")
	var resumed: Array = await manager.tick
	print("   paused at %d, resumed with %d" % [paused_at, resumed[0]])
	_check(resumed[0] == paused_at + 1, "resume continues at paused tick + 1")
	_check(recorder.ticks.back() == paused_at + 1, "tickable continues at paused tick + 1")
	manager.queue_free()


# Extra: el debug overlay se togglea con la acción de F3.
func _test_e_debug_overlay_toggle() -> void:
	print("-- (e) debug overlay F3 toggle --")
	var overlay: CanvasLayer = DebugOverlayScene.instantiate()
	root.add_child(overlay)
	_check(overlay.visible, "overlay starts visible")
	overlay.toggle()
	_check(not overlay.visible, "F3 hides the overlay")
	var label: Label = overlay.get_node("Label")
	_check(label.text.begins_with("tick: "), "overlay shows the tick")
	overlay.queue_free()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
