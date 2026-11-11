extends Node
## Plays like a person (2026-10-31, owner report): the real main scene, real frames (_physics_process),
## navigation from the town. Catches what manual tick() tests miss (freed nodes, input, saved floors).
##   godot --headless --path . res://tests/smoke_ingame.tscn --quit-after 60000
var fails := 0
var main: Node = null


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _frames(n: int) -> void:
    for i in n:
        await get_tree().physics_frame


func _screen() -> Node:
    var c: Node = main.get("_content")
    return c.get_child(c.get_child_count() - 1) if c != null and c.get_child_count() > 0 else null


func _ready() -> void:
    print("== In-game tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_ingame.json"
    Game.new_game()
    Game.starter_summons()
    for i in mini(5, Game.heroes.size()):
        Game.assign_party(i, Game.heroes.keys()[i])
    main = load("res://scenes/main.tscn").instantiate()
    add_child(main)
    await _frames(5)
    # --- the Wilds: walk onto a herb patch and gather it with real frames ------------------------
    main.show_screen("sandbox", -1)
    await _frames(5)
    var sb: SandboxScreen = _screen()
    check(sb != null and sb.is_wilds() and sb.nodes.size() > 0, "the Wilds open from the main scene with gathering spots")
    for e in sb.enemies:
        e.take_damage(999999)
    var g: GatherNode = sb.nodes[0]
    g.charges = 1                                    # D-117: last charge, so it empties in one ~5 s cycle
    var spot := g.position
    for h in sb.heroes:
        h.position = spot + Vector2(10, 0)
        h.order_hold()
    await _frames(480)                               # gathers (one 5 s cycle, fades) and keeps running after the node is freed
    check(not is_instance_valid(g) and not sb.ledger.is_empty(), "a gathered spot is removed and nothing crashes after it: %s" % str(sb.ledger))
    # --- dash with the real key ----------------------------------------------------------------
    sb.select_slot(0)
    var hero: SandboxHero = sb.heroes[0]
    var p0 := hero.position
    var ev := InputEventKey.new()
    ev.keycode = KEY_SPACE
    ev.pressed = true
    Input.parse_input_event(ev)
    await _frames(15)
    check(hero.dashes >= 1 and hero.position.distance_to(p0) > 10.0, "Space dashes the driven hero (%d dash, %.0f px; cd %.1f move %s cast '%s' down %s ctl %s)" % [hero.dashes, hero.position.distance_to(p0), hero.dash_cd, str(hero.can_move()), hero.casting, str(hero.downed), str(sb.controlled() == hero)])
    # --- tower floors from a new account: the new content ----------------------------------------
    for f in [1, 5, 10]:
        main.show_screen("sandbox", f)
        await _frames(8)
        var s: SandboxScreen = _screen()
        var cfg := TowerExpedition.get_floor_config(f)
        var types := {}
        for e in s.enemies:
            types[e.type_id] = true
        var bandit := types.keys().any(func(t): return BanditArt.has(String(t)))
        check(s.heroes.size() == TowerExpedition.party_max(f) and bandit, "floor %d '%s': %d heroes, bandits %s" % [f, cfg["name"], s.heroes.size(), str(types.keys())])
        check(s.enemies.size() >= int(cfg.get("min_enemies", 0)), "floor %d: %d creatures (min %d)" % [f, s.enemies.size(), int(cfg.get("min_enemies", 0))])
        if f == 10:
            check(s.boss != null and s.boss.type_id == "jefe_baron_carmesi" and s.altars.size() == 1, "floor 10 is the Crimson Baron with his altar")
        await _frames(60)
    main.show_screen("town")
    await _frames(10)
    check(_screen() is TownScreen, "back to the town without errors")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)
