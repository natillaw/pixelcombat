extends Control
## Map safety (playtest B1): no walkable cell of a tower floor is out of the pathfinder's reach, floors
## saved before the fix are sealed when loaded, a push never squeezes a unit through a corner, and the
## floor objectives can be finished by a player who does not know the map (B6, D4).
##   godot --headless --path . res://tests/smoke_map_safety.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


## Walkable cells the pathfinder cannot reach from the entrance (flood fill with A*'s corner rule).
func _unreachable(m: NavMap) -> int:
    var start: Vector2i = m.spawn_cells[0]
    var reach := {start: true}
    var queue: Array[Vector2i] = [start]
    var head := 0
    while head < queue.size():
        var c: Vector2i = queue[head]
        head += 1
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
            var n: Vector2i = c + d
            if reach.has(n) or m.is_blocked_cell(n):
                continue
            if d.x != 0 and d.y != 0 and (m.is_blocked_cell(c + Vector2i(d.x, 0)) or m.is_blocked_cell(c + Vector2i(0, d.y))):
                continue
            reach[n] = true
            queue.append(n)
    var n_out := 0
    for y in m.height:
        for x in m.width:
            if not m.is_blocked_cell(Vector2i(x, y)) and not reach.has(Vector2i(x, y)):
                n_out += 1
    return n_out


