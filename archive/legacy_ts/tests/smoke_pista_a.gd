extends Control
## D-090 (pista A): aggro and taunt, stealth and sight, class resources and costs, camp, one synergy of each
## type, the synergy codex in the save and the skill choices at levels 2 / 5 / 10. Run:
##   godot --headless --path . res://tests/smoke_pista_a.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _as(h: SandboxHero, cls: String) -> void:
    h.hero.hero_class = cls
    h.stats = h.hero.get_stats()
    h.item_mods = {}
    h.in_bush = false
    h._setup_skills()
    h.role = AiDefs.role_of(cls)


## One camp kit: pista D's item in a hero's bag when it exists, else the test counter.
func _give_kit(sb: SandboxScreen) -> void:
    if CampDefs.kit_is_item():
        sb.heroes[0].hero.bag[CampDefs.KIT_ID] = 1
    else:
        sb.camp_test_kits = 1


func _fresh(e: SandboxEnemy, at: Vector2) -> void:
    e.base_max_hp = 5000
    e.max_hp = 5000
    e.dead = false
    e.alive = true
    e.visible = true
    e.dormant = false
    e.alerted = false
    e.statuses.clear()
    e.threat.clear()
    e.hp = e.max_hp
    e.position = at
    e.state = SandboxEnemy.State.IDLE
    e.taunt_t = 0.0
    e.taunted_by = null
    e.focus = null
    e.ai_role = ""
    e.detect_mult = 1.0


