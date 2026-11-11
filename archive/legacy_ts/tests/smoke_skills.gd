extends Control
## Skills and classes (combat Phase 3, D-040..D-046): class resources, casting and interrupts, every
## effect type, new statuses, starting skill, level choices, skill books, Library, save v8. Run:
##   godot --headless --path . res://tests/smoke_skills.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _give(h: SandboxHero, id: String) -> void:
    h.slots.clear()
    h.slots.append(id)
    h.cds.clear()
    h.res = h.res_max
    h.crit_chance = 0.0


func _fresh(e: SandboxEnemy, at: Vector2) -> void:
    e.base_max_hp = 5000            # never dies here, so damage can be compared
    e.max_hp = 5000
    e.dead = false
    e.alive = true
    e.visible = true
    e.statuses.clear()
    e.hp = e.max_hp
    e.position = at
    e.state = SandboxEnemy.State.IDLE
    e.taunt_t = 0.0
    e.focus = null


func _ready() -> void:
    print("== Skill tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_skills.json"
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
    var h: SandboxHero = sb.heroes[0]
    var h1: SandboxHero = sb.heroes[1]
    if h.res_kind == "none":                                        # D-090: commoners pay nothing; costs are tested with mana
        h.res_kind = "mana"
        h.res_max = 100.0
    var e1: SandboxEnemy = sb.enemies[0]
    var e2: SandboxEnemy = sb.enemies[1]
    var squad: Array = sb.heroes
    var base := map.center_of(Vector2i(6, 15))
    for i in sb.heroes.size():
        sb.heroes[i].position = base + Vector2(0, 400 + i * 40)    # out of the way
    h.position = base
    h.combat_tick([], map)                                          # gives the hero its map
    var foes: Array = [e1, e2]

    # --- statuses ------------------------------------------------------------------------
    _fresh(e1, base + Vector2(40, 0))
    var d0 := CombatRules.resolve(DamageInfo.make(20.0, "physical", null), e1)
    e1.apply_status("marked", 5.0)
    var d1 := CombatRules.resolve(DamageInfo.make(20.0, "physical", null), e1)
    check(d1 > d0, "Marked: the target takes more damage (%d -> %d)" % [d0, d1])
    h.hp = h.max_hp / 2
    var hp0 := h.hp
    h.apply_status("regen", 5.0, 10.0)
    h.tick_combat(1.0)
    check(h.hp > hp0, "Regenerating heals over time")
    h.apply_status("poison", 5.0, 2.0)
    h.apply_status("stun", 5.0)
    h.apply_status("shield", 5.0, 30.0)
    check(h.cleanse() == 2 and not h.has_status("poison") and not h.has_status("stun") and h.has_status("shield"), "cleanse removes ailments, keeps shields")
    h.statuses.clear()
    h.hp = h.max_hp

    # --- interrupts (D-142: only Ambush, Interrupting Shot and Counterspell) -------------------
    var with_interrupt: Array = SkillDefs.SKILLS.keys().filter(func(id): return (SkillDefs.SKILLS[id]["effects"] as Array).any(func(e): return String(e["t"]) == "interrupt"))
    with_interrupt.sort()
    var expected: Array = SkillDefs.INTERRUPTERS.duplicate()
    expected.sort()
    check(with_interrupt == expected, "only %s interrupt casts %s" % [str(expected), str(with_interrupt)])
    _fresh(e1, base + Vector2(40, 0))
    e1.state = SandboxEnemy.State.WINDUP
    e1._timer = 0.5
    _give(h, "shield_bash")
    check(h.use_skill_slot(0, foes, squad) and e1.state == SandboxEnemy.State.WINDUP and e1.has_status("stun"), "Shield Bash stuns but no longer breaks the wind-up")
    _fresh(e1, base + Vector2(40, 0))
    e1.state = SandboxEnemy.State.WINDUP
    e1._timer = 0.5
    e1.apply_status("stun", 1.0)
    e1.tick(0.05, squad, map)
    check(e1.state == SandboxEnemy.State.WINDUP and is_equal_approx(e1._timer, 0.5), "a stun pauses an enemy wind-up instead of breaking it")
    for sid in ["ambush", "interrupt_shot", "counterspell"]:
        _fresh(e1, base + Vector2(40, 0))
        e1.state = SandboxEnemy.State.WINDUP
        e1._timer = 0.5
        _give(h, sid)
        var used := h.use_skill_slot(0, foes, squad)
        h._tick_pending(0.5)                                         # arrows and bolts fly before they land
        check(used and e1.state == SandboxEnemy.State.RECOVER, "%s breaks the wind-up" % sid)
    _fresh(e1, base + Vector2(40, 0))
    e1.apply_status("slow", 3.0)
    e1.state = SandboxEnemy.State.WINDUP
    e1._timer = 0.5
    e1.tick(0.05, squad, map)
    check(e1.state == SandboxEnemy.State.WINDUP, "a slow (not control) does not interrupt")

    _fresh(e1, base + Vector2(150, 0))
    _give(h, "fire_burst")
    var full := h.res
    check(h.use_skill_slot(0, foes, squad) and h.is_casting() and h.res < full, "a cast starts and pays its cost")
    h.apply_status("stun", 1.0)
    h.tick(0.05)
    check(not h.is_casting() and is_equal_approx(h.res, full) and h.skill_cd(0) <= SandboxHero.CAST_BREAK_CD, "a stun breaks the hero's cast: cost refunded, short cooldown")
    h.statuses.clear()
    _give(h, "fire_burst")
    h.use_skill_slot(0, foes, squad)
    var wp: Array[Vector2] = [base + Vector2(0, 60)]
    h.order_move(wp)
    check(not h.is_casting() and is_equal_approx(h.res, full), "a move order cancels the cast (D-016: the order wins)")
    h.path.clear()
    _give(h, "frost_bolt")
    h.res = 1.0
    check(not h.use_skill_slot(0, foes, squad) and h.last_refusal.begins_with("not enough"), "refused without enough resource, with its reason")

    # --- class resources (D-041) -------------------------------------------------------------
    h.res_kind = "fury"
    h.res_max = 100.0
    h.res = 0.0
    _fresh(e1, base + Vector2(40, 0))
    h._basic_attack(e1)
    check(h.res > 0.0, "Fury grows when the warrior hits")
    var fury := h.res
    h.target = null
    h.combat_t = 0.0                  # D-090: out of combat
    h.tick(1.0)
    check(h.res < fury, "Fury cools down out of combat")
    h.res_kind = "mana"
    h.res = 0.0
    h.tick(1.0)
    var calm := h.res
    check(calm > 0.0, "D-090: mana comes back slowly out of combat")
    h.combat_t = SkillDefs.COMBAT_LINGER
    h.tick(1.0)
    check(h.res - calm > 0.0 and h.res - calm < calm, "D-090: while fighting it comes back slower still")
    check(SkillDefs.resource_of("class.warrior") == "fury" and SkillDefs.resource_of("class.archer") == "concentration" and SkillDefs.resource_of("class.rogue") == "energy"
        and SkillDefs.resource_of("class.cleric") == "mana" and SkillDefs.resource_of("class.commoner") == "none", "class resources follow D-090")

    # --- effect types ------------------------------------------------------------------------
    _fresh(e1, base + Vector2(40, 0))
    _fresh(e2, base + Vector2(-40, 0))
    h1.position = base + Vector2(0, 30)
    e2.focus = h1
    e1.focus = h
    _give(h, "war_cry")
    check(h.use_skill_slot(0, foes, squad) and e1.taunted_by == h and e2._nearest_hero(squad) == h, "War Cry taunts nearby enemies onto the warrior")
    check(h.has_status("shield"), "War Cry also shields the warrior")
    h.statuses.clear()

    _fresh(e1, base + Vector2(30, 0))
    _give(h, "shove")
    var dist0 := e1.position.distance_to(h.position)
    h.use_skill_slot(0, foes, squad)
    check(e1.position.distance_to(h.position) > dist0 + 20.0, "Shove knocks the enemy back")

    _fresh(e1, base + Vector2(40, 0))
    _fresh(e2, base + Vector2(400, 0))
    e1.focus = h1
    _give(h, "backstab")
    h.use_skill_slot(0, [e1], squad)
    var busy_dmg := e1.max_hp - e1.hp
    _fresh(e1, base + Vector2(40, 0))
    e1.focus = h
    _give(h, "backstab")
    h.use_skill_slot(0, [e1], squad)
    check(busy_dmg > e1.max_hp - e1.hp, "Backstab hits harder on a foe busy with someone else")

    _fresh(e1, base + Vector2(40, 0))
    _give(h, "smoke_bomb")
    h.use_skill_slot(0, foes, squad)
    var zone: CombatZone = null
    for c in h.get_parent().get_children():
        if c is CombatZone:
            zone = c
    check(zone != null, "Smoke Bomb leaves a zone")
    if zone != null:
        zone.tick(0.05)
        check(e1.has_status("weaken"), "a foe inside the smoke is weakened")
        zone.duration = 0.0
        zone.tick(0.05)

    for x in squad:
        x.hp = x.max_hp
    h1.hp = h1.max_hp / 3
    h1.position = base + Vector2(0, 60)
    _give(h, "heal")
    check(h.use_skill_slot(0, foes, squad) and h.cast_target == h1, "Heal aims at the most wounded ally in range")
    var h1_hp := h1.hp
    h.tick(float(SkillDefs.info("heal")["cast"]) + 0.05)
    check(h1.hp > h1_hp, "the heal lands after its cast")
    for x in squad:
        x.hp = x.max_hp
    _give(h, "heal")
    check(not h.use_skill_slot(0, foes, squad) and h.last_refusal == "nobody is hurt", "Heal is refused when nobody is hurt")

    var far: SandboxHero = sb.heroes[4]
    far.position = base + Vector2(0, 600)
    _give(h, "rally")
    h.use_skill_slot(0, foes, squad)
    check(h1.has_status("shield") and not far.has_status("shield"), "Rally shields allies around, not far ones")

    _fresh(e1, base + Vector2(160, 0))
    _give(h, "charge")
    h.use_skill_slot(0, foes, squad)
    check(h.position.distance_to(e1.position) < 60.0 and e1.has_status("root"), "Charge dashes to the foe and roots it")
    h.position = base
    _fresh(e1, base + Vector2(40, 0))
    _give(h, "blink")
    h.use_skill_slot(0, foes, squad)
    check(h.position.distance_to(e1.position) > 100.0 and not map.is_blocked(h.position), "Blink teleports away from the nearest foe onto walkable ground")
    h.position = base

    # --- equipment powers and consumables in combat (HQ session, D-039) -------------------------
    h.position = base
    _fresh(e1, base + Vector2(40, 0))
    h.item_mods = {"lifesteal": 0.5}
    h.hp = h.max_hp / 2
    var hp_ls := h.hp
    h._basic_attack(e1)
    check(h.hp > hp_ls, "lifesteal heals on a basic hit")
    h.item_mods = {"procs": [{"on_hit_status": "burn", "chance": 1.0, "dur": 3.0, "mult": 0.1}]}
    _fresh(e1, base + Vector2(40, 0))
    h._basic_attack(e1)
    check(e1.has_status("burn"), "a unique's on-hit power applies its status")
    h.item_mods = {"thorns": 0.5}
    _fresh(e1, base + Vector2(30, 0))
    h.statuses.clear()
    h.hp = h.max_hp
    h.take_hit(DamageInfo.make(40.0, "physical", e1))
    check(e1.hp < e1.max_hp, "thorns hurt a melee attacker")
    h.item_mods = {"slow_immune": 1.0}
    h.apply_status("slow", 3.0)
    check(is_equal_approx(h.move_mult(), 1.0), "slow immunity ignores slows")
    h.item_mods = {}
    h.statuses.clear()
    h.hero.bag = {"potion": 1, "antidote": 1}
    h.hp = h.max_hp / 5
    var hp_p := h.hp
    h._potion_cd = 0.0
    h._use_consumables(0.05)
    check(h.hp > hp_p and not h.hero.bag.has("potion"), "a hurt hero drinks a carried potion on their own")
    h.apply_status("poison", 5.0, 1.0)
    h._potion_cd = 0.0
    h._use_consumables(0.05)
    check(not h.has_status("poison") and not h.hero.bag.has("antidote") and h.was_poisoned, "a carried antidote cures poison (and the poisoning is remembered for after the mission)")
    h.hero.bag["potion"] = 1
    h.hp = h.max_hp / 5
    h._potion_cd = 0.0
    h._use_consumables(0.05)
    check(h.hero.bag.has("potion") and h.drink_potion().contains("ready"), "a second healing potion waits the 5-minute cooldown (owner 2026-11-02)")
    h.heal_potion_cd = 0.0
    check(h.drink_potion() == "" and not h.hero.bag.has("potion"), "after the cooldown the potion can be drunk again")
    h.hp = h.max_hp

    # every skill in the data is well formed
    var bad: Array = []
    for sid in SkillDefs.SKILLS:
        var sk: Dictionary = SkillDefs.SKILLS[sid]
        for k in ["name", "class", "cost", "cd", "cast", "range", "target", "effects", "desc"]:
            if not sk.has(k):
                bad.append("%s.%s" % [sid, k])
        for eff in sk["effects"]:
            if String(eff["t"]) == "status" and not CombatRules.STATUS.has(String(eff["id"])):
                bad.append("%s status %s" % [sid, eff["id"]])
    for cls in SkillDefs.KITS:
        for sid in (SkillDefs.KITS[cls]["start"] as Array) + (SkillDefs.KITS[cls]["learn"] as Array):
            if not SkillDefs.SKILLS.has(sid):
                bad.append("%s kit %s" % [cls, sid])
    check(bad.is_empty(), "skill data is complete %s" % str(bad))

    # --- hero data: starter, level choices, loadout (D-043..D-045) ------------------------------
    var starters := {}
    for s in 40:
        var st := SkillDefs.starter_for("class.warrior", 1000 + s)
        starters[st] = true
        if st != SkillDefs.starter_for("class.warrior", 1000 + s):
            starters["nondeterministic"] = true
    check(starters.size() >= 2 and starters.keys().all(func(x): return (SkillDefs.KITS["class.warrior"]["start"] as Array).has(x)), "starters are deterministic per seed and vary within the class pool (D-044)")
    var hd := HeroGenerator.generate(424242, 3)
    check(hd.skills.is_empty() and hd.loadout.is_empty() and hd.skill_choices.is_empty(), "a new hero is born with only Q, no active (D-142)")
    check(SkillDefs.choice_levels() == [2, 5, 10] and SkillDefs.MAX_SLOTS == 3, "choices at levels 2, 5 and 10 for W, E and R: 4 actives at most (D-142)")
    hd.hero_class = "class.warrior"
    hd.skills.clear()
    hd.loadout.clear()
    hd.ensure_skills()
    check(hd.skills.is_empty(), "a hero with a new class gets no starter either (D-142)")
    hd.learn_skill("cleave", false)
    hd.level = 4
    hd.xp = 0
    while hd.level < 5:
        hd.add_xp(hd.xp_to_next())
    check(hd.skill_choices.size() == 1 and int(hd.skill_choices[0]["level"]) == 5, "reaching level 5 offers a skill choice (D-045)")
    var opts: Array = hd.skill_choices[0]["options"]
    check(opts.size() >= 2 and opts.size() <= 3 and not opts.has(hd.skills[0]), "the choice has 2-3 class skills the hero does not know")
    check(not hd.choose_skill(0, "meteor"), "a skill outside the offered options is refused")
    var pick := String(opts[0])
    check(hd.choose_skill(0, pick) and hd.skills.has(pick) and hd.loadout.has(pick) and hd.skill_choices.is_empty(), "choosing learns the skill and fills a slot")
    check(not hd.learn_skill("meteor"), "a warrior cannot learn a mage skill")
    check(hd.equip_skill(0, pick) and hd.loadout[0] == pick and hd.loadout.size() == 2, "equip_skill moves a skill to Q (swapping)")
    var rt := HeroData.from_dict(JSON.parse_string(JSON.stringify(hd.to_dict())))
    check(rt.skills == hd.skills and rt.loadout == hd.loadout, "skills and loadout survive save/load")

    # v7 hero (no skills saved) at level 12 -> starter + choices for levels 2, 5 and 10 (D-090)
    var old := hd.to_dict()
    old.erase("skills")
    old.erase("loadout")
    old.erase("skill_choices")
    old["level"] = 12
    var mig := HeroData.from_dict(JSON.parse_string(JSON.stringify(old)))
    check(mig.skills.is_empty() and mig.skill_choices.size() == 3, "v7 hero migrates: pending choices for levels 2, 5 and 10 (D-142)")
    check(mig.trust == hd.trust and mig.traits == hd.traits and mig.hero_name == hd.hero_name, "migration does not reroll the hero (D-004)")

    # --- skill books, Library, save v8 (D-046) --------------------------------------------------
    Game.new_game()
    Game.heroes[hd.id] = hd
    var r10 := Game.complete_floor(10, "boss")
    check((r10["skill_books"] as Array).size() >= 1, "the floor-10 boss always drops a skill book")
    var r3 := Game.complete_floor(3, "rescue")
    check((r3["skill_books"] as Array).size() >= 1, "a rescue mission rewards a skill book")
    Game.skill_books.clear()
    Game.grant_skill_book("meteor")
    check(Game.use_skill_book(hd, "meteor") != "" and int(Game.skill_books.get("meteor", 0)) == 1, "a book for another class cannot be read and is kept")
    var unknown := ""
    for sid in SkillDefs.KITS["class.warrior"]["learn"]:
        if not hd.skills.has(sid):
            unknown = String(sid)
    Game.grant_skill_book(unknown)
    check(Game.use_skill_book(hd, unknown) == "" and hd.skills.has(unknown) and not Game.skill_books.has(unknown), "reading a book teaches the skill and consumes the book")
    check(Game.use_skill_book(hd, unknown) != "", "a book you no longer have cannot be read")
    check(Game.library_cost() == 0 and Game.library_transcribe("class.warrior") == "", "no Library, no transcription")
    Game.town_buildings["library"] = 1
    Game.hq_outputs["materials"] = 500
    var book := Game.library_transcribe("class.mage")
    check(book != "" and int(Game.hq_outputs["materials"]) == 500 - TownTables.LIBRARY_BASE_COST and Game.skill_books.has(book), "the Library transcribes a book for materials")
    check(SkillDefs.usable_by(book, "class.mage"), "the Library book is of the chosen class (D-046)")
    Game.save_path = "user://smoke_skills.json"
    Game.save_game()
    var books_before := Game.skill_books.duplicate()
    Game.skill_books.clear()
    Game.load_game()
    check(Game.skill_books == books_before and (Game.heroes[hd.id] as HeroData).skills == hd.skills, "skill books and hero skills survive save/load (v%d)" % Game.SAVE_VERSION)
    var v7 := {"version": 7, "gems": 1, "stones": 1, "books": 1, "pity4": 0, "pity5": 0, "pull_count": 0, "summon_log": [], "memorial": [],
        "party": ["", "", "", "", ""], "heroes": [old], "hq_outputs": {"food": 1, "materials": 2, "medicine": 3}, "town_buildings": TownTables.start_levels(),
        "tower_maps": {}, "tower_cleared": {}}
    Game.apply_save(v7)
    check(Game.skill_books.is_empty() and (Game.heroes[hd.id] as HeroData).skills.is_empty(), "a v7 save loads: empty book shelf, no starter (D-142)")

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_skills.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_skills.json.bak"))
    get_tree().quit(1 if fails > 0 else 0)
