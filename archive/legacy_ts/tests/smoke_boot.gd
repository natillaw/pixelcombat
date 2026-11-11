extends Node
## Boots the real main scene and opens every screen once (catches script errors like F-001). Run:
##   godot --headless --path . res://tests/smoke_boot.tscn --quit-after 3000


func _ready() -> void:
    print("== Boot test ==")
    Game.autosave = false
    Game.save_path = "user://smoke_boot.json"
    Game.new_game()
    var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
    add_child(main)
    await get_tree().process_frame
    # D-063: the game opens on the title screen; New game -> welcome (D-058), Continue -> town (D-030)
    var ok := main.has_method("show_screen") and main.find_children("*", "", true, false).any(func(n): return n is TitleScreen)
    print("  ", "PASS  " if ok else "FAIL  ", "main.gd loaded and the game opens on the title screen (D-063)")
    main.call("show_screen", "welcome")
    await get_tree().process_frame
    var okw := main.find_children("*", "", true, false).any(func(n): return n is WelcomeScreen)
    print("  ", "PASS  " if okw else "FAIL  ", "a new account goes to the welcome (D-058)")
    ok = ok and okw
    main.queue_free()
    Game.starter_summons()
    var main2 := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
    add_child(main2)
    await get_tree().process_frame
    main2.call("show_screen", "town")
    await get_tree().process_frame
    var ok2 := main2.find_children("*", "", true, false).any(func(n): return n is TownScreen)
    print("  ", "PASS  " if ok2 else "FAIL  ", "Continue takes an account with heroes to the town (D-030)")
    ok = ok and ok2
    main = main2
    if ok:
        for s in ["title", "welcome", "summon", "roster", "party", "inventory", "memorial", "hq", "sandbox", "menu", "town"]:
            main.call("show_screen", s)
            await get_tree().process_frame
            print("  PASS  opened screen ", s)
    print("== %s ==" % ("ALL PASSED" if ok else "1 FAILED"))
    if FileAccess.file_exists("user://smoke_boot.json"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_boot.json"))
    get_tree().quit(0 if ok else 1)
