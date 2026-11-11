extends Control
## Whole UI (D-063): every screen opens without script errors, every path the AssetCatalog promises
## exists, the Theme uses the pixel fonts, the 640x360 base is set, and the keys answer (1-5 drive,
## Q attacks at the mouse, W E R skills, orders, Esc menu without pausing, I details).
##   godot --headless --path . res://tests/smoke_ui_full.tscn --quit-after 6000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _key(node: Node, code: Key, pressed: bool = true) -> void:
    var e := InputEventKey.new()
    e.keycode = code
    e.pressed = pressed
    node._input(e)


func _ready() -> void:
    print("== Full UI tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_ui_full.json"
    Game.new_game()
    var missing := AssetCatalog.all_paths().filter(func(p): return not ResourceLoader.exists(String(p)))
    check(missing.is_empty(), "every catalogued asset exists (%d paths) %s" % [AssetCatalog.all_paths().size(), str(missing)])
    for id in AssetCatalog.CREATURES:
        check(EnemySprites.has_processed(String(id)), "creature %s has its processed strips" % id)
    check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640 and String(ProjectSettings.get_setting("display/window/stretch/scale_mode")) == "integer",
        "640x360 base with whole-number scaling")
    var th := UIKit.make_theme()
    check(th.default_font != null and th.default_font.resource_path.ends_with("m5x7.ttf") and th.default_font_size == UIKit.BODY, "the Theme uses m5x7 at its native size")
    check(UIKit.px(40) == 20 and UIKit.fpx(13) == UIKit.BODY and UIKit.fpx(30) == UIKit.TITLE_BIG, "design units convert to whole base pixels and native font sizes")
    check(GameMenu.credit_lines().size() >= 10, "the credits come from the asset registry (%d lines)" % GameMenu.credit_lines().size())
    var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
    add_child(main)
    await get_tree().process_frame
    Game.starter_summons()
    for s in ["title", "welcome", "town", "summon", "roster", "party", "inventory", "memorial", "hq", "menu"]:
        main.call("show_screen", s)
        await get_tree().process_frame
        check(main.get_child_count() > 0, "screen %s opens" % s)
    # the hero sheet: 6 tabs
    main.call("show_screen", "roster")
    await get_tree().process_frame
    await get_tree().process_frame
    var sheets := main.find_children("*", "HeroSheet", true, false)
    var sheet: HeroSheet = null
    for n in main.find_children("*", "", true, false):
        if n is HeroSheet:
            sheet = n
    check(sheet != null and sheet._tabs != null and sheet._tabs.get_tab_count() == 6, "the hero sheet has 6 tabs (summary, skills, equipment, progression, profession, relations)")
    # expedition HUD and keys
    main.call("show_screen", "sandbox", 5)        # floor 5 lets 5 heroes in (D-082b: floor 1 = 1 hero)
    await get_tree().process_frame
    await get_tree().process_frame
    var sb: SandboxScreen = null
    for n in main.find_children("*", "", true, false):
        if n is SandboxScreen:
            sb = n
    check(sb != null and sb._hud != null and sb._hud._frames != null and sb._hud._frames.get_child_count() == sb.heroes.size() and sb._hud._skills.size() == 4, "the HUD shows the party (D-111 frames) and Q W E R")
    _key(sb, KEY_2)
    check(sb.heroes[1].is_controlled(), "key 2 drives hero 2")
    sb.heroes[1]._cooldown = 0.0
    _key(sb, KEY_Q)
    check(sb.heroes[1]._cooldown > 0.0, "Q fires the driven hero's attack at the mouse")
    _key(sb, KEY_Q, false)
    _key(sb, KEY_H)
    check(sb.heroes[1].order == "hold", "H gives the hold order")
    _key(sb, KEY_TAB)
    check(sb.controlled() == null, "Tab returns to the squad view")
    var t0 := sb.elapsed
    _key(sb, KEY_ESCAPE)
    check(sb._menu != null and is_instance_valid(sb._menu), "Esc opens the menu")
    sb.tick(0.5)
    check(sb.elapsed > t0 and not get_tree().paused, "the menu does not pause the expedition (D-014, D-062)")
    sb._menu.close()
    _key(sb, KEY_I)
    check(sb._hud._details != null, "I opens the details panel")
    print("== ALL PASSED ==" if fails == 0 else "== %d FAILED ==" % fails)
    get_tree().quit(0 if fails == 0 else 1)
