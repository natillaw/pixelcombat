extends SceneTree
## Overhaul LPC phase 1 (gate D-B): one picture with an LPC hero, an LPC bandit, a CraftPix creature, a
## tree, a rock, a building and a path tile over a 32 px grid, in two layouts:
##   left  = proposal D-B: 32 px grid, LPC at x1, 16 px tilesets doubled (x2, integer)
##   right = alternative: 16 px grid, LPC at x1, 16 px tilesets at x1 (characters look huge)
## Reads the vendor LPC clone and the extracted packs from the paths given in the environment.
##   LPC=<path to _vendor/lpc> PACKS=<extracted packs dir> godot --headless --path . --script res://tools/overhaul_scale_shot.gd


func _img(p: String) -> Image:
    var i := Image.load_from_file(p)
    if i == null:
        push_error("missing " + p)
        return Image.create(8, 8, false, Image.FORMAT_RGBA8)
    i.convert(Image.FORMAT_RGBA8)
    return i


## A south-facing idle frame (row 2, column 0) made of LPC layers bottom to top.
func _lpc(lpc: String, layers: Array) -> Image:
    var out := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for l in layers:
        var src := _img(lpc + "/spritesheets/" + String(l))
        out.blend_rect(src, Rect2i(0, 128, 64, 64), Vector2i.ZERO)
    return out


func _x2(i: Image) -> Image:
    var c := i.duplicate()
    c.resize(i.get_width() * 2, i.get_height() * 2, Image.INTERPOLATE_NEAREST)
    return c


func _init() -> void:
    var lpc := OS.get_environment("LPC")
    var packs := OS.get_environment("PACKS")
    var base := ["body/bodies/male/idle.png", "feet/shoes/basic/male/idle.png", "legs/pants/male/idle.png",
        "torso/clothes/longsleeve/longsleeve/male/idle.png", "head/heads/human/male/idle.png"]
    var hero := _lpc(lpc, base + ["hair/afro/adult/idle.png"])
    var bandit := _lpc(lpc, base + ["hat/cloth/hood/adult/idle.png"])
    var slime := _img(packs + "/free-slime-mobs-pixel-art-top-/PNG/Slime1/With_shadow/Slime1_Idle_with_shadow.png")
    slime = slime.get_region(Rect2i(0, 0, 64, 64))
    var tree := _img(packs + "/free-top-down-trees-pixel-art/PNG/Assets_separately/Trees/Autumn_tree1.png")
    var rock := _img(packs + "/free-rocks-and-stones-top-down/PNG/Objects_separately/Rock1_1.png")
    var house := _img(packs + "/free-fantasy-medieval-village-/PNG/Houses and Warehouses_Brick House - Level 1.png")
    var road := _img(packs + "/free-path-and-road-top-down-pi/PNG_Tiled/Road1_grass.png").get_region(Rect2i(0, 0, 48, 48))
    var w := 1600
    var h := 560
    var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
    out.fill(Color(0.36, 0.5, 0.3))
    for panel in 2:
        var ox := panel * 800
        var g := 32 if panel == 0 else 16
        for x in range(0, 800, g):
            out.fill_rect(Rect2i(ox + x, 0, 1, h), Color(0, 0, 0, 0.18))
        for y in range(0, h, g):
            out.fill_rect(Rect2i(ox, y, 800, 1), Color(0, 0, 0, 0.18))
        var tile := _x2(road) if panel == 0 else road
        for k in 6:
            out.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(ox + 20 + k * tile.get_width(), 470))
        out.blend_rect(hero, Rect2i(0, 0, 64, 64), Vector2i(ox + 40, 380))
        out.blend_rect(bandit, Rect2i(0, 0, 64, 64), Vector2i(ox + 120, 380))
        out.blend_rect(slime, Rect2i(0, 0, 64, 64), Vector2i(ox + 200, 380))
        out.blend_rect(rock, Rect2i(0, 0, 64, 64), Vector2i(ox + 280, 380))
        out.blend_rect(tree, Rect2i(0, 0, 128, 128), Vector2i(ox + 360, 316))
        out.blend_rect(house, Rect2i(0, 0, 320, 400), Vector2i(ox + 480, 44))
        out.fill_rect(Rect2i(ox + 798, 0, 4, h), Color(1, 1, 1))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/reports/overhaul"))
    out.save_png("res://docs/reports/overhaul/escala.png")
    print("RESULT escala.png %dx%d" % [w, h])
    quit(0)
