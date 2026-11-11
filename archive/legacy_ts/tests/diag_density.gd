extends SceneTree
## How full the floors are: creatures, rooms with an encounter, empty rooms in a row (walking gaps).
func _init() -> void:
    for f in range(1, 11):
        var cfg := TowerExpedition.get_floor_config(f)
        var m := ProceduralMap.new(int(cfg["width"]), int(cfg["height"]), 9000 + f, f)
        var n := 0
        for e in m.encounters:
            n += (e["members"] as Array).size()
        var rooms := m.room_zones.size()
        var busy := {}
        for e in m.encounters:
            for z in m.room_zones.size():
                if (m.room_zones[z]["rect"] as Rect2i).has_point(e["cells"][0]):
                    busy[z] = true
        var gap := 0
        var run := 0
        for z in rooms:
            run = 0 if busy.has(z) else run + 1
            gap = maxi(gap, run)
        print("RESULT floor %2d threat %3d creatures %3d rooms %2d with foes %2d longest empty run %d" % [f, int(cfg["threat"]), n, rooms, busy.size(), gap])
    quit(0)
