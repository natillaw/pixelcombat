class_name BushField
extends Node2D
## D-090 bushes: walkable cells of thick undergrowth at the forest edge (CombatRules.BUSH_*). A hero inside
## one gains BUSH_STEALTH (creatures notice it later) and is drawn half see-through. Bushes never block the
## path, the sight or the shots. Seeded by the map, so a floor always has the same bushes. Art: the CraftPix
## bush pack already used for the forest decor (docs/ASSET_REGISTRY.md).

const ART_DIR := "res://assets/pixel/packs/bushes/PNG/Assets_shadow/"
const ART_SCALE := 1.0

var cells: Dictionary = {}          # Vector2i -> true
var map: NavMap = null


static func make(p_map: NavMap, seed_value: int) -> BushField:
    var b := BushField.new()
    b.map = p_map
    b.cells = generate(p_map, seed_value)
    b.z_index = 0                    # over the ground, under the units (added before them): a hero inside is drawn over it, faded
    return b


## Deterministic bush cells for a map.
static func generate(m: NavMap, seed_value: int) -> Dictionary:
    var out: Dictionary = {}
    if m == null or m.width <= 0:
        return out
    var r := RandomNumberGenerator.new()
    r.seed = hash([seed_value, m.width, m.height, "bushes"])
    var banned: Dictionary = {m.goal_cell: true, m.extract_cell: true, m.relic_cell: true}
    for c in m.spawn_cells:
        banned[c] = true
    var seeds: Array = []
    for y in range(1, m.height - 1):
        for x in range(1, m.width - 1):
            var c := Vector2i(x, y)
            if m.is_blocked_cell(c) or banned.has(c):
                continue
            var trees := 0
            for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
                if m.is_blocked_cell(c + d):
                    trees += 1
            if trees >= CombatRules.BUSH_NEAR_TREES and r.randf() < CombatRules.BUSH_CHANCE:
                seeds.append(c)
    for c in seeds:
        out[c] = true
        for k in CombatRules.BUSH_CLUSTER:
            var n: Vector2i = c + [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][r.randi() % 4]
            if not m.is_blocked_cell(n) and not banned.has(n) and m.in_bounds(n):
                out[n] = true
    return out


func has_at(world: Vector2) -> bool:
    return map != null and cells.has(map.cell_of(world))


func _ready() -> void:
    if SimMode.on or map == null:
        return
    var textures: Array = []
    if DirAccess.dir_exists_absolute(ART_DIR):
        for f in DirAccess.get_files_at(ART_DIR):
            var name := f.trim_suffix(".import")
            if name.begins_with("Bush") and name.ends_with("1.png") and not textures.has(ART_DIR + name):   # the 64 px variants
                textures.append(ART_DIR + name)
    textures.sort()
    var r := RandomNumberGenerator.new()
    r.seed = hash(cells.size())
    var keys: Array = cells.keys()
    keys.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
    for c in keys:
        var centre := map.center_of(c)
        for k in 2:                              # two clumps per cell: it reads as thick undergrowth
            var spr := Sprite2D.new()
            if textures.is_empty():
                continue
            spr.texture = load(String(textures[r.randi() % textures.size()])) as Texture2D
            if spr.texture == null:
                continue
            spr.centered = true
            spr.offset = Vector2(0, -spr.texture.get_height() * 0.35)
            spr.position = centre + Vector2(r.randf_range(-12, 12), r.randf_range(-6, 14))
            spr.scale = Vector2.ONE * ART_SCALE
            spr.flip_h = r.randf() < 0.5
            add_child(spr)
    queue_redraw()


func _draw() -> void:
    if SimMode.on or map == null or get_child_count() > 0:
        return
    for c in cells:                                 # no art found: a plain green clump (pending art)
        draw_circle(map.center_of(c) + Vector2(0, 6), 16.0, Color(0.22, 0.45, 0.2, 0.85))
