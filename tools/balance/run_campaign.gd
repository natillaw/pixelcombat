## Campana por consola (un bot recorre los primeros pisos de la torre):
##
##   godot --headless --path . --script tools/balance/run_campaign.gd -- warrior 10 [regen] [rest] [forced]
## Sin `forced` juega las misiones reales de cada piso; con `forced`, solo limpieza/caza (campana antigua).
##
## Imprime por piso el tiempo, el nivel, la vida perdida y las muertes.
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var class_id := String(args[0]) if args.size() > 0 else "warrior"
	var floors := int(args[1]) if args.size() > 1 else 10
	var regen := float(args[2]) if args.size() > 2 else 0.0
	var rest := float(args[3]) if args.size() > 3 else 0.0
	print("== Campana: %s, pisos 1-%d, regen %.3f/s, descanso <%d%% ==" % [class_id, floors, regen, int(rest * 100.0)])
	print("%5s %8s %6s %7s %9s %7s %s" % ["piso", "tiempo", "nivel", "muertes", "vida_perd", "items", "ok"])
	for row: Dictionary in CampaignLab.run(class_id, floors, regen, rest, args.size() > 4 and String(args[4]) == "forced"):
		print("%5d %7.0fs %2d->%2d %7d %8.0f%% %7d %s" % [row["floor"], row["seconds"], row["level_start"], row["level_end"], row["deaths"], float(row["hp_lost"]) / maxf(float(row["hp_max"]), 1.0) * 100.0, row["items"], "si" if row["completed"] else "NO"])
	quit(0)
