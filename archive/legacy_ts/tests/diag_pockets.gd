extends Control
## Diagnostic: walkable cells the pathfinder cannot reach from the spawn ("pockets"), and how many of
## them touch a reachable cell only through a diagonal corner (a unit nudged in cannot path out).
func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://diag_pk.json"
    var total_maps := 0
    var maps_with := 0
    for run in 6:
        Game.new_game()
        for f in range(1, 6):
            var m: ProceduralMap = Game.get_or_create_tower_floor_map(f)
            total_maps += 1
            var start: Vector2i = m.spawn_cells[0]
            var reach := {start: true}
            var q: Array[Vector2i] = [start]
            var head := 0
            while head < q.size():
                var c: Vector2i = q[head]
                head += 1
                for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]:
                    var n: Vector2i = c + d
                    if reach.has(n) or m.is_blocked_cell(n):
                        continue
                    if d.x != 0 and d.y != 0 and (m.is_blocked_cell(c + Vector2i(d.x, 0)) or m.is_blocked_cell(c + Vector2i(0, d.y))):
                        continue                    # the pathfinder does not cut corners
                    reach[n] = true
                    q.append(n)
            var pockets := 0
            var corner := 0
            var sample := ""
            for y in m.height:
                for x in m.width:
                    var c := Vector2i(x, y)
                    if m.is_blocked_cell(c) or reach.has(c):
                        continue
                    pockets += 1
                    for d in [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]:
                        if reach.has(c + d):
                            corner += 1
                            if sample == "":
                                sample = str(c)
                            break
            if pockets > 0:
                maps_with += 1
            print("run %d floor %d: walkable-but-unreachable cells %d, of them touching the map only diagonally %d %s" % [run, f, pockets, corner, sample])
    print("maps with pockets: %d / %d" % [maps_with, total_maps])
    get_tree().quit(0)
