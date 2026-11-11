class_name BosqueArt
extends RefCounted
## Master prompt G + I (2026-10-31): bakes a tower floor with the owner's forest tileset and props.
##   - Ground: Match Corners terrain (0 grass, 1 dirt, 2 water) on a 16 px vertex grid. A vertex takes
##     the terrain of the cell under a noise-jittered point, so borders are organic, never rectangles.
##     Dirt and water never touch (no transition tiles): a water vertex next to dirt becomes grass.
##   - Grass variants with low probability; decor in clusters (flowers, tufts, stones), not uniform.
##   - Solid cells are a dense wall of mixed trees, Y-sorted, every tree with an elliptic shadow; the
##     ground under the canopy is darkened and edge trees lean into the clearing.
##   - Bandit floors show their base: camps (tent, palisade, crates, banner, campfire) in deep rooms.
## Deterministic per floor seed. Numbers are art tuning, kept here.

const TILES := "res://assets/tiles/bosque/bosque_tiles.png"
const PROPS := "res://assets/tiles/bosque/bosque_props.png"
const PROPS_JSON := "res://assets/tiles/bosque/bosque_tileset.json"
const CAMP := "res://assets/props/campamento/props_campamento.png"
const CAMP_JSON := "res://assets/props/campamento/bandidos.json"
const FIRE := "res://assets/props/campamento/prop_fogata_anim.png"
const T := 16
const SUB := 3                                   # NavMap.CELL (48) / T
const GRASS_VARIANT_P := 0.06                    # per variant (4 of them)
const FULL_VARIANT_P := 0.15                     # dirt / water variants
const JITTER := 1.3                              # vertex jitter, in tiles
const POND_NOISE := 0.42                         # solid areas above this noise become ponds
const CLUSTER_P := 0.05                          # an open cell starts a decor cluster
const SINGLE_P := 0.012                          # a lone big prop (log, stump, big rock, berry bush)
const CANOPY_SHADE := Color(0.03, 0.08, 0.04, 0.45)
const BIG_TREES := ["roble_grande_a", "roble_grande_b", "pino_grande"]
const MID_TREES := ["roble_mediano", "pino_chico", "arbol_joven"]
const CLUSTERS := [["flores_blancas"], ["flores_moradas"], ["flores_rosas"], ["flores_amarillas"],
    ["mata_a", "mata_b", "mata_c"], ["roca_chica", "roca_mediana"], ["hongos", "helecho"], ["arbusto_chico", "arbusto"]]
const SINGLES := ["tronco_caido", "tocon", "roca_grande", "arbusto_bayas"]
const CAMP_SET := ["tienda", "empalizada", "empalizada", "caja", "barril", "estandarte", "saco_botin", "saco_dormir", "armero", "carreta"]
const MAX_CAMPS := 2

static var _defs: Dictionary = {}
## Overhaul (owner: mix the packs): CraftPix trees, bushes and rocks join the owner's props, at x1
## (the LPC characters are drawn at half size, so all of these read x2 against them). Shadows included.
const PACK_TREES := ["res://assets/pixel/packs/trees/PNG/Assets_separately/Trees/", "^(Tree|Moss_tree|Fruit_tree)"]
const PACK_BUSHES := ["res://assets/pixel/packs/bushes/PNG/Assets_shadow/", "^(Bush|Fern|Leaf|Grass|Flower)"]
const PACK_ROCKS := ["res://assets/pixel/packs/rocks2/PNG/Objects_separately/", "^Rock[0-9]+_[0-9]+[.]png$"]
const PACK_TREE_P := 0.3                 # share of forest trees taken from the packs
const PACK_DECOR_P := 0.35               # share of decor clusters made of pack bushes / rocks
static var _pack_cache: Dictionary = {}


static func pack_images(spec: Array) -> Array:
    var key := String(spec[0]) + String(spec[1])
    if _pack_cache.has(key):
        return _pack_cache[key]
    var out: Array = []
    var re := RegEx.create_from_string(String(spec[1]))
    for f in DirAccess.get_files_at(String(spec[0])):
        if f.ends_with(".png") and re.search(f) != null:
            var img := _img(String(spec[0]) + f)
            if img != null:
                out.append(img)
    _pack_cache[key] = out
    return out


## A pack sprite with its bottom-centre on feet (their shadows are part of the picture).
static func blit_pack(dst: Image, img: Image, feet: Vector2i) -> void:
    var used := img.get_used_rect()
    dst.blend_rect(img, used, feet - Vector2i(used.size.x / 2, used.size.y - 2))


