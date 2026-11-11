extends Node
## Vertical slice capture (not pass/fail): welcome, the ten summons, the near-empty village with the
## Build menu and a placement ghost, and an expedition results screen. Needs a real renderer:
##   godot --path . --resolution 1280x720 res://tests/capture_slice.tscn   (CAPTURE_DIR overrides the folder)

var _dir: String = ""


func _ready() -> void:
    _dir = OS.get_environment("CAPTURE_DIR")
    if _dir == "":
        _dir = ProjectSettings.globalize_path("user://captures_slice")
    DirAccess.make_dir_recursive_absolute(_dir)
    Game.autosave = false
    Game.save_path = "user://capture_slice_save.json"
    Game.new_game()
    var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
    add_child(main)
    await _shot("slice_01_welcome", 0.6)
    var w: WelcomeScreen = main.find_children("*", "WelcomeScreen", true, false)[0] if not main.find_children("*", "WelcomeScreen", true, false).is_empty() else null
    for n in main.find_children("*", "", true, false):
        if n is WelcomeScreen:
            w = n
    if w != null:
        for i in WelcomeScreen.PAGES.size():
            w.next_page()
        await _shot("slice_02_first_summons", 0.6)
    main.call("show_screen", "town", 0)
    await _shot("slice_03_village_start", 2.0)
    var town: TownScreen = null
    for n in main.find_children("*", "", true, false):
        if n is TownScreen:
            town = n
    if town != null:
        Game.hq_outputs["materials"] = 300
        town.show_build_menu()
        await _shot("slice_04_build_menu", 0.4)
        town.start_place("blacksmith")
        town.view.ghost_cell = Vector2i(9, 12)
        town.view.ghost_ok = Game.placement_block("blacksmith", Vector2i(9, 12)) == ""
        town.view.queue_redraw()
        await _shot("slice_05_placing", 0.4)
    var squad: Array = Game.heroes.values().filter(func(h): return Game.is_fighter(h))
    for h in Game.heroes.values():
        if squad.size() < Game.PARTY_SIZE and not squad.has(h):
            squad.append(h)
    squad = squad.slice(0, Game.PARTY_SIZE)
    for i in squad.size():
        Game.assign_party(i, (squad[i] as HeroData).id)
    main.call("show_screen", "sandbox", 1)
    await get_tree().create_timer(1.0).timeout
    for n in main.find_children("*", "", true, false):
        if n is SandboxScreen:
            var sb := n as SandboxScreen
            await _shot("slice_06_floor1_fog", 0.2)
            for e in sb.enemies:
                e.take_hit(DamageInfo.make(99999.0, "true", sb.heroes[0]))
            sb.tick(0.05)
            await _shot("slice_07_results", 0.5)
            break
    print("CAPTURE DONE -> ", _dir)
    get_tree().quit(0)


func _shot(shot_name: String, wait: float) -> void:
    await get_tree().create_timer(wait).timeout
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    print("shot ", shot_name, " err=", img.save_png(_dir.path_join(shot_name + ".png")))
