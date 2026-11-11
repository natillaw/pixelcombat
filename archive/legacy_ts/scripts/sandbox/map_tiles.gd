class_name MapTiles
extends RefCounted
## T-025: bakes the fixed sandbox map into ONE texture from Pixel Crawler tiles (16 px, native
## scale). One logic cell (NavMap.CELL = 48) = 3x3 tiles, so pathing/collision stay unchanged.
## Floor = cobble. Wall = flat top; a wall with floor to its south shows the cliff face instead.
## Floor cells under a wall get a soft shadow. Returns null when the art is not installed.

const DIR := AssetCatalog.PIXEL_CRAWLER_TILES
const T := 16
const SUB := 3
const FLOOR := Vector2i(7, 10)          # Floors_Tiles.png (col, row)
const WALL_TOP := Vector2i(9, 3)        # Wall_Tiles.png
const FACE_COL := 9
const FACE_ROW := 6                     # rows 6,7,8 = three sub-rows of the cliff face


static func available() -> bool:
    return ResourceLoader.exists(DIR + "Floors_Tiles.png") and ResourceLoader.exists(DIR + "Wall_Tiles.png")


static func _img(file: String) -> Image:
    var tex := load(DIR + file) as Texture2D
    if tex == null:
        return null
    var img := tex.get_image()
    if img != null:
        img.convert(Image.FORMAT_RGBA8)
    return img


static func _is_wall(map: NavMap, x: int, y: int) -> bool:
    var c := Vector2i(x, y)
    return not map.in_bounds(c) or map.is_blocked_cell(c)


static func bake(map: NavMap) -> Texture2D:
    if not available():
        return null
    var fl := _img("Floors_Tiles.png")
    var wl := _img("Wall_Tiles.png")
    if fl == null or wl == null:
        return null
    var cell := NavMap.CELL
    var out := Image.create(map.width * cell, map.height * cell, false, Image.FORMAT_RGBA8)
    var shade := Image.create(cell, 12, false, Image.FORMAT_RGBA8)
    shade.fill(Color(0, 0, 0, 0.27))
    var sz := Vector2i(T, T)
    for y in map.height:
        for x in map.width:
            var wall := _is_wall(map, x, y)
            var south_floor := not _is_wall(map, x, y + 1)
            for sy in SUB:
                for sx in SUB:
                    var dst := Vector2i(x * cell + sx * T, y * cell + sy * T)
                    if wall:
                        var c := WALL_TOP
                        if south_floor:
                            c = Vector2i(FACE_COL, FACE_ROW + sy)
                        out.blend_rect(wl, Rect2i(c * T, sz), dst)
                    else:
                        out.blend_rect(fl, Rect2i(FLOOR * T, sz), dst)
            if not wall and _is_wall(map, x, y - 1):
                out.blend_rect(shade, Rect2i(0, 0, cell, 12), Vector2i(x * cell, y * cell))
    return ImageTexture.create_from_image(out)
