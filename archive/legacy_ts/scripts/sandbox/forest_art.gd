class_name ForestArt
extends RefCounted
## Bakes a procedural tower floor as a forest (D-031): grass clearings with tufts and flowers,
## dirt trails in the narrow corridors, and the solid cells as a dense wall of trees.
## Ground tiles come from Pixel Crawler; trees, bushes, rocks and flowers from ProcArt.

const TILE_DIR := AssetCatalog.PIXEL_CRAWLER_TILES
const T := 16
const GRASS := [Vector2i(2, 10), Vector2i(3, 10)]
const DIRT := Vector2i(12, 10)
const FOREST_FLOOR := Color(0.110, 0.204, 0.118)


static func _img(path: String) -> Image:
    if not ResourceLoader.exists(path):
        return null
    var tex := load(path) as Texture2D
    if tex == null:
        return null
    var img := tex.get_image()
    img.convert(Image.FORMAT_RGBA8)
    return img


## A walkable cell squeezed between two solid cells (left/right or up/down) is a trail.
static func is_trail(map: NavMap, c: Vector2i) -> bool:
    var lr := map.is_blocked_cell(c + Vector2i.LEFT) and map.is_blocked_cell(c + Vector2i.RIGHT)
    var ud := map.is_blocked_cell(c + Vector2i.UP) and map.is_blocked_cell(c + Vector2i.DOWN)
    return lr or ud


## D-115 (pista C): the last few baked floors are kept, so going back into a floor (or retrying it) does
## not bake the whole map again (the hitch when entering a floor).
const BAKE_CACHE_MAX := 3
static var _bake_cache: Dictionary = {}
static var _bake_order: Array = []


static var _tall_cache: Dictionary = {}


## Tall props of the last bake of this floor (Y-sorted sprites, see BosqueArt.prop_sprites).
static func tall_props(map: NavMap, art_seed: int, camps: bool = false) -> Array:
    bake(map, art_seed, camps)
    return _tall_cache.get(_key(map, art_seed, camps), [])


static func _key(map: NavMap, art_seed: int, camps: bool) -> String:
    return "%d|%s|%dx%d|%d" % [art_seed, camps, map.width, map.height, _grid_hash(map)]


static func bake(map: NavMap, art_seed: int, camps: bool = false) -> Texture2D:
    var key := _key(map, art_seed, camps)
    if _bake_cache.has(key):
        return _bake_cache[key]
    var tall: Array = []
    var t := _bake_uncached(map, art_seed, camps, tall)
    if t != null:
        _bake_cache[key] = t
        _tall_cache[key] = tall
        _bake_order.append(key)
        while _bake_order.size() > BAKE_CACHE_MAX:
            var old: String = _bake_order.pop_front()
            _bake_cache.erase(old)
            _tall_cache.erase(old)
    return t


static func _grid_hash(map: NavMap) -> int:
    var h := 0
    for y in map.height:
        for x in map.width:
            if map.is_blocked_cell(Vector2i(x, y)):
                h = (h * 31 + x * 7 + y * 13) & 0x7fffffff
    return h


static func _bake_uncached(map: NavMap, art_seed: int, camps: bool, tall: Array = []) -> Texture2D:
    if BosqueArt.available():                       # master prompt G: the owner's forest tileset
        var t := BosqueArt.bake(map, art_seed, camps, tall)
        if t != null:
            return t
    if CazArt.available():
        return bake_caz(map, art_seed)
    return bake_fallback(map, art_seed)


