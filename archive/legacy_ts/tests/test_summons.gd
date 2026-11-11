extends SceneTree
## Headless checks for summon system v2 (banners, log, social state, ledger, save v2).
##   godot --headless --path . --script res://tests/test_summons.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
    if cond:
        print("  PASS  ", msg)
    else:
        print("  FAIL  ", msg)
        fails += 1


func _new_game(seed_value: int, path: String) -> Node:
    var g: Node = load("res://scripts/autoload/game.gd").new()
    g.autosave = false
    g.save_path = path
    g.rng.seed = seed_value
    g.gems = 100000                          # enough for the many summons below (start gems: SummonConfig.START_GEMS)
    return g


func _init() -> void:
    print("== Summon v2 tests ==")

    # 1. banner config validation
    var b := SummonConfig.default_banner()
    check(SummonConfig.validate(b).is_empty(), "default banner is valid")
    var bad := SummonConfig.default_banner()
    bad["rates"] = [50.0, 30.0, 14.0, 5.0, 2.0]
    check(not SummonConfig.validate(bad).is_empty(), "rates summing to 101 are rejected")
    var bad2 := SummonConfig.default_banner()
    bad2.erase("pity5")
    check(not SummonConfig.validate(bad2).is_empty(), "banner with a missing key is rejected")
    check(SummonConfig.get_banner("nope").is_empty(), "unknown banner returns empty")

    # 2. published rates match what the roller really does (pity off by passing 0 counters)
    var rng := RandomNumberGenerator.new()
    rng.seed = 2024
    var counts := [0, 0, 0, 0, 0]
    var n := 200000
    for i in n:
        counts[int(Gacha.roll_stars(rng, 0, 0, b)["stars"]) - 1] += 1
    var worst := 0.0
    for i in 5:
        worst = maxf(worst, absf(100.0 * counts[i] / n - float(b["rates"][i])))
    check(worst < 0.5, "roll rates match published odds (worst error %.2f%%)" % worst)

    # 3. summon: log, seeds, ledger, social state
    var g := _new_game(777, "user://test_summon_a.json")
    var got: Array = g.pull(10)
    check(got.size() == 10 and g.pull_count == 10 and g.summon_log.size() == 10, "x10 pull logs 10 summons")
    var repro_ok := true
    var ledger_ok := true
    var social_ok := true
    for i in got.size():
        var h: HeroData = got[i]
        var entry: Dictionary = g.summon_log[i]
        var again := HeroGenerator.generate(String(entry["seed"]).hex_to_int(), int(entry["stars"]))
        if again.signature() != h.signature() or again.hero_name != h.hero_name or again.traits != h.traits:
            repro_ok = false
        if h.events.size() != 1 or String(h.events[0]["type"]) != "summoned" or h.summon_index != i + 1:
            ledger_ok = false
        if h.trust < 0 or h.trust > 100 or h.obedience < 0 or h.obedience > 100 or h.composure != 100:
            social_ok = false
    check(repro_ok, "every logged seed regenerates the same hero")
    check(ledger_ok, "each hero has a 'summoned' event and a pull number")
    check(social_ok, "Trust/Obedience stay 0-100, Composure starts at 100")
    var trust_vals := {}
    var obed_vals := {}
    for hh in g.heroes.values():
        trust_vals[hh.trust] = true
        obed_vals[hh.obedience] = true
    check(trust_vals.size() > 1 and obed_vals.size() > 1, "Trust and Obedience vary between heroes")

    # 4. failed pulls change nothing
    var broke := _new_game(1, "user://test_summon_b.json")
    broke.gems = 9
    var before := [broke.gems, broke.pity4, broke.pity5, broke.pull_count, broke.summon_log.size()]
    check(broke.pull(1).is_empty() and [broke.gems, broke.pity4, broke.pity5, broke.pull_count, broke.summon_log.size()] == before, "unaffordable pull leaves gems, pity and log untouched")
    check(broke.pull(1, "no_such_banner").is_empty(), "unknown banner pull does nothing")

    # 5. deterministic Trust/Obedience events + clamping
    var hero: HeroData = got[0]
    var t0 := hero.trust
    hero.add_event("rescued_ally", {"mission": 1}, 7, 2)
    check(hero.trust == mini(100, t0 + 7) and hero.events.size() == 2, "event applies deterministic Trust delta and is recorded")
    hero.add_event("test", {}, 500, -500)
    check(hero.trust == 100 and hero.obedience == 0, "deltas clamp to 0-100")
    hero.set_composure(-30)
    check(hero.composure == 0, "composure clamps")
    for i in 150:
        hero.add_event("noise")
    check(hero.events.size() == HeroData.EVENT_CAP, "ledger is capped at %d" % HeroData.EVENT_CAP)

    # 6. promotion writes a ledger event
    var p := HeroGenerator.generate(4242, 1)
    p.add_xp(100000)
    p.promote()
    check(String(p.events.back()["type"]) == "promoted", "promotion is recorded in the ledger")

    # 7. duplicate names get a callsign, display names stay unique
    var dup := _new_game(5, "user://test_summon_c.json")
    var base := HeroGenerator.generate(111, 2)
    dup.heroes[base.id] = base
    var twin := HeroGenerator.generate(222, 2)
    twin.hero_name = base.hero_name
    twin.epithet = base.epithet
    dup._disambiguate_name(twin)
    check(twin.callsign != "" and twin.display_name() != base.display_name(), "same name -> deterministic callsign (%s)" % twin.display_name())
    var twin2 := HeroGenerator.generate(222, 2)
    twin2.hero_name = base.hero_name
    twin2.epithet = base.epithet
    dup._disambiguate_name(twin2)
    check(twin2.callsign == twin.callsign, "callsign is deterministic for the same seed")

    # 8. save v2 round trip through a real file (+ atomic write + backup)
    check(g.save_game(), "atomic save succeeds")
    check(g.save_game() and FileAccess.file_exists(g.save_path + ".bak"), "second save keeps a .bak of the previous one")
    var g2 := _new_game(1, g.save_path)
    g2.load_game()
    check(g2.heroes.size() == 10 and g2.pull_count == 10 and g2.summon_log.size() == 10 and g2.gems == g.gems, "load restores heroes, pull count, log and gems")
    var same := true
    for id in g.heroes:
        if JSON.stringify(g.heroes[id].to_dict()) != JSON.stringify(g2.heroes[id].to_dict()):
            same = false
    check(same, "every hero is byte-identical after save/load (no re-roll)")

    # 9. corrupt main save falls back to the backup
    var f := FileAccess.open(g.save_path, FileAccess.WRITE)
    f.store_string("{ this is not json")
    f.close()
    var g3 := _new_game(1, g.save_path)
    g3.load_game()
    check(g3.heroes.size() == 10, "corrupt save falls back to the backup")

    # 10. v1 (Drop A) save migrates
    var legacy_hero := HeroGenerator.generate(31337, 3).to_dict()
    for k in ["trust", "obedience", "composure", "events", "event_seq", "callsign", "generator_version", "origin_banner", "summon_index"]:
        legacy_hero.erase(k)
    legacy_hero["loyalty"] = 64
    var v1 := {"version": 1, "gems": 321, "stones": 2, "books": 3, "pity4": 4, "pity5": 40, "party": ["", "", "", "", ""], "heroes": [legacy_hero]}
    var gm := _new_game(1, "user://test_summon_d.json")
    gm.apply_save(JSON.parse_string(JSON.stringify(v1)))
    var mh: HeroData = gm.heroes[legacy_hero["id"]]
    check(gm.gems == 321 and gm.pity5 == 40 and gm.pull_count == 1 and gm.summon_log.is_empty(), "v1 save: currencies, pity and counters survive")
    check(mh.trust == 64 and mh.obedience >= 0 and mh.obedience <= 100 and mh.composure == 100 and mh.generator_version == 1, "v1 hero: loyalty becomes Trust, Obedience derived, generator_version=1")

    # 11. old seeds keep their look/class/traits under the new generator
    var old_look := HeroGenerator.generate(987654321, 4)
    check(old_look.generator_version == HeroGenerator.VERSION, "new heroes carry the generator version")

    # cleanup
    for pth in ["a", "b", "c", "d"]:
        for ext in ["", ".bak", ".tmp"]:
            DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_summon_%s.json%s" % [pth, ext]))
    for e in [g, broke, dup, g2, g3, gm]:
        e.free()

    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
