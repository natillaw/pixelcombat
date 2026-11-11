class_name TownMap
extends NavMap
## The town (D-030): a fixed, hand-placed map that is always the same. Buildings come from
## TownTables; every built building is solid and its door cell (bottom centre) is walkable.
## Unbuilt plots stay walkable (dirt) so heroes can cross them.

## Ground kinds for drawing: "#" forest edge (trees), "B" building, "p" cobble path, "d" dirt plot,
## "w" well, "." grass.
var ground: Array[String] = []
var layout: Dictionary = {}       # building id -> moved plot position (D-050)
var built_levels: Dictionary = {}  # building id -> level, as given


func _init(levels: Dictionary = {}, p_layout: Dictionary = {}) -> void:
    layout = p_layout
    built_levels = levels
    var w := TownTables.MAP_W
    var h := TownTables.MAP_H
    var cells := []
    for y in h:
        var row := []
        for x in w:
            row.append("#" if x == 0 or y == 0 or x == w - 1 or y == h - 1 else ".")
        cells.append(row)
    # main roads: one east-west avenue and one north-south street through the plaza
    for x in range(1, w - 1):
        for y in [6, 7, 13, 14]:
            cells[y][x] = "p"
    for y in range(1, h - 1):
        for x in [7, 8, 19, 20, 25]:
            cells[y][x] = "p"
    # central plaza (cobble) with a well in the middle (solid)
    for y in range(9, 12):
        for x in range(15, 20):
            cells[y][x] = "p"
    cells[10][17] = "w"
    for id in TownTables.ids():
        var plot := plot_of(id)
        var built := int(levels.get(id, TownTables.info(id)["start"])) > 0
        if not built and not layout.has(id):
            continue                  # not built and never placed: no reserved plot (free placement)
        for y in range(plot.position.y, plot.end.y):
            for x in range(plot.position.x, plot.end.x):
                cells[y][x] = "B" if built else "d"
        var door := door_of(id)
        if door.y < h - 1:
            cells[door.y][door.x] = "p"
    var nav_rows: Array = []
    for y in h:
        var s := ""
        var g := ""
        for x in w:
            var c: String = cells[y][x]
            g += c
            s += "#" if c == "#" or c == "B" or c == "w" else "."
        ground.append(g)
        nav_rows.append(s)
    build_grid(nav_rows)
    var plaza := Vector2i(17, 10)
    goal_cell = plaza + Vector2i(0, 2)
    extract_cell = goal_cell
    relic_cell = goal_cell
    for dy in range(-1, 2):
        for dx in range(-2, 3):
            if dx != 0 or dy != 0:
                spawn_cells.append(plaza + Vector2i(dx, dy))


## Building id whose footprint contains the cell ("" if none).
func plot_of(id: String) -> Rect2i:
    return TownTables.plot_at(id, layout)


func door_of(id: String) -> Vector2i:
    return TownTables.door_at(id, layout)


## A building stands on the map once it is built or its construction site was placed.
func is_placed(id: String) -> bool:
    return int(built_levels.get(id, TownTables.info(id)["start"])) > 0 or layout.has(id)


func building_at(cell: Vector2i) -> String:
    for id in TownTables.ids():
        if not is_placed(id):
            continue
        var plot := plot_of(id)
        if plot.has_point(cell):
            return id
    return ""


## Random walkable cell (deterministic for a given rng) used by wandering heroes.
func random_walkable(rng: RandomNumberGenerator) -> Vector2i:
    for i in 200:
        var c := Vector2i(rng.randi_range(1, width - 2), rng.randi_range(1, height - 2))
        if not is_blocked_cell(c):
            return c
    return goal_cell
