extends SceneTree
## D-134 Sim Lab smoke (not in Run-Tests): opens the scene, plays 2 runs of floor 1 through the real
## simulator process and reads the result back.
##   godot --headless --path . -s res://tools/sim/sim_lab_smoke.gd

var fails := 0


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    var lab: Control = (load("res://tools/sim/sim_lab.tscn") as PackedScene).instantiate()
    root.add_child(lab)
    await process_frame
    _check(lab.floor_checks.size() == TowerExpedition.FLOORS.size(), "one floor box per TowerExpedition floor")
    _check(lab.constants.has("CombatRules.ARMOR_FLAT"), "overrides autocomplete lists the game's constants")
    _check(lab.archetype_pick.item_count >= 7, "archetypes read from archetypes.json")
    lab._apply_archetype("equilibrado")
    var cfg: Dictionary = lab.build_config(2)
    _check((cfg["party"] as Array).size() == 5 and bool(cfg["party"][0]["master"]), "archetype fills the 5-hero party, Master first")
    lab._set_floors([])
    _check(not lab.validate(lab.build_config(2)).is_empty(), "no floor -> error shown before launching")
    lab._set_floors([1])
    lab.max_time_spin.value = 300
    lab.workers_spin.value = 2
    lab.name_edit.text = "sim_lab_smoke"
    lab.start(2)
    _check(lab.is_running(), "the simulator process starts")
    var t0 := Time.get_ticks_msec()
    while lab.is_running() and Time.get_ticks_msec() - t0 < 300000:
        await create_timer(0.2).timeout
    _check(not lab.is_running(), "the run ends")
    var sum: Array = lab.read_summary(lab._out_dir)
    _check(sum.size() == 1 and int(sum[0]["floor"]) == 1 and int(sum[0]["runs"]) == 2, "results.json read back: floor 1, 2 runs")
    _check(lab.results_tree.get_root() != null and lab.results_tree.get_root().get_child_count() == 1, "the floor table shows the result")
    print("  status: %s" % lab.status_label.text)
    if lab.errors_label.text != "":
        print("  errors: %s" % lab.errors_label.text)
    var dir: String = lab._out_dir
    for fn in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(fn))
    DirAccess.remove_absolute(dir)
    print("== ALL PASSED ==" if fails == 0 else "== %d FAILED ==" % fails)
    quit(0 if fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
    print("  %s  %s" % ["PASS" if ok else "FAIL", what])
    if not ok:
        fails += 1
