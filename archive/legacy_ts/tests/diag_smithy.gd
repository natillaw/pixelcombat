extends SceneTree
## Beta economy probe: a fresh smith with plenty of ore and materials; how many town days until the
## first T1 piece, and how fast does the smith level? One line per day.
func _initialize() -> void:
    var g: Node = load("res://scripts/autoload/game.gd").new()
    root.add_child(g)
    g.autosave = false
    g.save_path = "user://diag_smithy.json"
    g.new_game()
    g.starter_summons()
    g.town_buildings["blacksmith"] = 1
    var smith: HeroData = g.heroes.values()[0]
    print("RESULT assign: '", g.assign_work(smith, "blacksmith"), "' worker=", smith.hq_assignment)
    g.hq_outputs["ore"] = 200
    g.hq_outputs["materials"] = 200
    var rid := ItemLibrary.recipe_id("blacksmith", "mail", 1)
    for day in range(1, 13):
        var lvl := smith.prof_level("blacksmith")
        var need := int(ItemLibrary.recipes()[rid]["min"])
        g.set_job("blacksmith", rid if lvl >= need else "smelt_iron")
        g.pass_time(24)
        print("RESULT day %d smith lvl %d xp %.1f job %s stash %d ingot %d problem '%s'" % [day, smith.prof_level("blacksmith"), float(smith.professions.get("blacksmith", {}).get("xp", 0.0)), g.job_of("blacksmith"), g.stash.size(), int(g.hq_outputs.get("ingot", 0)), String(g.town_problems.get("blacksmith", ""))])
    quit(0)
