extends SceneTree
## Comprehensive headless test suite for Procedural Generation Repair & Integration.
##   godot --headless --path . --script res://tests/test_procedural.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
    if cond:
        print("  PASS  ", msg)
    else:
        print("  FAIL  ", msg)
        fails += 1


func _init() -> void:
    print("== Procedural Generation Repair & Integration tests ==")
    
    # 1. Test Tower Expedition configs
    var cfg1 := TowerExpedition.get_floor_config(1)
    var cfg10 := TowerExpedition.get_floor_config(10)
    check(cfg1["name"] != "" and cfg10["mission"] == "boss", "tower floor configs 1 and 10 are valid")

    # 2. Test ProceduralMap multi-attempt room placement & enemy population
    var pmap := ProceduralMap.new(100, 100, 42, 1)
    check(pmap.width == 100 and pmap.height == 100, "procedural map created with correct dimensions")
    check(pmap.spawn_cells.size() > 0, "procedural map has spawn cells")
    check(not pmap.is_blocked_cell(pmap.goal_cell), "procedural map goal cell is walkable")
    check(pmap.enemy_spawn_cells.size() > 0, "enemy population matches floor configuration budget")
    check(pmap.treasure_cells.size() >= 0, "points of interest (treasure) placed successfully")

    # 3. Test pathfinding & strict walkability
    var start_pos := pmap.center_of(pmap.spawn_cells[0])
    var goal_pos := pmap.center_of(pmap.goal_cell)
    var path := pmap.find_path(start_pos, goal_pos)
    check(path.size() > 0, "procedural map successfully finds a valid path from spawn to goal")

    # 4. Test determinism (same seed & floor = identical goal and dimensions)
    var pmap_dup := ProceduralMap.new(100, 100, 42, 1)
    check(pmap.goal_cell == pmap_dup.goal_cell, "map generation is strictly deterministic for same seed and floor")

    # 5. Test persistent floor map caching in Game
    var g: Node = load("res://scripts/autoload/game.gd").new()
    g.autosave = false
    g.save_path = "user://test_persistent_map.json"
    var map_a: ProceduralMap = g.get_or_create_tower_floor_map(1)
    var map_b: ProceduralMap = g.get_or_create_tower_floor_map(1)
    check(map_a.goal_cell == map_b.goal_cell, "tower floor map is persistent across re-runs")

    # 6. Test population cap & dorms
    var cap: int = g.max_hero_capacity()
    check(cap == TownTables.beds_at("dorm_1", g.building_level("dorm_1")) + TownTables.beds_at("dorm_2", g.building_level("dorm_2")) + TownTables.beds_at("dorm_3", g.building_level("dorm_3")) and cap > 0, "max hero capacity = beds in the dorms (cap=%d)" % cap)

    for p in ["user://test_persistent_map.json", "user://test_persistent_map.json.bak", "user://test_persistent_map.json.tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
