extends Control
## Sandbox checks (T-004..T-006). Run:
##   godot --headless --path . res://tests/smoke_sandbox.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Sandbox tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_sandbox.json"
    Game.new_game()
    size = Vector2(1280, 720)
    var sb := SandboxScreen.new()
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)            # the test drives the simulation by hand
    for e in sb.enemies:                     # movement suite: combat is covered by smoke_combat
        e.alive = false
        e.visible = false
    await get_tree().process_frame
    await get_tree().process_frame

    check(sb.heroes.size() == 5, "five-hero squad deployed")
    var spawn_ok := true
    for h in sb.heroes:
        if sb.map.is_blocked(h.position):
            spawn_ok = false
    check(spawn_ok, "all heroes spawn on walkable ground")
    check(sb.selected.size() == 5, "squad starts selected (G behaviour)")
    check(sb.follow_slot == -1, "starts in group view")

    # camera / selection commands
    sb.select_slot(2)
    sb.update_camera_targets()
    check(sb.selected.size() == 1 and sb.selected[0] == sb.heroes[2] and sb.follow_slot == 2, "key 3 selects hero 3 and follows it")
    check(sb.camera_target.distance_to(sb.heroes[2].position) < 80.0 and is_equal_approx(sb.camera_zoom_target, float(CameraDefs.ZOOM_STEPS[CameraDefs.ZOOM_DEFAULT])), "camera targets the focused hero (framed above the HUD, whole zoom step)")
    sb.group_view()
    sb.update_camera_targets()
    check(sb.follow_slot == -1 and sb.selected.size() == 1, "Tab returns to group view without changing selection")
    sb.select_all()
    check(sb.selected.size() == 5, "G selects the whole squad")

    # pathfinding around walls: spawn room -> exit room
    var goal := sb.map.center_of(SandboxMap.GOAL_CELL)
    var path := sb.map.find_path(sb.heroes[0].position, goal)
    # paths are smoothed (NavMap.smooth_path): what matters is that no waypoint and no segment crosses a wall
    var wp_ok := path.size() >= 1
    var cur: Vector2 = sb.heroes[0].position
    for p in path:
        if sb.map.is_blocked(p) or not sb.map.has_line_of_sight(cur, p):
            wp_ok = false
        cur = p
    check(wp_ok, "path to the far room exists and every segment avoids walls (%d waypoints)" % path.size())
    check(sb.map.is_blocked(sb.map.center_of(Vector2i(13, 3))), "test wall is solid")
    var snapped := sb.map.nearest_walkable(sb.map.center_of(Vector2i(13, 3)))
    check(not sb.map.is_blocked(snapped), "order inside a wall snaps to the nearest walkable cell")

    # move order for the whole squad + camera switching mid-walk (orders must survive)
    sb.order_move_selected(goal)
    var lens_before: Array = []
    for h in sb.heroes:
        lens_before.append(h.path.size())
    check(lens_before.all(func(n): return n > 0), "every hero received a path")
    for i in 60:
        sb.tick(1.0 / 60.0)
    sb.select_slot(1)
    sb.group_view()
    sb.select_slot(4)
    sb.group_view()
    var still_moving := sb.heroes.all(func(h): return h.is_moving())
    check(still_moving, "camera switching does not cancel or pause orders")

    var min_gap := 9999.0
    var walls_ok := true
    for i in 3600:                                    # up to 60 simulated seconds
        sb.tick(1.0 / 60.0)
        for a in sb.heroes.size():
            if sb.map.is_blocked(sb.heroes[a].position):
                walls_ok = false
        if not sb.heroes.any(func(h): return h.is_moving()) and i > 200:
            break
    for a in sb.heroes.size():
        for b in range(a + 1, sb.heroes.size()):
            min_gap = minf(min_gap, sb.heroes[a].position.distance_to(sb.heroes[b].position))
    var arrived := sb.heroes.all(func(h): return h.position.distance_to(goal) < 80.0)
    check(arrived, "whole squad reached the exit area")
    check(walls_ok, "no hero ever stood inside a wall")
    check(min_gap >= SandboxScreen.SEPARATION - 1.0, "no clumping: closest pair is %.1f px apart" % min_gap)

    # selecting a single hero only moves that hero
    sb.select_slot(0)
    var others_before: Array = sb.heroes.slice(1).map(func(h): return h.position)
    sb.order_move_selected(sb.map.center_of(Vector2i(3, 3)))
    for i in 1800:
        sb.tick(1.0 / 60.0)
    # D-053: the order goes only to the driven hero; the others are not ordered, they follow it on their own
    var moved_only_one := sb.heroes[0].position.distance_to(sb.map.center_of(Vector2i(3, 3))) < 40.0
    var others_unordered := true
    var others_near := true
    for i in 4:
        var o: SandboxHero = sb.heroes[i + 1]
        if o.order == "move" or o.is_controlled():
            others_unordered = false
        if o.alive and o.position.distance_to(sb.heroes[0].position) > o.leash() + 80.0:
            others_near = false
    check(moved_only_one and others_unordered and sb.heroes[0].is_controlled(), "order only affects the driven hero; the others stay autonomous")
    check(others_near, "autonomous squadmates keep up with the driven hero instead of standing still")
    sb.group_view()
    check(sb.controlled() == null, "Tab / group view gives control back to autonomy")

    # real mouse events through _gui_input: click select, drag-box select, right-click order
    for i in sb.heroes.size():                         # regroup so everyone is on screen
        sb.heroes[i].stop()
        sb.heroes[i].position = sb.map.center_of(SandboxMap.SPAWN_CELLS[i])
    sb.group_view()
    sb.update_camera_targets()
    sb.camera.position = sb.camera_target
    sb.camera.zoom = Vector2.ONE * sb.camera_zoom_target
    var view := Vector2(sb._viewport.size)
    var z: float = sb.camera.zoom.x
    var hero_screen: Callable = func(h): return view * 0.5 + (h.position + Vector2(0, -16) - sb.camera.position) * z
    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_LEFT
    press.pressed = true
    press.position = hero_screen.call(sb.heroes[3])
    sb._gui_input(press)
    var rel := InputEventMouseButton.new()
    rel.button_index = MOUSE_BUTTON_LEFT
    rel.pressed = false
    rel.position = press.position
    sb._gui_input(rel)
    check(sb.selected.size() == 1 and sb.selected[0] == sb.heroes[3], "left-click on a hero selects it")
    var p2 := InputEventMouseButton.new()
    p2.button_index = MOUSE_BUTTON_LEFT
    p2.pressed = true
    p2.position = Vector2(0, 0)
    sb._gui_input(p2)
    var r2 := InputEventMouseButton.new()
    r2.button_index = MOUSE_BUTTON_LEFT
    r2.pressed = false
    r2.position = view
    sb._gui_input(r2)
    check(sb.selected.size() == 5, "drag box over the whole screen selects the squad")
    var rc := InputEventMouseButton.new()
    rc.button_index = MOUSE_BUTTON_RIGHT
    rc.pressed = true
    rc.position = hero_screen.call(sb.heroes[0]) + Vector2(120, 0)
    sb._gui_input(rc)
    check(sb.heroes.all(func(h): return h.is_moving() or h.position.distance_to(sb.screen_to_world(rc.position)) < 120.0), "right-click issues a move order to the selection")

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")

    # screen -> world transform round trip
    var center_world := sb.screen_to_world(Vector2(sb._viewport.size) * 0.5)
    check(center_world.distance_to(sb.camera.position) < 1.0, "screen center maps to the camera center")

    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_sandbox.json"))
    get_tree().quit(1 if fails > 0 else 0)
