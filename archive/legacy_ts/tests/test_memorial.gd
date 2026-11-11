extends SceneTree
## Headless checks for permanent death + memorial + save v3 (T-013).
##   godot --headless --path . --script res://tests/test_memorial.gd

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
    return g


func _init() -> void:
    print("== Memorial tests ==")
    var path := "user://test_memorial.json"
    var g := _new_game(77, path)
    g.gems = 100000
    var pulled: Array = g.pull(5)
    check(pulled.size() == 5, "summoned five heroes")
    for i in 5:
        g.assign_party(i, pulled[i].id)
    var victim: HeroData = pulled[2]
    var vid := victim.id
    var vname := victim.display_name()
    var trust_before: Array = []
    for i in 5:
        trust_before.append(pulled[i].trust)

    check(g.record_death(victim, "Slain by Grunt", "Recover the relic"), "record_death succeeds for a roster hero")
    check(not g.heroes.has(vid), "dead hero leaves the roster for good")
    check(g.party[2] == "" and g.party_heroes().size() == 4, "dead hero leaves the party slot")
    check(g.memorial.size() == 1, "memorial has one entry")
    var m: Dictionary = g.memorial[0]
    check(m["name"] == vname and m["cause"] == "Slain by Grunt" and m["mission"] == "Recover the relic", "entry keeps name, cause and mission")
    check(m["snapshot"]["id"] == vid and m["snapshot"]["seed"] == victim.to_dict()["seed"], "entry keeps a full snapshot (id + seed)")
    check(String(victim.events.back()["type"]) == "died", "death is recorded in the hero's ledger")
    var trust_ok := true
    for i in 5:
        if i == 2:
            continue
        var ph: HeroData = pulled[i]
        if ph.trust != clampi(int(trust_before[i]) - 2, 0, 100) or String(ph.events.back()["type"]) != "ally_fell":
            trust_ok = false
    check(trust_ok, "survivors lose 2 Trust (deterministic) and log ally_fell")
    check(not g.record_death(victim, "again", ""), "a dead hero cannot die twice (no duplicate memorial)")
    check(not g.record_death(HeroGenerator.generate(999, 2), "x", ""), "a hero not on the roster is ignored")
    check(g.memorial.size() == 1, "memorial unchanged after refused calls")

    # save v3 round trip
    check(g.save_game(), "save with memorial succeeds")
    var g2 := _new_game(1, path)
    g2.load_game()
    check(g2.memorial.size() == 1 and JSON.stringify(g2.memorial) == JSON.stringify(g.memorial), "memorial is identical after save/load")
    check(not g2.heroes.has(vid) and g2.heroes.size() == 4, "dead hero stays dead after load (no resurrection)")

    # v2 save (no memorial key) migrates to an empty memorial
    var v2 := {"version": 2, "gems": 5, "stones": 1, "books": 1, "pity4": 0, "pity5": 0, "pull_count": 0, "summon_log": [], "party": ["", "", "", "", ""], "heroes": []}
    var g3 := _new_game(1, path)
    g3.apply_save(v2)
    check(g3.memorial.is_empty(), "v2 save migrates with an empty memorial")

    # the memorial is never capped
    var g4 := _new_game(5, path)
    g4.gems = 1000000
    var many: Array = g4.pull(10)
    for h in many:
        g4.record_death(h, "test", "")
    for i in 5:
        for h in g4.pull(10):
            g4.record_death(h, "test", "")
    check(g4.memorial.size() == 60 and g4.heroes.is_empty(), "memorial keeps all %d fallen heroes" % g4.memorial.size())

    # new_game wipes it (explicit reset only)
    g4.new_game()
    check(g4.memorial.is_empty(), "new_game resets the memorial")

    for p in [path, path + ".bak", path + ".tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
