extends SceneTree
## D-110: writes every juice profile in JuiceDefs as res://assets/juice/<id>.tres (script-first, D-009).
## A saved file wins over the table, so tune a profile by editing its .tres; re-run with --force to
## overwrite the files from the table again. Run:
##   godot --headless --path . -s res://tools/build_juice_profiles.gd [-- --force]


func _init() -> void:
    var force := OS.get_cmdline_user_args().has("--force")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(JuiceProfile.DIR))
    var written := 0
    var kept := 0
    for id in JuiceDefs.all_ids():
        var path := JuiceProfile.file_name(String(id))
        if ResourceLoader.exists(path) and not force:
            kept += 1
            continue
        var p := JuiceProfile.from_dict(String(id), JuiceDefs.raw(String(id)))
        var err := ResourceSaver.save(p, path)
        if err != OK:
            push_error("could not save %s (%d)" % [path, err])
            quit(1)
            return
        written += 1
    print("juice profiles: %d written, %d kept (%s)" % [written, kept, JuiceProfile.DIR])
    quit(0)
