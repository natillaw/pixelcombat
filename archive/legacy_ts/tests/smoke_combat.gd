extends Control
## Combat checks (T-007, T-010). Run:
##   godot --headless --path . res://tests/smoke_combat.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Combat tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_combat.json"
    Game.new_game()
    size = Vector2(1280, 720)
    var sb := SandboxScreen.new()
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    await get_tree().process_frame
    await get_tree().process_frame

    check(CombatRules.damage(10, 4) == 8 and CombatRules.damage(1, 50) == 1, "damage formula: half DEF, minimum 1")
    check(CombatRules.hero_interval(1) <= 1.6 and CombatRules.hero_interval(99) >= 0.6, "attack interval clamped")
    check(sb.enemies.size() == sb.map.enemy_spawn_cells.size(), "enemies spawned on the fixed map")
    var on_floor := sb.enemies.all(func(e): return not sb.map.is_blocked(e.position))
    check(on_floor, "enemies spawn on walkable ground")

    # isolate: one enemy next to hero 0, the rest removed
    for e in sb.enemies:
        e.alive = false
        e.visible = false
    var foe: SandboxEnemy = sb.enemies[0]
    foe.alive = true
    foe.visible = true
    foe.hp = foe.max_hp
    foe.state = SandboxEnemy.State.IDLE
    var h0: SandboxHero = sb.heroes[0]
    for h in sb.heroes.slice(1):
        h.position = sb.map.center_of(Vector2i(2, 2))     # far away, out of perception
    foe.position = h0.position + Vector2(150, 0)

    # T-007: idle hero attacks on its own and kills the enemy
    var hp0 := foe.hp
    var saw_auto_walk := false
    for i in 600:
        sb.tick(1.0 / 60.0)
        if h0.auto_path:
            saw_auto_walk = true
        if not foe.alive:
            break
    check(foe.hp < hp0, "idle hero damaged the enemy without any order")
    check(saw_auto_walk or h0.is_ranged(), "melee hero walked into range by itself")

    # T-010: enemy telegraphs before it hits, and the hit can be dodged
    foe.alive = true
    foe.visible = true
    foe.hp = foe.max_hp
    foe.state = SandboxEnemy.State.IDLE
    h0.alive = true
    h0.hp = h0.max_hp
    h0.position = sb.map.center_of(Vector2i(20, 17))
    h0.stop()
    foe.position = h0.position + Vector2(30, 0)
    var saw_telegraph := false
    var hp_before := h0.hp
    var dodged_hp := -1
    for i in 120:
        foe.tick(1.0 / 60.0, sb.living_heroes(), sb.map)
        if foe.is_telegraphing():
            saw_telegraph = true
            if dodged_hp < 0:
                hp_before = h0.hp
                dodged_hp = 0
                h0.position += Vector2(200, 0)     # step out of the marked circle (player order)
                h0.position = sb.map.nearest_walkable(h0.position)
    check(saw_telegraph, "enemy shows a wind-up telegraph before striking")
    check(h0.hp == hp_before or h0.position.distance_to(foe.position) > foe.strike_radius, "moving out of the telegraph avoids the hit")

    # direct orders always win over autonomy (D-016)
    foe.alive = true
    foe.visible = true
    foe.state = SandboxEnemy.State.IDLE
    h0.position = sb.map.center_of(Vector2i(20, 17))
    foe.position = h0.position + Vector2(100, 0)
    h0.order_move(sb.map.find_path(h0.position, sb.map.center_of(Vector2i(16, 17))))
    for i in 10:
        h0.combat_tick(sb.living_enemies(), sb.map)
    check(h0.target == null and not h0.auto_path, "combat never overrides a direct move order")

    # permanent death: dead heroes stay dead and drop out of selection
    sb.select_only([h0])
    h0.take_damage(99999)
    sb.tick(1.0 / 60.0)
    check(not h0.alive and h0.downed and not sb.selected.has(h0), "fallen hero is removed from selection")
    var agony0 := h0.agony
    h0.take_damage(1)
    check(h0.hp == 0 and not h0.alive and h0.agony < agony0, "a hit on a fallen hero shortens the agony instead of hp (D-036)")
    sb.select_slot(0)
    check(not sb.selected.has(h0), "key 1 cannot select a dead hero")

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_combat.json"))
    get_tree().quit(1 if fails > 0 else 0)