## Forest drawn with Caz's tiles: grass variants, dirt trails, flowers/bushes/rocks/stumps/logs in
## clearings, and a dense wall of Caz trees (big and small, a few dead ones) on every solid cell.
static func bake_caz(map: NavMap, art_seed: int) -> Texture2D:
    var cell := NavMap.CELL
    var out := Image.create(map.width * cell, map.height * cell, false, Image.FORMAT_RGBA8)
    var r := RandomNumberGenerator.new()
    r.seed = art_seed
    for y in map.height:
        for x in map.width:
            var c := Vector2i(x, y)
            var area := Rect2i(c * cell, Vector2i(cell, cell))
            if map.is_blocked_cell(c):
                CazArt.fill_tiles(out, area, CazArt.GRASS, r)
                out.fill_rect(area, Color(0.05, 0.12, 0.06, 0.55))      # shade under the canopy
            elif is_trail(map, c):
                CazArt.fill_tiles(out, area, CazArt.DIRT, r)
            else:
                CazArt.fill_tiles(out, area, CazArt.GRASS, r)
    # clearing decor (never blocks movement)
    for y in map.height:
        for x in map.width:
            var c := Vector2i(x, y)
            if map.is_blocked_cell(c) or is_trail(map, c):
                continue
            var feet := c * cell + Vector2i(r.randi_range(10, 38), r.randi_range(20, 44))
            var roll := r.randf()
            if roll < 0.10:
                CazArt.blit_feet(out, CazArt.image(CazArt.FLOWER), feet)
            elif roll < 0.15:
                CazArt.blit_feet(out, CazArt.pick(CazArt.BUSHES, r), feet)
            elif roll < 0.18:
                CazArt.blit_feet(out, CazArt.pick(CazArt.ROCKS, r), feet)
            elif roll < 0.195:
                CazArt.blit_feet(out, CazArt.pick(CazArt.STUMPS, r), feet)
            elif roll < 0.205:
                CazArt.blit_feet(out, CazArt.image(CazArt.LOG), feet)
    # tree wall, top to bottom so nearer trees overlap farther ones
    for y in range(-1, map.height + 1):
        for x in range(-1, map.width + 1):
            var c := Vector2i(x, y)
            if map.in_bounds(c) and not map.is_blocked_cell(c):
                continue
            var open_south := map.in_bounds(c + Vector2i.DOWN) and not map.is_blocked_cell(c + Vector2i.DOWN)
            var count := 1 if open_south else 2
            for k in count:
                var roll := r.randf()
                var tree: Image
                if roll < 0.06:
                    tree = CazArt.pick(CazArt.DEAD_TREES, r)
                elif roll < 0.30:
                    tree = CazArt.pick(CazArt.SMALL_TREES, r)
                else:
                    tree = CazArt.pick(CazArt.BIG_TREES, r)
                var feet := c * cell + Vector2i(r.randi_range(6, 42), (44 if open_south else r.randi_range(14, 46)) - k * 18)
                CazArt.blit_feet(out, tree, feet)
    out.convert(Image.FORMAT_RGB8)                  # the ground is opaque: 25% less memory on big floors
    return ImageTexture.create_from_image(out)


static func bake_fallback(map: NavMap, art_seed: int) -> Texture2D:
    var fl := _img(TILE_DIR + "Floors_Tiles.png")
    var cell := NavMap.CELL
    var out := Image.create(map.width * cell, map.height * cell, false, Image.FORMAT_RGBA8)
    var r := RandomNumberGenerator.new()
    r.seed = art_seed
    var sz := Vector2i(T, T)
    # 1. ground
    for y in map.height:
        for x in map.width:
            var c := Vector2i(x, y)
            var o := c * cell
            if map.is_blocked_cell(c):
                out.fill_rect(Rect2i(o, Vector2i(cell, cell)), FOREST_FLOOR)
                continue
            var trail := is_trail(map, c)
            for sy in 3:
                for sx in 3:
                    var dst := o + Vector2i(sx, sy) * T
                    if fl == null:
                        out.fill_rect(Rect2i(dst, sz), Color8(150, 105, 60) if trail else Color8(60, 120, 50))
                    else:
                        var t: Vector2i = DIRT if trail else GRASS[r.randi() % GRASS.size()]
                        out.blend_rect(fl, Rect2i(t * T, sz), dst)
            if not trail:
                ProcArt.stamp_tufts(out, o, r)
                if r.randf() < 0.18:
                    ProcArt.stamp_flowers(out, o + Vector2i(r.randi_range(4, 30), r.randi_range(4, 30)), r)
    # 2. small decor on open ground (never blocks movement)
    for y in map.height:
        for x in map.width:
            var c := Vector2i(x, y)
            if map.is_blocked_cell(c) or is_trail(map, c):
                continue
            var roll := r.randf()
            var o := c * cell + Vector2i(r.randi_range(4, 26), r.randi_range(8, 30))
            if roll < 0.04:
                _blit(out, ProcArt.bush(r.randi() % 2), o)
            elif roll < 0.07:
                _blit(out, ProcArt.rock(0), o)
    # 3. tree wall, top to bottom so lower trees overlap the ones behind
    for y in range(-1, map.height):
        for x in map.width:
            var c := Vector2i(x, y)
            if y >= 0 and not map.is_blocked_cell(c):
                continue
            # trees on the edge of a clearing keep their trunk inside the solid cell
            var open_south := y + 1 < map.height and not map.is_blocked_cell(c + Vector2i.DOWN)
            for k in (1 if open_south else 2):
                var img := ProcArt.tree([0, 0, 1, 2][r.randi() % 4])
                var p := c * cell + Vector2i(r.randi_range(-8, 24), r.randi_range(-14, 10) + k * 18) - Vector2i(0, 8)
                _blit(out, img, p)
    out.convert(Image.FORMAT_RGB8)                  # the ground is opaque: 25% less memory on big floors
    return ImageTexture.create_from_image(out)


static func _blit(dst: Image, src: Image, at: Vector2i) -> void:
    dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
