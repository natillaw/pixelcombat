class_name ProcArt
extends RefCounted
## Pixel art drawn by code at the tiles' native scale (1 px = 1 tile px, tiles are 16 px).
## Used until owner-supplied town/forest packs arrive (see docs/ASSET_REGISTRY.md). Deterministic:
## the same key always gives the same image. Results are cached.

const OUTLINE := Color(0.086, 0.149, 0.094)
const LEAF_DARK := Color(0.149, 0.329, 0.173)
const LEAF := Color(0.227, 0.463, 0.220)
const LEAF_LIGHT := Color(0.376, 0.620, 0.275)
const LEAF_TOP := Color(0.549, 0.745, 0.361)
const TRUNK := Color(0.384, 0.251, 0.149)
const TRUNK_DARK := Color(0.243, 0.157, 0.102)

static var _cache: Dictionary = {}


static func _rng(key: String) -> RandomNumberGenerator:
    var r := RandomNumberGenerator.new()
    r.seed = hash(key)
    return r


## Round-canopy tree (32 x 44) or pine (variant 2). Feet (trunk base) at (16, 41).
static func tree(variant: int) -> Image:
    var key := "tree%d" % variant
    if _cache.has(key):
        return _cache[key]
    var img := Image.create(32, 44, false, Image.FORMAT_RGBA8)
    var r := _rng(key)
    # shadow
    for y in range(38, 44):
        for x in range(4, 28):
            var dx := (x - 16.0) / 12.0
            var dy := (y - 41.0) / 3.0
            if dx * dx + dy * dy <= 1.0:
                img.set_pixel(x, y, Color(0, 0, 0, 0.28))
    # trunk
    for y in range(26, 41):
        for x in range(13, 19):
            img.set_pixel(x, y, TRUNK_DARK if x >= 17 or x == 13 else TRUNK)
    img.set_pixel(12, 40, TRUNK_DARK)
    img.set_pixel(19, 40, TRUNK_DARK)
    var inside := func(x: int, y: int) -> bool: return false
    if variant == 2:
        inside = func(x: int, y: int) -> bool:
            for tier in 3:
                var top := 2 + tier * 8
                var half := 5.0 + tier * 4.0
                if y >= top and y <= top + 12 and absf(x - 15.5) <= half * float(y - top) / 12.0:
                    return true
            return false
    else:
        var blobs := [Vector3(16, 12, 10), Vector3(9, 18, 7.5), Vector3(23, 18, 7.5), Vector3(16, 21, 8.5)]
        if variant == 1:
            blobs = [Vector3(16, 13, 11), Vector3(10, 20, 7), Vector3(22, 20, 7)]
        inside = func(x: int, y: int) -> bool:
            for b in blobs:
                var v := b as Vector3
                if Vector2(x - v.x, y - v.y).length() <= v.z:
                    return true
            return false
    for y in 32:
        for x in 32:
            if not inside.call(x, y):
                continue
            var edge: bool = not (inside.call(x - 1, y) and inside.call(x + 1, y) and inside.call(x, y - 1) and inside.call(x, y + 1))
            var c := LEAF
            var light := float(x) * -0.35 + float(y)       # light from the top-left
            if edge:
                c = OUTLINE
            elif light < 4.0:
                c = LEAF_TOP
            elif light < 10.0:
                c = LEAF_LIGHT
            elif light > 20.0:
                c = LEAF_DARK
            if not edge and r.randf() < 0.12:
                c = c.darkened(0.18) if r.randf() < 0.5 else c.lightened(0.12)
            img.set_pixel(x, y, c)
    _cache[key] = img
    return img


static func bush(variant: int) -> Image:
    var key := "bush%d" % variant
    if _cache.has(key):
        return _cache[key]
    var img := Image.create(18, 14, false, Image.FORMAT_RGBA8)
    var r := _rng(key)
    var blobs := [Vector3(6, 8, 5), Vector3(12, 8, 5), Vector3(9, 5, 4.5)]
    for y in 14:
        for x in 18:
            var n := 0
            for b in blobs:
                var v := b as Vector3
                if Vector2(x - v.x, y - v.y).length() <= v.z:
                    n += 1
            if n == 0:
                continue
            var c := LEAF_LIGHT if y < 6 else LEAF
            if y > 10:
                c = LEAF_DARK
            if r.randf() < 0.15:
                c = c.darkened(0.2)
            img.set_pixel(x, y, c)
    for i in 3:
        if variant == 1:
            img.set_pixel(4 + i * 4, 6 + (i % 2) * 3, Color8(200, 40, 50))      # berries
    _outline(img, OUTLINE)
    _cache[key] = img
    return img


