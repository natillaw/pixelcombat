extends RefCounted
## D-083 simulator parent: reads and validates the config, builds the overrides packs, splits the runs into
## jobs, runs them in parallel Godot worker processes (run_sim.gd --child) and writes the report
## (sim_report.gd) into docs/reports/sim/<date>_<name>/.

const SimConfig := preload("res://tools/sim/sim_config.gd")
const SimOverrides := preload("res://tools/sim/sim_overrides.gd")
const SimParty := preload("res://tools/sim/sim_party.gd")
const SimReport := preload("res://tools/sim/sim_report.gd")

var quiet := false
var cancel_file := ""             # D-130: the Sim Lab creates this file to stop the run (workers are killed)


func main(tree: SceneTree, args: Dictionary) -> void:
    quiet = args.has("quiet")
    cancel_file = String(args.get("cancel-file", ""))
    if not args.has("config"):
        _fail(tree, ["usage: godot --headless --path . -s res://tools/sim/run_sim.gd -- --config tools/sim/configs/<file>.json"])
        return
    var cfg_path := _res(String(args["config"]))
    var loaded := SimConfig.load_file(cfg_path)
    if loaded.has("error"):
        _fail(tree, [loaded["error"]])
        return
    var raw: Dictionary = loaded["data"]
    if args.has("runs"):
        raw["runs"] = int(args["runs"])
    var name := String(raw.get("name", cfg_path.get_file().get_basename()))
    var errors: Array = []
    var variants := SimConfig.expand(raw, errors)
    var presets := SimParty.load_presets()
    if presets.is_empty():
        errors.append("gear presets not found or invalid: %s" % SimParty.PRESETS_PATH)
    var applied := {}
    var work := ProjectSettings.globalize_path("user://sim_work/%d_%d" % [Time.get_unix_time_from_system(), OS.get_process_id()])
    DirAccess.make_dir_recursive_absolute(work)
    for i in variants.size():
        var cfg: Dictionary = variants[i]["config"]
        for f in cfg["floors"]:
            if not TowerExpedition.FLOORS.has(int(f)):
                errors.append("floor %s does not exist (floors: %s)" % [f, str(TowerExpedition.FLOORS.keys())])
        if int(cfg["runs"]) < 1 and not cfg.has("seeds"):
            errors.append("runs must be >= 1")
        if float(cfg["tick_hz"]) <= 0.0 or float(cfg["max_time"]) <= 0.0:
            errors.append("tick_hz and max_time must be > 0")
        for k in ["hp", "damage", "count"]:
            if float(cfg["enemies"][k]) < 0.0:
                errors.append("enemies.%s must be >= 0" % k)
        for e in SimParty.validate(cfg, presets) + SimParty.validate_progress(cfg, presets):
            if not errors.has(e):
                errors.append(e)
        var ov: Dictionary = cfg["overrides"]
        if not ov.is_empty():
            var b := SimOverrides.build(ov)
            for e in b["errors"]:
                if not errors.has(e):
                    errors.append(e)
            if (b["errors"] as Array).is_empty():
                var pack := work.path_join("overrides_%d.zip" % i)
                var werr := SimOverrides.write_pack(b["files"], pack)
                if werr != "":
                    errors.append(werr)
                variants[i]["pack"] = pack
                applied[variants[i]["label"]] = b["applied"]
    if not errors.is_empty():
        _fail(tree, errors)
        return
    var workers := int(args.get("workers", raw.get("workers", clampi(OS.get_processor_count() - 1, 1, 8))))
    var public_variants: Array = variants.map(func(v): return {"label": v["label"], "config": v["config"], "sweep": v.get("sweep", {}),
        "dims": v.get("dims", {}), "pair": v.get("pair", v["label"])})
    _say("Simulación \"%s\": %d variantes, %d runs, %d procesos" % [name, variants.size(), _count_runs(variants), workers])
    var a: Dictionary = await _run_all(tree, variants, work.path_join("a"), workers)
    if a.has("error"):
        _fail(tree, [a["error"]])
        return
    var rows := SimReport.aggregate(public_variants, a["runs"])
    if args.has("check-determinism"):
        # the second pass splits the runs differently (other worker count): a run must not depend on
        # which process played it or what that process played before
        var b2: Dictionary = await _run_all(tree, variants, work.path_join("b"), 1 if workers > 1 else 2)
        var fails := 0
        var ok_runs := (a["runs"] as Array).size() == _count_runs(variants)
        print("  %s  %d runs played without errors" % ["PASS" if ok_runs else "FAIL", (a["runs"] as Array).size()])
        fails += 0 if ok_runs else 1
        var same: bool = not b2.has("error") and JSON.stringify(rows) == JSON.stringify(SimReport.aggregate(public_variants, b2["runs"])) \
            and JSON.stringify(_strip_wall(a["runs"])) == JSON.stringify(_strip_wall(b2["runs"]))
        print("  %s  same seeds and config -> same summary and same runs" % ("PASS" if same else "FAIL"))
        fails += 0 if same else 1
        print("== ALL PASSED ==" if fails == 0 else "== %d FAILED ==" % fails)
        _cleanup(work)
        tree.quit(0 if fails == 0 else 1)
        return
    var dir := _res(String(args["out"])) if args.has("out") else _res("docs/reports/sim/%s_%s" % [Time.get_date_string_from_system(), name.validate_filename()])
    dir = ProjectSettings.globalize_path(dir) if dir.begins_with("res://") else dir
    SimReport.write(dir, name, raw, public_variants, a["runs"], rows, a["speed"], applied)
    _print_table(rows, a["speed"], SimReport.alerts(rows, variants[0]["config"]))
    print("Informe: %s" % dir.path_join("resumen.md"))
    _cleanup(work)
    tree.quit(0)


