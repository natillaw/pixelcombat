extends Control
## Tactics (D-065): mechanics that ask the player to think. Creature skills (wind-up, interrupt, slam
## area), lookouts that raise the alarm, the slow relic carrier everything hunts, the boss's shamans and
## ward, and heroes that use their skills on their own (heal, interrupt) unless set to manual (T).
##   godot --headless --path . res://tests/smoke_tactics.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _screen(floor_num: int) -> SandboxScreen:
    var sb := SandboxScreen.new(floor_num)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    return sb


## Moves every creature far away (out of the way of a staged test).
func _clear(sb: SandboxScreen, keep: Array) -> void:
    for e in sb.enemies:
        if not keep.has(e):
            e.position = Vector2(-90000, -90000)
            e.dormant = true


func _ready() -> void:
    print("== Tactics tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_tactics.json"
    Game.new_game()

    # --- creature skills: a slam is a marked area; stepping out avoids it ------------------------
    var sb := _screen(4)
    await get_tree().process_frame
    var h: SandboxHero = sb.heroes[0]
    var brute := sb._spawn_enemy(sb.map.cell_of(h.position), "orc_brute")
    _clear(sb, [brute])
    for x in sb.heroes:
        x.order_hold()
        if x != h:
            x.position = h.position + Vector2(-2000, 0)
    brute.position = sb.map.nearest_walkable(h.position + Vector2(90, 0))
    brute.alert()
    check(brute.skills.has("slam"), "a brute knows Slam")
    var started := false
    for i in 30:
        brute.tick(0.05, sb.heroes, sb.map)
        if brute.casting_skill == "slam":
            started = true
            break
    check(started and brute.telegraph_radius() >= 90.0, "the brute winds up a Slam: a %d px marked area" % roundi(brute.telegraph_radius()))
    var hp0 := h.hp
    h.position = brute.aim_point() + Vector2(0, 160)         # the player moves the hero out of the circle
    for i in 40:
        brute.tick(0.05, sb.heroes, sb.map)
    check(h.hp == hp0, "a hero who stepped out of the circle takes nothing")
    # D-145 telegraph shapes and looks
    check(brute.telegraph_shape() == "cone", "Slam marks a cone in front of the brute")
    check(EnemyDefs.strike_shape("ranged", "archer", "arrow")["shape"] == "line" and EnemyDefs.strike_shape("ranged", "caster", "fireball")["shape"] == "circle"
        and EnemyDefs.strike_shape("brute", "", "")["shape"] == "cone" and EnemyDefs.strike_shape("swarm", "", "")["shape"] == "circle",
        "basic strikes: archers a line, casters a circle, brutes a cone, the rest a circle")
    var cone := {"shape": "cone", "angle": 90.0, "reach": 100.0}
    check(SandboxEnemy._in_shape(Vector2(80, 0), cone, Vector2.ZERO, Vector2(50, 0), 0.0) and not SandboxEnemy._in_shape(Vector2(0, 80), cone, Vector2.ZERO, Vector2(50, 0), 0.0)
        and not SandboxEnemy._in_shape(Vector2(130, 0), cone, Vector2.ZERO, Vector2(50, 0), 0.0), "a cone hits in front, not to the side or past its reach")
    var lane := {"shape": "line", "width": 20.0, "reach": 200.0}
    check(SandboxEnemy._in_shape(Vector2(180, 5), lane, Vector2.ZERO, Vector2(60, 0), 0.0) and not SandboxEnemy._in_shape(Vector2(100, 40), lane, Vector2.ZERO, Vector2(60, 0), 0.0),
        "a line hits along its lane past the target, not beside it")
    check(EnemyDefs.SKILLS["fireball"]["look"]["proj"] == "fireball" and EnemyDefs.SKILLS["aimed_shot"]["look"]["proj"] == "arrow"
        and EnemyDefs.SKILLS.keys().all(func(id): return not EnemyDefs.SKILLS[id].has("dmg_mult") or EnemyDefs.SKILLS[id].has("look")),
        "every damaging creature skill has its own look (fireball flies, arrows fly)")
    check(EnemyDefs.SKILLS.keys().all(func(id): return not EnemyDefs.SKILLS[id].has("dmg_mult") or JuiceDefs.raw("eskill." + String(id)) != {}),
        "every damaging creature skill has a juice profile")
    sb.queue_free()
    await get_tree().process_frame

    # --- lookouts raise the alarm (floor 4) ------------------------------------------------------
    var sb4 := _screen(4)
    await get_tree().process_frame
    var scouts: Array = sb4.enemies.filter(func(e): return e.job == "scout")
    check(not scouts.is_empty(), "floor 4 has lookouts (%d)" % scouts.size())
    if not scouts.is_empty():
        var sc: SandboxEnemy = scouts[0]
        var other: SandboxEnemy = null
        for e in sb4.enemies:
            if not sc.group_mates.has(e) and not e.alerted and e.alive:
                other = e
                break
        sc.alert()
        sc._allies = sb4.living_enemies()
        sc.position = sb4.map.nearest_walkable(other.position + Vector2(60, 0))
        sc.tick(0.05, [], sb4.map)
        check(other.alerted and sc.job == "", "a lookout that reaches another group raises the alarm there")
    sb4.queue_free()
    await get_tree().process_frame

    # --- the relic carrier (floor 3) -------------------------------------------------------------
    var sb3 := _screen(3)
    await get_tree().process_frame
    var c: SandboxHero = sb3.heroes[0]
    var speed0 := c.move_mult()
    c.slots.append("second_breath")                         # D-142: heroes start with no active
    c.cds.clear()
    c.carrying = true
    check(c.move_mult() < speed0 * 0.7, "the relic carrier walks slower (%.2f -> %.2f)" % [speed0, c.move_mult()])
    check(not c.use_skill_slot(0, sb3.living_enemies(), sb3.heroes) and c.last_refusal.contains("relic"), "the carrier cannot use skills")
    var hunter: SandboxEnemy = sb3.enemies[0]
    hunter.position = c.position + Vector2(hunter.perception * 1.6, 0)
    var other_h: SandboxHero = sb3.heroes[1]
    other_h.position = hunter.position + Vector2(40, 0)
    check(hunter._nearest_hero(sb3.heroes) == c, "a creature goes for the carrier over a closer hero")
    c.carrying = false
    sb3.queue_free()
    await get_tree().process_frame

    # --- the boss and its shamans (floor 5) ------------------------------------------------------
    var sb5 := _screen(5)
    await get_tree().process_frame
    check(sb5.shamans.size() == int(TowerExpedition.get_floor_config(5).get("shamans", EnemyDefs.BOSS_SHAMANS)) and sb5.shamans.all(func(s): return s.skills.has("ward")), "the boss comes with %d shamans" % sb5.shamans.size())
    sb5.tick(0.05)
    var b: SandboxEnemy = sb5.boss
    var dmg_warded := b.take_hit(DamageInfo.make(100.0, "true", sb5.heroes[0]))
    for s in sb5.shamans:
        s.take_hit(DamageInfo.make(99999.0, "true", sb5.heroes[0]))
    b.statuses.erase("warded")
    sb5.tick(0.05)
    var dmg_open := b.take_hit(DamageInfo.make(100.0, "true", sb5.heroes[0]))
    check(dmg_warded < dmg_open, "while a shaman lives the boss takes less damage (%d vs %d)" % [dmg_warded, dmg_open])
    b.apply_status("shield", 10.0, 500.0)
    b.apply_status("stun", 0.5)
    check(not b.has_status("shield"), "a stun breaks the boss's shield")
    sb5.queue_free()
    await get_tree().process_frame

    # --- heroes use skills on their own (unless manual) ------------------------------------------
    var sbh := _screen(7)                       # needs 2+ heroes (party per floor)
    await get_tree().process_frame
    _clear(sbh, [])
    var healer: SandboxHero = null
    for x in sbh.heroes:
        if x.slots.has("heal"):
            healer = x
    if healer == null:
        healer = sbh.heroes[0]
        healer.hero.hero_class = "class.cleric"
        healer.hero.learn_skill("heal", false)
        healer.hero.equip_skill(0, "heal")
        healer._setup_skills()
    var patient: SandboxHero = sbh.heroes[1] if sbh.heroes[0] == healer else sbh.heroes[0]
    patient.position = healer.position + Vector2(60, 0)
    patient.hp = patient.max_hp / 4
    healer.res = healer.res_max
    healer.auto_skills = false
    for i in 20:
        healer.tick(0.05)
        healer.combat_tick([], sbh.map)
    check(healer.casting == "" and healer.cds.get("heal", 0.0) == 0.0, "skills set to manual: the healer waits for the player")
    healer.auto_skills = true
    var p0 := patient.hp
    for i in 40:
        healer.tick(0.05)
        healer.combat_tick([], sbh.map)
    check(patient.hp > p0 and float(healer.cds.get("heal", 0.0)) > 0.0, "an autonomous cleric heals a hurt ally on its own, then waits its cooldown (%d -> %d)" % [p0, patient.hp])
    sbh.select_only([healer])
    sbh.toggle_auto_skills()
    check(not healer.auto_skills, "T switches the selected heroes' skills to manual")
    sbh.queue_free()
    await get_tree().process_frame

    # --- dash (2026-10-31): i-frames, cooldown, imperfect AI, faster warriors ---------------------
    var sbd := _screen(7)
    var dh: SandboxHero = sbd.heroes[0]
    var dp0 := dh.position
    var ok_dash := dh.dash(Vector2.RIGHT)
    var hp_d := dh.hp
    dh.take_hit(DamageInfo.make(80.0, "true", null))
    check(ok_dash and dh.hp == hp_d and not dh.dash(Vector2.LEFT), "a dash gives i-frames (the blow misses) and has a cooldown")
    for k in 10:
        dh.tick(0.05)
    check(dh.position.distance_to(dp0) > 8.0, "the dash moves the hero (%.0f px)" % dh.position.distance_to(dp0))
    check(CombatRules.ai_dash_chance(10, 30) <= CombatRules.AI_DASH_MAX and CombatRules.AI_DASH_MAX < 0.7, "autonomous heroes dash at most %.0f%% of the time" % (CombatRules.AI_DASH_MAX * 100.0))
    var w := CombatRules.derive({"agi": 5}, "class.warrior")
    var m := CombatRules.derive({"agi": 5}, "class.mage")
    check(float(w["interval"]) < float(m["interval"]), "warriors swing faster (%.2f s vs %.2f s)" % [float(w["interval"]), float(m["interval"])])
    sbd.queue_free()
    print("== ALL PASSED ==" if fails == 0 else "== %d FAILED ==" % fails)
    get_tree().quit(0 if fails == 0 else 1)