static func available() -> bool:
    return ResourceLoader.exists(TILES) and ResourceLoader.exists(PROPS) and FileAccess.file_exists(PROPS_JSON)


static func _json(path: String) -> Dictionary:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return {}
    var d = JSON.parse_string(f.get_as_text())
    return d if d is Dictionary else {}


static func _img(path: String) -> Image:
    var tex := load(path) as Texture2D
    if tex == null:
        return null
    var img := tex.get_image()
    if img.is_compressed():
        img.decompress()
    img.convert(Image.FORMAT_RGBA8)
    return img


static func defs() -> Dictionary:
    if _defs.is_empty():
        _defs = {"props": _json(PROPS_JSON).get("props", {}), "camp": _json(CAMP_JSON).get("props", {})}
    return _defs


## Camp centres (world px) on a bandit floor: the centres of up to MAX_CAMPS deep rooms.
static func camp_spots(map: NavMap, art_seed: int) -> Array:
    var out: Array = []
    if not (map is ProceduralMap):
        return out
    var rooms: Array = (map as ProceduralMap).room_zones.filter(func(z): return String(z["zone"]) in ["danger", "explore"])
    var r := RandomNumberGenerator.new()
    r.seed = art_seed + 77
    while out.size() < MAX_CAMPS and not rooms.is_empty():
        var z: Dictionary = rooms.pop_at(r.randi() % rooms.size())
        var c: Vector2i = (z["rect"] as Rect2i).get_center()
        if not map.is_blocked_cell(c):
            out.append(map.center_of(c))
    return out


## Props tall enough for a unit to walk behind (owner 2026-11-02: "le paso por encima a rocas y troncos").
## They are not baked into the ground: bake() lists them in `tall_out` and the floor makes Y-sorted sprites.
const TALL := ["roble_grande_a", "roble_grande_b", "pino_grande", "roble_mediano", "pino_chico", "arbol_joven",
    "juncos", "altar", "menhir", "menhir_runa", "roca_grande", "arbusto", "tronco_caido", "tocon", "arbusto_bayas",
    "roca_mediana", "arbusto_chico", "helecho"]
const TALL_PACK_H := 18                  # a pack sprite this tall (px) or more is a Y-sorted prop
const SPRITE_DEPTH := 3                  # solid cells further than this from open ground stay baked (no one walks there)


