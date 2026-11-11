extends Control
## Tower floors on the real mission screen: forest floors, creatures, and every mission type
## (combat, retrieval, rescue, exploration, survival, defense, boss) plus the town. Run:
##   godot --headless --path . res://tests/smoke_tower.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _kill_all(sb: SandboxScreen) -> void:
    for e in sb.enemies:
        if e.alive:
            e.take_damage(999999)


func _make(floor_num: int) -> SandboxScreen:
    var sb := SandboxScreen.new(floor_num)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    return sb


func _ready() -> void:
    print("== Tower floor tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_tower.json"
    Game.new_game()
    size = Vector2(1280, 720)

    var fixed := SandboxMap.new()
    check(fixed.relic_cell != fixed.extract_cell, "fixed map: relic is not on the extraction cell")

    for floor_num in [1, 3, 5, 6, 8, 9, 10]:
        var sb := _make(floor_num)
        await get_tree().process_frame
        var cfg: Dictionary = TowerExpedition.get_floor_config(floor_num)
        check(sb.map is ProceduralMap and sb.heroes.size() == TowerExpedition.party_max(floor_num) and sb.mission_type == String(cfg["mission"]), "floor %d: procedural forest, %d heroes (party max), mission '%s'" % [floor_num, sb.heroes.size(), sb.mission_type])
        check(not sb.enemies.is_empty() and sb.enemies.all(func(e): return (cfg["foes"] as Array).has(e.type_id) or e.job == "shaman"), "floor %d: forest creatures from the floor table (+ the boss's shamans, D-065)" % floor_num)
        var extract: Vector2 = sb.map.center_of(sb.map.extract_cell)
        match sb.mission_type:
            "combat":
                sb.tick(0.1)
                check(sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: combat is active while enemies live" % floor_num)
                _kill_all(sb)
                sb.tick(0.1)
            "boss":
                check(sb.boss != null and sb.boss.enemy_name == String(TowerExpedition.get_floor_config(floor_num).get("boss_name", "Orc Chieftain")) and sb.boss.max_hp > sb.enemies[1].max_hp * 4, "floor %d: the floor boss is a real boss" % floor_num)
                for e in sb.enemies:
                    if e != sb.boss:
                        e.take_damage(999999)
                sb.tick(0.1)
                check(sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: boss fight continues while the chieftain lives" % floor_num)
                sb.boss.immune = false                   # floor 10: the altar's window (tested below)
                sb.boss.take_damage(999999)
                sb.tick(0.1)
            "retrieval", "rescue":
                _kill_all(sb)
                sb.heroes[0].position = sb.relic.position
                sb.tick(0.1)
                check(sb.carrier == sb.heroes[0] and sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: picking up does not end the mission" % floor_num)
                sb.heroes[0].position = extract
                sb.tick(0.1)
            "exploration":
                _kill_all(sb)
                check(sb.clues.size() == 3, "floor %d: three clues to discover" % floor_num)
                for k in sb.clues.size() - 1:
                    sb.heroes[0].position = sb.clues[k].position
                    sb.tick(0.1)
                check(sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: not done until every clue is found" % floor_num)
                sb.heroes[0].position = sb.clues[sb.clues.size() - 1].position
                sb.tick(0.1)
            "survival", "defense":
                for i in 200:                         # floor 3 holds 210 s, floor 9 survives 300 s (D-084)
                    _kill_all(sb)
                    if sb.shrine != null:
                        for h in sb.heroes:
                            h.position = sb.shrine.position
                    sb.tick(2.0)
                    if sb.mission_state != SandboxScreen.Mission.ACTIVE:
                        break
                check(sb.enemies.size() > int(cfg.get("threat", 0)) / 3, "floor %d: waves spawned more enemies" % floor_num)
        check(sb.mission_state == SandboxScreen.Mission.SUCCESS, "floor %d: '%s' can be completed" % [floor_num, sb.mission_title()])
        sb.queue_free()
        await get_tree().process_frame

    Game.gems = 100000
    Game.pull(3)
    var town := TownScreen.new()
    add_child(town)
    town.size = Vector2(1280, 720)
    await get_tree().process_frame
    check(town.heroes.size() == Game.heroes.size() and town.view != null, "town shows every hero")
    if town.master_th != null:                    # owner 2026-11-02: the Master walks there; stand him at the door
        town.master_th.position = town.map.center_of(town.map.door_of("tower_gate"))
    town.click_at(town.map.center_of((TownTables.info("tower_gate")["plot"] as Rect2i).position))
    check(town.selected == "tower_gate", "clicking a building (with the Master at its door) goes in")
    if town.master_th != null:
        town.click_at(town.map.center_of(town.map.door_of("town_hall")) + Vector2(0, 40))
        check(town.selected == "" and town.master_th.walking(), "clicking the ground walks the Master there")
    Game.hq_outputs["materials"] = 1000
    Game.town_buildings["town_hall"] = 2          # the alchemy lab needs a level-2 Summoner's Hall
    var lvl_before := Game.building_level("alchemy")
    var crew: HeroData = Game.heroes.values()[0]
    crew.professions.clear()
    Game.assign_work(crew, "construction")       # D-048: a builder does the work
    check(Game.build_or_upgrade("alchemy") and Game.building_level("alchemy") == lvl_before, "construction starts (not instant)")
    Game.pass_time(96)
    await get_tree().process_frame
    check(Game.building_level("alchemy") == lvl_before + 1 and town.map.is_blocked_cell((TownTables.info("alchemy")["plot"] as Rect2i).position), "building from the town updates the map")
    var th: TownHero = town.heroes[0]
    town.click_at(th.position + Vector2(0, -14))
    check(town.hero_panel != null and town.hero_panel.hero == th.hero, "clicking a hero opens its panel")
    for i in 10:
        for x in town.heroes:
            x._process(0.5)
    check(town.heroes.any(func(x): return x.activity != "idle"), "town heroes choose activities on their own")
    town.queue_free()

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    # --- master prompt D: party per floor, threat budget, modifiers, escape -------------------------
    var sizes_ok := true
    var bandits_ok := true
    for f in range(1, 11):
        var pm := TowerExpedition.party_max(f)
        sizes_ok = sizes_ok and pm >= 1 and pm <= 5
        for id in TowerExpedition.get_floor_config(f)["foes"]:
            bandits_ok = bandits_ok and BanditArt.has(String(id))
    check(sizes_ok and TowerExpedition.party_max(1) == 1 and TowerExpedition.party_max(10) == 5, "every floor has a squad size of 1-5 (floor 1: 1, floor 10: 5)")
    check(bandits_ok, "floors 1-10 are held by the bandit band")
    var m4 := ProceduralMap.new(136, 116, 777, 4)
    var spent := 0
    var same := 0
    for enc in m4.encounters:
        if enc.get("filler", false):
            continue                              # D-082b: density fillers are on top of the threat budget
        for id in enc["members"]:
            spent += EnemyDefs.threat_of(String(id))
        if (enc["members"] as Array).size() == TowerExpedition.party_max(4) and String(enc["zone"]) != "objective":
            same += 1
    check(spent > 0 and spent <= int(TowerExpedition.get_floor_config(4)["threat"]) + 12, "floor 4 spends its threat budget (%d of %d)" % [spent, int(TowerExpedition.get_floor_config(4)["threat"])])
    for pair in [[3, "fog"], [4, "hazard"], [5, "enrage"], [6, "no_heal"]]:
        var sm := _make(int(pair[0]))
        await get_tree().process_frame
        var applied := false
        match String(pair[1]):
            "fog":
                applied = sm.heroes[0].vision_mod < 0
            "hazard":
                applied = sm._world.get_children().any(func(n): return n is CombatZone)
            "enrage":
                applied = sm.enemies.all(func(e): return e.enrage_low)
            "no_heal":
                applied = sm.heroes[0].heal(50) == 0
        check(sm.modifier == String(pair[1]) and applied, "floor %d: modifier '%s' is in effect" % [pair[0], pair[1]])
        if int(pair[0]) == 4:
            for h in sm.heroes:
                h.position = sm.map.center_of(sm.map.relic_cell)
            sm.tick(0.05)
            check(sm.mission_state == SandboxScreen.Mission.SUCCESS, "floor 4 escape: reaching the far side wins")
        sm.queue_free()
    # --- master prompt D: sabotage (floor 7) ---------------------------------------------------------
    var s7 := _make(7)
    await get_tree().process_frame
    check(s7.mission_type == "sabotage" and s7.totems.size() == FloorMods.TOTEMS, "floor 7: %d bandit totems to destroy" % s7.totems.size())
    var foe: SandboxEnemy = null
    for e in s7.enemies:
        if e.job != "totem":
            foe = e
            break
    foe.position = s7.totems[0].position + Vector2(60, 0)
    foe.take_damage(999999)
    var n_before := s7.living_enemies().size()
    s7._revive_tick(FloorMods.REVIVE_EVERY + 0.1)
    check(s7.living_enemies().size() == n_before + 1, "a standing totem raises a fallen bandit")
    for t in s7.totems:
        t.take_damage(999999)
    s7.tick(0.05)
    check(s7.mission_state == SandboxScreen.Mission.SUCCESS, "destroying every totem wins")
    s7.queue_free()
    # --- master prompt E: the Crimson Baron and his altar ----------------------------------------
    var sbb := _make(10)
    await get_tree().process_frame
    var baron := sbb.boss
    check(baron != null and baron.type_id == "jefe_baron_carmesi" and baron.immune and sbb.altars.size() == 1, "floor 10: the Crimson Baron waits shielded, with one altar")
    var hp0 := baron.hp
    baron.take_hit(DamageInfo.make(500.0, "true", sbb.heroes[0]))
    check(baron.hp == hp0, "the shield takes every blow (0 damage)")
    var alt: BaronAltar = sbb.altars[0]
    for e in sbb.enemies:
        if e == baron:
            continue
        e.alive = false
        e.visible = false
    for i in AltarDefs.CHANNEL_HEROES:
        sbb.heroes[i].position = alt.position
    for k in int(AltarDefs.CHANNEL_TIME / 0.5) - 2:
        sbb._altar_tick(0.5)
    sbb.heroes[0].take_hit(DamageInfo.make(1.0, "true", null))
    sbb._altar_tick(0.5)
    check(alt.progress < 1.0 and baron.immune, "a hit on a channeler breaks the channel")
    for k in int(AltarDefs.CHANNEL_TIME / 0.5) + 2:
        sbb._altar_tick(0.5)
    check(not baron.immune and sbb.vuln_t > 0.0, "%d heroes channel %.0f s on the altar: the shield falls" % [AltarDefs.CHANNEL_HEROES, AltarDefs.CHANNEL_TIME])
    sbb._altar_tick(AltarDefs.VULN_TIME + 0.5)
    check(baron.immune, "after %.0f s the shield comes back" % AltarDefs.VULN_TIME)
    baron.hp = roundi(float(baron.max_hp) * 0.5)
    sbb._altar_tick(0.1)
    check(sbb.altars.size() == 2, "under 66%% a second altar appears")
    sbb.queue_free()
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    for p in ["user://smoke_tower.json", "user://smoke_tower.json.bak", "user://smoke_tower.json.tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    get_tree().quit(1 if fails > 0 else 0)
