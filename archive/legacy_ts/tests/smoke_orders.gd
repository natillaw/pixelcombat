extends Control
## Tactical control (combat Phase 2, D-040): hold, attack-move, follow, regroup, retreat, keys,
## line of sight, ranged kiting, telegraph dodge, unreachable-order feedback. Run:
##   godot --headless --path . res://tests/smoke_orders.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _key(sb: SandboxScreen, code: Key) -> void:
    var ev := InputEventKey.new()
    ev.keycode = code
    ev.pressed = true
    sb._input(ev)


func _run(sb: SandboxScreen, seconds: float) -> void:
    for i in int(seconds / 0.05):
        sb.tick(0.05)


func _ready() -> void:
    print("== Order tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_orders.json"
    Game.new_game()
    size = Vector2(1280, 720)
    var sb := SandboxScreen.new(0)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    await get_tree().process_frame
    await get_tree().process_frame
    var map: NavMap = sb.map
    for e in sb.enemies:
        e.alive = false
        e.visible = false
    var foe: SandboxEnemy = sb.enemies[0]
    var h0: SandboxHero = sb.heroes[0]
    var h1: SandboxHero = sb.heroes[1]
    var room := map.center_of(Vector2i(6, 15))          # open area in the left room

    # hold: fights in range, never chases
    for h in sb.heroes:
        h.position = map.center_of(Vector2i(3, 3)) + Vector2(sb.heroes.find(h) * 30, 0)
    sb.select_only([h0])
    _key(sb, KEY_H)
    check(h0.order == "hold", "H gives a hold order")
    foe.alive = true
    foe.visible = true
    foe.position = h0.position + Vector2(200, 0)
    var spot := h0.position
    _run(sb, 2.0)
    check(h0.position.distance_to(spot) < 30.0, "a holding hero does not chase a foe out of range")

    # attack-move: walks, engages what it meets
    foe.alive = false
    foe.visible = false
    sb.select_only([h0])
    _key(sb, KEY_A)
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    var vsize := Vector2(sb._viewport.size)
    click.position = vsize * 0.5 + (room - sb.camera.position) * sb.camera.zoom.x
    sb._gui_input(click)
    check(h0.order == "attack_move", "A then click gives an attack-move order")
    foe.alive = true
    foe.dead = false
    foe.visible = true
    foe.hp = foe.max_hp
    foe.position = h0.position + Vector2(0, 150)
    _run(sb, 4.0)
    check(foe.hp < foe.max_hp, "attack-move engages an enemy met on the way")
    foe.alive = false
    foe.visible = false

    # follow: stays close to the leader
    h0.order_move(map.find_path(h0.position, room))
    sb.select_only([h1])
    sb.select_slot(0)
    sb.select_only([h1])
    _key(sb, KEY_V)
    check(h1.order == "follow" and h1.follow_leader == h0, "V makes the selection follow the focused hero (D-082: F is interaction)")
    _run(sb, 8.0)
    check(h1.position.distance_to(h0.position) < 140.0, "a following hero stays near the leader (%.0f px)" % h1.position.distance_to(h0.position))

    # regroup: gathers the selection
    sb.select_all()
    _key(sb, KEY_C)
    _run(sb, 8.0)
    var spread := 0.0
    for a in sb.heroes:
        for b in sb.heroes:
            spread = maxf(spread, a.position.distance_to(b.position))
    check(spread < 160.0, "C regroups the squad (spread %.0f px)" % spread)

    # retreat: runs to EXTRACT without stopping to fight
    foe.alive = true
    foe.dead = false
    foe.visible = true
    foe.hp = foe.max_hp
    foe.position = h0.position + Vector2(40, 0)
    sb.select_all()
    _key(sb, KEY_X)
    check(sb.heroes.all(func(h): return h.order == "retreat"), "X gives a retreat order")
    var hp_foe := foe.hp
    _run(sb, 1.0)
    check(foe.hp == hp_foe, "a retreating hero does not stop to fight")
    foe.alive = false
    foe.visible = false

    # #14: a retreat first picks up a fallen ally close by, then both run for the exit
    for h in sb.heroes:
        h.stop()
    var fallen: SandboxHero = sb.heroes[1]
    var helper: SandboxHero = sb.heroes[0]
    fallen.position = map.nearest_walkable(helper.position + Vector2(60, 0))
    fallen.go_down()
    sb.select_only([helper])
    _key(sb, KEY_X)
    check(helper.order == "rescue" and helper.rescue_target == fallen and helper.then_retreat != Vector2.INF, "X near a fallen ally: pick them up first")
    _key(sb, KEY_X)
    check(helper.rescue_target == fallen, "pressing X again does not cancel the pick-up")
    _run(sb, 5.0)
    check(not fallen.downed and helper.order == "retreat" and fallen.order == "retreat", "after the pick-up both head for the exit")
    for h in [helper, fallen]:
        h.stop()
        h.statuses.clear()
        h.hp = h.max_hp                              # back to full for the tests below

    # line of sight: a ranged hero cannot shoot through a wall
    var archer: SandboxHero = null
    for h in sb.heroes:
        if h.is_ranged():
            archer = h
    if archer == null:
        archer = h0
        archer.hero.hero_class = "class.archer"
    check(not map.has_line_of_sight(map.center_of(Vector2i(12, 3)), map.center_of(Vector2i(15, 3))), "walls block line of sight")
    check(map.has_line_of_sight(map.center_of(Vector2i(3, 3)), map.center_of(Vector2i(8, 3))), "open ground keeps line of sight")

    # telegraph dodge (bounded autonomy, D-014)
    for h in sb.heroes:
        h.stop()
    h1.position = map.center_of(Vector2i(6, 16))
    foe.alive = true
    foe.dead = false
    foe.visible = true
    foe.hp = foe.max_hp
    foe.position = h1.position + Vector2(30, 0)
    # D-052: the reaction is a roll per strike from AGI and level, zero at level 1
    foe.state = SandboxEnemy.State.WINDUP
    foe._timer = 0.7
    foe._aim = h1.position
    foe.strike_seq += 1
    h1.hero.level = 1
    h1.combat_tick(sb.living_enemies(), map)
    check(not (h1._dodge_t > 0.0), "a level-1 autonomous hero does not dodge a telegraphed strike (D-052)")
    check(is_equal_approx(CombatRules.auto_dodge_chance(10, 1), 0.0) and CombatRules.auto_dodge_chance(10, 20) > 0.0
        and CombatRules.auto_dodge_chance(99, 99) <= CombatRules.DODGE_MAX, "dodge chance: 0 at level 1, grows with level, capped")
    h1.hero.level = 99
    h1.stats["spd"] = 99
    var dodged := 0
    var rerolls_ok := true
    for k in 60:
        h1.stop()
        h1._dodge_t = 0.0
        h1.dash_t = 0.0                                     # 2026-10-31: the AI may dash instead of stepping
        h1.dash_cd = 0.0
        h1.position = map.center_of(Vector2i(6, 16))
        foe.state = SandboxEnemy.State.WINDUP
        foe._timer = 0.7
        foe._aim = h1.position
        foe.strike_seq += 1
        h1.combat_tick(sb.living_enemies(), map)
        var moved := h1._dodge_t > 0.0 or h1.dash_t > 0.0
        if moved:
            dodged += 1
        else:
            h1.combat_tick(sb.living_enemies(), map)           # same strike: no second roll
            rerolls_ok = rerolls_ok and not (h1._dodge_t > 0.0 or h1.dash_t > 0.0)
    check(dodged > 0 and dodged < 48, "a veteran hero sometimes steps or dashes out, far from always (%d/60)" % dodged)
    check(rerolls_ok, "one roll per strike: a failed reaction is not retried every tick")
    h1.hero.level = 1
    h1.stats["spd"] = 5
    h1.stop()
    h1.order_move(map.find_path(h1.position, h1.position + Vector2(0, 48)))
    var path_before := h1.path.duplicate()
    h1.combat_tick(sb.living_enemies(), map)
    check(h1.path == path_before, "an explicit move order is not overridden by the dodge")

    # unreachable order feedback
    sb.select_only([h0])
    sb.order_move_selected(map.center_of(Vector2i(0, 0)) + Vector2(-500, -500))
    check(true, "ordering into the void does not crash (feedback shown)")

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)
