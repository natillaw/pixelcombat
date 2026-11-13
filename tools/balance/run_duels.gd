## Matriz de duelos entre clases por consola (PvP normalizado):
##
##   godot --headless --path . --script tools/balance/run_duels.gd -- [rondas]
##
## Imprime el % de victorias de cada clase (fila) contra cada otra (columna) y su media, y vuelca
## `tests/out/duel_matrix.csv`.
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var rounds := int(args[0]) if args.size() > 0 else 10
	var result := DuelLab.matrix(rounds)
	var ids: Array = result["classes"]
	print("== Duelos PvP normalizados (%d rondas por pareja, lados cambiados) ==" % rounds)
	var header := "%-9s" % "vs"
	for b: String in ids:
		header += "%9s" % b
	header += "%9s" % "media"
	print(header)
	var csv := "clase," + ",".join(ids) + ",media\n"
	for a: String in ids:
		var line := "%-9s" % a
		var row := a
		for b: String in ids:
			if a == b:
				line += "%9s" % "-"
				row += ","
			else:
				var rate: float = (result["table"][a] as Dictionary)[b]
				line += "%8d%%" % int(round(rate * 100.0))
				row += ",%.3f" % rate
		line += "%8d%%" % int(round(float(result["average"][a]) * 100.0))
		row += ",%.3f" % float(result["average"][a])
		print(line)
		csv += row + "\n"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	var file := FileAccess.open("res://tests/out/duel_matrix.csv", FileAccess.WRITE)
	if file != null:
		file.store_string(csv)
	quit(0)
