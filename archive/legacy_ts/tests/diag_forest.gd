extends SceneTree
## Master prompt G: bakes floors with the owner's forest tileset and saves a crop of each for review.
##   godot --headless --path . --script res://tests/diag_forest.gd   -> tests/out/forest_floor<N>.png
func _init() -> void:
    for f in [1, 5, 10]:
        var cfg := TowerExpedition.get_floor_config(f)
        var m := ProceduralMap.new(int(cfg["width"]), int(cfg["height"]), 4242 + f, f)
        var t0 := Time.get_ticks_msec()
        var tex := ForestArt.bake(m, m.seed_value, true)
        var img := tex.get_image()
        var spots := BosqueArt.camp_spots(m, m.seed_value)
        var at := Vector2i(spots[0]) - Vector2i(320, 200) if not spots.is_empty() else Vector2i(img.get_width() / 3, img.get_height() / 3)
        at = at.clamp(Vector2i.ZERO, img.get_size() - Vector2i(640, 400))
        img.get_region(Rect2i(at, Vector2i(640, 400))).save_png("res://tests/out/forest_floor%d.png" % f)
        print("RESULT floor %d baked %dx%d in %d ms, camps %d" % [f, img.get_width(), img.get_height(), Time.get_ticks_msec() - t0, spots.size()])
    quit(0)
