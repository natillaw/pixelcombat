extends Node2D
## Master prompt H: the eight bandits built from Tiny Pixel Fantasy layers (BanditArt presets), with the
## new "accessory" and "mask" layers. Shows every bandit with every animation (open the scene in the
## game window to watch them) and, headless, checks the data and writes a contact sheet.
##   godot --headless --path . res://tests/smoke_bandits.tscn --quit-after 3000
const IDS := ["bandido_maton", "bandido_arquero", "bandido_degollador", "bandido_bruto", "bandido_mago",
    "bandido_chaman", "capitan_bandido", "jefe_baron_carmesi"]
const ANIMS := ["idle", "run", "attack", "hurt", "death"]
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Bandit tests ==")
    check(SpriteComposer.LAYER_ORDER.has("accessory") and SpriteComposer.LAYER_ORDER.has("mask")
        and SpriteComposer.LAYER_ORDER.find("mask") > SpriteComposer.LAYER_ORDER.find("facial_hair"), "the composer has the accessory and mask layers")
    var sheet := Image.create(ANIMS.size() * 4 * 48, IDS.size() * 96, false, Image.FORMAT_RGBA8)
    sheet.fill(Color(0.35, 0.45, 0.3))
    for r in IDS.size():
        var id: String = IDS[r]
        check(EnemyDefs.TYPES.has(id) and BanditArt.has(id), "%s has stats (%s) and a layer preset" % [id, EnemyDefs.role_of(id)])
        var faction := LpcFactions.layers(id, 0).any(func(p): return String(p[1]).contains(LpcFactions.COLOR))
        check(faction, "%s wears the faction colour '%s'" % [id, LpcFactions.COLOR])
        var sf := EnemySprites.build_frames(id)
        check(sf != null, "%s builds its animations" % id)
        if sf == null:
            continue
        var col := 0
        for a in ANIMS:
            var ok := sf.has_animation(a) and sf.get_frame_count(a) > 0
            var opaque := false
            if ok:
                for i in sf.get_frame_count(a):
                    var img := sf.get_frame_texture(a, i).get_image()
                    if img.is_compressed():
                        img.decompress()
                    img.convert(Image.FORMAT_RGBA8)
                    opaque = opaque or img.get_used_rect().size.x > 0
                    if col < ANIMS.size() * 4:
                        if img.get_width() > 48:
                            img.resize(48, 48, Image.INTERPOLATE_NEAREST)
                        sheet.blend_rect(img, Rect2i(0, 0, 48, 48), Vector2i(col * 48, r * 96 + 24))
                    col += 1
                    var spr := AnimatedSprite2D.new()
                    spr.sprite_frames = sf
                    spr.position = Vector2(60 + ANIMS.find(a) * 110, 60 + r * 90)
                    add_child(spr)
                    spr.play(a)
                    break
            check(ok and opaque, "%s: animation %s has visible frames" % [id, a])
    # D-E: no hero (1000 seeds) wears the faction colour; every bandit does
    var hero_clean := true
    for i in 1000:
        for p in LpcWardrobe.layers_for(HeroGenerator.lpc_look(i * 13 + 1), "class.warrior"):
            hero_clean = hero_clean and not String(p[1]).contains(LpcFactions.COLOR)
    check(hero_clean, "no hero in 1000 seeds wears the bandit colour")
    var e := SandboxEnemy.new()
    e.setup_type("bandido_degollador", 3)
    check(e.role == "assassin" and e.skills.has("leap"), "the cutthroat is an assassin that leaps to the backline")
    e.free()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
    sheet.save_png("res://tests/out/bandits_sheet.png")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    if DisplayServer.get_name() == "headless":
        get_tree().quit(1 if fails > 0 else 0)