static func bake(map: NavMap, art_seed: int, camps: bool = false, tall_out = null) -> Texture2D:
    var tiles := _img(TILES)
    var props := _img(PROPS)
    if tiles == null or props == null:
        return null
    var w := map.width * SUB
    var h := map.height * SUB
    var out := Image.create(w * T, h * T, false, Image.FORMAT_RGBA8)
    var r := RandomNumberGenerator.new()
    r.seed = art_seed
    var nx := FastNoiseLite.new()
    nx.seed = art_seed
    nx.frequency = 0.21
    var ny := FastNoiseLite.new()
    ny.seed = art_seed + 1
    ny.frequency = 0.21
    var pond := FastNoiseLite.new()
    pond.seed = art_seed + 2
    pond.frequency = 0.08
    # 1) terrain per cell, then per jittered vertex
    var cell_t := {}
    for y in map.height:
        for x in map.width:
            var c := Vector2i(x, y)
            if map.is_blocked_cell(c):
                cell_t[c] = 2 if pond.get_noise_2d(x, y) > POND_NOISE and _interior(map, c) else 0
            elif ForestArt.is_trail(map, c):
                cell_t[c] = 1
            else:
                cell_t[c] = 0
    var vert := PackedByteArray()
    vert.resize((w + 1) * (h + 1))
    for vy in h + 1:
        for vx in w + 1:
            var q := Vector2(vx, vy) + Vector2(nx.get_noise_2d(vx, vy), ny.get_noise_2d(vx, vy)) * JITTER
            var c := Vector2i(clampi(floori(q.x / SUB), 0, map.width - 1), clampi(floori(q.y / SUB), 0, map.height - 1))
            vert[vy * (w + 1) + vx] = int(cell_t.get(c, 0))
    for vy in h + 1:                                 # no dirt next to water: one grass tile between them
        for vx in w + 1:
            if vert[vy * (w + 1) + vx] != 2:
                continue
            for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
                var px: int = vx + d.x
                var py: int = vy + d.y
                if px >= 0 and py >= 0 and px <= w and py <= h and vert[py * (w + 1) + px] == 1:
                    vert[vy * (w + 1) + vx] = 0
                    break
    # 2) ground tiles (Match Corners: index = TL*1 + TR*2 + BL*4 + BR*8)
    for ty in h:
        for tx in w:
            var k := [vert[ty * (w + 1) + tx], vert[ty * (w + 1) + tx + 1], vert[(ty + 1) * (w + 1) + tx], vert[(ty + 1) * (w + 1) + tx + 1]]
            var other := 0
            for v in k:
                other = maxi(other, int(v))
            var at := Vector2i(0, 0)
            if other == 0:
                var roll := r.randf()
                if roll < GRASS_VARIANT_P * 4.0:
                    at = Vector2i(8 + int(roll / GRASS_VARIANT_P) % 4, 0)
            else:
                var idx := 0
                for i in 4:
                    if int(k[i]) == other:
                        idx |= 1 << i
                var origin := Vector2i(0, 0) if other == 1 else Vector2i(4, 0)
                at = origin + Vector2i(idx % 4, idx / 4)
                if idx == 15 and r.randf() < FULL_VARIANT_P * 2.0:
                    at = Vector2i(8 + r.randi() % 2, other)
            out.blit_rect(tiles, Rect2i(at * T, Vector2i(T, T)), Vector2i(tx, ty) * T)
    # 3) shade under the canopy
    var shade := Image.create(T, T, false, Image.FORMAT_RGBA8)       # per tile, on the same jittered field
    shade.fill(CANOPY_SHADE)
    for ty in h:
        for tx in w:
            var q := Vector2(tx + 0.5, ty + 0.5) + Vector2(nx.get_noise_2d(tx + 0.5, ty + 0.5), ny.get_noise_2d(tx + 0.5, ty + 0.5)) * JITTER
            var c := Vector2i(clampi(floori(q.x / SUB), 0, map.width - 1), clampi(floori(q.y / SUB), 0, map.height - 1))
            if map.is_blocked_cell(c) and int(cell_t[c]) != 2:
                out.blend_rect(shade, Rect2i(0, 0, T, T), Vector2i(tx, ty) * T)
    # 4) props, Y-sorted (each with its shadow first)
    var draw: Array = []                             # [feet y, name, feet, source]
    var cs := NavMap.CELL
    for y in range(-1, map.height + 1):
        for x in range(-1, map.width + 1):
            var c := Vector2i(x, y)
            var solid := not map.in_bounds(c) or map.is_blocked_cell(c)
            if solid:
                if map.in_bounds(c) and int(cell_t[c]) == 2:
                    if r.randf() < 0.25:
                        draw.append(_entry("nenufar" if r.randf() < 0.7 else "nenufar_flor", c * cs + Vector2i(r.randi_range(8, 40), r.randi_range(10, 40))))
                    continue
                var edge := map.in_bounds(c + Vector2i.DOWN) and not map.is_blocked_cell(c + Vector2i.DOWN)
                for k in (2 if not edge else 1 + int(r.randf() < 0.5)):
                    var pack_trees := pack_images(PACK_TREES)
                    if not pack_trees.is_empty() and r.randf() < PACK_TREE_P:
                        draw.append([c.y * cs + 40 - k * 16, "", c * cs + Vector2i(r.randi_range(4, 44), r.randi_range(16, 46) - k * 16), "pack", "", pack_trees[r.randi() % pack_trees.size()]])
                        continue
                    var big := r.randf() < 0.6
                    var tree: String = (BIG_TREES if big else MID_TREES)[r.randi() % 3]
                    var lean := r.randi_range(0, 18) if edge else 0      # the edge invades the clearing
                    draw.append(_entry(tree, c * cs + Vector2i(r.randi_range(4, 44), r.randi_range(16, 46) + lean - k * 16), "sombra_grande" if big else "sombra_mediana"))
                continue
            if ForestArt.is_trail(map, c):
                continue
            if r.randf() < CLUSTER_P and r.randf() < PACK_DECOR_P:
                var pool: Array = pack_images(PACK_BUSHES) if r.randf() < 0.6 else pack_images(PACK_ROCKS)
                if not pool.is_empty():
                    for i in r.randi_range(1, 3):
                        var p := c * cs + Vector2i(24 + r.randi_range(-18, 18), 34 + r.randi_range(-10, 10))
                        draw.append([p.y, "", p, "pack", "", pool[r.randi() % pool.size()]])
            elif r.randf() < CLUSTER_P:
                var fam: Array = CLUSTERS[r.randi() % CLUSTERS.size()]
                var centre := c * cs + Vector2i(24, 30)
                for i in r.randi_range(3, 6):
                    var p := centre + Vector2i(r.randi_range(-22, 22), r.randi_range(-14, 14))
                    var n: String = fam[r.randi() % fam.size()]
                    draw.append(_entry(n, p, "sombra_chica" if n.begins_with("roca") or n.begins_with("arbusto") else ""))
            elif r.randf() < SINGLE_P:
                var n: String = SINGLES[r.randi() % SINGLES.size()]
                draw.append(_entry(n, c * cs + Vector2i(r.randi_range(12, 36), r.randi_range(26, 44)), "sombra_mediana"))
    if camps:
        var camp_img := _img(CAMP)
        if camp_img != null:
            for spot in camp_spots(map, art_seed):
                var base := Vector2i(spot)
                for i in CAMP_SET.size():
                    var a := TAU * float(i) / float(CAMP_SET.size()) + r.randf() * 0.3
                    var p := base + Vector2i(Vector2.RIGHT.rotated(a) * r.randf_range(46.0, 70.0))
                    draw.append([p.y, CAMP_SET[i], p, "camp", "sombra_chica"])
    draw.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
    var camp_src := _img(CAMP) if camps else null
    for e in draw:
        if String(e[4]) != "":
            _blit(out, props, defs()["props"], String(e[4]), e[2])
        if tall_out is Array and _is_tall(e) and _near_open(map, Vector2i(e[2]) / cs):
            (tall_out as Array).append(e)
            continue
        if String(e[3]) == "pack":
            blit_pack(out, e[5], e[2])
            continue
        if String(e[3]) == "camp":
            if camp_src != null:
                _blit(out, camp_src, defs()["camp"], String(e[1]), e[2])
        else:
            _blit(out, props, defs()["props"], String(e[1]), e[2])
    out.convert(Image.FORMAT_RGB8)
    return ImageTexture.create_from_image(out)


