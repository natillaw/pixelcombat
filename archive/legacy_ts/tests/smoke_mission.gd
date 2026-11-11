extends Control
## Mission flow, skills and panel checks (T-008, T-009, T-011, T-013 integration). Run:
##   godot --headless --path . res://tests/smoke_mission.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _make_screen() -> SandboxScreen:
    var sb := SandboxScreen.new()
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    return sb


## Puts one skill on Q with a full resource bar (test helper).
func _give(h: SandboxHero, id: String) -> void:
    h.slots.clear()
    h.slots.append(id)
    h.cds.clear()
    h.res = h.res_max


func _clear_enemies(sb: SandboxScreen) -> void:
    for e in sb.enemies:
        e.alive = false
        e.visible = false


func _ready() -> void:
    print("== Mission tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_mission.json"
    Game.new_game()
    size = Vector2(1280, 720)

    # --- real party: relic, carrier death, memorial, extraction, reward --------------------
    Game.gems = 100000
    var pulled: Array = Game.pull(5)
    for i in 5:
        Game.assign_party(i, pulled[i].id)
    var sb := _make_screen()
    await get_tree().process_frame
    await get_tree().process_frame
    check(sb.real_squad and sb.heroes.size() == 5, "saved party is deployed as the squad")
    check(sb.mission_state == SandboxScreen.Mission.ACTIVE and sb.relic.visible, "mission starts active with the relic on the map")
    _clear_enemies(sb)

    var id0: String = sb.heroes[0].hero.id
    sb.heroes[0].position = sb.relic.position
    sb.tick(1.0 / 60.0)
    check(sb.carrier == sb.heroes[0] and sb.heroes[0].carrying and not sb.relic.visible, "walking onto the relic picks it up")

    var drop_at: Vector2 = sb.heroes[0].position
    sb.heroes[0].take_damage(99999, sb.enemies[0])
    sb.tick(1.0 / 60.0)
    check(not sb.heroes[0].alive and sb.carrier == null and sb.relic.visible and sb.relic.position.distance_to(drop_at) < 1.0, "carrier falls: relic drops where they fell")
    sb.heroes[0].tick(CombatRules.AGONY_TIME + 1.0)          # nobody rescues: the agony runs out
    check(not Game.heroes.has(id0) and Game.memorial.size() == 1, "death is permanent: removed from roster, written to memorial")
    check(Game.memorial[0]["cause"] == "Slain by Grunt" and Game.memorial[0]["mission"] == SandboxScreen.MISSION_NAME, "memorial records cause and mission")
    check(Game.party[0] == "" and sb.fallen.size() == 1, "party slot cleared, fallen list updated")

    sb.heroes[1].position = sb.relic.position
    sb.tick(1.0 / 60.0)
    check(sb.carrier == sb.heroes[1], "another hero can recover the dropped relic")

    sb.select_slot(0)
    check(not sb.selected.has(sb.heroes[0]) and sb.follow_slot != 0, "a fallen hero cannot be selected with its key")
    sb.select_slot(1)
    sb._refresh_info()
    check(sb._info.text.contains("Skills:") and sb._squad_label.text.contains("FALLEN") and sb._squad_label.text.contains("[RELIC]"), "panel shows skill, fallen hero and relic carrier")

    var gems_before := Game.gems
    var stones_before := Game.stones
    sb.heroes[1].position = sb.map.center_of(SandboxMap.GOAL_CELL)
    sb.tick(1.0 / 60.0)
    check(sb.mission_state == SandboxScreen.Mission.SUCCESS, "carrier reaching the exit completes the mission")
    check(Game.gems == gems_before + SandboxScreen.REWARD_GEMS and Game.stones == stones_before + SandboxScreen.REWARD_STONES, "placeholder reward granted once")
    var t_end := sb.elapsed
    sb.tick(1.0)
    check(is_equal_approx(sb.elapsed, t_end) and sb.reward_given, "simulation stops after the result; no second reward")
    var txt := sb.result_text()
    check(txt.contains("MISSION COMPLETE") and txt.contains("Fallen") and sb._overlay != null, "result screen lists the outcome and the fallen")
    sb.queue_free()

    # memorial screen lists the fallen hero
    var ms := MemorialScreen.new()
    add_child(ms)
    await get_tree().process_frame
    var entry := MemorialScreen.entry_text(Game.memorial[0])
    check(entry.contains(Game.memorial[0]["name"]) and entry.contains("Slain by Grunt"), "memorial entry text shows name and cause")
    check(ms.find_children("*", "Label", true, false).any(func(x): return x.text.contains("Slain by Grunt")), "memorial screen renders the entry")
    ms.queue_free()

    # --- test squad: failure when everyone dies, nothing recorded --------------------------
    Game.new_game()
    var sb2 := _make_screen()
    await get_tree().process_frame
    await get_tree().process_frame
    check(not sb2.real_squad, "no full party -> test squad")
    for dead in sb2.heroes:
        dead.take_damage(99999)
    sb2.tick(1.0 / 60.0)
    check(sb2.mission_state == SandboxScreen.Mission.FAILED and sb2.result_text().contains("MISSION FAILED"), "all heroes dead -> mission failed")
    check(Game.memorial.is_empty() and Game.gems == SummonConfig.START_GEMS, "test heroes write no memorial and earn no reward")
    sb2.queue_free()

    # --- skills ----------------------------------------------------------------------------
    var sb3 := _make_screen()
    await get_tree().process_frame
    await get_tree().process_frame
    check(sb3.heroes.all(func(x): return x.slots.all(func(s): return SkillDefs.SKILLS.has(s))), "every equipped active is a known skill (D-142: new heroes start with only Q)")
    for cls in HeroTables.CLASSES:
        check(SkillDefs.KITS.has(cls) and SkillDefs.CLASS_RESOURCE.has(cls), "skill kit and resource defined for %s" % cls)
    _clear_enemies(sb3)
    var h: SandboxHero = sb3.heroes[0]
    var e1: SandboxEnemy = sb3.enemies[0]
    var e2: SandboxEnemy = sb3.enemies[1]
    var e3: SandboxEnemy = sb3.enemies[2]
    for e in [e1, e2, e3]:
        e.alive = true
        e.visible = true
        e.hp = e.max_hp
    h.position = sb3.map.center_of(Vector2i(20, 17))
    h.hp = h.max_hp
    var foes: Array = [e1, e2, e3]
    var squad: Array = sb3.heroes

    _give(h, "cleave")
    e1.position = h.position + Vector2(50, 0)
    e2.position = h.position + Vector2(-50, 0)
    e3.position = h.position + Vector2(300, 0)
    check(h.use_skill_slot(0, foes, squad), "Cleave fires")
    check(e1.hp < e1.max_hp and e2.hp < e2.max_hp and e3.hp == e3.max_hp, "Cleave hits enemies around the hero, not far ones")
    h.res = h.res_max
    check(not h.skill_ready(0) and not h.use_skill_slot(0, foes, squad) and h.last_refusal.begins_with("cooldown"), "skill is refused because of its cooldown, and says so")
    h.tick(float(SkillDefs.info("cleave")["cd"]) + 0.1)
    h.res = h.res_max
    check(h.skill_cd(0) <= 0.0 and h.skill_ready(0), "skill is ready again after the cooldown")

    e1.position = h.position + Vector2(900, 0)
    e2.position = h.position + Vector2(900, 50)
    check(not h.use_skill_slot(0, foes, squad) and h.skill_ready(0) and h.res == h.res_max, "no target in reach: refused, cooldown and resource not spent")

    _give(h, "fire_burst")
    e1.hp = e1.max_hp
    e2.hp = e2.max_hp
    e1.position = h.position + Vector2(150, 0)
    e2.position = e1.position + Vector2(40, 0)
    e3.position = e1.position + Vector2(200, 0)
    check(h.use_skill_slot(0, foes, squad) and h.is_casting() and e1.hp == e1.max_hp, "Fire Burst starts a cast (no damage yet)")
    h.tick(float(SkillDefs.info("fire_burst")["cast"]) + 0.05)
    check(not h.is_casting() and e1.hp == e1.max_hp, "the fireball is in flight: no damage before it arrives (D-054)")
    for k in 20:
        h.tick(0.05)
    check(e1.hp < e1.max_hp and e2.hp < e2.max_hp and e3.hp == e3.max_hp, "the cast lands on the target and its neighbours only")

    _give(h, "second_breath")
    check(not h.use_skill_slot(0, foes, squad) and h.skill_ready(0), "self-heal is refused at full HP (cooldown kept)")
    h.hp = h.max_hp - 10
    var hp_before := h.hp
    check(h.use_skill_slot(0, foes, squad) and h.hp > hp_before and h.hp <= h.max_hp, "Second Breath heals")

    # key / button path through the screen
    _give(h, "quick_slash")
    e1.hp = e1.max_hp
    e1.position = h.position + Vector2(40, 0)
    sb3.select_slot(0)
    check(sb3.use_skill_selected(0) == 1 and e1.hp < e1.max_hp, "use_skill_selected fires slot Q for the selected hero")
    check(sb3.use_skill_selected(3) == 0 and h.last_refusal == "no skill learned", "an empty slot is refused with its reason")
    h.path.append(h.position + Vector2(100, 0))
    sb3.stop_selected()
    check(not h.is_moving(), "stop order clears the path")

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_mission.json"))
    get_tree().quit(1 if fails > 0 else 0)