static func rock(variant: int) -> Image:
    var key := "rock%d" % variant
    if _cache.has(key):
        return _cache[key]
    var img := Image.create(14, 10, false, Image.FORMAT_RGBA8)
    for y in 10:
        for x in 14:
            var dx := (x - 6.5) / 6.5
            var dy := (y - 5.5) / 4.5
            if dx * dx + dy * dy <= 1.0:
                var c := Color8(120, 120, 128) if y > 4 else Color8(160, 160, 168)
                if x > 8 and y > 5:
                    c = Color8(86, 86, 96)
                img.set_pixel(x, y, c)
    _outline(img, Color8(40, 40, 48))
    _cache[key] = img
    return img


## Tiny flower clusters stamped on grass.
static func stamp_flowers(dst: Image, origin: Vector2i, r: RandomNumberGenerator) -> void:
    var colors := [Color8(240, 230, 120), Color8(235, 120, 150), Color8(150, 170, 245), Color8(250, 250, 250)]
    var c: Color = colors[r.randi() % colors.size()]
    for i in r.randi_range(2, 4):
        var p := origin + Vector2i(r.randi_range(0, 10), r.randi_range(0, 10))
        if p.x < 1 or p.y < 2 or p.x >= dst.get_width() - 1 or p.y >= dst.get_height() - 1:
            continue
        dst.set_pixelv(p + Vector2i(0, 1), Color8(46, 100, 40))
        dst.set_pixelv(p, c)
        dst.set_pixelv(p + Vector2i(1, 0), c.darkened(0.2))


## Grass tuft/speckles so large grass areas do not look like one repeated tile.
static func stamp_tufts(dst: Image, origin: Vector2i, r: RandomNumberGenerator) -> void:
    for i in r.randi_range(3, 7):
        var p := origin + Vector2i(r.randi_range(0, 46), r.randi_range(0, 46))
        if p.x < 0 or p.y < 1 or p.x >= dst.get_width() or p.y >= dst.get_height():
            continue
        dst.set_pixelv(p, Color8(36, 92, 30))
        dst.set_pixelv(p - Vector2i(0, 1), Color8(84, 150, 52))


static func _outline(img: Image, c: Color) -> void:
    var w := img.get_width()
    var h := img.get_height()
    var src := img.duplicate() as Image
    for y in h:
        for x in w:
            if src.get_pixel(x, y).a > 0.5:
                continue
            for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                var n := Vector2i(x, y) + (d as Vector2i)
                if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and src.get_pixelv(n).a > 0.5:
                    img.set_pixel(x, y, c)
                    break


