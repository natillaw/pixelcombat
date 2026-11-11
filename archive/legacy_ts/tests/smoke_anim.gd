extends Control
## Animation checks (T-023, D-020). Run:
##   godot --headless --path . res://tests/smoke_anim.tscn --quit-after 3000
## Headless has no renderer: this proves the logic/wiring, not how it looks.
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Animation tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_anim.json"
    Game.new_game()
    size = Vector2(1280, 720)
    var sb := SandboxScreen.new()
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    await get_tree().process_frame
    await get_tree().process_frame

    var h0: SandboxHero = sb.heroes[0]
    var names := h0._sprite.sprite_frames.get_animation_names()
    for n in ["attack_right", "attack_left", "ready_right", "ready_left", "down_right", "down_left"]:
        check(names.has(n), "frames contain '%s'" % n)
    check(HeroAnim.attack_anim("up", "left") == "attack_left" and HeroAnim.attack_anim("down", "right") == "attack_right", "up/down attacks reuse the last side")
    check(HeroAnim.attack_anim("left", "right") == "attack_left", "left/right attacks use their own side")

    var lock := HeroAnim.play_attack(h0._sprite, "right", "right", false)
    check(lock > 0.0 and h0._sprite.animation == "attack_right", "melee attack plays the lunge frames and returns a pose lock")
    h0._anim_lock = 0.5
    h0._play("walk_left")
    check(h0._sprite.animation == "attack_right", "walk/idle cannot override a locked pose")
    h0._anim_lock = 0.0
    h0._play("walk_left")
    check(h0._sprite.animation == "walk_left", "walk plays again once the lock ends")
    check(HeroAnim.play_attack(h0._sprite, "up", "left", true) > 0.0 and h0._sprite.animation == HeroAnim.dir_anim(h0._sprite, "ready_", "up", "left"), "ranged attack uses the ready pose, facing up when the sheet has it (%s)" % h0._sprite.animation)
    check(HeroAnim.play_cast(h0._sprite, "right") > 0.0, "cast returns a pose lock")
    HeroAnim.play_hit(h0._sprite, Vector2.LEFT)
    check(h0._sprite.has_meta("anim_tween"), "hit reaction tween created")

    var hp_before := h0.hp
    var parent := h0.get_parent()
    h0.take_damage(99999)
    await get_tree().process_frame
    await get_tree().process_frame
    check(not h0.alive and h0.downed and h0.hp == 0 and hp_before > 0 and h0._sprite.animation.begins_with("down_"), "at 0 HP the hero falls and lies down (D-036)")
    h0.die()
    await get_tree().process_frame
    await get_tree().process_frame
    var ghosts := parent.get_children().filter(func(c): return c != h0 and c.get_child_count() > 0 and c.get_child(0) is AnimatedSprite2D and (c.get_child(0) as AnimatedSprite2D).animation.begins_with("down_"))
    check(ghosts.size() == 1, "one corpse sprite lies down where the hero fell")

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_anim.json"))
    get_tree().quit(1 if fails > 0 else 0)
