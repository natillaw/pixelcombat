extends Control
## The Wilds (D-066): the repeatable farming dungeon outside the tower. A new map every run, tier from
## the tower (changes every 10 floors), deeper rooms richer and deadlier, hidden caches of building
## materials deep inside, loot kept on the way out and lost in a wipe. The tower: no gathering spots.
##   godot --headless --path . res://tests/smoke_wilds.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Wilds tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_wilds.json"
    Game.new_game()
    Game.starter_summons()

    # --- tier follows the tower ------------------------------------------------------------------
    check(Game.wilds_tier() == 1 and DungeonDefs.tier_for(9) == 1 and DungeonDefs.tier_for(10) == 2, "the Wilds change tier every 10 tower floors")
    check(String(TowerExpedition.get_floor_config(-1)["mission"]) == "farm" and String(TowerExpedition.get_floor_config(-2)["name"]) != String(TowerExpedition.get_floor_config(-1)["name"]),
        "each tier is another place (%s / %s)" % [TowerExpedition.get_floor_config(-1)["name"], TowerExpedition.get_floor_config(-2)["name"]])

    # --- a new map every run ---------------------------------------------------------------------
    var a := Game.new_wilds_map(1)
    var b := Game.new_wilds_map(1)
    check(a.grid_rows != b.grid_rows and not Game.tower_maps.has("-1"), "every run is a new map, never saved")
    var caches := a.resource_nodes.filter(func(n): return String(n["kind"]) == "cache")
    check(not caches.is_empty() and caches.all(func(n): return a.zone_of(n["cell"]) in ["danger", "objective"]), "hidden caches lie in the deep rooms (%d)" % caches.size())

    # --- deeper = harder and richer --------------------------------------------------------------
    var sb := SandboxScreen.new(-1)
    add_child(sb)
    sb.set_physics_process(false)
    await get_tree().process_frame
    check(sb.is_wilds() and sb.mission_type == "farm" and not sb.relic.visible, "a Wilds run has no mission objective")
    var by_type := {}
    for e in sb.enemies:
        var z := (sb.map as ProceduralMap).zone_of(sb.map.cell_of(e.home))
        if not by_type.has(e.type_id):
            by_type[e.type_id] = {}
        by_type[e.type_id][z] = maxi(int(by_type[e.type_id].get(z, 0)), e.max_hp)
    var deeper := false
    for t in by_type:
        var d: Dictionary = by_type[t]
        if d.has("objective") and d.has("explore") and int(d["objective"]) > int(d["explore"]):
            deeper = true
        if d.has("danger") and d.has("explore") and int(d["danger"]) > int(d["explore"]):
            deeper = true
    check(deeper, "the same creature is stronger deeper in")
    var shallow := 0
    var deep := 0
    for g in sb.nodes:
        var z := (sb.map as ProceduralMap).zone_of(sb.map.cell_of(g.position))
        var sum := 0
        for r in g.amounts:
            sum += int(g.amounts[r])
        if z in ["danger", "objective"]:
            deep = maxi(deep, sum)
        elif z in ["entrance", "explore"]:
            shallow = maxi(shallow, sum)
    check(deep > shallow, "spots deep in hold more (%d vs %d)" % [deep, shallow])

    # --- loot: kept on the way out ---------------------------------------------------------------
    sb.ledger = {"materials": 25, "hide": 3}
    var mat0 := int(Game.hq_outputs.get("materials", 0))
    var exit := sb.map.center_of(sb.map.extract_cell)
    for h in sb.heroes:
        h.position = exit
    check(sb.extract() and int(Game.hq_outputs["materials"]) == mat0 + 25 and sb.result_text().contains("BACK FROM THE WILDS"), "leaving by the entrance keeps what was carried")
    check(Game.tower_cleared.is_empty(), "a Wilds run completes no tower floor")
    sb.queue_free()
    await get_tree().process_frame

    # --- a wiped squad loses it (and the fallen die for good) -------------------------------------
    var sw := SandboxScreen.new(-1)
    add_child(sw)
    sw.set_physics_process(false)
    await get_tree().process_frame
    sw.ledger = {"materials": 40}
    var mat1 := int(Game.hq_outputs.get("materials", 0))
    var mem0 := Game.memorial.size()
    for h in sw.heroes:
        h.take_damage(99999)
    for i in 3:
        sw.tick(0.05)
    check(sw.mission_state == SandboxScreen.Mission.FAILED and int(Game.hq_outputs.get("materials", 0)) == mat1, "a wiped squad loses everything it carried")
    check(Game.memorial.size() > mem0, "the fallen in the Wilds die for good (D-011)")
    sw.queue_free()
    await get_tree().process_frame

    # --- tower: no gathering, rare drops ---------------------------------------------------------
    var st := SandboxScreen.new(2)
    add_child(st)
    st.set_physics_process(false)
    await get_tree().process_frame
    check(st.nodes.is_empty() and not st.is_wilds(), "tower floors have no gathering spots")
    var basic := ["hide", "wood", "stone", "herb", "ore", "bone", "gel", "silk", "fang", "materials"]
    var clean := true
    for f in LootDefs.FLOORS:
        for t in ["drops", "chest", "boss"]:
            for id in (LootDefs.FLOORS[f] as Dictionary).get(t, {}):
                clean = clean and not basic.has(String(id)) and EconomyDefs.RESOURCES.has(String(id))
    check(clean, "master prompt A: tower floors drop only rare materials and keys (no Wilds' basics), all known resources")
    var lr := RandomNumberGenerator.new()
    lr.seed = LootService.seed_for(5, 1)
    var boss5 := LootService.enemy_drops(5, true, true, lr)
    var chest1 := LootService.chest(1, true, lr)
    var replay1 := LootService.chest(1, false, lr)
    check(int(boss5.get("core", 0)) >= 1 and not chest1.is_empty() and not replay1.is_empty(), "floor 5 miniboss always drops a guardian core; the chest always pays, also on replays")
    check(LootService.chest(5, true, lr).has("key_floor5_seal") and not LootService.chest(5, false, lr).has("key_floor5_seal"), "the floor 5 seal is first-clear only")
    st.queue_free()
    await get_tree().process_frame

    print("== ALL PASSED ==" if fails == 0 else "== %d FAILED ==" % fails)
    get_tree().quit(0 if fails == 0 else 1)
