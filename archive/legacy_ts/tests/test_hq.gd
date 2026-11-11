extends SceneTree
## HQ Phase 1 (D-047..D-050): professions, work, production chains, storage, beds, needs, hospital,
## diseases, tavern, construction, placement, expeditions, save v9, determinism, performance.
##   godot --headless --path . --script res://tests/test_hq.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
    if cond:
        print("  PASS  ", msg)
    else:
        print("  FAIL  ", msg)
        fails += 1


func _game(seed_value: int) -> Node:
    var g: Node = load("res://scripts/autoload/game.gd").new()
    g.autosave = false
    g.save_path = "user://test_hq.json"
    g.rng.seed = seed_value
    g.new_game()
    g.debug_full_town()          # production systems under test need the basic town (new accounts start empty)
    g.gems = 1000000
    return g


## A fresh hero with exactly the professions given ({prof: level}).
func _hero(g: Node, profs: Dictionary) -> HeroData:
    var h: HeroData = g.pull(1)[0]
    h.professions.clear()
    h.passion = ""
    for p in profs:
        h.professions[p] = {"lvl": int(profs[p]), "xp": 0.0}
    return h


func _init() -> void:
    print("== HQ tests ==")
    var g := _game(7)

    # --- professions (D-049) ---------------------------------------------------------------------
    var h := _hero(g, {"miner": 3})
    check(h.learn_prof("cook") == "" and h.prof_level("cook") == 0, "a hero learns a second profession as an apprentice")
    check(h.learn_prof("doctor").contains("forget"), "a third profession is refused until one is forgotten (D-049)")
    check(h.forget_prof("cook") and h.learn_prof("doctor") == "", "forgetting frees the slot")
    h.forget_prof("doctor")
    check(h.work_efficiency("miner") > h.work_efficiency("cook"), "an unknown profession gives no work (%.2f vs %.2f)" % [h.work_efficiency("miner"), h.work_efficiency("cook")])
    var lv0 := h.prof_level("miner")
    for i in 200:
        h.add_prof_xp("miner", 1.0)
    check(h.prof_level("miner") > lv0, "work experience raises the profession level (%d -> %d)" % [lv0, h.prof_level("miner")])
    var p1 := _hero(g, {"farmer": 1})
    var p2 := _hero(g, {"farmer": 1})
    p2.passion = "farmer"
    p1.add_prof_xp("farmer", 10.0)
    p2.add_prof_xp("farmer", 10.0)
    check(float(p2.professions["farmer"]["xp"]) > float(p1.professions["farmer"]["xp"]) or p2.prof_level("farmer") > p1.prof_level("farmer"), "passion (past life) learns faster")

    # --- assignment ----------------------------------------------------------------------------
    check(g.assign_work(p1, "alchemy").contains("not built"), "cannot work in an unbuilt building")
    var full := _hero(g, {"farmer": 1})
    g.assign_work(p1, "farm")
    g.assign_work(p2, "farm")
    check(g.assign_work(full, "farm").contains("no free work place"), "work places are limited per building level")
    var busy := _hero(g, {"farmer": 1, "cook": 1})
    check(g.assign_work(busy, "mine").contains("forget") and busy.hq_assignment == "", "a hero with 2 professions cannot take a third trade's job")

    # --- production chain: ore -> ingot -> weapon -> equipped ------------------------------------------
    g = _game(11)
    var miner := _hero(g, {"miner": 5})
    var smith := _hero(g, {"blacksmith": 4})
    g.assign_work(miner, "mine")
    g.set_job("mine", "dig_ore")
    g.hq_outputs["ore"] = 0
    g.hq_outputs["ingot"] = 0
    g.pass_time(6)
    check(int(g.hq_outputs["ore"]) > 0, "the miner digs ore (%d)" % int(g.hq_outputs["ore"]))
    g.assign_work(smith, "blacksmith")
    g.pass_time(30)
    check(int(g.hq_outputs["ingot"]) > 0 or g.town_batches.has("blacksmith"), "the smith smelts that ore into ingots (%d ingots)" % int(g.hq_outputs["ingot"]))
    g.hq_outputs["ingot"] = 10
    g.hq_outputs["wood"] = 10
    g.town_batches.erase("blacksmith")
    g.set_job("blacksmith", "forge_weapon")
    var stash0: int = g.stash.size()
    g.pass_time(48)
    check(g.stash.size() > stash0, "the blacksmith forges a weapon into the stash")
    var weapon: Dictionary = g.stash.back()
    check(String(ItemDefs.BASES[String(weapon["base"])]["kind"]) == "weapon" and int(g.hq_outputs["ingot"]) <= 7, "the forged item is a weapon and its ingots were used")
    var atk0: int = int(smith.get_stats()["atk"]) + int(smith.get_stats()["mag"])
    check(g.equip(smith, int(weapon["uid"])) == "" and smith.equipment.has("main_hand") and g.stash_index(int(weapon["uid"])) < 0, "the weapon is equipped and leaves the stash")
    check(int(smith.get_stats()["atk"]) + int(smith.get_stats()["mag"]) > atk0, "the weapon raises the hero's combat stats")

    # --- no free production, no double use, storage caps ----------------------------------------------
    g = _game(12)
    var cook := _hero(g, {"cook": 2})
    g.assign_work(cook, "kitchen")
    g.town_clock = 9
    g.hq_outputs["grain"] = 0
    var food0: int = int(g.hq_outputs["food"])
    g.pass_time(10)
    check(int(g.hq_outputs["food"]) <= food0 and String(g.town_problems.get("kitchen", "")).contains("grain"), "no grain, no meals: the kitchen reports what is missing")
    g.hq_outputs["grain"] = 3
    g.pass_time(1)
    check(int(g.hq_outputs["grain"]) == 1 and g.town_batches.has("kitchen"), "a batch takes its inputs when it starts (they cannot be used twice)")
    check(not g.has_resources({"grain": 2}) and g.start_batch("kitchen", "cook_meal") != "", "the remaining grain cannot start a second batch")
    var farmer := _hero(g, {"farmer": 5})
    g.assign_work(farmer, "farm")
    g.hq_outputs["grain"] = g.storage_cap()
    g.town_batches.erase("farm")
    g.pass_time(4)
    check(int(g.hq_outputs["grain"]) <= g.storage_cap() and String(g.town_problems.get("farm", "")).contains("storage full"), "a full warehouse stops production instead of losing goods")

    # --- beds and housing ----------------------------------------------------------------------------
    g = _game(13)
    var beds: int = g.max_hero_capacity()
    check(beds == TownTables.beds_at("dorm_1", 1) + TownTables.beds_at("dorm_2", 1), "capacity = beds in the built dormitories (%d)" % beds)
    var many: Array = g.pull(beds)
    check(many.size() == beds and g.heroes.values().all(func(x): return x.bed != ""), "every hero up to capacity gets a bed")
    check(g.pull(1).is_empty() and g.housing_block(1).contains("beds"), "no free bed: the summon is refused with the reason")
    var away: HeroData = many[0]
    var away_bed: String = away.bed
    g.pass_time(24, [away.id])
    check(away.bed == away_bed and away.activity_state == "deployed", "a hero in the tower keeps their bed")
    g.town_buildings["dorm_2"] = 0
    g.assign_beds()
    var rough: int = g.heroes.values().filter(func(x): return x.bed == "").size()
    check(g.heroes.size() == beds and rough == TownTables.beds_at("dorm_2", 1), "losing beds never removes heroes: %d sleep rough" % rough)
    var sleeper: HeroData = g.heroes.values().filter(func(x): return x.bed == "")[0]
    sleeper.fatigue = 90
    var bedded: HeroData = g.heroes.values().filter(func(x): return x.bed != "")[0]
    bedded.fatigue = 90
    var s0 := sleeper.stress
    TownSim._needs(g, sleeper, "sleeping")
    TownSim._needs(g, bedded, "sleeping")
    check(bedded.fatigue < sleeper.fatigue and sleeper.stress > s0, "sleeping rough rests less and adds stress")

    # --- needs ------------------------------------------------------------------------------------
    g = _game(14)
    var eater := _hero(g, {})
    eater.hunger = 80
    var meals: int = int(g.hq_outputs["food"])
    g.town_clock = 12
    g.pass_time(1)
    check(eater.hunger < 80 and int(g.hq_outputs["food"]) == meals - 1, "a hungry hero eats one meal from storage")
    g.hq_outputs["food"] = 0
    eater.hunger = 100
    var st0 := eater.stress
    g.pass_time(1)
    check(eater.stress > st0 and eater.hunger == 100, "no food: hunger stays and stress grows")
    var tired := _hero(g, {})
    tired.fatigue = 95
    g.town_clock = 12
    g.pass_time(1)
    check(tired.activity_state == "sleeping" and tired.fatigue < 95, "an exhausted hero sleeps even by day")

    # --- illness and hospital ---------------------------------------------------------------------------
    g = _game(15)
    var patient := _hero(g, {})
    var vit0: int = int(patient.attributes()["vit"])
    patient.catch_disease("infected_wound", "test")
    check(int(patient.attributes()["vit"]) < vit0, "a disease lowers attributes (VIT %d -> %d), so it weakens the hero in combat" % [vit0, int(patient.attributes()["vit"])])
    check(not patient.catch_disease("infected_wound", "test"), "the same disease is not caught twice")
    var hours0: float = float(patient.diseases[0]["hours"])
    g.pass_time(48)
    check(patient.has_disease("infected_wound") and float(patient.diseases[0]["hours"]) == hours0 and String(g.town_problems.get("infirmary", "")).contains("no doctor"), "an infected wound does not heal without a doctor")
    check(g.patients.has(patient.id) and patient.activity_state == "in_treatment", "the sick hero takes a hospital bed")
    var doc := _hero(g, {"doctor": 3})
    g.assign_work(doc, "infirmary")
    g.hq_outputs["medicine"] = 0
    g.pass_time(12)
    check(patient.has_disease("infected_wound") and String(g.town_problems.get("infirmary", "")).contains("medicine"), "a doctor without medicine cannot treat")
    g.hq_outputs["medicine"] = 5
    g.town_clock = 8
    g.pass_time(120)
    g.pass_time(1)
    check(not patient.has_disease("infected_wound") and int(g.hq_outputs["medicine"]) < 5, "a doctor with medicine cures the wound (medicine left %d)" % int(g.hq_outputs["medicine"]))
    check(not g.patients.has(patient.id), "a cured hero leaves the hospital bed")
    var fever := _hero(g, {})
    fever.catch_disease("marsh_fever", "test")
    g.assign_work(doc, "")
    g.pass_time(int(EconomyDefs.DISEASES["marsh_fever"]["hours"]) + 2)
    check(not fever.has_disease("marsh_fever"), "a mild fever passes with rest alone")
    var beds_h: int = TownTables.info("infirmary")["sick_beds"][g.building_level("infirmary")]
    for i in beds_h + 1:
        _hero(g, {}).catch_disease("marsh_fever", "test")
    g.pass_time(1)
    check(g.patients.size() == beds_h, "hospital beds are limited (%d)" % beds_h)

    # contagion: a coughing hero infects dorm mates sooner or later (deterministic)
    g = _game(16)
    var cougher := _hero(g, {})
    var mates: Array = []
    for i in 4:
        mates.append(_hero(g, {}))
    cougher.catch_disease("cave_cough", "test")
    var crng := RandomNumberGenerator.new()
    crng.seed = 99
    for i in 50:
        TownSim._contagion(g, [], crng, {"events": []})
    var caught := mates.filter(func(m): return m.bed == cougher.bed and m.has_disease("cave_cough"))
    check(mates.any(func(m): return m.bed == cougher.bed) and caught.size() > 0, "cave cough spreads to dorm mates (%d caught)" % caught.size())
    var other_dorm := mates.filter(func(m): return m.bed != cougher.bed and m.has_disease("cave_cough"))
    check(other_dorm.is_empty(), "it does not jump to other dorms")

    # --- tavern and relationships ------------------------------------------------------------------------
    g = _game(17)
    var t1 := _hero(g, {})
    var t2 := _hero(g, {})
    t1.traits = ["trait.cheerful"]
    t2.traits = ["trait.kind"]
    t1.stress = 90
    t2.stress = 90
    g.town_clock = 12
    g.pass_time(1)
    check(t1.activity_state == "socializing" and t1.stress < 90, "a stressed hero unwinds at the tavern")
    check(t1.get_relationship(t2.id)["level"] > 0, "two friendly natures bond at the tavern")
    var q1 := _hero(g, {})
    var q2 := _hero(g, {})
    q1.traits = ["trait.hot_headed"]
    q2.traits = ["trait.arrogant"]
    for i in 12:
        q1.stress = 90
        q2.stress = 90
        t1.stress = 0
        t2.stress = 0
        g.town_clock = 12 + 24 * (i + 1)      # a different hour each time: a different (deterministic) roll
        g.pass_time(1)
    check(q1.get_relationship(q2.id)["level"] < 0, "two quarrelsome natures end up arguing (%d)" % q1.get_relationship(q2.id)["level"])
    var w1 := _hero(g, {"farmer": 3})
    var w2 := _hero(g, {"farmer": 3})
    w1.update_relationship(w2.id, 60)
    check(TownSim._teamwork(w1, [w1, w2]) > 1.0, "friends work better together")
    w1.update_relationship(w2.id, -150)
    check(TownSim._teamwork(w1, [w1, w2]) < 1.0, "rivals slow each other down")

    # --- construction (D-048) and placement (D-050) -------------------------------------------------------
    g = _game(18)
    g.hq_outputs["materials"] = 10000
    check(g.build_or_upgrade("town_hall") and g.building_level("town_hall") == 1, "construction is queued, not instant")
    var b1 := _hero(g, {"builder": 4})
    var b2 := _hero(g, {"builder": 4})
    g.assign_work(b1, "construction")
    g.assign_work(b2, "construction")
    g.pass_time(60)
    check(g.building_level("town_hall") == 2, "builders raise the Summoner's Hall")
    g.build_or_upgrade("kitchen")
    g.build_or_upgrade("farm")
    var k0: float = float(g.under_construction("kitchen")["work_left"])
    var f0: float = float(g.under_construction("farm")["work_left"])
    for b in [b1, b2]:
        b.hunger = 0
        b.fatigue = 0
        b.stress = 0
    g.town_clock = 9
    g.pass_time(1)
    check(float(g.under_construction("kitchen")["work_left"]) < k0 and float(g.under_construction("farm")["work_left"]) < f0, "two builders work on two projects at once")
    check(g.placement_block("memorial", Vector2i(16, 9)).contains("plaza"), "a building cannot cover the plaza")
    check(g.placement_block("memorial", Vector2i(14, 2)).contains("overlaps"), "a building cannot overlap another")
    check(g.placement_block("memorial", Vector2i(42, 22)).contains("outside"), "a building cannot leave the town")
    check(g.placement_block("memorial", Vector2i(3, 18)).contains("too far"), "a building cannot be moved away from the village")
    check(g.move_building("memorial", Vector2i(3, 12)) == "" and g.plot_of("memorial").position == Vector2i(3, 12), "a valid spot moves the building")
    var m := TownMap.new(g.town_buildings, g.town_layout)
    check(m.is_blocked_cell(Vector2i(3, 12)) and not m.is_blocked_cell(Vector2i(3, 15)), "the town map follows the new layout")

    # --- expeditions ---------------------------------------------------------------------------------------
    g = _game(19)
    var e1 := _hero(g, {"farmer": 2})
    var e2 := _hero(g, {"farmer": 2})
    g.assign_work(e1, "farm")
    var xp0: float = float(e1.professions["farmer"]["xp"]) + 100.0 * e1.prof_level("farmer")
    var clock0: int = g.town_clock
    g.rng.seed = 5
    var res := [{"hero": e1, "downed": true, "poisoned": true}, {"hero": e2, "downed": false, "poisoned": false}]
    g.after_expedition(res, 4, 1)
    check(g.town_clock == clock0 + EconomyDefs.HOURS_PER_EXPEDITION, "an expedition moves the town one day (D-047)")
    check(float(e1.professions["farmer"]["xp"]) + 100.0 * e1.prof_level("farmer") == xp0, "a hero in the tower does not work in the town")
    check(e2.fatigue > 0 and e2.stress >= int(EconomyDefs.AFTER_MISSION["stress_death"]), "the squad comes back tired and shaken by a death")
    var got_sick := 0
    for s in 30:
        var gg := _game(100 + s)
        var hh := _hero(gg, {})
        gg.after_expedition([{"hero": hh, "downed": true, "poisoned": true}], 3, 0)
        if hh.has_disease("infected_wound") or hh.has_disease("toxin"):
            got_sick += 1
        gg.free()
    check(got_sick > 5 and got_sick < 30, "being downed or poisoned can leave a disease (%d/30), not always" % got_sick)

    # --- save v9, migration, no duplication ------------------------------------------------------------------
    g = _game(20)
    var sv := _hero(g, {"blacksmith": 3})
    g.assign_work(sv, "blacksmith")
    sv.catch_disease("toxin", "test")
    sv.hunger = 33
    g.stash.append(ItemGen.generate(g.rng, g._next_uid(), 3, "rare"))
    g.equip(sv, int(g.stash.back()["uid"]))
    g.hq_outputs["materials"] = 5000
    g.build_or_upgrade("town_hall")
    g.move_building("memorial", Vector2i(3, 18))
    g.pass_time(5)
    check(g.save_game(), "the town saves")
    var g2: Node = load("res://scripts/autoload/game.gd").new()
    g2.autosave = false
    g2.save_path = g.save_path
    g2.load_game()
    var sv2: HeroData = g2.heroes[sv.id]
    check(g2.town_clock == g.town_clock and g2.hq_outputs == g.hq_outputs and g2.construction.size() == 1 and g2.town_layout == g.town_layout, "clock, storage, construction and layout survive save/load")
    check(sv2.prof_level("blacksmith") == sv.prof_level("blacksmith") and sv2.hunger == sv.hunger and sv2.has_disease("toxin") and sv2.bed == sv.bed and sv2.equipment.has("main_hand") == sv.equipment.has("main_hand"), "professions, needs, illness, bed and gear survive save/load")
    var items_a: int = g.stash.size() + sv.equipment.size()
    g2.save_game()
    g2.load_game()
    check(g2.stash.size() + (g2.heroes[sv.id] as HeroData).equipment.size() == items_a and g2.item_seq >= g.item_seq, "saving and loading again duplicates nothing")
    g.pass_time(24)
    g2.pass_time(24)
    check(g2.hq_outputs == g.hq_outputs and g2.town_clock == g.town_clock, "the reloaded town keeps living exactly like the original (deterministic)")
    var old := sv.to_dict()
    for k in ["professions", "passion", "needs", "diseases", "bed", "equipment", "bag"]:
        old.erase(k)
    old["profession"] = "occupation.miner"
    var v8 := {"version": 8, "gems": 1, "stones": 1, "books": 1, "pity4": 0, "pity5": 0, "pull_count": 1, "summon_log": [], "memorial": [],
        "party": ["", "", "", "", ""], "heroes": [old], "hq_outputs": {"food": 7, "materials": 9, "medicine": 2},
        "town_buildings": {"town_hall": 1, "dorm_1": 1, "dorm_2": 1, "kitchen": 2}, "tower_maps": {}, "tower_cleared": {}, "skill_books": {}}
    var g3: Node = load("res://scripts/autoload/game.gd").new()
    g3.autosave = false
    g3.apply_save(JSON.parse_string(JSON.stringify(v8)))
    var mh: HeroData = g3.heroes[sv.id]
    check(g3.building_level("farm") == 1 and g3.building_level("kitchen") == 2 and int(g3.hq_outputs["food"]) == 7 and int(g3.hq_outputs["grain"]) > 0, "a v8 save migrates: buildings kept, new ones added, storage kept")
    check(mh.prof_level("miner") == ProfessionDefs.PAST_LIFE_LEVEL and mh.bed != "" and mh.hero_name == sv.hero_name and mh.traits == sv.traits, "v8 heroes get their past-life profession and a bed, nothing rerolled")

    # --- performance: 60 heroes, 10 town days ------------------------------------------------------------------
    var gp := _game(21)
    gp.town_buildings["dorm_1"] = 5
    gp.town_buildings["dorm_2"] = 5
    gp.town_buildings["dorm_3"] = 5
    gp.town_buildings["dorm_4"] = 5               # dorms hold 5 at level 1 (vertical slice), 13 at level 5
    gp.assign_beds()
    var crowd: Array = gp.pull(40)
    for i in crowd.size():
        var places := ["farm", "lumber_camp", "mine", "kitchen", "workshop", "blacksmith", "construction"]
        gp.assign_work(crowd[i], places[i % places.size()])
    var t0 := Time.get_ticks_msec()
    gp.pass_time(240)
    var ms := Time.get_ticks_msec() - t0
    check(ms < 4000, "40 heroes x 240 town hours simulate in %d ms (< 4000)" % ms)
    check(gp.heroes.size() == 40, "nobody vanished during the long run")

    # owner 2026-11-02: town-tower link (kitchen level gates meals, one site per builder, time scale)
    var gk := _game(31)
    gk.town_buildings["kitchen"] = 1
    for rid_in in ["grain", "herb", "bone"]:
        gk.hq_outputs[rid_in] = 50
    check(String(gk.start_batch("kitchen", "cook_broth")).contains("level 3"), "bone broth needs a level-3 kitchen")
    gk.town_buildings["kitchen"] = 3
    check(gk.start_batch("kitchen", "cook_broth") == "", "a level-3 kitchen cooks bone broth")
    gk.town_buildings["town_hall"] = 5
    gk.town_buildings["farm"] = 1
    gk.hq_outputs["materials"] = 100000
    gk.construction.clear()
    for i in gk.builder_count():
        gk.construction.append({"bid": "warehouse", "to": 9, "work_left": 999.0})
    check(String(gk.construction_block("farm")).contains("builder"), "one building site per builder")
    var alc := _hero(gk, {"alchemist": 3})
    gk.town_buildings["alchemy"] = 2
    check(gk.assign_work(alc, "alchemy") == "", "an alchemist can work at an idle alchemy lab (%s)" % gk.last_reason)
    gk.hq_outputs["potion"] = 0
    gk.pass_time(24)
    check(int(gk.hq_outputs["potion"]) == 0 and gk.job_of("alchemy") == "", "without the Master's order the alchemist brews nothing")
    check(gk.order_craft("alchemy", "brew_potion", 2) == "", "the Master orders two healing potions")
    gk.pass_time(48)
    check(int(gk.hq_outputs["potion"]) == 2 and not gk.craft_left.has("alchemy"), "the order is brewed and the bench rests (%d potions)" % int(gk.hq_outputs["potion"]))
    gk.hq_outputs["herb"] = 0
    check(String(gk.order_craft("alchemy", "brew_potion", 0)).contains("materials"), "no materials, no order")
    check(EconomyDefs.expedition_hours(1200.0) == 48 and EconomyDefs.expedition_hours(5.0) == 1, "20 real minutes in the tower = 2 town days")
    check(is_equal_approx(EconomyDefs.REAL_SECONDS_PER_HOUR * 24.0, 1200.0), "20 real minutes in the town = 1 town day")

    for x in [g, g2, g3, gp, gk]:
        x.free()
    for p in ["user://test_hq.json", "user://test_hq.json.bak", "user://test_hq.json.tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
