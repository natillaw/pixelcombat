class_name FogMap
extends RefCounted
## Fog of war data (D-056), one byte per map cell, no nodes:
##   NEVER  = never seen: terrain and everything on it hidden;
##   SEEN   = explored earlier: terrain shown dimmed, but no live information (creatures are hidden);
##   VISIBLE = inside a hero's sight right now.
## Sight belongs to the heroes (radius in cells + line of sight through trees/walls), never to the
## camera: zooming out or the M overview reveal nothing. Explored cells persist per floor (pack/unpack).

const NEVER := 0
const SEEN := 1
const VISIBLE := 2

var width: int = 0
var height: int = 0
var state: PackedByteArray = PackedByteArray()
var _lit: PackedInt32Array = PackedInt32Array()    # cell indexes VISIBLE after the last update
var changed: bool = true
var dirty: PackedInt32Array = PackedInt32Array()   # cells whose state changed since the view last drew
var full_redraw: bool = true                        # the view must redraw every cell (new / unpacked)


func _init(w: int = 0, h: int = 0) -> void:
    width = w
    height = h
    state.resize(w * h)
    state.fill(NEVER)


func index(c: Vector2i) -> int:
    return c.y * width + c.x


func get_state(c: Vector2i) -> int:
    if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
        return NEVER
    return state[index(c)]


func is_visible(c: Vector2i) -> bool:
    return get_state(c) == VISIBLE


func is_explored(c: Vector2i) -> bool:
    return get_state(c) != NEVER


## viewers = [[cell: Vector2i, radius_in_cells: int], ...]. Cells lit last time fall back to SEEN.
## Returns, per viewer, how many never-seen cells it uncovered this update (scouting credit).
func update(viewers: Array, map: NavMap) -> Array:
    for i in _lit:
        state[i] = SEEN
        dirty.append(i)
    _lit.clear()
    var found: Array = []
    for v in viewers:
        found.append(0)
        var o: Vector2i = v[0]
        var r: int = v[1]
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy > r * r:
                    continue
                var c := o + Vector2i(dx, dy)
                if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
                    continue
                var i := index(c)
                if state[i] == VISIBLE:
                    continue
                if _sees(o, c, map):
                    if state[i] == NEVER:
                        found[found.size() - 1] = int(found[found.size() - 1]) + 1
                    state[i] = VISIBLE
                    _lit.append(i)
                    dirty.append(i)
    changed = true
    return found


## Grid line of sight: blocked if any cell strictly between a and b is solid (the solid cell itself
## can be seen, so the edge of the forest shows).
func _sees(a: Vector2i, b: Vector2i, map: NavMap) -> bool:
    var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
    for k in range(1, n):
        var t := float(k) / float(n)
        var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
        if map.is_blocked_cell(c):
            return false
    return true


func explored_fraction() -> float:
    var n := 0
    for s in state:
        if s != NEVER:
            n += 1
    return float(n) / float(maxi(1, state.size()))


## Explored cells as bits (8 cells per byte), base64: what the save keeps per floor.
func pack() -> String:
    var bytes := PackedByteArray()
    bytes.resize((state.size() + 7) / 8)
    for i in state.size():
        if state[i] != NEVER:
            bytes[i / 8] = bytes[i / 8] | (1 << (i % 8))
    return Marshalls.raw_to_base64(bytes)


func unpack(text: String) -> void:
    if text == "":
        return
    var bytes := Marshalls.base64_to_raw(text)
    for i in mini(state.size(), bytes.size() * 8):
        if bytes[i / 8] & (1 << (i % 8)):
            state[i] = SEEN
    changed = true
    full_redraw = true
