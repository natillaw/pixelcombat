extends Control
## D-082b capture (not pass/fail): an expedition with the starter kit (shield, two daggers), the camera
## framing, the edge markers and the (smaller) ping wheel, at the window size given. Needs a real renderer:
##   godot --path . --resolution 1920x1080 res://tests/capture_kit.tscn
## CAPTURE_DIR = output folder (default user://captures).


func _ready() -> void:
    var dir := OS.get_environment("CAPTURE_DIR") if OS.get_environment("CAPTURE_DIR") != "" else "user://captures"
    DirAccess.make_dir_recursive_absolute(dir)
    Game.autosave = false
    Game.save_path = "user://capture_kit.json"
    Game.new_game()
    Game.rng.seed = 77
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
    for i in sb.heroes.size():
        sb.heroes[i].position = sb.map.nearest_walkable(m.position + Vector2(40 * i - 80, 30))
    sb.heroes[sb.heroes.size() - 1].position = sb.map.nearest_walkable(m.position + Vector2(900, 0))   # off screen: edge marker
    for i in 40:
        await get_tree().process_frame
    var tag := "%dx%d" % [get_viewport().size.x, get_viewport().size.y]
    get_viewport().get_texture().get_image().save_png(dir + "/kit_%s.png" % tag)
    sb.open_wheel(sb.size * 0.5)
    for i in 5:
        await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png(dir + "/wheel_%s.png" % tag)
    print("CAPTURED ", ProjectSettings.globalize_path(dir))
    get_tree().quit(0)
