## Laboratorio de balance por consola:
##
##   godot --headless --path . --script tools/balance/run_balance.gd
##   godot --headless --path . --script tools/balance/run_balance.gd -- 20     (nivel 20)
##
## Imprime la matriz de clases (DPS, oleada del tier 1 y jefe) y escribe
## tests/out/balance_matrix.csv.
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := 10
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		level = int(args[0])
	print("== Laboratorio de balance (nivel %d) ==" % level)
	var rows := BalanceLab.matrix(level)
	var csv := "class,level,hp,dps,burst_dps,sustained_dps,wave_cleared,wave_time,wave_hp_left,wave_damage_taken,boss_cleared,boss_time,boss_hp_left\n"
	print("%-8s %6s %8s %8s %10s %7s %8s %8s %s" % ["clase", "vida", "dps", "rafaga", "sostenido", "oleada", "tiempo", "vida_fin", "jefe"])
	for row: Dictionary in rows:
		var boss_text := "NO"
		if row["boss_cleared"]:
			boss_text = "%.0fs / %.0f%% vida" % [row["boss_time"], float(row["boss_hp_left"]) * 100.0]
		print("%-8s %6d %8.1f %8.1f %10.1f %7s %7.1fs %7.0f%% %s" % [row["class"], int(row["hp"]), row["dps"], row["burst_dps"], row["sustained_dps"], "si" if row["wave_cleared"] else "NO", row["wave_time"], float(row["wave_hp_left"]) * 100.0, boss_text])
		csv += "%s,%d,%.0f,%.2f,%.2f,%.2f,%s,%.2f,%.3f,%.1f,%s,%.2f,%.3f\n" % [row["class"], row["level"], row["hp"], row["dps"], row["burst_dps"], row["sustained_dps"], str(row["wave_cleared"]), row["wave_time"], row["wave_hp_left"], row["wave_damage_taken"], str(row["boss_cleared"]), row["boss_time"], row["boss_hp_left"]]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	var file := FileAccess.open("res://tests/out/balance_matrix.csv", FileAccess.WRITE)
	file.store_string(csv)
	file.close()
	print("Escrito tests/out/balance_matrix.csv")
	quit(0)
