extends Node
## Cohesion capture (not pass/fail, D-063): Caz heroes next to every creature of the new packs, on the
## forest at the 640x360 base, plus a few effects. Needs a real renderer:
##   godot --path . res://tests/capture_cohesion.tscn      (CAPTURE_DIR overrides the folder)

func _ready() -> void:
    var dir := OS.get_environment("CAPTURE_DIR")
    if dir == "":
        dir = ProjectSettings.globalize_path("user://captures_cohesion")
    DirAccess.make_dir_recursive_absolute(dir)
    Game.autosave = false
    Game.save_path = "user://capture_cohesion_save.json"
    Game.new_game()
    var s := SandboxScreen.new(1)
    add_child(s)
    s.set_anchors_preset(Control.PRESET_FULL_RECT)
    s.size = get_viewport().get_visible_rect().size
    await get_tree().process_frame
    for e in s.enemies:
        e.queue_free()
    s.enemies.clear()
    var base: Vector2 = s.heroes[0].position
    var ids: Array = AssetCatalog.CREATURES.keys()
    for i in ids.size():
        var e := s._spawn_enemy(Vector2i(0, 0), String(ids[i]))
        e.position = base + Vector2(-210 + (i % 8) * 60, -60 + (i / 8) * 80)
        e.perception = 0.0
        e.visible = true
    for i in s.heroes.size():
        s.heroes[i].position = base + Vector2(-120 + i * 50, 110)
        s.heroes[i].order_hold()
    s.fog = null
    s._fog_view.visible = false
    for e in s.enemies:
        e.visible = true
    s.group_view()
    CombatVFX.play(s._world, base + Vector2(150, 110), "slash", 1.0)
    CombatVFX.play(s._world, base + Vector2(200, 110), "fire_impact", 1.0)
    await get_tree().create_timer(1.2).timeout
    for e in s.enemies:
        e.visible = true
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    print("shot cohesion err=", img.save_png(dir.path_join("cohesion_lineup.png")))
    get_tree().quit(0)
