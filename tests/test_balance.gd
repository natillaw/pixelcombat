## Banda de balance entre clases, medida con el laboratorio (bots deterministas).
##
##   godot --headless --path . --script tests/test_balance.gd
##
## No fija numeros: exige que ninguna clase se salga de una banda respecto a la
## media de las cuatro (DPS, sostenido y rafaga), que todas limpien la oleada del
## tier 1 y que la identidad de resistencia se conserve (Warrior mas vida, Mage
## menos). Si retocas daños o crecimiento y este test falla, la clase que se salio
## esta en el mensaje; la matriz completa sale con tools/balance/run_balance.gd.
extends SceneTree

const LEVELS := [1, 4, 10, 30]
const SECONDS := 20.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_balance (banda entre clases) ==")
	_test_dps_bands()
	_test_waves_are_cleared()
	_test_resistance_identity()
	_test_the_lab_is_deterministic()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_dps_bands() -> void:
	for level: int in LEVELS:
		var rows: Array = []
		for class_id: String in ClassCatalog.all_ids():
			rows.append(BalanceLab.dps_run(class_id, level, SECONDS))
		var tolerance := 0.25 if level <= 4 else 0.15
		print("   nivel %d: %s" % [level, " | ".join(rows.map(func(r: Dictionary) -> String: return "%s %.0f" % [r["class"], r["dps"]]))])
		_band(rows, "dps", tolerance, "nivel %d: DPS" % level)
		if level == 10:
			_band(rows, "sustained_dps", 0.15, "nivel 10: DPS sostenido")
			_band(rows, "burst_dps", 0.30, "nivel 10: rafaga")
		for row: Dictionary in rows:
			_check(int(row["hits"]) > 5, "nivel %d: %s llega a golpear (%d impactos)" % [level, row["class"], int(row["hits"])])


## Cada clase dentro de +-tolerance de la media de `field`.
func _band(rows: Array, field: String, tolerance: float, label: String) -> void:
	var total := 0.0
	for row: Dictionary in rows:
		total += float(row[field])
	var mean := total / float(rows.size())
	for row: Dictionary in rows:
		var ratio := float(row[field]) / mean
		_check(absf(ratio - 1.0) <= tolerance, "%s de %s = %.0f%% de la media (banda +-%d%%)" % [label, row["class"], ratio * 100.0, int(tolerance * 100.0)])


func _test_waves_are_cleared() -> void:
	for level: int in [1, 10]:
		for class_id: String in ClassCatalog.all_ids():
			var wave := BalanceLab.wave_run(class_id, level)
			_check(bool(wave["cleared"]) and bool(wave["alive"]), "nivel %d: %s limpia la oleada del tier 1 (%.0f s, %.0f%% de vida)" % [level, class_id, wave["time"], float(wave["hp_left"]) * 100.0])
			_check(float(wave["time"]) < 45.0, "nivel %d: %s la limpia en menos de 45 s" % [level, class_id])


func _test_resistance_identity() -> void:
	var hp: Dictionary = {}
	for class_id: String in ClassCatalog.all_ids():
		var world := BalanceLab._new_world(class_id, 10, 1)
		hp[class_id] = world.player.max_health
	_check(hp["warrior"] > hp["archer"] and hp["warrior"] > hp["rogue"], "el Warrior es el mas resistente (%d)" % int(hp["warrior"]))
	_check(hp["mage"] < hp["rogue"] and hp["mage"] < hp["archer"], "el Mage es el mas fragil (%d)" % int(hp["mage"]))


func _test_the_lab_is_deterministic() -> void:
	var a := BalanceLab.dps_run("archer", 10, 8.0, 5)
	var b := BalanceLab.dps_run("archer", 10, 8.0, 5)
	var c := BalanceLab.dps_run("archer", 10, 8.0, 6)
	_check(is_equal_approx(float(a["dps"]), float(b["dps"])) and a["casts"] == b["casts"], "la misma semilla da la misma medicion")
	_check(not is_equal_approx(float(a["dps"]), float(c["dps"])), "otra semilla cambia los criticos")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
