extends Control
func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://diag_cl.json"
    for k in 3:
        Game.new_game()
        Game.starter_summons()
        var sb := SandboxScreen.new(2)
        add_child(sb)
        await get_tree().process_frame
        sb.set_physics_process(false)
        var sp := sb.map.center_of(sb.map.spawn_cells[0])
        var goal := sb.map.center_of(sb.map.relic_cell)
        print("run %d: spawn->goal %.0f px; clues: %s; under fog at start: %s" % [k, sp.distance_to(goal),
            str(sb.clues.map(func(c): return "d_spawn=%.0f d_goal=%.0f" % [c.position.distance_to(sp), c.position.distance_to(goal)])),
            str(sb.clues.map(func(c): return not sb.fog.is_explored(sb.map.cell_of(c.position))))])
        sb.queue_free()
        await get_tree().process_frame
    get_tree().quit(0)