func _run_all(tree: SceneTree, variants: Array, work: String, workers: int) -> Dictionary:
    DirAccess.make_dir_recursive_absolute(work)
    var jobs: Array = []
    var total := _count_runs(variants)
    # small jobs: steady progress and balanced workers (a worker starts in ~2 s)
    var per_job := clampi(ceili(float(total) / float(maxi(1, workers * 4))), 1, 5)
    for vi in variants.size():
        var cfg: Dictionary = variants[vi]["config"]
        var list: Array = []
        var seeds: Array = cfg.get("seeds", [])
        if seeds.is_empty():
            for k in int(cfg["runs"]):
                seeds.append(int(cfg["seed"]) + k)
        var idx := 0
        for f in cfg["floors"]:
            for s in seeds:
                list.append({"floor": int(f), "seed": int(s), "index": idx})
                idx += 1
        var start := 0
        while start < list.size():
            var n := jobs.size()
            var job := {"label": variants[vi]["label"], "config": cfg, "runs": list.slice(start, start + per_job),
                "pack": variants[vi].get("pack", ""), "result": work.path_join("result_%d.json" % n)}
            var jp := work.path_join("job_%d.json" % n)
            var f := FileAccess.open(jp, FileAccess.WRITE)
            f.store_string(JSON.stringify(job))
            f.close()
            jobs.append({"path": jp, "result": job["result"], "pid": -1, "done": false, "n": (job["runs"] as Array).size(), "overrides": cfg["overrides"]})
            start += per_job
    var t0 := Time.get_ticks_msec()
    var running := 0
    var next := 0
    var finished := 0
    var played := 0
    while finished < jobs.size():
        while running < workers and next < jobs.size():
            jobs[next]["pid"] = OS.create_process(OS.get_executable_path(), _child_args(jobs[next]["path"]))
            running += 1
            next += 1
        await tree.create_timer(0.1).timeout
        if cancel_file != "" and FileAccess.file_exists(cancel_file):
            for j in jobs:
                if int(j["pid"]) > 0 and not j["done"] and OS.is_process_running(int(j["pid"])):
                    OS.kill(int(j["pid"]))
            return {"error": "cancelled"}
        for j in jobs:
            if j["pid"] > 0 and not j["done"] and not OS.is_process_running(int(j["pid"])):
                j["done"] = true
                running -= 1
                finished += 1
                played += int(j["n"])
                if not quiet:
                    print("  [%d/%d runs] %.0f s" % [played, total, float(Time.get_ticks_msec() - t0) / 1000.0])
    var runs: Array = []
    for j in jobs:
        var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(j["result"]))) if FileAccess.file_exists(String(j["result"])) else null
        if not (data is Dictionary):
            var out: Array = []
            OS.execute(OS.get_executable_path(), _child_args(j["path"]), out, true)
            var log := "\n".join(out)
            return {"error": "a worker failed (%s). Its output:\n%s" % [j["path"], log.right(3000)]}
        if String(data["error"]) != "":
            return {"error": "%s: %s" % [data["variant"], data["error"]]}
        for k in (data.get("effective", {}) as Dictionary):
            var want: Variant = j["overrides"].get(k)
            if str(data["effective"][k]) != str(want) and not (want is float and data["effective"][k] is float and is_equal_approx(float(want), float(data["effective"][k]))):
                return {"error": "override %s was not applied in the worker (it has %s)" % [k, str(data["effective"][k])]}
        for r in data["runs"]:
            r["variant"] = data["variant"]
            runs.append(r)
    runs.sort_custom(func(x, y): return [String(x["variant"]), int(x["index"])] < [String(y["variant"]), int(y["index"])])
    var wall := float(Time.get_ticks_msec() - t0) / 1000.0
    var sim_s := 0.0
    var cpu_s := 0.0
    for r in runs:
        sim_s += float(r["time"])
        cpu_s += float(r["wall_ms"]) / 1000.0
    return {"runs": runs, "speed": {"runs": runs.size(), "sim_s": sim_s, "cpu_s": cpu_s, "wall_s": wall, "workers": workers,
        "x_per_process": sim_s / maxf(0.001, cpu_s), "x_total": sim_s / maxf(0.001, wall)}}


