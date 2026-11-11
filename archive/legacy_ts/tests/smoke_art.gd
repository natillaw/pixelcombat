extends Control
## Art wiring checks (T-024 enemies, T-025 map). Run:
##   godot --headless --path . res://tests/smoke_art.tscn --quit-after 3000
## Without the art installed the art checks are skipped (still PASS); headless cannot judge looks.
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Art tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_art.json"
    Game.new_game()
    size = Vector2(1280, 720)
    var sb := SandboxScreen.new()
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    await get_tree().process_frame
    await get_tree().process_frame

    check(SandboxScreen.ENEMY_TYPES.all(func(t): return EnemySprites.IDS.has(t)), "every enemy type is a known mob id")
    if EnemySprites.available("orc"):
        for id in EnemySprites.IDS:
            var f := EnemySprites.build_frames(id)
            check(f != null and f.has_animation("idle") and f.has_animation("run") and f.has_animation("death"), "%s has idle/run/death" % id)
            if f != null and EnemySprites.has_processed(id):
                # D-063: drawn from the Enemy Animations Set strips (complete idle / move / attack / hurt / death)
                check(f.get_frame_count("idle") >= 4 and f.get_frame_count("run") >= 6 and f.get_frame_count("death") >= 6
                    and f.has_animation("attack") and f.has_animation("hurt"), "%s frame counts (new strips: idle, run, death, attack, hurt)" % id)
            elif f != null:
                check(f.get_frame_count("idle") == 4 and f.get_frame_count("run") == 6 and f.get_frame_count("death") >= 6, "%s frame counts (4 idle, 6 run, >=6 death)" % id)
        var foe: SandboxEnemy = sb.enemies[0]
        check(foe._sprite != null and foe.type_id == "orc", "spawned enemy uses the mob sprite")
        check(foe.enemy_name == "Grunt", "enemy name unchanged (memorial text depends on it)")
        var parent := foe.get_parent()
        foe.take_damage(99999)
        await get_tree().process_frame
        await get_tree().process_frame
        var ghosts := parent.get_children().filter(func(c): return c != foe and c.get_child_count() > 0 and c.get_child(0) is AnimatedSprite2D and (c.get_child(0) as AnimatedSprite2D).animation == "death")
        check(not foe.alive and ghosts.size() == 1, "dead enemy leaves one corpse playing the death animation")
    else:
        print("  SKIP  enemy art not installed (run tools/prepare_crawler.py)")
    if MapTiles.available():
        var tex := MapTiles.bake(sb.map)
        check(tex != null and Vector2(tex.get_size()) == sb.map.world_size(), "baked map texture covers the whole fixed map")
    else:
        print("  SKIP  tileset not installed (run tools/prepare_crawler.py)")
    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_art.json"))
    get_tree().quit(1 if fails > 0 else 0)
