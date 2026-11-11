extends Control
## Diagnostic: one separation nudge (the game's own _nudge) can put a hero in a corner pocket, and then
## no order can get it out (find_path is empty).
func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://diag_tr.json"
    Game.new_game()
    Game.starter_summons()
    var sb := SandboxScreen.new(1)
    add_child(sb)
    await get_tree().process_frame
    sb.set_physics_process(false)
    var m := sb.map
    var spawn := m.center_of(m.spawn_cells[0])
    for y in m.height:
        for x in m.width:
            var p := Vector2i(x, y)
            if m.is_blocked_cell(p) or not m.find_path(m.center_of(p), spawn).is_empty():
                continue
            for d in [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]:
                var r: Vector2i = p + d
                if m.is_blocked_cell(r) or m.find_path(m.center_of(r), spawn).is_empty():
                    continue
                var h: SandboxHero = sb.heroes[0]
                var dir := -Vector2(d).normalized()          # from the reachable cell toward the pocket
                h.position = m.center_of(r) + dir * 30.0     # standing in the corner of its cell
                var before := m.cell_of(h.position)
                sb._nudge(h, dir * 12.0)                     # a 12 px separation push
                var after := m.cell_of(h.position)
                var out := m.find_path(h.position, spawn)
                print("pocket %s: hero in %s, pushed 12 px -> %s; path back to the entrance: %d points; order_move: %s" % [str(p), str(before), str(after),
                    out.size(), "trapped" if out.is_empty() else "ok"])
                get_tree().quit(0)
                return
    print("no pocket found")
    get_tree().quit(0)
