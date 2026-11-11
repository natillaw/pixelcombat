class_name NavMap
extends RefCounted
## Common base for every walkable mission map (fixed SandboxMap, procedural tower floors).
## Combat, enemies and map drawing take a NavMap, so any floor type works with them (F-002).
## "#" cells are solid; pathing uses AStarGrid2D on CELL-sized cells.

const CELL := 48

var width: int = 0
var height: int = 0
var grid: AStarGrid2D
var spawn_cells: Array[Vector2i] = []
var goal_cell: Vector2i = Vector2i.ZERO
var enemy_spawn_cells: Array[Vector2i] = []
var treasure_cells: Array[Vector2i] = []
var relic_cell: Vector2i = Vector2i.ZERO      # where the mission relic starts
var extract_cell: Vector2i = Vector2i.ZERO    # where the squad extracts (never the relic cell)


## Builds the A* grid from rows of "#" (wall) and "." (floor).
func build_grid(rows: Array) -> void:
    height = rows.size()
    width = String(rows[0]).length() if height > 0 else 0
    grid = AStarGrid2D.new()
    grid.region = Rect2i(0, 0, width, height)
    grid.cell_size = Vector2(CELL, CELL)
    grid.offset = Vector2(CELL, CELL) * 0.5      # path points are cell centers
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    for y in height:
        var row := String(rows[y])
        for x in width:
            if row[x] == "#":
                grid.set_point_solid(Vector2i(x, y), true)


## True when a unit at `from` may be placed at `to` by a push, a nudge or a steering step: `to` is not a
## wall, and a move into a diagonal cell does not slip through a gap between two diagonal walls (both
## side cells solid: a closed corner, the only way into a pocket). Rounding an ordinary corner (one side
## cell solid) stays allowed, or creatures chasing along smoothed paths would stall at every bend.
func can_step(from: Vector2, to: Vector2) -> bool:
    if is_blocked(to):
        return false
    var a := cell_of(from)
    var b := cell_of(to)
    var d := b - a
    if absi(d.x) > 1 or absi(d.y) > 1:
        return has_line_of_sight(from, to)
    if d.x != 0 and d.y != 0:
        return not (is_blocked_cell(Vector2i(b.x, a.y)) and is_blocked_cell(Vector2i(a.x, b.y)))
    return true


## Walkable cells the pathfinder cannot reach from `from_cell` become solid ("#"). Map generation
## leaves a few such pockets (tree clumps closing a corner); a unit pushed into one could never walk
## out (B1 of the playtest report). Returns how many cells were sealed. `rows` (optional) is updated too.
func seal_unreachable(from_cell: Vector2i, rows: Array = []) -> int:
    if grid == null or is_blocked_cell(from_cell):
        return 0
    var reach := {from_cell: true}
    var queue: Array[Vector2i] = [from_cell]
    var head := 0
    while head < queue.size():
        var c: Vector2i = queue[head]
        head += 1
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
            var n: Vector2i = c + d
            if reach.has(n) or is_blocked_cell(n):
                continue
            if d.x != 0 and d.y != 0 and (is_blocked_cell(c + Vector2i(d.x, 0)) or is_blocked_cell(c + Vector2i(0, d.y))):
                continue
            reach[n] = true
            queue.append(n)
    var sealed := 0
    for y in height:
        for x in width:
            var c := Vector2i(x, y)
            if not reach.has(c) and not grid.is_point_solid(c):
                grid.set_point_solid(c, true)
                sealed += 1
                if y < rows.size():
                    var row := String(rows[y])
                    rows[y] = row.substr(0, x) + "#" + row.substr(x + 1)
    return sealed


func world_size() -> Vector2:
    return Vector2(width, height) * CELL


func cell_of(world: Vector2) -> Vector2i:
    return Vector2i(floori(world.x / CELL), floori(world.y / CELL))


func center_of(cell: Vector2i) -> Vector2:
    return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_blocked_cell(cell: Vector2i) -> bool:
    return not in_bounds(cell) or grid.is_point_solid(cell)


func is_blocked(world: Vector2) -> bool:
    return is_blocked_cell(cell_of(world))


## Closest walkable cell center to a world point (searches outward in rings).
func nearest_walkable(world: Vector2) -> Vector2:
    var c := cell_of(world)
    c = Vector2i(clampi(c.x, 0, width - 1), clampi(c.y, 0, height - 1))
    if not is_blocked_cell(c):
        return world if not is_blocked(world) else center_of(c)
    for r in range(1, maxi(width, height)):
        var best := Vector2.ZERO
        var best_d := INF
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if maxi(absi(dx), absi(dy)) != r:
                    continue
                var n := c + Vector2i(dx, dy)
                if is_blocked_cell(n):
                    continue
                var d := center_of(n).distance_to(world)
                if d < best_d:
                    best_d = d
                    best = center_of(n)
        if best_d < INF:
            return best
    return center_of(c)


## True when no solid cell lies on the straight segment a -> b (ranged attacks need it).
func has_line_of_sight(a: Vector2, b: Vector2) -> bool:
    var dist := a.distance_to(b)
    var steps := maxi(1, ceili(dist / 12.0))
    for i in range(1, steps):
        if is_blocked(a.lerp(b, float(i) / float(steps))):
            return false
    return true


## Path of world waypoints from a to b (b is snapped to a walkable cell). Empty if unreachable.
func find_path(a: Vector2, b: Vector2) -> Array[Vector2]:
    var out: Array[Vector2] = []
    var start := cell_of(nearest_walkable(a))
    var goal := cell_of(nearest_walkable(b))
    if is_blocked_cell(start) or is_blocked_cell(goal):
        return out
    var pts := grid.get_point_path(start, goal)
    for i in pts.size():
        if i == 0 and pts.size() > 1:
            continue          # we are already standing in the first cell
        out.append(pts[i])
    # land on the exact requested spot (formation offsets) when it is walkable
    if not out.is_empty() and not is_blocked(b) and cell_of(b) == goal:
        out[out.size() - 1] = b
    return smooth_path(a, out)


## Clearance kept from walls when a path cuts a corner (about a body width).
const PATH_CLEARANCE := 12.0


## Grid paths zig-zag along cell centres (8 directions). Drops every waypoint that can be skipped with a
## clear, body-wide straight line from the last kept point, so units walk straight and turn only at real
## corners. The last waypoint (the destination) is always kept.
func smooth_path(from: Vector2, pts: Array[Vector2]) -> Array[Vector2]:
    if pts.size() < 2:
        return pts
    var out: Array[Vector2] = []
    var anchor := from
    var i := 0
    while i < pts.size():
        var j := pts.size() - 1
        while j > i and not _clear_lane(anchor, pts[j]):
            j -= 1
        out.append(pts[j])
        anchor = pts[j]
        i = j + 1
    return out


func _clear_lane(a: Vector2, b: Vector2) -> bool:
    var side := (b - a).normalized().orthogonal() * PATH_CLEARANCE
    return has_line_of_sight(a, b) and has_line_of_sight(a + side, b + side) and has_line_of_sight(a - side, b - side)         and not is_blocked(b + side) and not is_blocked(b - side)