func _ready() -> void:
    print("== Pista A tests (D-090) ==")
    Game.autosave = false
    Game.save_path = "user://smoke_pista_a.json"
    Game.new_game()
    var sb := SandboxScreen.new(0)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    await get_tree().process_frame
    await get_tree().process_frame
    var map: NavMap = sb.map
    for e in sb.enemies:
        e.alive = false
        e.visible = false
        e.position = Vector2(-5000, -5000)
    var war: SandboxHero = sb.heroes[0]
    var mage: SandboxHero = sb.heroes[1]
    var rogue: SandboxHero = sb.heroes[2]
    var archer: SandboxHero = sb.heroes[3]
    var cleric: SandboxHero = sb.heroes[4] if sb.heroes.size() > 4 else sb.heroes[1]
    _as(war, "class.warrior")
    _as(mage, "class.mage")
    _as(rogue, "class.rogue")
    _as(archer, "class.archer")
    _as(cleric, "class.cleric")
    var e1: SandboxEnemy = sb.enemies[0]
    var e2: SandboxEnemy = sb.enemies[1]
    var base := map.center_of(Vector2i(6, 15))
    for i in sb.heroes.size():
        sb.heroes[i].position = base + Vector2(0, 600 + i * 60)
        sb.heroes[i].combat_tick([], map)

    # --- 1 aggro and taunt ---------------------------------------------------------------------
    _fresh(e1, base)
    war.position = base + Vector2(40, 0)
    mage.position = base + Vector2(-60, 0)
    e1.add_threat(war, 10.0)
    e1.add_threat(mage, 15.0)
    check(is_equal_approx(e1.threat_of(war), 20.0) and is_equal_approx(e1.threat_of(mage), 15.0), "damage makes threat; the warrior's counts x2")
    e1.alerted = true
    check(e1._nearest_hero(sb.heroes) == war, "a creature follows its threat table (warrior on top)")
    e1.focus = war
    e1.add_threat(mage, 6.0)                         # 21 vs 20: not enough to switch (THREAT_SWITCH)
    check(e1._nearest_hero(sb.heroes) == war, "it does not flip to a hero that barely passes the current one")
    e1.add_threat(mage, 20.0)
    check(e1._nearest_hero(sb.heroes) == mage, "it switches when another hero clearly passes it")
    e1.focus = mage
    cleric.position = base + Vector2(0, 150)
    mage.hp = mage.max_hp / 2
    var before := e1.threat_of(cleric)
    cleric._apply_effect({"t": "heal", "mult": 2.0}, [], [mage], mage.position, [e1], sb.heroes)
    check(e1.threat_of(cleric) > before, "healing an ally next to the fight draws threat on the healer")
    var wc: Dictionary = SkillDefs.info("war_cry")
    check(is_equal_approx(float(wc["effects"][0]["dur"]), 3.5), "War Cry forces the target 3-4 s (3.5)")
    e1.taunt(war, 3.5)
    check(e1.attention() == war and e1.threat_ranking()[0][0] == war, "taunt: forced target, first in the table")
    check(e1._nearest_hero(sb.heroes) == war, "a taunted creature goes for the taunter")
    _fresh(e2, base + Vector2(0, -40))
    e2.ai_role = "assassin"
    e2.alerted = true
    cleric.position = base + Vector2(0, -150)
    check(e2._nearest_hero(sb.heroes) == cleric or e2._nearest_hero(sb.heroes) == mage, "the assassin goes for the cleric or the mage")
    e2.taunt(war, 3.5)
    check(e2._nearest_hero(sb.heroes) == war, "...unless it is taunted")
    e2.taunt_t = 0.0
    check(e1.has_method("attention") and e1.has_method("threat_ranking"), "attention() / threat_ranking() exposed for the UI")

    # --- 2 sight and stealth --------------------------------------------------------------------
    check(war.vision_cells() == int(CombatRules.CLASS_VISION["class.warrior"]) + war.perception(), "sight = class base + perception")
    check(rogue.vision_cells() > war.vision_cells() - war.perception() + rogue.perception() - 1, "scouts see further")
    _fresh(e1, base)
    for h in sb.heroes:
        h.position = base + Vector2(0, 900)
    war.position = base + Vector2(180, 0)
    check(e1._notices(war, 230.0), "a warrior at 180 px is noticed (perception 230)")
    war.position = base + Vector2(0, 900)
    rogue.position = base + Vector2(180, 0)
    check(not e1._notices(rogue, 230.0), "a rogue at 180 px is not (230 x (1 - 0.35))")
    rogue.position = base + Vector2(100, 0)
    check(e1._notices(rogue, 230.0), "...but closer it is")
    rogue.in_bush = true
    check(not e1._notices(rogue, 230.0) and is_equal_approx(rogue.detect_range(230.0), 230.0 * CombatRules.DETECT_MIN), "in a bush: never below 35 % of the range")
    rogue.position = base + Vector2(70, 0)
    check(e1._notices(rogue, 230.0), "inside 35 % even a hidden rogue is seen")
    rogue.in_bush = false
    var wall_map := NavMap.new()
    wall_map.build_grid(["........", "...#....", "...#....", "...#....", "........"])
    var saved_map := e1._map
    e1._map = wall_map
    e1.position = wall_map.center_of(Vector2i(1, 2))
    war.position = wall_map.center_of(Vector2i(5, 2))
    check(not e1._notices(war, 300.0), "a tree / wall in between hides the hero from a calm creature")
    e1.alerted = true
    check(e1._notices(war, 300.0), "once fighting, it keeps track without a clear line")
    e1._map = saved_map
    check(sb.bushes != null and sb.bushes.cells is Dictionary, "the floor has a bush field (%d bush cells)" % sb.bushes.cells.size())
    check(BushField.generate(map, 7) == BushField.generate(map, 7), "bushes are deterministic per map seed")

    # --- 3 resources and costs ----------------------------------------------------------------
    check(rogue.resource_kind() == "energy" and is_equal_approx(rogue.resource_max(), 100.0), "rogue: energy 100")
    check(war.resource_kind() == "fury" and archer.resource_kind() == "concentration" and mage.resource_kind() == "mana", "warrior fury, archer concentration, mage mana")
    var com := HeroGenerator.generate(777, 1)
    com.hero_class = "class.commoner"
    check(SkillDefs.resource_of("class.commoner") == "none" and SkillDefs.cost_for("shove", "class.commoner") == 0.0, "commoner: no resource, no cost")
    var missing: Array = []
    for sid in SkillDefs.SKILLS:
        var sk: Dictionary = SkillDefs.SKILLS[sid]
        if not sk.has("cost") or (String(sk["class"]) != "" and String(sk["class"]) != "class.commoner" and int(sk["cost"]) <= 0):
            missing.append(sid)
    check(missing.is_empty(), "every class skill has a cost %s" % str(missing))
    rogue.res = 0.0
    rogue.tick(1.0)
    check(rogue.res >= 9.9, "energy +10/s always")
    _fresh(e1, base)
    rogue.position = base + Vector2(30, 0)
    rogue.combo = 0
    rogue.slots.clear()
    rogue.slots.append("eviscerate")
    rogue.cds.clear()
    rogue.res = 100.0
    check(not rogue.use_skill_slot(0, [e1], sb.heroes) and rogue.last_refusal == "no combo points", "a finisher needs combo points")
    rogue._land_basic(e1, DamageInfo.make(5.0, "physical", rogue), e1.position)
    rogue._land_basic(e1, DamageInfo.make(5.0, "physical", rogue), e1.position)
    check(rogue.combo_points() == 2, "basic hits build combo points")
    check(not rogue._auto_skill([e1]), "the AI waits for 3 points before a finisher")
    rogue.combo = 5
    var hp0 := e1.hp
    check(rogue.use_skill_slot(0, [e1], sb.heroes) and rogue.combo_points() == 0, "the finisher spends every point")
    var d5 := hp0 - e1.hp
    rogue.cds.clear()
    rogue.combo = 1
    rogue.res = 100.0
    hp0 = e1.hp
    rogue.use_skill_slot(0, [e1], sb.heroes)
    check(d5 > hp0 - e1.hp, "5 points hit harder than 1 (%d vs %d)" % [d5, hp0 - e1.hp])
    rogue.res = 0.0
    rogue.combo = 5
    rogue.cds.clear()
    check(not rogue._auto_skill([e1]), "the AI never casts what it cannot pay")
    archer.res = 0.0
    archer.path.clear()
    archer._still_t = 1.0
    archer.combat_t = 0.0
    archer.tick(1.0)
    var still_gain := archer.res
    archer.res = 0.0
    archer.path.append(archer.position + Vector2(200, 0))
    archer.tick(1.0)
    check(still_gain > archer.res, "concentration regenerates faster standing still (%.1f vs %.1f)" % [still_gain, archer.res])
    archer.path.clear()
    check(archer.arrows_left() == AiDefs.ARROWS_START, "the archer enters with a full quiver (%d)" % archer.arrows_left())
    archer._draw_target = e1
    archer._release_shot()
    check(archer.arrows_left() == AiDefs.ARROWS_START - 1, "every shot spends an arrow")
    e1.arrows_in = 4
    archer._arrow_corpses.append(e1)
    e1.dead = true
    e1.alive = false
    archer.position = e1.position + Vector2(10, 0)
    archer._pick_up_arrows()
    check(archer.arrows_left() == AiDefs.ARROWS_START - 1 + ceili(4 * AiDefs.ARROW_RECOVER), "arrows are taken back from the bodies")
    archer.arrows = 0
    check(not archer.is_ranged(), "with no arrows the archer fights up close")
    archer.arrows = AiDefs.ARROWS_START
    for x in archer._shots:
        if is_instance_valid(x):
            x.free()
    archer._shots.clear()

    # --- 4 camp ---------------------------------------------------------------------------------
    for e in sb.enemies:
        e.alive = false
        e.position = Vector2(-5000, -5000)
    var spot := base + Vector2(0, 300)
    for h in sb.heroes:
        h.position = spot + Vector2(float(h.slot) * 20.0, 0)
        h.target = null
        h.statuses.clear()
    _give_kit(sb)
    check(sb.start_camp(spot) == "" and sb.camp != null, "camp: starts with a kit and nobody around")
    _fresh(e1, spot + Vector2(150, 0))
    e1.alerted = true
    var foes := sb.living_enemies()
    sb.camp.tick(0.1, foes)
    await get_tree().process_frame
    check(sb.camps_interrupted == 1 and sb.camps_done == 0, "a creature coming close interrupts the camp")
    sb.camp = null
    check(sb.camp_refusal(spot) == "no camp kit", "the kit was spent")
    e1.alive = false
    e1.position = Vector2(-5000, -5000)
    _give_kit(sb)
    war.hp = war.max_hp / 3
    war.hero.bag["food"] = 1
    mage.res = 0.0
    var chef: SandboxHero = cleric
    chef.hero.profession = "occupation.chef"
    sb.start_camp(spot)
    var c: CampSite = sb.camp
    c.tick(CampDefs.DURATION + 1.0, [])
    await get_tree().process_frame
    check(sb.camps_done == 1 and war.hp == war.max_hp, "a finished camp: everyone eats and is back to full health")
    check(war.has_status("well_fed") and not war.hero.bag.has("food"), "...the meal comes from the hero's bag and leaves a buff")
    check(mage.res > 0.0, "...and the mana comes back")
    check(war.statuses["well_fed"]["t"] > CampDefs.FED_TIME * 1.5, "the cook (synergy) makes the meal last longer")

    # --- 5 synergies, one of each type ---------------------------------------------------------
    Game.synergy_codex.clear()
    _fresh(e1, base)
    rogue.position = base + Vector2(30, 0)
    e1.apply_status("stun", 2.0)
    var info := DamageInfo.make(10.0, "physical", rogue, 0.0, rogue.combat_rng)
    rogue.synergy_before_hit(e1, info)
    check(info.crit_chance >= 1.0 and Game.synergy_codex.has("stun_crit"), "combo: a stunned foe takes a rogue crit (codex: discovered)")
    e1.statuses.clear()
    war.position = base + Vector2(-40, 0)
    rogue.position = base + Vector2(40, 0)
    war.target = e1
    rogue.target = e1
    var info2 := DamageInfo.make(10.0, "physical", rogue, 0.05, rogue.combat_rng)
    rogue.synergy_before_hit(e1, info2)
    check(is_equal_approx(info2.crit_chance, 0.05 + rogue.syn_crit) and not Game.synergy_codex.has("flank"), "no flanking synergy any more (D-142)")
    check(not SynergyDefs.SYNERGIES.has("flank") and not SynergyDefs.SYNERGIES.has("back_to_back") and not SynergyDefs.SYNERGIES.has("tank_wall"),
        "flanking, back to back and the shield wall are gone (D-142)")
    check(is_equal_approx(float(CombatRules.STATUS["marked"]["in_dmg"]), 1.15), "the archer's mark: +15% damage from the whole squad (D-142)")
    war.hero.relationships[mage.hero.id] = {"level": 80, "status": "trusted_ally", "interactions": 5}
    mage.hero.relationships[war.hero.id] = {"level": 80, "status": "trusted_ally", "interactions": 5}
    war.position = base
    mage.position = base + Vector2(60, 0)
    war.combat_t = 3.0
    SquadSynergies.update(sb.heroes, [], null, null, map)
    check(war.syn_in < 1.0 and mage.syn_in < 1.0 and Game.synergy_codex.has("friends"), "bond: friends near each other take less damage")
    rogue.position = base + Vector2(0, 100)
    archer.position = base + Vector2(0, 160)
    SquadSynergies.update(sb.heroes, [], null, null, map)
    check(rogue.synergy_vision == 1 and archer.synergy_vision == 1 and Game.synergy_codex.has("shared_sight"), "exploration: two scouts share sight")
    check(float(chef.contrib.get("syn_cook", 0.0)) >= 1.0, "camp: the chef cooked for the camp (synergy fired)")
    check(SynergyDefs.SYNERGIES.has("gather_pair") and String(SynergyDefs.info("gather_pair")["type"]) == "gather", "gathering: defined (its effect belongs to gather_node, pista C)")
    _fresh(e1, base)
    e1.apply_status("frozen", 2.0)
    var info3 := DamageInfo.make(10.0, "physical", war)
    war.synergy_before_hit(e1, info3)
    check(info3.amount > 10.0 and not e1.has_status("frozen"), "combo: a physical blow shatters a frozen foe")
    _fresh(e1, base)
    e1.taunt(war, 3.0)
    var info4 := DamageInfo.make(10.0, "physical", mage)
    info4.set_meta("aoe", true)
    e1._on_hit(info4, 10)
    check(e1.threat_of(mage) == 0.0, "combo: area damage on a taunted foe draws no threat")

    # --- 6 codex in the save ---------------------------------------------------------------------
    var codex_before := Game.synergy_codex.duplicate()
    check(SynergyDefs.shown_name("stun_crit", codex_before) == "Opening" and SynergyDefs.shown_name("bard", codex_before) == "???", "the codex shows names once discovered, ??? before")
    Game.save_game()
    Game.synergy_codex.clear()
    Game.load_game()
    check(Game.synergy_codex == codex_before, "the synergy codex survives save/load (%d found)" % codex_before.size())
    var old_save := {"version": Game.SAVE_VERSION, "heroes": [], "party": ["", "", "", "", ""]}
    Game.apply_save(old_save)
    check(Game.synergy_codex.is_empty(), "an older save without a codex loads with an empty one")

    # --- 7 skill choices at 2 / 5 / 10 ------------------------------------------------------------
    var hd := HeroGenerator.generate(424243, 3)
    hd.hero_class = "class.warrior"
    hd.skills.clear()
    hd.loadout.clear()
    hd.skill_choices.clear()
    hd.level = 1
    hd.xp = 0
    hd.ensure_skills()
    check(SkillDefs.choice_levels() == [2, 5, 10], "choice levels: 2, 5 and 10 (D-142)")
    var levels: Array = []
    while hd.level < 16:
        hd.add_xp(hd.xp_to_next() - hd.xp)
    for ch in hd.skill_choices:
        levels.append(int(ch["level"]))
    check(levels == [2, 5, 10], "a hero from 1 to 16 gets choices only at 2, 5 and 10 (%s)" % str(levels))
    check((hd.skill_choices[0]["options"] as Array).size() == SkillDefs.CHOICE_OPTIONS, "each choice offers 3 options")
    var first: Array = (hd.skill_choices[0]["options"] as Array).duplicate()
    hd.choose_skill(0, String(first[0]))
    check(hd.skills.has(first[0]) and not hd.skills.has(first[1]) and hd.skill_choices.size() == 2, "choosing one: the others are not learned")
    while not hd.skill_choices.is_empty():
        hd.choose_skill(0, String(hd.skill_choices[0]["options"][0]))
    hd.learn_skill("shield_wall")
    check(hd.loadout.size() <= SkillDefs.MAX_SLOTS and SkillDefs.MAX_SLOTS == 3, "Q = basic attack + at most 3 actives on W E R: %d" % hd.loadout.size())
    check(SkillDefs.level_choices("class.warrior", [], 2, 9, 1).size() == SkillDefs.CHOICE_OPTIONS + 1, "a skill tome adds one option")
    check(SandboxScreen.SKILL_KEYS == "WER", "skills on W E R (Q stays the basic attack)")
    var scr := SkillChoiceScreen.make(hd, 0)
    check(scr != null, "the choice screen builds")
    scr.free()

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_pista_a.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_pista_a.json.bak"))
    get_tree().quit(1 if fails > 0 else 0)