func _ready() -> void:
    print("== Map safety tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_map_safety.json"

    # --- generated floors: every walkable cell is reachable ---------------------------------------
    var bad := 0
    var checked := 0
    for seed_val in [11, 222, 3333]:
        for f in range(1, 6):
            var cfg := TowerExpedition.get_floor_config(f)
            var m := ProceduralMap.new(int(cfg["width"]), int(cfg["height"]), seed_val, f)
            checked += 1
            if _unreachable(m) > 0:
                bad += 1
            for c in m.enemy_spawn_cells + m.treasure_cells:
                if m.is_blocked_cell(c):
                    bad += 1
    check(bad == 0, "no pockets and no content in sealed cells on %d generated floors" % checked)

    # --- an old snapshot with a pocket is sealed on load (the reachable layout is unchanged) -------
    var m0 := ProceduralMap.new(92, 80, 77, 1)
    var snap := m0.to_snapshot()
    var rows: Array = snap["grid_rows"]
    # carve a pocket: a free cell closed on its four sides, touching the open map only by a corner
    var pocket := Vector2i(-1, -1)
    for y in range(2, m0.height - 2):
        for x in range(2, m0.width - 2):
            var r := Vector2i(x + 1, y + 1)
            if String(rows[y])[x] == "#" and String(rows[y])[x + 1] == "#" and String(rows[y + 1])[x] == "#" \
                    and String(rows[y - 1])[x] == "#" and String(rows[y])[x - 1] == "#" and not m0.is_blocked_cell(r) \
                    and not m0.find_path(m0.center_of(r), m0.center_of(m0.spawn_cells[0])).is_empty():
                pocket = Vector2i(x, y)
                break
        if pocket.x >= 0:
            break
    check(pocket.x >= 0, "found a wall cell to turn into a corner pocket (%s)" % str(pocket))
    if pocket.x >= 0:
        rows[pocket.y] = String(rows[pocket.y]).substr(0, pocket.x) + "." + String(rows[pocket.y]).substr(pocket.x + 1)
        var loaded := ProceduralMap.from_snapshot(snap, 1)
        check(loaded.is_blocked_cell(pocket) and _unreachable(loaded) == 0, "a saved floor with a pocket is sealed when loaded")
        var open_before := 0
        var open_after := 0
        for y in m0.height:
            for x in m0.width:
                open_before += 0 if m0.is_blocked_cell(Vector2i(x, y)) else 1
                open_after += 0 if loaded.is_blocked_cell(Vector2i(x, y)) else 1
        check(open_before == open_after, "every reachable cell stays walkable (%d / %d)" % [open_after, open_before])

        # --- a push cannot squeeze through that corner ------------------------------------------
        var raw := ProceduralMap.new(92, 80, 77, 1, ProceduralMap.GEN_VERSION, false)
        raw.width = m0.width
        raw.height = m0.height
        raw.build_grid(rows)                     # the same floor without sealing
        var from := raw.center_of(pocket + Vector2i(1, 1)) + Vector2(-20, -20)
        var into := raw.center_of(pocket) + Vector2(18, 18)
        check(not raw.is_blocked(into) and not raw.can_step(from, into), "a nudge across a closed corner is refused")
        check(raw.can_step(from, from + Vector2(6, 0)), "an ordinary small nudge is allowed")

    # --- objectives a first-time player can finish (playtest B6, D4) ------------------------------
    Game.new_game()
    var sb := SandboxScreen.new(1)                   # combat: "clear the floor"
    add_child(sb)
    await get_tree().process_frame
    sb.set_physics_process(false)
    var live: Array = sb.living_enemies()
    for i in live.size() - 4:
        live[i].take_hit(DamageInfo.make(99999.0, "true", sb.heroes[0]))
    var rest: Array = sb.living_enemies()
    for e in rest:
        e.dormant = false
    check(rest.size() == 4 and sb.revealed_enemies().is_empty(), "with 4 awake creatures left nothing is marked yet")
    for e in rest:
        e.dormant = true
    check(sb.revealed_enemies().size() == 4 and sb._mission_objective().contains("marked"), "when only sleeping ambushers are left they are marked on the map")
    rest[0].dormant = false
    rest[0].take_hit(DamageInfo.make(99999.0, "true", sb.heroes[0]))
    check(sb.revealed_enemies().size() == 3, "with 3 left they are always marked")
    sb.queue_free()
    await get_tree().process_frame

    var sb2 := SandboxScreen.new(2)                  # exploration: three markers
    add_child(sb2)
    await get_tree().process_frame
    sb2.set_physics_process(false)
    var rooms := {}
    var min_gap := INF
    for i in sb2.clues.size():
        for z in (sb2.map as ProceduralMap).room_zones:
            if (z["rect"] as Rect2i).has_point(sb2.map.cell_of(sb2.clues[i].position)):
                rooms[z["rect"]] = true
        for j in range(i + 1, sb2.clues.size()):
            min_gap = minf(min_gap, sb2.clues[i].position.distance_to(sb2.clues[j].position))
    check(sb2.clues.size() == 3 and rooms.size() == 3 and min_gap > 15.0 * NavMap.CELL, "the 3 markers are in 3 different rooms, at least 15 cells apart (%.0f cells)" % (min_gap / NavMap.CELL))
    sb2.queue_free()
    await get_tree().process_frame

    var sb5 := SandboxScreen.new(5)
    add_child(sb5)
    await get_tree().process_frame
    sb5.set_physics_process(false)
    check(sb5._mission_objective() == "defeat %s" % String(TowerExpedition.get_floor_config(5)["boss_name"]), "the boss objective names the floor's boss (%s)" % sb5._mission_objective())
    # #8: the boss fights in phases (calls its warband, then enrages)
    var b: SandboxEnemy = sb5.boss
    for s in sb5.shamans:                            # D-065: shamans ward the boss; out of the way for this check
        s.take_hit(DamageInfo.make(99999.0, "true", sb5.heroes[0]))
    b.statuses.erase("warded")
    var n0 := sb5.enemies.size()
    var atk0 := b.atk
    b.take_hit(DamageInfo.make(float(b.max_hp) * 0.45, "true", sb5.heroes[0]))
    var n1 := sb5.enemies.size()
    check(b.alive and n1 == n0 + int(EnemyDefs.BOSS_PHASES[0]["adds"]) and sb5.enemies[n1 - 1].alerted, "below 60%% the boss calls its warband (+%d creatures)" % (n1 - n0))
    b.take_hit(DamageInfo.make(float(b.max_hp) * 0.3, "true", sb5.heroes[0]))
    check(b.alive and sb5.enemies.size() == n1 + int(EnemyDefs.BOSS_PHASES[1]["adds"]) and b.atk > atk0, "below 30%% it calls again and enrages (atk %d -> %d)" % [atk0, b.atk])
    b.take_hit(DamageInfo.make(1.0, "true", sb5.heroes[0]))
    check(sb5.enemies.size() == n1 + int(EnemyDefs.BOSS_PHASES[1]["adds"]), "each phase happens once")
    sb5.queue_free()
    await get_tree().process_frame

    print("== ALL PASSED ==" if fails == 0 else "== %d FAILED ==" % fails)
    get_tree().quit(0 if fails == 0 else 1)
