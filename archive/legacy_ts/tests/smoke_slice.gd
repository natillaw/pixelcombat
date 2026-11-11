extends Control
## Vertical slice, end to end (5 floors + town): new account, welcome summons (builder guaranteed,
## 10 beds), free placement and construction, an expedition that escapes (keeps the ledger, no reward)
## and one that succeeds (reward, XP, MVP), crafting by profession, ascension with luck and pity,
## training for 2-star heroes, and a save/load round trip of all of it.
##   godot --headless --path . res://tests/smoke_slice.tscn --quit-after 6000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Vertical slice tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_slice.json"
    Game.new_game()

    # --- new account ---------------------------------------------------------------------------
    var built: Array = TownTables.ids().filter(func(b): return Game.building_level(b) > 0)
    built.sort()
    check(not Game.onboarded and Game.heroes.is_empty(), "a new account has no heroes and has not been welcomed")
    check(built == ["dorm_1", "dorm_2", "summon_circle", "tower_gate", "town_hall"], "the village starts nearly empty: %s" % str(built))
    check(Game.max_hero_capacity() == 10 and TownTables.beds_at("dorm_1", 1) == 5, "two dormitories of 5 beds: capacity 10")
    var first: Array = Game.starter_summons()
    check(first.size() == 10 and Game.heroes.size() == 10 and Game.onboarded, "ten free summons, really generated")
    var builders := first.filter(func(h): return (h as HeroData).knows_prof("builder"))
    check(not builders.is_empty() and Game.builders().size() >= 1, "at least one builder, already on the building site")
    check(first.filter(func(h): return Game.is_fighter(h)).size() >= SummonConfig.STARTER_MIN_FIGHTERS, "enough fighters for floor 1")
    check(first.all(func(h): return (h as HeroData).stars <= 3), "early odds: no 4-5 stars in the first summons")
    check(Game.party_heroes().size() == Game.PARTY_SIZE, "the first summons already form a full squad of five")
    check(Game.starter_summons().is_empty(), "the free summons happen once")
    check(not Game.can_summon(1) and Game.housing_block(1) != "", "the dorms are full: more heroes need more dormitories")
    var welcome := WelcomeScreen.new()
    add_child(welcome)
    check(welcome.PAGES.size() <= 5 and String(welcome.PAGES[welcome.PAGES.size() - 1]).contains("find out for yourself"), "the welcome is short and ends with the rest to discover")
    welcome.queue_free()

    # --- free placement and construction --------------------------------------------------------
    Game.hq_outputs["materials"] = 500
    check(Game.place_and_build("blacksmith", Vector2i(38, 20)).contains("too far"), "a building cannot be placed away from the village")
    var spot := Vector2i(9, 12)
    var why := Game.place_and_build("blacksmith", spot)
    check(why == "" and not Game.under_construction("blacksmith").is_empty(), "the blacksmith is placed where the player chose (%s)" % why)
    Game.pass_time(48)
    check(Game.building_level("blacksmith") == 1 and Game.plot_of("blacksmith").position == spot, "the builder raises it on that spot")

    # --- an expedition that escapes --------------------------------------------------------------
    # a full party of five: the fighters first, then anyone (the starter rule only promises 4 fighters)
    var squad: Array = Game.heroes.values().filter(func(h): return Game.is_fighter(h))
    for h in Game.heroes.values():
        if squad.size() < Game.PARTY_SIZE and not squad.has(h):
            squad.append(h)
    squad = squad.slice(0, Game.PARTY_SIZE)
    for i in squad.size():
        Game.assign_party(i, (squad[i] as HeroData).id)
    var stock_before := Game.hq_outputs.duplicate()
    var sb := SandboxScreen.new(-1)                 # D-066: gathering happens in the Wilds
    add_child(sb)
    sb.size = Vector2(1280, 720)
    await get_tree().process_frame
    check(sb.real_squad and sb.nodes.size() > 0, "the Wilds have gathering spots (%d)" % sb.nodes.size())
    var foe: SandboxEnemy = sb.enemies[0]
    foe.take_hit(DamageInfo.make(99999.0, "true", sb.heroes[0]))
    var g: GatherNode = sb.nodes[0]
    for e in sb.enemies:                           # a creature in reach would keep the gatherer busy fighting
        if e.alive and e.position.distance_to(g.position) < CombatRules.HERO_PERCEPTION + 100.0:
            e.take_hit(DamageInfo.make(99999.0, "true", sb.heroes[0]))
    sb.heroes[1].position = g.position + Vector2(10, 0)
    sb.heroes[1].order_hold()                      # holds there (an explorer would otherwise go scouting)
    var charges_before := g.charges
    for i in 110:                                  # D-117: one charge per ~5 s work cycle
        sb.tick(0.05)
    check(not sb.ledger.is_empty() and (not is_instance_valid(g) or g.charges < charges_before), "drops and one gathered charge fill the expedition ledger: %s" % str(sb.ledger))
    var ledger := sb.ledger.duplicate()
    var exit := sb.map.center_of(sb.map.extract_cell)
    for h in sb.heroes:
        h.position = exit + Vector2(randf_range(-20, 20), randf_range(-20, 20))
    check(sb.extract(), "the squad escapes from the extraction point")
    check(sb.mission_state == SandboxScreen.Mission.ESCAPED and int(Game.tower_cleared.get("1", 0)) == 0, "leaving the Wilds completes no tower floor")
    var kept := true
    for res in ledger:
        if int(Game.hq_outputs.get(res, 0)) < mini(Game.storage_cap(), int(stock_before.get(res, 0)) + int(ledger[res])) - 60:
            kept = false
    check(kept and not sb.results.get("loot", {}).is_empty(), "an escape keeps what was gathered and dropped")
    check(String(sb.results.get("mvp", "")) == "" and sb.result_text().contains("BACK FROM THE WILDS"), "a Wilds run has no completion reward and no MVP")
    var tsb := SandboxScreen.new(1)
    add_child(tsb)
    await get_tree().process_frame
    check(tsb.nodes.is_empty(), "D-066: tower floors have no gathering spots")
    tsb.queue_free()
    await get_tree().process_frame
    sb.queue_free()
    await get_tree().process_frame

    # --- an expedition that succeeds -------------------------------------------------------------
    var levels_before: Array = squad.map(func(h): return (h as HeroData).level)
    var xp_before: Array = squad.map(func(h): return (h as HeroData).xp + (h as HeroData).level * 10000)
    var sb2 := SandboxScreen.new(7)                # a 4-hero combat floor (master prompt D: party per floor)
    add_child(sb2)
    sb2.size = Vector2(1280, 720)
    await get_tree().process_frame
    for e in sb2.enemies:
        e.take_hit(DamageInfo.make(99999.0, "true", sb2.heroes[2]))
    sb2.heroes[3].credit("healing", 500.0)
    sb2.tick(0.05)
    check(sb2.mission_state == SandboxScreen.Mission.SUCCESS and int(Game.tower_cleared.get("7", 0)) == 1, "clearing floor 7 completes it")
    check(int(sb2.results.get("reward", {}).get("starsteel", 0)) > 0 and int(sb2.results.get("reward", {}).get("gems", 0)) > 0, "completion pays its reward (gems, starsteel)")
    check(String(sb2.results.get("mvp", "")) != "" and int(sb2.results.get("mvp_bonus", 0)) > 0, "an MVP is chosen and gets a bonus: %s (%s, +%d)" % [sb2.results.get("mvp", ""), sb2.results.get("mvp_reason", ""), int(sb2.results.get("mvp_bonus", 0))])
    var grew := true
    for i in squad.size():
        if i < sb2.heroes.size() and (squad[i] as HeroData).xp + (squad[i] as HeroData).level * 10000 <= int(xp_before[i]):
            grew = false
    check(grew, "every survivor gained experience (levels %s -> %s)" % [str(levels_before), str(squad.map(func(h): return (h as HeroData).level))])
    check(sb2.result_text().contains("MVP OF THE EXPEDITION") and sb2.result_text().contains("Experience"), "the results screen shows loot, reward, XP and the MVP")
    sb2.queue_free()

    # --- the MVP is about contribution, not kills ----------------------------------------------
    var a := HeroGenerator.generate(7, 1)
    var c := HeroGenerator.generate(8, 1)
    var r := ExpeditionResults.compute([
        {"hero": a, "alive": true, "contrib": {"damage": 300.0, "kills": 6.0}},
        {"hero": c, "alive": true, "contrib": {"healing": 400.0, "rescues": 1.0, "damage": 40.0}}], "success", 1, 100)
    check(r["mvp"] == c, "a healer who kept the squad alive can be the MVP (%s)" % r["mvp_reason"])
    check(int(r["mvp_bonus"]) <= c.xp_to_next() and int(r["mvp_bonus"]) > 0, "the MVP bonus is a bounded multiplier (%d / %d)" % [int(r["mvp_bonus"]), c.xp_to_next()])

    # --- crafting needs the profession ---------------------------------------------------------
    var smith: HeroData = Game.heroes.values().filter(func(h): return not (h as HeroData).knows_prof("builder"))[0]
    smith.professions.clear()
    var nobody: HeroData = Game.heroes.values().filter(func(h): return h != smith and not (h as HeroData).knows_prof("blacksmith") and not (h as HeroData).knows_prof("builder"))[0]
    nobody.professions.clear()
    for w in Game.workers_at("blacksmith"):
        Game.assign_work(w, "")
    check(Game.assign_work(nobody, "blacksmith") != "" and not nobody.knows_prof("blacksmith"), "2026-11-01: without a master at the forge a hero without the trade cannot work there")
    Game.hq_outputs["ingot"] = 20
    Game.hq_outputs["wood"] = 20
    Game.set_job("blacksmith", "forge_weapon")
    var stash0 := Game.stash.size()
    Game.pass_time(24)
    check(Game.stash.size() == stash0, "nobody qualified at the forge: no weapon is forged")
    smith.learn_prof("blacksmith")
    smith.professions["blacksmith"]["lvl"] = 2
    check(Game.assign_work(smith, "blacksmith") == "", "a blacksmith takes the forge")
    Game.pass_time(36)
    check(Game.stash.size() > stash0, "the blacksmith forges a weapon into the master's stash (%d -> %d)" % [stash0, Game.stash.size()])

    # --- ascension: level, sanctuary, materials, luck, pity ---------------------------------------
    var ones: Array = Game.heroes.values().filter(func(h): return (h as HeroData).stars == 1)
    var hero: HeroData = ones[0] if not ones.is_empty() else squad[0]
    hero.stars = 1                                  # the 1-star -> 2-star step of the slice
    hero.add_xp(999999)
    check(hero.level == 10 and Game.promotion_block(hero).contains("Sanctuary"), "level 10 is not enough: the Sanctuary of Ascension is needed")
    Game.town_buildings["town_hall"] = 2
    Game.town_buildings["ascension"] = 1
    for k in Game.ascension_cost(hero):
        Game.hq_outputs[k] = 200
    check(Game.promotion_block(hero) == "", "with the sanctuary and tower materials the hero may try")
    var c0 := Game.promotion_chance(hero)
    check(c0 >= 0.5 and c0 < 1.0, "the try is a chance (%d%% with luck %d), not a certainty" % [roundi(c0 * 100.0), hero.luck()])
    hero.ascension_fails = 1
    check(Game.promotion_chance(hero) > c0, "each failure makes the next try likelier")
    hero.ascension_fails = ProgressionDefs.ASCENSION_PITY_HARD
    check(is_equal_approx(Game.promotion_chance(hero), 1.0), "after %d failures the next try cannot fail" % ProgressionDefs.ASCENSION_PITY_HARD)
    var res := Game.attempt_promotion(hero)
    check(bool(res["ok"]) and hero.stars == 2 and hero.ascension_fails == 0, "the hero ascends to 2 stars")

    # --- training: only 2-star+, one chosen skill per extra star ----------------------------------
    var one: HeroData = Game.heroes.values().filter(func(h): return (h as HeroData).stars == 1 and h != hero)[0]
    Game.town_buildings["training_grounds"] = 1
    Game.hq_outputs["ingot"] = 10
    check(Game.training_block(one).contains("1-star"), "a 1-star hero cannot train class skills")
    var opts := Game.training_options(hero)
    check(opts.size() >= 1 and opts.size() <= ProgressionDefs.TRAIN_OPTIONS, "a 2-star hero is offered a choice of %d skills" % opts.size())
    if not opts.is_empty():
        check(Game.train_skill(hero, String(opts[0])) == "" and hero.skills.has(opts[0]), "it learns the chosen one, not all of them")
        check(Game.training_block(hero).contains("as much as its rank"), "2 stars = one trained skill")

    # --- synthesis and sacrifice (D-061) ------------------------------------------------------------
    Game.clear_party()
    var pool: Array = Game.heroes.values().filter(func(x): return x != hero)
    var target: HeroData = pool[0]
    var src: HeroData = pool[1]
    src.add_xp(400)                                # a source with some experience to pass on
    var xp0 := target.total_xp()
    var pv := Game.synthesis_preview(target, [src])
    check(bool(pv["ok"]) and int(pv["xp"]) > 0 and (pv["lost"] as Array).has(src.display_name()), "synthesis shows what is gained and lost first")
    var mem0 := Game.memorial.size()
    Game.synthesize(target, [src])
    check(target.total_xp() >= xp0 + int(pv["xp"]) - 1 and not Game.heroes.has(src.id) and Game.memorial.size() == mem0 + 1
        and String(Game.memorial[Game.memorial.size() - 1]["cause"]) == "sacrificed", "the source is absorbed (lossy XP) and goes to the memorial as sacrificed")
    var victim: HeroData = pool[2]
    var mat0 := int(Game.hq_outputs.get("materials", 0))
    var sp := Game.sacrifice_preview(victim)
    Game.sacrifice(victim)
    check(not Game.heroes.has(victim.id) and int(Game.hq_outputs.get("materials", 0)) > mat0 and bool(sp["ok"]), "a sacrifice turns a hero into tower materials")
    Game.assign_party(0, target.id)
    check(not bool(Game.sacrifice_preview(target)["ok"]), "a hero in the party (on an expedition) cannot be consumed")

    # --- save and load ----------------------------------------------------------------------------
    Game.save_game()
    var snapshot := {"heroes": Game.heroes.size(), "smith_lvl": Game.building_level("blacksmith"), "layout": Game.plot_of("blacksmith").position,
        "stash": Game.stash.size(), "stars": hero.stars, "floor": Game.tower_cleared.get("1", 0), "explored": Game.floor_explored(1),
        "ingot": int(Game.hq_outputs.get("ingot", 0)), "onboarded": Game.onboarded}
    Game.new_game()
    Game.load_game()
    var back := {"heroes": Game.heroes.size(), "smith_lvl": Game.building_level("blacksmith"), "layout": Game.plot_of("blacksmith").position,
        "stash": Game.stash.size(), "stars": (Game.heroes[hero.id] as HeroData).stars, "floor": Game.tower_cleared.get("1", 0),
        "explored": Game.floor_explored(1), "ingot": int(Game.hq_outputs.get("ingot", 0)), "onboarded": Game.onboarded}
    check(back == snapshot, "town, inventory, heroes, floors and progress survive save/load")
    if back != snapshot:
        print("    saved ", snapshot, "\n    loaded ", back)

    print("== ALL PASSED ==" if fails == 0 else "== %d FAILED ==" % fails)
    get_tree().quit(0 if fails == 0 else 1)
