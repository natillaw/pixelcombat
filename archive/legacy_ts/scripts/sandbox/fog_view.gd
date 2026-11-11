class_name FogView
extends Node2D
## Draws a FogMap over the mission world: ONE small image (one pixel per cell) stretched over the map
## with linear filtering, so the fog has soft edges and costs a single draw call, whatever the map size.
## Never explored = opaque dark; explored = dimmed; visible = clear.

const NEVER_COLOR := Color(0.03, 0.04, 0.05, 1.0)
const SEEN_COLOR := Color(0.03, 0.04, 0.06, 0.55)

var fog: FogMap
var _img: Image
var _tex: ImageTexture


func _init(p_fog: FogMap = null) -> void:
    fog = p_fog
    z_index = 40                      # above units and effects, below floating texts (50)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func refresh() -> void:
    if fog == null:
        return
    if _img == null:
        _img = Image.create(fog.width, fog.height, false, Image.FORMAT_RGBA8)
        fog.full_redraw = true
    if fog.full_redraw:
        for y in fog.height:
            for x in fog.width:
                _img.set_pixel(x, y, _color(fog.state[y * fog.width + x]))
        fog.full_redraw = false
    else:
        for i in fog.dirty:                  # only the cells that changed since the last update
            _img.set_pixel(i % fog.width, i / fog.width, _color(fog.state[i]))
    fog.dirty.clear()
    if _tex == null:
        _tex = ImageTexture.create_from_image(_img)
    else:
        _tex.update(_img)
    fog.changed = false
    queue_redraw()


static func _color(s: int) -> Color:
    return NEVER_COLOR if s == FogMap.NEVER else (SEEN_COLOR if s == FogMap.SEEN else Color(0, 0, 0, 0))


func _draw() -> void:
    if _tex != null:
        draw_texture_rect(_tex, Rect2(Vector2.ZERO, Vector2(fog.width, fog.height) * NavMap.CELL), false)
