extends SceneTree
## Headless integration tests for Phase 3 Deep Systems & Simulation Integrity.
##   godot --headless --path . --script res://tests/test_deep_systems.gd

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
    g.debug_full_town()          # the HQ production under test needs the basic town (new accounts start empty)
    return g


func _init() -> void:
    print("== Phase 3 Deep Systems & Simulation Integrity tests ==")
    var path := "user://test_deep_systems.json"
    var g := _new_game(101, path)
    g.gems = 10000

    var pulled: Array = g.pull(3)
    check(pulled.size() == 3, "summoned three heroes for deep systems test")
    var h1: HeroData = pulled[0]
    var h2: HeroData = pulled[1]
    var h3: HeroData = pulled[2]

    # Scenario A: Rescue creates history & relationship boost
    h1.rescue_hero(h2)
    check(h1.memories.any(func(m): return String(m["type"]) == "rescue"), "rescuer records rescue memory")
    var rel_h1_h2 := h1.get_relationship(h2.id)
    check(rel_h1_h2["level"] == 15 and rel_h1_h2["status"] == "acquaintance", "rescue gives positive relationship boost")

    # Scenario C: Secret discovery persistence & idempotency
    var first_disc := h1.discover_secret("secret.shadow_strike", "Clue: Shadows whisper in the ruins.")
    var second_disc := h1.discover_secret("secret.shadow_strike", "Clue: Shadows whisper in the ruins.")
    check(first_disc == true and second_disc == false, "secret discovery is strictly idempotent (no duplicate rewards)")
    check(h1.discovered_secrets.size() == 1 and h1.secret_clues.size() == 1, "secret and clue recorded correctly")

    # Scenario D: Death preserves legacy in memorial without automatic inheritance
    h2.discover_secret("secret.forbidden_arcana", "Clue: Arcane texts in vault.")
    var h2_secret_count := h2.discovered_secrets.size()
    check(h2_secret_count == 1, "h2 discovered a secret")
    var h1_secrets_before := h1.discovered_secrets.size()
    g.assign_party(0, h2.id)
    g.record_death(h2, "Slain in deep test", "Test Mission")
    check(g.memorial.size() == 1, "dead hero recorded in memorial")
    check(not g.heroes.has(h2.id), "dead hero removed from roster")
    check(h1.discovered_secrets.size() == h1_secrets_before, "surviving hero did not inherit dead hero's secret skill")
    check(str(g.memorial[0]["hero_id"]) == h2.id, "memorial preserves dead hero identity and records")

    # Scenario F: Headquarters systems integration & co-worker relationships
    g.assign_hq(h1.id, "kitchen")
    g.assign_hq(h3.id, "kitchen")
    var food_before: int = g.hq_outputs["food"]
    var turn_summary: Dictionary = g.process_headquarters_turn()
    check(int(turn_summary.get("food_produced", 0)) > 0, "hq kitchen produces food output (the town also eats it: %d -> %d)" % [food_before, int(g.hq_outputs["food"])])
    var rel_h1_h3 := h1.get_relationship(h3.id)
    check(rel_h1_h3["interactions"] > 0, "co-workers in kitchen build relationship interactions")

    # Scenario H: Save v4 integrity with deep system fields
    check(g.save_game(), "save game with secrets, memories, and HQ state succeeds")
    var g2 := _new_game(101, path)
    g2.load_game()
    check(g2.heroes.has(h1.id) and (g2.heroes[h1.id] as HeroData).discovered_secrets.has("secret.shadow_strike"), "secret discoveries survive save/load round trip")

    for p in [path, path + ".bak", path + ".tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