## Ground only, for any grid (the town uses it): kind_at(x, y) -> 0 grass, 1 dirt, 2 water per cell.
## Same jittered Match-Corners terrain as bake(), so paths have organic edges.
static func ground_image(w_cells: int, h_cells: int, kind_at: Callable, art_seed: int, full_variant_p: float = FULL_VARIANT_P) -> Image:
    var tiles := _img(TILES)
    var w := w_cells * SUB
    var h := h_cells * SUB
    var out := Image.create(w * T, h * T, false, Image.FORMAT_RGBA8)
    var r := RandomNumberGenerator.new()
    r.seed = art_seed
    var nx := FastNoiseLite.new()
    nx.seed = art_seed
    nx.frequency = 0.21
    var ny := FastNoiseLite.new()
    ny.seed = art_seed + 1
    ny.frequency = 0.21
    var vert := PackedByteArray()
    vert.resize((w + 1) * (h + 1))
    for vy in h + 1:
        for vx in w + 1:
            var q := Vector2(vx, vy) + Vector2(nx.get_noise_2d(vx, vy), ny.get_noise_2d(vx, vy)) * JITTER
            vert[vy * (w + 1) + vx] = int(kind_at.call(clampi(floori(q.x / SUB), 0, w_cells - 1), clampi(floori(q.y / SUB), 0, h_cells - 1)))
    for ty in h:
        for tx in w:
            var k := [vert[ty * (w + 1) + tx], vert[ty * (w + 1) + tx + 1], vert[(ty + 1) * (w + 1) + tx], vert[(ty + 1) * (w + 1) + tx + 1]]
            var other := 0
            for v in k:
                other = maxi(other, int(v))
            var at := Vector2i(0, 0)
            if other == 0:
                var roll := r.randf()
                if roll < GRASS_VARIANT_P * 4.0:
                    at = Vector2i(8 + int(roll / GRASS_VARIANT_P) % 4, 0)
            else:
                var idx := 0
                for i in 4:
                    if int(k[i]) == other:
                        idx |= 1 << i
                at = (Vector2i(0, 0) if other == 1 else Vector2i(4, 0)) + Vector2i(idx % 4, idx / 4)
                if idx == 15 and r.randf() < full_variant_p * 2.0:
                    at = Vector2i(8 + r.randi() % 2, other)
            out.blit_rect(tiles, Rect2i(at * T, Vector2i(T, T)), Vector2i(tx, ty) * T)
    return out


## A decor cluster (flowers, tufts, stones...) around a point, or a tree with its shadow.
static func decor_cluster(out: Image, centre: Vector2i, r: RandomNumberGenerator) -> void:
    var props := _img(PROPS)
    var fam: Array = CLUSTERS[r.randi() % CLUSTERS.size()]
    for i in r.randi_range(3, 6):
        var n: String = fam[r.randi() % fam.size()]
        _blit(out, props, defs()["props"], n, centre + Vector2i(r.randi_range(-22, 22), r.randi_range(-14, 14)))