func _child_args(job_path: String) -> PackedStringArray:
    return PackedStringArray(["--headless", "--quiet", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/sim/run_sim.gd", "--", "--child", job_path])


func _count_runs(variants: Array) -> int:
    var n := 0
    for v in variants:
        var c: Dictionary = v["config"]
        n += (c["floors"] as Array).size() * ((c["seeds"] as Array).size() if c.has("seeds") else int(c["runs"]))
    return n


static func _strip_wall(runs: Array) -> Array:
    return runs.map(func(r):
        var c: Dictionary = (r as Dictionary).duplicate(true)
        c.erase("wall_ms")
        return c)


func _print_table(rows: Array, speed: Dictionary, al: Array) -> void:
    print("")
    print("%-28s %5s %-12s %6s %9s %14s %10s %10s" % ["variante", "piso", "misión", "runs", "victoria", "duración s", "derribos", "muertes"])
    for r in rows:
        print("%-28s %5d %-12s %6d %8.0f%% %14s %10s %10s" % [String(r["variant"]).left(28), r["floor"], r["mission"], r["runs"], float(r["win_rate"]) * 100.0,
            SimReport._pm(r["time"], 0), SimReport._pm(r["downs"], 1), SimReport._pm(r["deaths"], 2)])
    for a in al:
        print("ALERTA: " + String(a).replace("**", ""))
    print("Velocidad: x%.1f tiempo real por proceso, x%.1f en total con %d procesos (%.0f s simulados en %.1f s)" % [float(speed["x_per_process"]),
        float(speed["x_total"]), int(speed["workers"]), float(speed["sim_s"]), float(speed["wall_s"])])


func _fail(tree: SceneTree, errors: Array) -> void:
    for e in errors:
        printerr("SIM ERROR: " + String(e))
    tree.quit(2)


func _say(s: String) -> void:
    if not quiet:
        print(s)


static func _res(p: String) -> String:
    if p.begins_with("res://") or p.begins_with("user://") or p.is_absolute_path():
        return p
    return "res://" + p


static func _cleanup(dir: String) -> void:
    for sub in ["a", "b", ""]:
        var d := dir.path_join(sub) if sub != "" else dir
        var da := DirAccess.open(d)
        if da == null:
            continue
        for fn in da.get_files():
            da.remove(fn)
        if sub != "":
            DirAccess.remove_absolute(d)
    DirAccess.remove_absolute(dir)
