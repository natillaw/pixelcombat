extends SceneTree
## Town buildings (D-030, D-048): construction, Summoner's Hall caps, beds, rewards, save migration.
##   godot --headless --path . --script res://tests/test_town.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
    if cond:
        print("  PASS  ", msg)
    else:
        print("  FAIL  ", msg)
        fails += 1


func _init() -> void:
    print("== Town tests ==")
    var g: Node = load("res://scripts/autoload/game.gd").new()
    g.autosave = false
    g.save_path = "user://test_town.json"
    g.new_game()

    # every building has a plot inside the map, no two plots overlap, doors are free cells
    var plots: Array = []
    var ok_plots := true
    for id in TownTables.ids():
        var p: Rect2i = TownTables.info(id)["plot"]
        if p.position.x < 1 or p.position.y < 1 or p.end.x > TownTables.MAP_W - 1 or p.end.y > TownTables.MAP_H - 1:
            ok_plots = false
        for q in plots:
            if (q as Rect2i).intersects(p):
                ok_plots = false
        plots.append(p)
    check(ok_plots, "building plots are inside the town and never overlap")
    var town := TownMap.new(g.town_buildings)
    var doors_ok := true
    for id in TownTables.ids():
        if town.is_blocked_cell(TownTables.door_cell(id)):
            doors_ok = false
        elif town.find_path(town.center_of(town.goal_cell), town.center_of(TownTables.door_cell(id))).is_empty():
            doors_ok = false
    check(doors_ok, "every building door is reachable from the plaza")

    # building is construction work now (D-048): materials up front, then builders' hours
    check(g.building_level("alchemy") == 0 and g.building_level("library") == 0, "alchemy lab and library start unbuilt")
    check(not g.build_or_upgrade("library") and g.last_reason.contains("Summoner's Hall level 2"), "the library needs a level-2 Summoner's Hall")
    var cost: int = g.next_building_cost("town_hall")
    g.hq_outputs["materials"] = cost - 1
    check(not g.build_or_upgrade("town_hall") and g.building_level("town_hall") == 1 and g.last_reason.contains("materials"), "cannot start without enough materials (nothing changes)")
    g.hq_outputs["materials"] = cost + 5
    check(g.build_or_upgrade("town_hall") and g.building_level("town_hall") == 1 and int(g.hq_outputs["materials"]) == 5 and g.construction.size() == 1, "starting construction spends exactly its cost; the level waits for the work")
    check(not g.build_or_upgrade("town_hall") and g.last_reason.contains("already"), "one project per building")
    g.pass_time(48)
    check(g.building_level("town_hall") == 1, "without a builder nothing gets built")
    g.gems = 100000
    var pulled: Array = g.pull(2)
    var a: HeroData = pulled[0]
    var b: HeroData = pulled[1]
    a.professions.clear()
    check(g.assign_work(a, "construction") == "" and a.prof_level("builder") == 0, "a hero joins the construction crew and learns Builder as an apprentice")
    g.pass_time(120)
    check(g.building_level("town_hall") == 2 and g.construction.is_empty(), "the builder finishes the Summoner's Hall")
    g.hq_outputs["materials"] = 100000
    check(g.build_or_upgrade("library"), "a level-2 Hall unlocks the library")
    g.pass_time(96)
    check(g.building_level("library") == 1, "the library gets built")
    check(TownMap.new(g.town_buildings, g.town_layout).is_blocked_cell(g.plot_of("library").position), "a built building becomes solid on the town map")
    g.town_buildings["kitchen"] = 2
    check(not g.build_or_upgrade("kitchen") and g.last_reason.contains("Summoner's Hall"), "no building can outgrow the Summoner's Hall")

    # beds: dorm upgrades add beds, max level is respected
    var cap_before: int = g.max_hero_capacity()
    g.town_buildings["dorm_1"] = 2
    check(g.max_hero_capacity() == cap_before + TownTables.beds_at("dorm_1", 2) - TownTables.beds_at("dorm_1", 1), "a dormitory level adds beds")
    check(g.next_building_cost("summon_circle") == -1 and not g.build_or_upgrade("summon_circle"), "a max-level building cannot be upgraded")

    # the past life gives the first profession (D-049)
    var chef := HeroGenerator.generate(777, 1)
    chef.profession = "occupation.chef"
    chef.professions.clear()
    chef.init_professions()
    check(chef.prof_level("cook") == ProfessionDefs.PAST_LIFE_LEVEL and chef.passion == "cook", "a former chef starts as a level-2 cook with passion")
    check(TownTables.best_workplaces("occupation.chef").has("kitchen"), "a chef is an expert at the kitchen")
    check(TownTables.best_workplaces("cook").has("kitchen") and TownTables.best_workplaces("carpenter").has("workshop")
        and TownTables.best_workplaces("occupation.tailor").has("workshop"), "workplaces also answer for profession ids (#16)")

    # floor rewards and tower progress
    var gems0: int = g.gems
    var steel0 := int(g.hq_outputs.get("starsteel", 0))
    var r: Dictionary = g.complete_floor(4)
    check(int(r["materials"]) == 0 and int(r["starsteel"]) > 0 and int(g.hq_outputs["starsteel"]) == steel0 + int(r["starsteel"]) and g.gems == gems0 + ProgressionDefs.FIRST_GEMS_BASE + ProgressionDefs.FIRST_GEMS_PER_FLOOR * 4
        and int(g.tower_cleared["4"]) == 1, "D-066: completing floor 4 pays gems and starsteel, no town materials, and is recorded")
    check(TowerExpedition.floor_block(3, 1) == "" and TowerExpedition.floor_block(10, 1) == "" and TowerExpedition.floor_advice(3, 1) != ""
        and TowerExpedition.floor_advice(3, 2) == "", "2026-10-31: no building lock on floors; the Hall level is only advice")

    # save v5 -> v6 migration keeps old facility levels and adds the new buildings
    var v5 := {"version": 5, "gems": 1, "stones": 1, "books": 1, "pity4": 0, "pity5": 0, "pull_count": 0,
        "summon_log": [], "memorial": [], "party": ["", "", "", "", ""], "heroes": [],
        "hq_facilities": {"kitchen": 3, "workshop": 2, "infirmary": 1, "common": 1},
        "hq_outputs": {"food": 1, "materials": 2, "medicine": 3},
        "town_buildings": {"town_hall": 1, "dorm_1": 2, "dorm_2": 1, "blacksmith": 1, "kitchen": 1, "infirmary": 1},
        "tower_maps": {}}
    var g2: Node = load("res://scripts/autoload/game.gd").new()
    g2.autosave = false
    g2.apply_save(JSON.parse_string(JSON.stringify(v5)))
    check(g2.building_level("dorm_1") == 2 and g2.building_level("workshop") == 2 and g2.building_level("alchemy") == 0 and g2.building_level("tower_gate") == 1, "v5 save migrates: levels kept, new buildings added")
    check(g2.building_level("kitchen") == 1, "existing town_buildings level wins over the old facility level")
    g.free()
    g2.free()
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
