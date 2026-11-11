extends Node
## UI capture (not pass/fail, D-063): title, character creator (D-080), summon reveal and summary, village, hero sheet tabs,
## inventory, expedition HUD, Esc menu, options, credits and results. Needs a real renderer:
##   godot --path . res://tests/capture_ui.tscn      (CAPTURE_DIR overrides the folder)

var _dir: String = ""
var _main: Control


func _ready() -> void:
    _dir = OS.get_environment("CAPTURE_DIR")
    if _dir == "":
        _dir = ProjectSettings.globalize_path("user://captures_ui")
    DirAccess.make_dir_recursive_absolute(_dir)
    Game.autosave = false
    Game.save_path = "user://capture_ui_save.json"
    Game.new_game()
    _main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
    add_child(_main)
    await _shot("ui_01_title", 1.0)
    _main.call("show_screen", "master", 0)            # D-080: the character creator, one shot per tab
    await get_tree().process_frame
    var mc: MasterCreator = _find("MasterCreator")
    mc.randomize_all()
    for t in 4:
        mc._tabs.current_tab = t
        await _shot("ui_01b_master_tab%d" % t, 0.5)
    mc.confirm()
    Game.hardcore = true                               # D-081: show the skull on the HUD shot
    _main.call("show_screen", "welcome", 0)
    await get_tree().process_frame
    var w: WelcomeScreen = _find("WelcomeScreen")
    for i in WelcomeScreen.PAGES.size():
        w.next_page()
    await _shot("ui_02_reveal", 1.2)
    var r: SummonReveal = _find("SummonReveal")
    if r != null:
        r._skip_all = true
    await _shot("ui_03_reveal_summary", 0.8)
    _main.call("show_screen", "town", 0)
    await _shot("ui_04_town", 1.5)
    Game.hq_outputs["materials"] = 400
    for k in ["hide", "gel", "silk", "ingot"]:
        Game.hq_outputs[k] = 20
    var rng := RandomNumberGenerator.new()
    for i in 6:
        Game.stash.append(ItemGen.generate(rng, Game._next_uid(), 3, ["common", "uncommon", "rare", "epic", "legendary", "common"][i]))
    _main.call("show_screen", "roster", 0)
    await _shot("ui_05_roster_summary", 0.8)
    var sheet: HeroSheet = _find("HeroSheet")
    for t in [2, 3]:
        if sheet != null:
            sheet._tabs.current_tab = t
        await _shot("ui_06_sheet_tab%d" % t, 0.4)
    var mst := Game.master()                           # D-081: the Master's sheet (Leadership, memories)
    if mst != null:
        MasterRules.unlock_memory(mst, 10)
        _main.call("show_screen", "roster", 0)
        await get_tree().process_frame
        var ms: HeroSheet = _find("HeroSheet")
        if ms != null:
            ms.hero = mst
            ms._tab_index = 6
            ms.rebuild()
        await _shot("ui_06b_master_memories", 0.5)
        _main.call("show_screen", "master_edit", 0)
        await _shot("ui_06c_mirror", 0.5)
    _main.call("show_screen", "inventory", 0)
    await _shot("ui_07_inventory", 0.8)
    _main.call("show_screen", "sandbox", 1)
    await get_tree().create_timer(1.0).timeout
    var sb: SandboxScreen = _find("SandboxScreen")
    if sb != null:
        sb.select_slot(0)
        await _shot("ui_08_hud_driven", 0.6)
        sb.open_menu()
        await _shot("ui_09_esc_menu", 0.4)
        sb._menu.show_options()
        await _shot("ui_10_options", 0.3)
        sb._menu.show_credits()
        await _shot("ui_11_credits", 0.3)
        sb._menu.close()
        for e in sb.enemies:
            e.take_hit(DamageInfo.make(99999.0, "true", sb.heroes[0]))
        sb.tick(0.05)
        await _shot("ui_12_results", 0.6)
    print("CAPTURE DONE -> ", _dir)
    get_tree().quit(0)


func _find(cls: String) -> Node:
    for n in _main.find_children("*", "", true, false):
        if is_instance_valid(n) and n.get_script() != null and (n.get_script() as Script).get_global_name() == cls:
            return n
    return null


func _shot(shot_name: String, wait: float) -> void:
    await get_tree().create_timer(wait).timeout
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    print("shot ", shot_name, " err=", img.save_png(_dir.path_join(shot_name + ".png")))
