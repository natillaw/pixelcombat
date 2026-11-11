extends SceneTree
## Headless checks for Phase 2 Hero Simulation & Living Headquarters.
##   godot --headless --path . --script res://tests/test_simulation.gd

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
    g.debug_full_town()          # the town production under test needs the basic town (new accounts start empty)
    return g


func _init() -> void:
    print("== Hero Simulation & HQ tests ==")
    var path := "user://test_simulation.json"
    var g := _new_game(42, path)
    g.gems = 50000

    # 1. Summoning creates summon memory
    var pulled: Array = g.pull(2)
    check(pulled.size() == 2, "summoned two heroes for simulation test")
    var h1: HeroData = pulled[0]
    var h2: HeroData = pulled[1]
    check(h1.memories.size() >= 1 and String(h1.memories[0]["type"]) == "summoned", "summoned hero records summon memory")

    # 2. Memories and persistence
    h1.add_memory("custom", "Test custom memory", h2.id, 2)
    check(h1.memories.size() >= 2, "custom memory added")
    var d := h1.to_dict()
    var h1_restored := HeroData.from_dict(d)
    check(h1_restored.memories.size() == h1.memories.size() and String(h1_restored.memories.back()["text"]) == "Test custom memory", "memories persist through to_dict/from_dict")

    # 3. Relationships evolution & status
    h1.update_relationship(h2.id, 15, "chat")
    var rel := h1.get_relationship(h2.id)
    check(rel["level"] == 15 and rel["interactions"] == 1 and rel["status"] == "acquaintance", "relationship level and status update correctly")
    h1.update_relationship(h2.id, 40, "quest")
    rel = h1.get_relationship(h2.id)
    check(rel["level"] == 55 and rel["status"] == "trusted_ally", "relationship level reaches trusted_ally")

    # 4. Headquarters assignment and turn processing
    g.assign_hq(h1.id, "kitchen")
    g.assign_hq(h2.id, "workshop")
    check(h1.hq_assignment == "kitchen" and h1.knows_prof("cook"), "hero assigned to the kitchen (learns Cook)")
    
    var initial_food: int = g.hq_outputs["food"]
    var initial_mat: int = g.hq_outputs["materials"]
    var turn_res: Dictionary = g.process_headquarters_turn()
    check(int(turn_res.get("food_produced", 0)) > 0 and int(turn_res.get("materials_produced", 0)) > 0, "a town day produces food and materials from assigned workers (%d food, %d materials now)" % [int(g.hq_outputs["food"]), int(g.hq_outputs["materials"])])

    # 5. Death witness memory & relationship impact
    g.assign_party(0, h1.id)
    g.assign_party(1, h2.id)
    var h2_id := h2.id
    g.record_death(h2, "Slain in simulation test", "Test Mission")
    check(h1.memories.any(func(m): return String(m["type"]) == "witnessed_death"), "surviving party member records witnessed_death memory")
    var rel_after := h1.get_relationship(h2_id)
    check(rel_after["level"] < 55, "relationship reflects death penalty")

    # 6. Save v4 round-trip with HQ and simulation data
    check(g.save_game(), "save game with simulation data succeeds")
    var g2 := _new_game(42, path)
    g2.load_game()
    check(g2.hq_outputs.size() > 0 and g2.heroes.has(h1.id), "game state, hq outputs, and living heroes survive save/load")
    check((g2.heroes[h1.id] as HeroData).memories.size() == (g.heroes[h1.id] as HeroData).memories.size(), "hero memories survive save/load round trip")

    for p in [path, path + ".bak", path + ".tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
