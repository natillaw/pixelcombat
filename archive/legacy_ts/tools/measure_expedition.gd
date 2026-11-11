extends SceneTree
## Expedition metrics (D-056 report): size, encounters and walking times of tower floors, generated
## with fixed seeds (never touches a save). Walking speed = a typical level-1 hero (~88 px/s).
##   godot --headless --path . --script res://tools/measure_expedition.gd

const HERO_SPEED := 88.0
const SEEDS := [11, 22, 33]


func _path_len(m: NavMap, a: Vector2, b: Vector2) -> float:
    var p := m.find_path(a, b)
    if p.is_empty():
        return -1.0
    var total := 0.0
    var cur := a
    for q in p:
        total += cur.distance_to(q)
        cur = q
    return total


func _initialize() -> void:
    for f in [1, 5, 10]:
        for sd in SEEDS:
            var t0 := Time.get_ticks_msec()
            var m := ProceduralMap.new(int(TowerExpedition.get_floor_config(f)["width"]), int(TowerExpedition.get_floor_config(f)["height"]), sd, f)
            var gen_ms := Time.get_ticks_msec() - t0
            var start := m.center_of(m.spawn_cells[0])
            var goal := m.center_of(m.goal_cell)
            var kinds := {}
            var members := 0
            var first := INF
            for e in m.encounters:
                kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
                members += (e["members"] as Array).size()
                var d := _path_len(m, start, m.center_of(e["cells"][0]))
                if d > 0.0:
                    first = minf(first, d)
            # a tour of every room in chain order (what a full exploration walks at least)
            var tour := 0.0
            var cur := start
            for z in m.room_zones:
                var c := m.center_of((z["rect"] as Rect2i).get_center())
                var d2 := _path_len(m, cur, c)
                if d2 > 0.0:
                    tour += d2
                    cur = c
            var to_goal := _path_len(m, start, goal)
            print("FLOOR %d seed %d: %dx%d cells (%dx%d px), %d rooms, %d encounters %s, %d foes; gen %d ms" % [f, sd, m.width, m.height,
                m.width * NavMap.CELL, m.height * NavMap.CELL, m.room_zones.size(), m.encounters.size(), str(kinds), members, gen_ms])
            print("   walk to first encounter %.0f s | straight to goal %.0f s | tour of all rooms %.1f min" % [first / HERO_SPEED,
                to_goal / HERO_SPEED, tour / HERO_SPEED / 60.0])
    var m1 := ProceduralMap.new(92, 80, 11, 1)
    var t1 := Time.get_ticks_msec()
    var tex := ForestArt.bake(m1, 11)
    print("BAKE floor 1: %d ms, texture %dx%d (~%.0f MB as RGBA8)" % [Time.get_ticks_msec() - t1, tex.get_width(), tex.get_height(),
        float(tex.get_width() * tex.get_height() * 4) / 1048576.0])
    quit()
