extends Node
## Game-feel capture (not a pass/fail suite): scale line-up (hero next to a small, standard, large,
## huge creature and the boss) and area skills at the moment they land, so their look can be compared
## with their real radius. Needs a real renderer (not --headless):
##   godot --path . --resolution 1280x720 res://tests/capture_feel.tscn
## CAPTURE_DIR overrides the output folder. Uses its own save file; never touches the player's save.

var _dir: String = ""


func _ready() -> void:
    _dir = OS.get_environment("CAPTURE_DIR")
    if _dir == "":
        _dir = ProjectSettings.globalize_path("user://captures_feel")
    DirAccess.make_dir_recursive_absolute(_dir)
    Game.autosave = false
    Game.save_path = "user://capture_feel_save.json"
    Game.new_game()
    var s := SandboxScreen.new(1)
    add_child(s)
    s.set_anchors_preset(Control.PRESET_FULL_RECT)
    s.size = get_viewport().get_visible_rect().size
    await get_tree().process_frame
    var hs: Array = s.heroes
    var es: Array = s.enemies
    # line-up: one creature of each size next to hero 1, all still (out of perception of each other)
    var base: Vector2 = hs[0].position
    var kinds := ["rat", "goblin", "orc_brute", "golem", "orc_chieftain"]
    for e in es:
        e.queue_free()
    es.clear()
    var line: Array = []
    for i in kinds.size():
        var e := s._spawn_enemy(Vector2i(0, 0), kinds[i])
        if kinds[i] == "orc_chieftain":
            e.make_boss()
        e.position = base + Vector2(-150 + i * 75, -10)
        e.perception = 0.0
        line.append(e)
    for i in hs.size():
        hs[i].position = base + Vector2(-60 + i * 30, 70)
        hs[i].order_hold()
    s.group_view()
    await _shot("feel_01_scale_lineup", 1.5)
    # area skills at their real radius on a cluster of creatures
    for e in line:
        es.erase(e)
        e.queue_free()
    var cluster: Array = []
    for k in 8:
        var e := s._spawn_enemy(Vector2i(0, 0), "goblin")
        e.position = base + Vector2(140, 0) + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0) * 0.6) * 60.0
        e.perception = 0.0
        cluster.append(e)
    var looks := ["earthshatter", "fire_burst", "frost_nova", "rain_of_arrows", "meteor"]
    for skill in looks:
        var h: SandboxHero = hs[0]
        h.position = base + Vector2(140, 0) if SkillDefs.info(skill)["target"] == "self_aoe" else base
        h.slots.clear()
        h.slots.append(skill)
        h.res = h.res_max
        h.cds.clear()
        h.casting = ""
        h.use_skill_slot(0, cluster, hs)
        h.cast_left = 0.0
        for e in cluster:
            e.hp = e.max_hp
        await _shot("feel_02_%s_a" % skill, 0.1)
        await _shot("feel_02_%s_b" % skill, 0.2)
        await get_tree().create_timer(0.8).timeout
    print("CAPTURE DONE -> ", _dir)
    get_tree().quit(0)


func _shot(shot_name: String, wait: float) -> void:
    await get_tree().create_timer(wait).timeout
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    var path := _dir.path_join(shot_name + ".png")
    print("shot ", shot_name, " -> ", path, " err=", img.save_png(path))
