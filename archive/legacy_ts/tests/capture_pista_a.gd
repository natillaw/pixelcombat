extends Control
## D-090 capture (not pass/fail): a bush with a rogue inside, a taunted creature (attention marker), combo
## pips, a low quiver, a camp, the synergy codex and the skill choice screen. Needs a real renderer:
##   godot --path . --resolution 1280x720 res://tests/capture_pista_a.tscn
## CAPTURE_DIR = output folder (default user://captures).


func _ready() -> void:
    var dir := OS.get_environment("CAPTURE_DIR") if OS.get_environment("CAPTURE_DIR") != "" else "user://captures"
    DirAccess.make_dir_recursive_absolute(dir)
    Game.autosave = false
    Game.save_path = "user://capture_pista_a.json"
    Game.new_game()
    Game.rng.seed = 90
    Game.create_master({"first": "Cap", "last": "Master", "class": "class.warrior", "trait": "trait.stubborn",
        "look": {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}})
    Game.starter_summons()
    UIKit.fill(self)
    theme = UIKit.make_theme()
    var sb := SandboxScreen.new(-1)
    add_child(sb)
    UIKit.fill(sb)
    for i in 20:
        await get_tree().process_frame
    var m := sb.master_hero
    # the nearest bush to the Master: a hero stands in it
    var bush := Vector2.INF
    for c in sb.bushes.cells:
        var p := sb.map.center_of(c)
        if bush == Vector2.INF or p.distance_to(m.position) < bush.distance_to(m.position):
            bush = p
    var others: Array = sb.heroes.filter(func(h): return h != m)
    for i in others.size():
        others[i].position = sb.map.nearest_walkable(m.position + Vector2(50 * i - 60, 50))
    print("bush cells: ", sb.bushes.cells.size(), " nearest at ", bush.distance_to(m.position) if bush != Vector2.INF else -1.0)
    if bush != Vector2.INF and not others.is_empty():
        m.position = sb.map.nearest_walkable(bush + Vector2(100, 0))
        for i in others.size():
            others[i].position = sb.map.nearest_walkable(m.position + Vector2(50 * i - 60, 60))
        others[0].position = bush
    for h in sb.heroes:
        if h.hero.hero_class == "class.rogue":
            h.combo = 3
        if h.arrows >= 0:
            h.arrows = 7
    var foe: SandboxEnemy = null
    for e in sb.enemies:
        if e.alive and (foe == null or e.position.distance_to(m.position) < foe.position.distance_to(m.position)):
            foe = e
    if foe != null:
        foe.position = sb.map.nearest_walkable(m.position + Vector2(110, -30))
        foe.alerted = true
        foe.taunt(m, 30.0)
    for i in 30:
        await get_tree().process_frame
    var tag := "%dx%d" % [get_viewport().size.x, get_viewport().size.y]
    get_viewport().get_texture().get_image().save_png(dir + "/pista_a_field_%s.png" % tag)
    # camp: nobody around
    for e in sb.enemies:
        if e.position.distance_to(m.position) < 600.0:
            e.alive = false
            e.visible = false
    sb.camp_test_kits = 1
    print("camp: ", sb.start_camp(m.position + Vector2(0, 40)))
    for i in 30:
        await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png(dir + "/pista_a_camp_%s.png" % tag)
    Game.synergy_codex = {"stun_crit": true, "shatter": true, "friends": true, "shared_sight": true}
    var layer := CanvasLayer.new()
    layer.layer = 60
    add_child(layer)
    var cc := CenterContainer.new()
    cc.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(cc)
    var codex := SynergyCodex.new()
    cc.add_child(codex)
    for i in 5:
        await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png(dir + "/pista_a_codex_%s.png" % tag)
    codex.queue_free()
    var hd: HeroData = others[0].hero if not others.is_empty() else m.hero
    hd.skill_choices.clear()
    hd._queue_skill_choices(1, 2)
    cc.add_child(SkillChoiceScreen.make(hd, 0))
    for i in 5:
        await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png(dir + "/pista_a_choice_%s.png" % tag)
    print("CAPTURED ", ProjectSettings.globalize_path(dir))
    get_tree().quit(0)
