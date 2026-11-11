extends SceneTree
## Master prompt B + C: offline expeditions, merchant, save v11, and a headless economy simulator.
##   godot --headless --path . --script res://tests/test_economy.gd          (tests)
##   SIM_DAYS=30 godot --headless --path . --script res://tests/test_economy.gd   (+ simulator table)
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _initialize() -> void:
    print("== Economy tests ==")
    var g: Node = load("res://scripts/autoload/game.gd").new()
    root.add_child(g)
    g.autosave = false
    g.save_path = "user://test_economy.json"
    g.new_game()
    g.starter_summons()
    var ids: Array = g.heroes.keys().slice(0, 3)
    var now := 1_000_000.0
    check(OfflineExpeditions.block(g, 3, ids, now).contains("floor 5"), "expeditions open only after floor 5")
    for f in range(1, 6):
        g.tower_cleared[str(f)] = 1
    check(OfflineExpeditions.block(g, 7, ids, now) != "", "only floors already cleared")
    check(OfflineExpeditions.start(g, 3, ids, now) == "" and (g.heroes[ids[0]] as HeroData).hq_assignment == "expedition", "3 heroes leave for floor 3 (they cannot work meanwhile)")
    check(not g.party_heroes().has(g.heroes[ids[0]]), "a hero away is not in the squad")
    check(OfflineExpeditions.claim(g, now + 60.0).is_empty(), "nothing comes back before floor x 20 min")
    var back: Array = OfflineExpeditions.claim(g, now + 3.0 * ExpeditionDefs.MINUTES_PER_FLOOR * 60.0 + 1.0)
    var got: Dictionary = back[0]["loot"] if not back.is_empty() else {}
    check(not back.is_empty() and not got.is_empty() and not got.keys().any(func(k): return String(k).begins_with("key_")), "it brings basics and floor drops, never key_ items: %s" % str(got))
    check((g.heroes[ids[0]] as HeroData).hq_assignment == "", "the heroes are free again")
    var full := LootService.chest(5, false, RandomNumberGenerator.new())
    var exp5 := OfflineExpeditions.loot(5, 7)
    check(not exp5.has("key_floor5_seal") and not exp5.has("core"), "floor 5 offline: no seal, no guardian core")
    g.exp_charges = 0
    check(OfflineExpeditions.block(g, 3, ids, now + 10.0).contains("charges"), "no charges left")
    OfflineExpeditions.refresh_charges(g, now + 10.0 + ExpeditionDefs.CHARGE_HOURS * 3600.0 + 1.0)
    check(g.exp_charges == 1, "a charge comes back after %.0f h" % ExpeditionDefs.CHARGE_HOURS)
    # merchant
    var offers: Array = g.merchant_offers()
    check(offers.size() == MerchantDefs.OFFERS_PER_DAY and offers == g.merchant_offers(), "the merchant shows %d offers, stable within the day" % offers.size())
    var o: Dictionary = MerchantDefs.OFFERS[int(offers[0])]
    for k in o["give"]:
        g.hq_outputs[k] = int(o["give"][k]) * 3
    var before: int = int(g.hq_outputs.get(o["get"].keys()[0], 0))
    check(g.merchant_trade(int(offers[0])) == "" and int(g.hq_outputs[o["get"].keys()[0]]) == before + int(o["get"].values()[0]), "a trade swaps old materials for a new one")
    g.merchant_trade(int(offers[0]))
    check(g.merchant_trade(int(offers[0])) != "", "each offer sells out for the day")
    # save v11
    g.expeditions = [{"floor": 2, "heroes": [], "start": 1.0, "end": 2.0}]
    g.save_game()
    g.expeditions = []
    g.load_game()
    check(g.expeditions.size() == 1 and int(g.SAVE_VERSION) >= 11, "expeditions survive save/load (save v%d)" % int(g.SAVE_VERSION))
    var migrated: Dictionary = g._migrate({"version": 10})
    check((migrated["expeditions"] as Array).is_empty() and int(migrated["exp_charges"]) == ExpeditionDefs.CHARGES_MAX, "v10 -> v11 migration adds empty expeditions with full charges")
    var old11: Dictionary = g._migrate({"version": 11, "tower_maps": {"10": {"seed": 1}}, "tower_cleared": {"3": 1}})
    check((old11["tower_maps"] as Dictionary).is_empty() and int((old11["tower_cleared"] as Dictionary)["3"]) == 1, "v11 -> v12: old floor maps are regenerated (new bandit floors), clears are kept")
    var old12: Dictionary = g._migrate({"version": 12, "heroes": [{"hero_seed": 4242}], "memorial": [{"snapshot": {"hero_seed": 77}}]})
    check(old12["heroes"][0]["look"] == HeroGenerator.lpc_look(4242) and old12["memorial"][0]["snapshot"]["look"] == HeroGenerator.lpc_look(77),
        "v12 -> v13: roster and memorial heroes get their LPC look from their seed")
    # owner 2026-11-01: only smiths work the forge; others learn it as apprentices beside a master
    var g2: Node = load("res://scripts/autoload/game.gd").new()
    root.add_child(g2)
    g2.autosave = false
    g2.save_path = "user://test_economy_appr.json"
    g2.new_game()
    g2.starter_summons()
    check(g2.heroes.values().any(func(x): return (x as HeroData).knows_prof("blacksmith")), "the first ten summons always bring a smith")
    g2.town_buildings["blacksmith"] = 2
    var smiths: Array = g2.heroes.values().filter(func(x): return (x as HeroData).knows_prof("blacksmith"))
    var cands: Array = g2.heroes.values().filter(func(x): return not (x as HeroData).knows_prof("blacksmith") and (x as HeroData).professions.size() < ProfessionDefs.MAX_KNOWN)
    var good: Array = cands.filter(func(x): return AptitudeDefs.tier(x, "blacksmith") in ["normal", "talented", "prodigy"])
    var pupil: HeroData = good[0] if not good.is_empty() else cands[0]
    for x in g2.heroes.values():
        (x as HeroData).hq_assignment = ""
    for i in 5:
        g2.party[i] = ""
    check(g2.assign_work(pupil, "blacksmith") != "", "no master at the forge: a non-smith cannot work there")
    var master: HeroData = smiths[0]
    master.professions["blacksmith"]["lvl"] = TownTables.MASTER_MIN_LVL
    var r_m: String = g2.assign_work(master, "blacksmith")
    var r_p: String = g2.assign_work(pupil, "blacksmith")
    check(r_m == "" and r_p == "", "with a master working, a hero joins as an apprentice (master: %s, pupil: %s)" % [r_m, r_p])
    g2.hq_outputs["ore"] = 300
    g2.hq_outputs["materials"] = 300
    g2.set_job("blacksmith", "smelt_iron")
    for d in 14:
        g2.pass_time(24)
    check(pupil.knows_prof("blacksmith") and pupil.aptitude_known.has("blacksmith"), "a %s apprentice beside a master becomes a smith (level %d) and its talent is known" % [AptitudeDefs.tier(pupil, "blacksmith"), pupil.prof_level("blacksmith")])
    # an incompatible apprentice gives up after a few hours (sampled: some hero is incompatible)
    var dud := HeroData.new()
    var k := 0
    while true:
        k += 1
        dud = HeroGenerator.generate(5000 + k, 1)
        if AptitudeDefs.tier(dud, "blacksmith") == "incompatible" and dud.professions.size() < ProfessionDefs.MAX_KNOWN and not dud.knows_prof("blacksmith"):
            break
    g2.heroes[dud.id] = dud
    check(g2.assign_work(dud, "blacksmith") == "", "an untested hero may try the apprenticeship")
    for d in 3:
        g2.pass_time(24)
    check(dud.hq_assignment == "" and String(dud.aptitude_known.get("blacksmith", "")) == "incompatible" and g2.assign_work(dud, "blacksmith") != "", "an incompatible apprentice leaves, and the town remembers it")
    var counts := {}
    for i in 500:
        var t := AptitudeDefs.tier(HeroGenerator.generate(i * 31 + 7, 1 + i % 3), "blacksmith")
        counts[t] = int(counts.get(t, 0)) + 1
    check(int(counts.get("incompatible", 0)) > 20 and int(counts.get("prodigy", 0)) > 20 and int(counts.get("normal", 0)) > int(counts.get("prodigy", 0)), "aptitudes vary between heroes: %s" % str(counts))
    if OS.get_environment("SIM_DAYS") != "":
        _simulate(int(OS.get_environment("SIM_DAYS")))
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)