## A building seen from the front-top: shingled roof, chimney, facade with windows and door.
## style: "plaster" | "stone" | "wood". size in pixels (footprint cells * 48).
static func house(w: int, h: int, roof: Color, style: String, windows_lit: bool) -> Image:
    var key := "house_%d_%d_%s_%s_%s" % [w, h, roof.to_html(), style, windows_lit]
    if _cache.has(key):
        return _cache[key]
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    var facade := 34
    var roof_bottom := h - facade
    var roof_dark := roof.darkened(0.35)
    var roof_light := roof.lightened(0.18)
    # roof: shingle rows, lighter at the top, ridge cap, dark side edges
    img.fill_rect(Rect2i(0, 4, w, roof_bottom - 4), roof)
    var row := 0
    for y in range(6, roof_bottom, 5):
        var shade := roof_light if row < 2 else (roof if row < 5 else roof.darkened(0.12))
        img.fill_rect(Rect2i(0, y, w, 4), shade)
        img.fill_rect(Rect2i(0, y + 4, w, 1), roof_dark)
        var off := 0 if row % 2 == 0 else 4
        for x in range(off, w, 8):
            img.fill_rect(Rect2i(x, y, 1, 4), roof_dark)
        row += 1
    img.fill_rect(Rect2i(0, 4, w, 3), roof_dark.darkened(0.2))            # ridge
    img.fill_rect(Rect2i(0, 4, 2, roof_bottom - 4), roof_dark)
    img.fill_rect(Rect2i(w - 2, 4, 2, roof_bottom - 4), roof_dark)
    # chimney
    var cx := w - 30
    img.fill_rect(Rect2i(cx, 0, 10, 14), Color8(110, 104, 100))
    img.fill_rect(Rect2i(cx, 0, 10, 2), Color8(60, 56, 54))
    img.fill_rect(Rect2i(cx + 8, 2, 2, 12), Color8(78, 72, 70))
    # facade
    var wall := Color8(222, 206, 172)
    var trim := Color8(92, 62, 40)
    match style:
        "stone":
            wall = Color8(150, 146, 140)
            trim = Color8(84, 80, 78)
        "wood":
            wall = Color8(150, 104, 64)
            trim = Color8(84, 56, 34)
    img.fill_rect(Rect2i(0, roof_bottom, w, facade), wall)
    match style:
        "stone":
            for y in range(roof_bottom + 3, h - 5, 6):
                img.fill_rect(Rect2i(0, y, w, 1), trim)
                var off := 0 if ((y - roof_bottom) / 6) % 2 == 0 else 6
                for x in range(off, w, 12):
                    img.fill_rect(Rect2i(x, y - 5, 1, 5), trim)
        "wood":
            for y in range(roof_bottom + 4, h - 5, 4):
                img.fill_rect(Rect2i(0, y, w, 1), trim)
        _:
            img.fill_rect(Rect2i(0, roof_bottom + 2, w, 2), trim)
            for x in range(0, w, 24):
                img.fill_rect(Rect2i(x, roof_bottom, 3, facade - 5), trim)
            img.fill_rect(Rect2i(w - 3, roof_bottom, 3, facade - 5), trim)
    img.fill_rect(Rect2i(0, roof_bottom, w, 3), Color(0, 0, 0, 0.35))       # eave shadow
    img.fill_rect(Rect2i(0, h - 5, w, 5), Color8(108, 104, 100))            # foundation
    img.fill_rect(Rect2i(0, h - 5, w, 1), Color8(70, 66, 64))
    # door (centre) and windows
    var door := Rect2i(w / 2 - 7, h - 25, 14, 20)
    img.fill_rect(door.grow(1), Color8(50, 32, 20))
    img.fill_rect(door, Color8(120, 78, 44))
    for x in range(door.position.x + 3, door.end.x, 4):
        img.fill_rect(Rect2i(x, door.position.y, 1, door.size.y), Color8(86, 54, 30))
    img.set_pixel(door.end.x - 3, door.position.y + 11, Color8(240, 200, 90))
    var glass := Color8(250, 214, 120) if windows_lit else Color8(120, 150, 180)
    var slots := maxi(1, (w - 30) / 34)
    for i in slots * 2:
        var side := -1 if i % 2 == 0 else 1
        var k := i / 2
        var wx := w / 2 + side * (22 + k * 34) - 6
        if wx < 4 or wx + 12 > w - 4:
            continue
        var win := Rect2i(wx, roof_bottom + 9, 12, 11)
        img.fill_rect(win.grow(1), trim)
        img.fill_rect(win, glass)
        img.fill_rect(Rect2i(win.position.x + 5, win.position.y, 2, win.size.y), trim)
        img.fill_rect(Rect2i(win.position.x, win.position.y + 5, win.size.x, 1), trim)
        img.fill_rect(Rect2i(win.position.x, win.end.y + 1, win.size.x, 2), Color8(70, 130, 60))   # flower box
    _cache[key] = img
    return img


## Stone well (24 x 26).
static func well() -> Image:
    if _cache.has("well"):
        return _cache["well"]
    var img := Image.create(24, 26, false, Image.FORMAT_RGBA8)
    img.fill_rect(Rect2i(2, 12, 20, 12), Color8(140, 136, 132))
    for y in range(14, 24, 4):
        img.fill_rect(Rect2i(2, y, 20, 1), Color8(90, 86, 84))
    img.fill_rect(Rect2i(4, 12, 16, 4), Color8(40, 70, 110))
    img.fill_rect(Rect2i(3, 0, 2, 14), Color8(92, 62, 40))
    img.fill_rect(Rect2i(19, 0, 2, 14), Color8(92, 62, 40))
    img.fill_rect(Rect2i(1, 0, 22, 4), Color8(150, 60, 50))
    _outline(img, Color8(30, 26, 24))
    _cache["well"] = img
    return img


static func texture(img: Image) -> ImageTexture:
    var key := img.get_instance_id()
    if _cache.has(key):
        return _cache[key]
    var t := ImageTexture.create_from_image(img)
    _cache[key] = t
    return t
