extends Control
## Diagnostic: for floors 1-10, is every enemy, gathering node, clue spot and the relic reachable from the spawn?
func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://diag.json"
    Game.new_game()
    for f in range(1, 11):
        var m: ProceduralMap = Game.get_or_create_tower_floor_map(f)
        var start := m.center_of(m.spawn_cells[0])
        var bad: Array = []
        for enc in m.encounters:
            for i in (enc["cells"] as Array).size():
                var c: Vector2i = enc["cells"][i]
                if m.find_path(start, m.center_of(c)).is_empty():
                    bad.append("%s@%s(%s,%s) blocked=%s" % [enc["members"][i], str(c), enc["kind"], enc["zone"], str(m.is_blocked_cell(c))])
        var nb: Array = []
        for n in m.resource_nodes:
            if m.find_path(start, m.center_of(n["cell"])).is_empty():
                nb.append(str(n["cell"]))
        var tb: Array = []
        for c in m.treasure_cells:
            if m.find_path(start, m.center_of(c)).is_empty():
                tb.append(str(c))
        var relic_ok := not m.find_path(start, m.center_of(m.relic_cell)).is_empty()
        print("floor %d %dx%d enemies=%d unreachable_enemies=%d %s | nodes_unreach=%s | treasure_unreach=%s | relic_ok=%s extract=%s spawn=%s goal_dist=%.0f" % [f, m.width, m.height,
            m.enemy_spawn_cells.size(), bad.size(), str(bad), str(nb), str(tb), str(relic_ok), str(m.extract_cell), str(m.spawn_cells[0]), Vector2(m.spawn_cells[0]).distance_to(Vector2(m.relic_cell))])
    get_tree().quit(0)