## Economy simulator: each day one tower run (a new floor while the record grows every 2 days, else a
## replay of the record), 3 offline expeditions once floor 5 is cleared. Prints gems, summons
## affordable, guardian cores and new materials every 5 days.
func _simulate(days: int) -> void:
    var g: Node = load("res://scripts/autoload/game.gd").new()
    root.add_child(g)
    g.new_game()
    g.starter_summons()
    var rng := RandomNumberGenerator.new()
    rng.seed = 99
    var record := 0
    var t := 0.0
    var ids: Array = g.heroes.keys().slice(0, 5)
    print("RESULT day gems summons(100 each) cores stones mats_T2 record")
    for d in range(1, days + 1):
        t += 86400.0
        var f := record + 1 if d % 2 == 1 and record < 10 else maxi(1, record)
        for k in 12:
            var drops := LootService.enemy_drops(f, k == 0 and f % 5 == 0, int(g.tower_cleared.get(str(f), 0)) == 0, rng)
            for id in drops:
                g.hq_outputs[id] = int(g.hq_outputs.get(id, 0)) + int(drops[id])
        g.complete_floor(f)
        record = maxi(record, f)
        OfflineExpeditions.claim(g, t)
        for i in 3:
            OfflineExpeditions.start(g, maxi(1, record - 1), [ids[i]], t + float(i))
        if d % 5 == 0:
            var t2 := 0
            for id in ["mat_enchanted_cloth", "mat_iron_ore", "mat_resonant_crystal", "mat_moon_flower", "mat_rune_plate"]:
                t2 += int(g.hq_outputs.get(id, 0))
            print("RESULT %3d %5d %4d %4d %4d %5d %3d" % [d, g.gems, g.gems / SummonConfig.get_banner(SummonConfig.DEFAULT_BANNER)["cost_single"], int(g.hq_outputs.get("core", 0)), g.stones, t2, record])
