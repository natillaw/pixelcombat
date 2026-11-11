extends Node
## Visual capture (not a pass/fail suite): opens the real screens and saves PNG screenshots.
## Needs a real renderer (not --headless). In CI:
##   CAPTURE_DIR=$PWD/screenshots xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/capture_screens.tscn
## Uses its own save file; never touches the player's save.

var _dir: String = ""
var _main: Control = null


func _ready() -> void:
    _dir = OS.get_environment("CAPTURE_DIR")
    if _dir == "":
        _dir = ProjectSettings.globalize_path("user://captures")
    DirAccess.make_dir_recursive_absolute(_dir)
    Game.autosave = false
    Game.save_path = "user://capture_save.json"
    Game.new_game()
    Game.gems = 100000
    var pulled: Array = Game.pull(10)
    for i in mini(5, pulled.size()):
        Game.assign_party(i, (pulled[i] as HeroData).id)

    var scene: PackedScene = load("res://scenes/main.tscn")
    _main = scene.instantiate() as Control
    add_child(_main)
    await _shot("01_town", 4.0)
    var town: Node = _find("TownScreen")
    if town != null:
        town.call("select_building", "tower_gate")
        await _shot("01b_town_tower_gate", 0.5)
        town.call("select_building", "town_hall")
        await _shot("01e_town_hall_panel", 0.5)
        town.call("select_building", "blacksmith")
        await _shot("01f_town_blacksmith_panel", 0.5)
        town.call("select_building", "")
        var th_list: Array = town.get("heroes")
        if not th_list.is_empty():
            town.call("open_hero", th_list[0])
            await _shot("01c_town_hero_panel", 0.8)
            town.call("close_hero")
        var cam: Camera2D = town.get("camera")
        cam.zoom = Vector2.ONE * 1.6
        cam.position = Vector2(17 * 48, 9 * 48)
        await _shot("01d_town_closeup_plaza", 3.0)
    for screen in ["summon", "roster", "party"]:
        _main.call("show_screen", screen, 0)
        await _shot("02_" + screen, 0.6)
    for f in [1, 2, 3, 4, 5, 10]:
        _main.call("show_screen", "sandbox", f)
        await _shot("03_floor%d_squad" % f, 2.5)
        var sb: Node = _find("SandboxScreen")
        if sb != null:
            sb.set("overview", true)
            await _shot("04_floor%d_map" % f, 2.0)
    _main.call("show_screen", "sandbox", 0)
    await _shot("05_training_ground", 4.0)
    # staged fight on floor 4: every hero fires a showy skill next to a foe; auras on some units
    _main.call("show_screen", "sandbox", 4)
    await get_tree().create_timer(1.0).timeout
    var fight: Node = _find("SandboxScreen")
    if fight != null:
        var hs: Array = fight.get("heroes")
        var es: Array = fight.get("enemies")
        for i in es.size():
            es[i].position = hs[i % hs.size()].position + Vector2(45 + (i / hs.size()) * 30, -10)
        var looks := ["fire_burst", "cleave", "smite", "rapid_shot", "frost_nova"]
        for i in hs.size():
            var h = hs[i]
            h.slots.clear()
            h.slots.append(looks[i % looks.size()])
            h.res = h.res_max
            h.cds.clear()
            h.use_skill_slot(0, es, hs)
        if es.size() >= 3:
            es[0].apply_status("burn", 6.0, 1.0)
            es[1].apply_status("poison", 6.0, 1.0)
            es[2].apply_status("stun", 3.0)
        hs[1].apply_status("shield", 6.0, 40.0)
        await _shot("06_combat_fx_a", 0.15)
        await _shot("06_combat_fx_b", 0.3)
        await _shot("06_combat_fx_c", 0.5)
    print("CAPTURE DONE -> ", _dir)
    get_tree().quit(0)


func _find(cls: String) -> Node:
    for n in _main.find_children("*", "", true, false):
        var s: Script = n.get_script()
        if s != null and s.get_global_name() == cls:
            return n
    return null


func _shot(shot_name: String, wait: float) -> void:
    await get_tree().create_timer(wait).timeout
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    var path := _dir.path_join(shot_name + ".png")
    var err := img.save_png(path)
    print("shot ", shot_name, " -> ", path, " err=", err)
