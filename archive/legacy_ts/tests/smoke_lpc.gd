extends SceneTree
## Overhaul LPC phase 2: the imported sheets, LpcComposer and the starter outfit.
##   godot --headless --path . --script res://tests/smoke_lpc.gd   -> docs/reports/overhaul/tira_heroe.png
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _init() -> void:
    print("== LPC tests ==")
    check(LpcComposer.available() and LpcComposer.index()["pieces"].size() >= 20, "the LPC index is imported (%d pieces)" % LpcComposer.index()["pieces"].size())
    var rng := RandomNumberGenerator.new()
    var outfits := {}
    var hair := {}
    var skins := {}
    var all_anims := true
    var faction_free := true
    for i in 100:
        rng.seed = 1000 + i
        var look := LpcWardrobe.random_look(rng, "elf" if i % 5 == 0 else "human")
        var layers := LpcWardrobe.layers_for(look, "class.warrior")
        outfits[str(layers.filter(func(p): return String(p[0]) in ["shirt_longsleeve", "pants", "shoes_basic"]))] = true
        hair[str(look["hair"]) + str(look["hair_color"])] = true
        skins[look["skin"]] = true
        for p in layers:
            faction_free = faction_free and String(p[1]) != LpcWardrobe.BANDIT_COLOR
        if i < 6:
            var sf := LpcComposer.build_frames_for(look, "class.warrior")
            for a in LpcComposer.index()["anims"]:
                for d in LpcComposer.DIRS:
                    all_anims = all_anims and sf.has_animation("%s_%s" % [a, d]) and sf.get_frame_count("%s_%s" % [a, d]) > 0
    check(outfits.size() == 1, "100 heroes wear the identical starter outfit")
    check(hair.size() >= 20 and skins.size() >= 5, "variety in hair (%d combos) and skin (%d)" % [hair.size(), skins.size()])
    check(faction_free, "no starter layer uses the bandit colour '%s'" % LpcWardrobe.BANDIT_COLOR)
    check(all_anims, "every animation exists in the 4 directions")
    rng.seed = 77
    var a := LpcWardrobe.random_look(rng)
    rng.seed = 77
    check(a == LpcWardrobe.random_look(rng), "the same seed gives the same look")
    # D-D: equipping a helm and a mail shirt replaces their layers; unequipping restores them
    rng.seed = 5
    var lk := LpcWardrobe.random_look(rng)
    var bare := LpcComposer.visual_layers(lk, "class.warrior").map(func(l): return String(l["piece"]))
    var eq := ItemVisuals.equipment_layers({"head": {"base": "helm", "ilvl": 3}, "chest": {"base": "mail", "ilvl": 15}})
    var worn := LpcComposer.visual_layers(lk, "class.warrior", eq).map(func(l): return String(l["piece"]))
    check(worn.has("helmet_barbuta") and worn.has("chainmail") and not worn.has("shirt_longsleeve") and bare.has("shirt_longsleeve")
        and String(eq["head"][1]) == "copper" and String(eq["chest"][1]) == "steel", "equipped helm (copper, ilvl 3) and mail (steel, ilvl 15) replace their layers; bare look restored")
    # strip: 4 heroes, each animation facing down (row 2; hurt row 0)
    var looks: Array = []
    for s in [3, 11, 25, 40]:
        rng.seed = s
        looks.append(LpcWardrobe.random_look(rng, "elf" if s == 25 else "human"))
    var classes := ["class.warrior", "class.rogue", "class.mage", "class.archer"]
    var anims: Array = LpcComposer.index()["anims"]
    var strip := Image.create(64 * 13, 64 * anims.size() * looks.size(), false, Image.FORMAT_RGBA8)
    strip.fill(Color(0.33, 0.45, 0.3))
    var y := 0
    for i in looks.size():
        var layers := LpcComposer.visual_layers(looks[i], classes[i])
        for an in anims:
            var img := LpcComposer.compose_anim(layers, String(an))
            if img != null:
                var row := 2 if img.get_height() >= 192 else 0
                var w := mini(img.get_width(), strip.get_width())
                strip.blend_rect(img, Rect2i(0, row * 64, w, 64), Vector2i(0, y))
            y += 64
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/reports/overhaul"))
    strip.save_png("res://docs/reports/overhaul/tira_heroe.png")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
