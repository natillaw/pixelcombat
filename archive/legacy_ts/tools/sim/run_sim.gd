extends SceneTree
## D-083 headless combat simulator: plays real expeditions with the game's own code (rules, items, hero
## AI, bandit AI and the MasterBot), with nothing drawn, at a fixed step and as fast as the CPU allows.
##
##   godot --headless --path . -s res://tools/sim/run_sim.gd -- --config tools/sim/configs/floor1_tactico_vs_loco.json
##
## Options after "--":
##   --config <file>       the config (tools/sim/configs/*.json, // comments allowed)
##   --runs <n>            overrides "runs" (seeds = seed .. seed + n - 1)
##   --workers <n>         parallel Godot processes (default: CPU cores - 1, max 8)
##   --out <dir>           report folder (default docs/reports/sim/<date>_<name>/)
##   --check-determinism   runs everything twice and checks both summaries are identical (test)
##   --quiet               less console output
##   --cancel-file <path>  stop (and kill the workers) as soon as this file exists (Sim Lab, D-130)
##
## This file names no game class on purpose: a worker process (--child) first loads the balance overrides
## (a pack with patched copies of the scripts, tools/sim/sim_overrides.gd) and only then lets the game's
## scripts compile. The parent (sim_main.gd) plans, validates, launches the workers and writes the report.

var _args: Dictionary = {}
var _keep: RefCounted = null      # the running main/worker object (a coroutine dies with its object)


func _init() -> void:
    _args = _parse(OS.get_cmdline_user_args())
    if _args.has("child"):
        var job: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(_args["child"])))
        if job is Dictionary:
            var pack := String((job as Dictionary).get("pack", ""))
            if pack != "" and not ProjectSettings.load_resource_pack(pack, true):
                printerr("SIM ERROR: could not load the overrides pack %s" % pack)
        _args["job"] = job


func _initialize() -> void:
    if _args.has("child"):
        if not (_args.get("job") is Dictionary):
            printerr("SIM ERROR: unreadable job file %s" % String(_args["child"]))
            quit(3)
            return
        _keep = load("res://tools/sim/sim_runner.gd").new()
        _keep.run_job(self, _args["job"], String(_args["child"]))
    else:
        _keep = load("res://tools/sim/sim_main.gd").new()
        _keep.main(self, _args)


static func _parse(argv: PackedStringArray) -> Dictionary:
    var out := {}
    var i := 0
    while i < argv.size():
        var a := String(argv[i])
        if a.begins_with("--"):
            var key := a.substr(2)
            if i + 1 < argv.size() and not String(argv[i + 1]).begins_with("--"):
                out[key] = String(argv[i + 1])
                i += 1
            else:
                out[key] = true
        i += 1
    return out