static func tree(out: Image, feet: Vector2i, r: RandomNumberGenerator) -> void:
    var props := _img(PROPS)
    var big := r.randf() < 0.6
    _blit(out, props, defs()["props"], "sombra_grande" if big else "sombra_mediana", feet)
    _blit(out, props, defs()["props"], (BIG_TREES if big else MID_TREES)[r.randi() % 3], feet)


static func _is_tall(e: Array) -> bool:
    match String(e[3]):
        "camp":
            return true
        "pack":
            return (e[5] as Image).get_used_rect().size.y >= TALL_PACK_H
    return String(e[1]) in TALL


## Within SPRITE_DEPTH cells of a walkable cell (or anything in the open).
static func _near_open(map: NavMap, c: Vector2i) -> bool:
    for dy in range(-SPRITE_DEPTH, SPRITE_DEPTH + 1):
        for dx in range(-SPRITE_DEPTH, SPRITE_DEPTH + 1):
            var q := c + Vector2i(dx, dy)
            if map.in_bounds(q) and not map.is_blocked_cell(q):
                return true
    return false


static var _tex_cache: Dictionary = {}


## Y-sorted sprites for the props bake() left out (feet on the sprite position, so Y-sort is by feet).
static func prop_sprites(entries: Array) -> Node2D:
    var layer := Node2D.new()
    layer.y_sort_enabled = true
    var props_tex := load(PROPS) as Texture2D
    var camp_tex := load(CAMP) as Texture2D if ResourceLoader.exists(CAMP) else null
    var wind := Ambience.wind_material(true)
    for e in entries:
        var s := Sprite2D.new()
        s.centered = false
        s.region_enabled = true
        s.position = Vector2(e[2])
        var kind := String(e[3])
        if kind == "pack":
            var img: Image = e[5]
            var key := img.get_instance_id()
            if not _tex_cache.has(key):
                _tex_cache[key] = ImageTexture.create_from_image(img)
            var used := img.get_used_rect()
            s.texture = _tex_cache[key]
            s.region_rect = Rect2(used)
            s.offset = -Vector2(used.size.x / 2, used.size.y - 2)
            if used.size.y > 40:
                s.material = wind
        else:
            var table: Dictionary = defs()["camp" if kind == "camp" else "props"]
            var d: Dictionary = table.get(String(e[1]), {})
            if d.is_empty() or not d.has("rect"):
                continue
            var rc: Array = d["rect"]
            var o: Array = d.get("origin", [0, 0])
            s.texture = camp_tex if kind == "camp" else props_tex
            if s.texture == null:
                continue
            s.region_rect = Rect2(int(rc[0]), int(rc[1]), int(rc[2]), int(rc[3]))
            s.offset = -Vector2(int(o[0]), int(o[1]))
            if String(e[1]) in BIG_TREES or String(e[1]) in MID_TREES:
                s.material = wind
        layer.add_child(s)
    return layer


static func _entry(name: String, feet: Vector2i, shadow: String = "") -> Array:
    return [feet.y, name, feet, "props", shadow]


## A solid cell with solid cells all around (ponds stay inside the woods).
static func _interior(map: NavMap, c: Vector2i) -> bool:
    for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
        if map.in_bounds(c + d) and not map.is_blocked_cell(c + d):
            return false
    return true


## Draws prop `name` (rect + origin from its JSON) with its origin on `feet`.
static func _blit(dst: Image, src: Image, table: Dictionary, name: String, feet: Vector2i) -> void:
    var d: Dictionary = table.get(name, {})
    if d.is_empty() or not d.has("rect"):
        return
    var rc: Array = d["rect"]
    var o: Array = d.get("origin", [0, 0])
    dst.blend_rect(src, Rect2i(int(rc[0]), int(rc[1]), int(rc[2]), int(rc[3])), feet - Vector2i(int(o[0]), int(o[1])))


## Animated campfire sprites for the camps (4 frames of 16x18 at 8 fps), feet on each camp centre.
static func campfires(map: NavMap, art_seed: int) -> Array:
    var out: Array = []
    if not ResourceLoader.exists(FIRE):
        return out
    var tex := load(FIRE) as Texture2D
    var sf := SpriteFrames.new()
    sf.set_animation_speed("default", 8.0)
    for i in 4:
        var at := AtlasTexture.new()
        at.atlas = tex
        at.region = Rect2(i * 16, 0, 16, 18)
        sf.add_frame("default", at)
    for spot in camp_spots(map, art_seed):
        var s := AnimatedSprite2D.new()
        s.sprite_frames = sf
        s.centered = false
        s.offset = Vector2(-8, -16)
        s.position = spot
        s.play("default")
        out.append(s)
    return out
