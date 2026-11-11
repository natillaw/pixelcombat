extends SceneTree
## Overhaul LPC phase 4 (gate: the Baron's size). Left: option A, the composed LPC sheet doubled (x2,
## integer, as D-070 did with the TPF sheet). Right: option B, normal size with a red aura. A hero and a
## bandit stand next to him for scale.
##   godot --headless --path . --script res://tools/overhaul_baron_shot.gd
func _frame(pairs: Array, body: String, scale: int) -> Image:
    var layers := LpcComposer.layers_from(pairs, body)
    var img := LpcComposer.compose_anim(layers, "idle").get_region(Rect2i(0, 128, 64, 64))
    if scale != 1:
        img.resize(64 * scale, 64 * scale, Image.INTERPOLATE_NEAREST)
    return img


func _init() -> void:
    var out := Image.create(720, 240, false, Image.FORMAT_RGBA8)
    out.fill(Color(0.33, 0.45, 0.3))
    var hero := LpcComposer.compose_anim(LpcComposer.visual_layers(HeroGenerator.lpc_look(11), "class.warrior"), "idle").get_region(Rect2i(0, 128, 64, 64))
    var bandit := _frame(LpcFactions.layers("bandido_maton", 0), "male", 1)
    var baron_pairs := LpcFactions.layers("jefe_baron_carmesi", 0)
    for panel in 2:
        var ox := panel * 360
        out.blend_rect(hero, Rect2i(0, 0, 64, 64), Vector2i(ox + 10, 150))
        out.blend_rect(bandit, Rect2i(0, 0, 64, 64), Vector2i(ox + 70, 150))
        if panel == 0:
            var big := _frame(baron_pairs, "male", 2)
            out.blend_rect(big, Rect2i(0, 0, 128, 128), Vector2i(ox + 160, 86))
        else:
            for r in range(44, 4, -4):                       # red aura, soft rings
                var ring := Image.create(64, 64, false, Image.FORMAT_RGBA8)
                for y in 64:
                    for x in 64:
                        if Vector2(x - 32, (y - 40) * 1.6).length() < float(r) * 0.7:
                            ring.set_pixel(x, y, Color(0.9, 0.1, 0.1, 0.05))
                out.blend_rect(ring, Rect2i(0, 0, 64, 64), Vector2i(ox + 190, 150))
            out.blend_rect(_frame(baron_pairs, "male", 1), Rect2i(0, 0, 64, 64), Vector2i(ox + 190, 150))
        out.fill_rect(Rect2i(ox + 358, 0, 4, 240), Color(1, 1, 1))
    out.save_png("res://docs/reports/overhaul/baron_opciones.png")
    print("RESULT baron_opciones.png")
    quit(0)
