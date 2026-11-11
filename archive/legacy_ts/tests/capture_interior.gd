extends Node
## Capture (not pass/fail): the town, then the blacksmith's and the kitchen's interiors with workers.
##   godot --path . --resolution 1280x720 res://tests/capture_interior.tscn   (CAPTURE_DIR overrides the folder)
func _shot(n: String) -> void:
    for i in 20:
        await get_tree().process_frame
    var dir := OS.get_environment("CAPTURE_DIR")
    if dir == "":
        dir = ProjectSettings.globalize_path("user://captures_interior")
    DirAccess.make_dir_recursive_absolute(dir)
    get_viewport().get_texture().get_image().save_png(dir.path_join(n + ".png"))


func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://capture_interior.json"
    Game.new_game()
    Game.starter_summons()
    Game.town_buildings["blacksmith"] = maxi(1, int(Game.town_buildings.get("blacksmith", 0)))
    Game.town_buildings["kitchen"] = maxi(1, int(Game.town_buildings.get("kitchen", 0)))
    var hs: Array = Game.heroes.values()
    hs[0].hq_assignment = "blacksmith"
    hs[1].hq_assignment = "blacksmith"
    hs[2].hq_assignment = "kitchen"
    var main: Node = load("res://scenes/main.tscn").instantiate()
    add_child(main)
    await get_tree().process_frame
    main.show_screen("town")
    await _shot("town")
    var town = main.get("_content").get_child(main.get("_content").get_child_count() - 1)
    town.select_building("blacksmith")
    await _shot("interior_blacksmith")
    town.open_recipes("blacksmith")
    await _shot("recipes_blacksmith")
    town.recipes_win.queue_free()
    town.recipes_win = null
    town.select_building("kitchen")
    await _shot("interior_kitchen")
    town.select_building("infirmary")
    await _shot("interior_infirmary")
    get_tree().quit(0)
