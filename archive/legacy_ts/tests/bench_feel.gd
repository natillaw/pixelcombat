extends Node
## Rough simulation cost of a crowded fight (not pass/fail): 5 heroes vs 40 creatures of every size,
## skills fired every second. Prints the average and worst SandboxScreen.tick() time and live node count.
##   godot --headless --path . res://tests/bench_feel.tscn


func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://bench_feel_save.json"
    Game.new_game()
    var s := SandboxScreen.new(8)
    add_child(s)
    await get_tree().process_frame
    var kinds := ["rat", "goblin", "orc_brute", "golem", "spider"]
    var base: Vector2 = s.heroes[0].position
    for i in 40:
        var e := s._spawn_enemy(Vector2i(0, 0), kinds[i % kinds.size()])
        e.position = s.map.nearest_walkable(base + Vector2(cos(i * 0.7), sin(i * 0.7)) * (120.0 + 6.0 * i))
    var total := 0
    var worst := 0
    var n := 1200
    for f in n:
        if f % 60 == 0:
            for h in s.heroes:
                h.res = h.res_max
                h.cds.clear()
                h.use_skill_slot(0, s.living_enemies(), s.heroes)
        var t0 := Time.get_ticks_usec()
        s.tick(1.0 / 60.0)
        var dt := Time.get_ticks_usec() - t0
        total += dt
        worst = maxi(worst, dt)
        if f % 20 == 0:
            await get_tree().process_frame
    print("BENCH ticks=%d avg=%.3f ms worst=%.3f ms enemies_alive=%d nodes=%d" % [n, float(total) / n / 1000.0,
        float(worst) / 1000.0, s.living_enemies().size(), get_tree().get_node_count()])
    get_tree().quit(0)
