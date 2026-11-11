extends Control
## Diagnostic: load a stuck save and describe floor N (env STUCK_FLOOR, file user://stuck_floorN.json).
func _ready() -> void:
    var f := int(OS.get_environment("STUCK_FLOOR")) if OS.get_environment("STUCK_FLOOR") != "" else 3
    Game.autosave = false
    Game.save_path = "user://stuck_floor%d.json" % f
    Game.load_game()
    var m: ProceduralMap = Game.get_or_create_tower_floor_map(f)
    var sp := m.center_of(m.spawn_cells[0])
    print("floor %d gen %d size %dx%d spawn %s goal %s relic %s extract %s" % [f, m.gen_version, m.width, m.height, str(m.spawn_cells), str(m.goal_cell), str(m.relic_cell), str(m.extract_cell)])
    print("relic blocked %s path spawn->relic %d" % [str(m.is_blocked_cell(m.relic_cell)), m.find_path(sp, m.center_of(m.relic_cell)).size()])
    for y in range(maxi(0, m.relic_cell.y - 4), mini(m.height, m.relic_cell.y + 5)):
        print("  ", m.grid_rows[y].substr(maxi(0, m.relic_cell.x - 10), 21))
    get_tree().quit(0)
