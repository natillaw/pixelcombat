extends Control
## D-080: the Master. Creation (character creator) -> save -> load keeps looks, class and trait; an old
## save without a Master asks for one and keeps the roster; the Master cannot be sacrificed, absorbed,
## sold, put to work or sent offline; always slot 1; the only driven hero in an expedition; never dies
## (lost -> the expedition fails and they come home wounded); every trait has a downside.
## D-081: no elf Master (an elf one migrates), commands (unlock, cooldown, radius, Obedience), Leadership
## (inside the radius only, diminishing returns), panic, bond events and persistence, memories once,
## the mirror (looks only), hardcore (the Master's death ends the game; not in normal).
##   godot --headless --path . res://tests/smoke_master.tscn --quit-after 3000
var fails := 0
const PATH := "user://smoke_master.json"


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Master tests ==")
    Game.autosave = false
    Game.save_path = PATH
    Game.new_game()
    check(Game.needs_master(), "a new account has no Master yet: the creator opens")

    # --- the creator -----------------------------------------------------------------------------
    var mc := MasterCreator.new()
    add_child(mc)
    await get_tree().process_frame
    mc.confirm()
    check(Game.master() == null and mc.block() != "", "the creator refuses an empty name and surname")
    mc._first.text = "Aldric"
    mc._last.text = "Vane"
    mc.step_look("race", 1)
    mc.step_look("body", 1)
    var body := String(mc.choices["look"]["body"])
    mc.step_look("hair_color", 1)
    mc.choose_class("class.mage")
    mc.choose_trait("trait.curious")
    var wanted: Dictionary = (mc.choices["look"] as Dictionary).duplicate()
    mc.confirm()
    var m := Game.master()
    check(m != null and m.is_master and m.hero_name == "Aldric Vane" and m.first_name == "Aldric" and m.surname == "Vane",
        "Confirm makes the Master with the chosen name and surname")
    check(m != null and m.hero_class == "class.mage" and m.traits == ["trait.curious"] and m.stars == MasterDefs.STARS,
        "class and trait are the chosen ones; mid rarity (%d stars)" % MasterDefs.STARS)
    var same_look := true
    for k in wanted:
        if m == null or str(m.look.get(k, "")) != str(wanted[k]):
            same_look = false
    check(same_look and m.look["body"] == body, "the look is exactly the one in the preview")
    check(m != null and String(m.equipment.get("chest", {}).get("base", "")) == "plain_shirt" and LpcWardrobe.layers_for(m.look, m.hero_class, ItemVisuals.equipment_layers(m.equipment)).has(LpcWardrobe.STARTER_OUTFIT["chest"]),
        "the Master wears the plain starter outfit of every summon")
    check(m != null and Game.party[0] == m.id and m.innate.is_empty(), "the Master takes slot 1 and has no summon gifts")
    mc.queue_free()

    # --- save / load ---------------------------------------------------------------------------
    Game.save_game()
    var id := m.id
    var look_before: Dictionary = m.look.duplicate()
    Game.new_game()
    Game.load_game()
    var m2 := Game.master()
    check(m2 != null and m2.id == id and m2.is_master and m2.hero_name == "Aldric Vane" and m2.surname == "Vane",
        "save -> load keeps the Master and their name")
    check(m2 != null and m2.look == look_before and m2.hero_class == "class.mage" and m2.traits == ["trait.curious"],
        "save -> load keeps the same looks, class and trait")
    check(Game.party[0] == id and not Game.needs_master(), "after loading the Master is still in slot 1")

    # --- the first ten summons fill the slots after the Master ---------------------------------
    var ten: Array = Game.starter_summons()
    check(ten.size() == SummonConfig.STARTER_COUNT, "the ten free summons still come with a Master already made")
    check(Game.party[0] == id and Game.party.slice(1).all(func(x): return x != "" and x != id), "first squad: Master in slot 1 + 4 summons")
    check(Game.master().bed == Game.MASTER_BED and Game.max_hero_capacity() >= Game.heroes.size() - 1,
        "the Master sleeps in the Hall and does not take a dorm bed")

    # --- party rules ---------------------------------------------------------------------------
    var other: HeroData = Game.heroes[Game.party[1]]
    Game.assign_party(0, other.id)
    check(Game.party[0] == id, "nobody else can take slot 1")
    Game.assign_party(3, id)
    check(Game.party[0] == id and Game.party[3] != id, "the Master cannot be moved to another slot")
    Game.clear_slot(0)
    check(Game.party[0] == id, "slot 1 cannot be emptied")
    Game.clear_party()
    check(Game.party[0] == id and Game.party.slice(1).all(func(x): return x == ""), "Clear all keeps the Master")
    check(Game.party_heroes()[0] == Game.master(), "the party always starts with the Master")

    # --- what the Master can never be ----------------------------------------------------------
    var mm := Game.master()
    check(not bool(Game.sacrifice_preview(mm)["ok"]) and not bool(Game.sacrifice(mm).get("ok", false)) and Game.heroes.has(id),
        "sacrificing the Master is refused")
    var spare: HeroData = Game.heroes.values().filter(func(h): return not h.is_master)[0]
    check(not bool(Game.synthesis_preview(spare, [mm])["ok"]) and Game.heroes.has(id), "absorbing the Master in a synthesis is refused")
    check(Game.consumable_block(mm) != "", "the Master cannot be consumed or sold (%s)" % Game.consumable_block(mm))
    check(Game.assign_work(mm, "kitchen") != "" and mm.hq_assignment == "", "the Master cannot be put to work")
    check(OfflineExpeditions.block(Game, 1, [id], 0.0) != "", "the Master cannot go on an offline expedition")
    check(not Game.record_death(mm, "test") and Game.heroes.has(id) and Game.memorial.is_empty(), "the Master never goes to the memorial")

    # --- every trait has an upside and a downside -----------------------------------------------
    var free: Array = []
    for t in HeroTables.TRAITS:
        if MasterCreator.trait_pros(t).is_empty() or MasterCreator.trait_cons(t).is_empty():
            free.append(t)
    check(free.is_empty(), "no trait is free: every one shows an upside and a downside %s" % str(free))

    # --- an old save without a Master ----------------------------------------------------------
    Game.new_game()
    Game.gems = 100000
    var pulled: Array = Game.pull(6)
    for i in Game.PARTY_SIZE:
        Game.assign_party(i, (pulled[i] as HeroData).id)
    Game.onboarded = true
    Game.save_game()
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    raw["version"] = 16
    for hd in raw["heroes"]:
        (hd as Dictionary).erase("is_master")
    Game.apply_save(raw)
    var before := Game.heroes.size()
    var was_first := String(Game.party[0])
    check(Game.needs_master() and before == 6, "a v16 save loads with its 6 heroes and asks for a Master")
    var old_m := Game.create_master({"first": "Old", "last": "Hand", "class": "class.warrior", "trait": "trait.stoic"})
    check(Game.heroes.size() == before + 1 and pulled.all(func(h): return Game.heroes.has((h as HeroData).id)), "creating the Master keeps the whole roster")
    check(Game.party[0] == old_m.id and Game.heroes.has(was_first), "the Master takes slot 1; whoever had it stays on the roster")
    check(Game._migrate({"version": 16})["version"] == Game.SAVE_VERSION and Game.SAVE_VERSION >= 17, "save v16 -> current")

    # --- in the tower: the Master is the driven hero and never dies -----------------------------
    var floor_num := 3
    for i in range(1, Game.PARTY_SIZE):
        Game.party[i] = ""
    for i in range(1, TowerExpedition.party_max(floor_num)):
        Game.assign_party(i, (pulled[i] as HeroData).id)
    var sb := SandboxScreen.new(floor_num)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    await get_tree().process_frame
    check(sb.real_squad and sb.master_hero != null and sb.master_hero.hero == old_m, "the Master goes in as the first hero of the squad")
    check(sb.controlled() == sb.master_hero, "the Master is the driven hero from the start")
    sb.select_slot(1)
    check(sb.controlled() == sb.master_hero, "1-5 no longer switches the driven hero")
    sb.group_view()
    check(sb.controlled() == sb.master_hero, "the squad view keeps the Master driven")
    check(sb.heroes.filter(func(h): return h.is_controlled()).size() == 1, "the other heroes stay autonomous")
    sb.master_hero.go_down()
    sb.master_hero.agony = 0.01
    for i in 3:
        sb.tick(0.05)
    check(sb.master_hero.lost and not sb.master_hero.dead and sb.mission_state == SandboxScreen.Mission.FAILED,
        "the Master's agony runs out: no death, the expedition fails")
    check(Game.heroes.has(old_m.id) and Game.master() == old_m and Game.memorial.is_empty(), "the Master is still on the roster, not in the memorial")
    check(old_m.has_disease(MasterDefs.WOUND_DISEASE), "the Master comes home wounded (%s)" % MasterDefs.WOUND_DISEASE)
    sb.queue_free()
    await _d081()

    for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)


func _squad(floor_num: int, crew: Array) -> SandboxScreen:
    for i in range(1, Game.PARTY_SIZE):
        Game.party[i] = ""
    for i in range(1, TowerExpedition.party_max(floor_num)):
        Game.assign_party(i, (crew[i - 1] as HeroData).id)
    var sb := SandboxScreen.new(floor_num)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    await get_tree().process_frame
    return sb


func _d081() -> void:
    print("-- D-081 --")
    # 0. no elves for the Master
    var mc := MasterCreator.new()
    check(not MasterDefs.RACES.has("elf") and not mc._options("race").has("elf"), "the creator offers no elf")
    mc.free()
    var elf := HeroGenerator.create_master(777, {"first": "E", "last": "L"}).to_dict()
    elf["look"]["race"] = "elf"
    elf["look"]["ears"] = "ears_elven"
    var hair := String(elf["look"]["hair"])
    var back := HeroData.from_dict(elf)
    check(back.look["race"] == "human" and back.look["ears"] == "" and back.look["hair"] == hair,
        "a saved elf Master migrates to human and keeps the rest of the look")
    check(Game.SAVE_VERSION >= 18 and Game._migrate({"version": 17})["version"] == Game.SAVE_VERSION, "save v17 -> v18 (and on to the current version)")
    # v19 -> v20 (integration + 03b): new fields get defaults and the ranger / explorador becomes the archer
    var v19 := {"version": 19, "heroes": [{"class": "class.ranger", "skill_choices": [{"level": 5, "options": ["volley"]}]},
        {"class": "class.explorador"}], "memorial": [{"class": "class.ranger", "snapshot": {"class": "class.ranger"}}]}
    var m20 := Game._migrate(v19)
    var h20: Dictionary = m20["heroes"][0]
    check(int(m20["version"]) == Game.SAVE_VERSION and Game.SAVE_VERSION >= 20 and (m20["synergy_codex"] as Dictionary).is_empty(),
        "save v19 -> v20: synergy codex starts empty")
    check(h20["class"] == "class.archer" and m20["heroes"][1]["class"] == "class.archer" and (h20["hoard"] as Array).is_empty()
        and int(h20["bonus_skill_choice"]) == 0 and h20["skill_choices"][0]["bonus"] == false, "save v19 -> v20: ranger/explorador -> archer, hoard and tome fields")
    check(m20["memorial"][0]["class"] == "class.archer" and m20["memorial"][0]["snapshot"]["class"] == "class.archer", "save v19 -> v20: memorial archers")
    var sim_party: GDScript = load("res://tools/sim/sim_party.gd")
    check(HeroData.from_dict({"class": "class.ranger"}).hero_class == "class.archer" and sim_party.class_id("ranger") == "class.archer"
        and sim_party.class_id("explorador") == "class.archer" and sim_party.class_id("class.ranger") == "class.archer", "old ranger ids are read as the archer")

    Game.new_game()
    var m := Game.create_master({"first": "Lead", "last": "Er", "class": "class.warrior", "trait": "trait.brave"})
    Game.gems = 100000
    var crew: Array = Game.pull(6)

    # 1. commands unlock by level
    check(MasterRules.commands(m) == ["focus_fire"], "level 1: only Focus fire")
    m.level = 5
    check(MasterRules.commands(m) == ["focus_fire", "regroup"], "level 5: Regroup too")
    m.level = 10
    check(MasterRules.commands(m) == ["focus_fire", "regroup", "hold_fast"], "level 10: Hold fast too")
    check(MasterRules.commands(crew[0]) .is_empty(), "only the Master has commands")

    # 2. Leadership grows with level, with diminishing returns
    m.level = 1
    var r1 := MasterRules.leadership_radius(m)
    m.level = 30
    var r30 := MasterRules.leadership_radius(m)
    m.level = 59
    var r59 := MasterRules.leadership_radius(m)
    check(r30 > r1 and r59 - r30 < r30 - r1 and r59 < MasterDefs.RADIUS_BASE + MasterDefs.RADIUS_EXTRA,
        "Leadership radius %d -> %d -> %d px: grows, more slowly, never past the cap" % [roundi(r1), roundi(r30), roundi(r59)])
    m.level = 1

    # 3. bond
    var h0: HeroData = crew[0]
    check(h0.bond_master == MasterDefs.BOND_START, "a new hero starts at bond %d" % MasterDefs.BOND_START)
    MasterRules.bond_event(h0, "rescued_by_master")
    MasterRules.bond_event(h0, "mvp")
    check(h0.bond_master == MasterDefs.BOND_START + int(MasterDefs.BOND_DELTA["rescued_by_master"]) + int(MasterDefs.BOND_DELTA["mvp"]),
        "being rescued by the Master and MVP raise the bond")
    check(MasterRules.bond_event(m, "mvp") == 0, "the Master has no bond with themself")
    for i in 4:
        Game.assign_party(i + 1, (crew[i] as HeroData).id)
    var b1 := (crew[1] as HeroData).bond_master
    Game.record_death(crew[3], "Slain by left behind", "test")
    check((crew[1] as HeroData).bond_master == b1 + int(MasterDefs.BOND_DELTA["ally_died"]) + int(MasterDefs.BOND_DELTA["left_behind"]),
        "an ally left behind with the Master lowers everybody's bond")
    var b2 := (crew[2] as HeroData).bond_master
    Game.finish_expedition(3, "success", {}, [{"hero": m, "alive": true, "contrib": {}}, {"hero": crew[2], "alive": true, "contrib": {}}], 0, "defense")
    check((crew[2] as HeroData).bond_master >= b2 + int(MasterDefs.BOND_DELTA["floor_cleared"]), "a floor cleared with the Master raises the bond")
    var keep := {}
    for h in Game.heroes.values():
        keep[(h as HeroData).id] = (h as HeroData).bond_master
    Game.save_game()
    Game.new_game()
    Game.load_game()
    check(Game.heroes.values().all(func(h): return (h as HeroData).bond_master == int(keep[(h as HeroData).id])), "bonds survive save -> load")
    m = Game.master()
    crew = crew.filter(func(h): return Game.heroes.has((h as HeroData).id)).map(func(h): return Game.heroes[(h as HeroData).id])

    # 4. memories: the boss of floor 10 unlocks memory_01 once
    var rew := Game.complete_floor(10, "boss")
    check(String((rew["memory"] as Dictionary).get("id", "")) == "memory_01" and m.master_memories == ["memory_01"] and m.leadership_points == 5,
        "beating floor 10 unlocks memory_01 (+5 Leadership)")
    var rew2 := Game.complete_floor(10, "boss")
    check((rew2["memory"] as Dictionary).is_empty() and m.master_memories.size() == 1 and m.leadership_points == 5, "and only once")
    check((Game.complete_floor(3, "defense")["memory"] as Dictionary).is_empty(), "other floors unlock no memory")

    # 5. the mirror
    var before := {"class": m.hero_class, "traits": m.traits.duplicate(), "name": m.hero_name, "bg": m.background_text}
    var nl: Dictionary = m.look.duplicate()
    nl["hair"] = "hair_long"
    nl["race"] = "elf"
    nl["class"] = "class.mage"
    nl["first"] = "Hacker"
    check(Game.restyle_master(nl) == "", "the mirror is free")
    check(m.look["hair"] == "hair_long" and m.look["race"] == "human" and m.look["ears"] == "" and m.hero_class == before["class"]
        and m.traits == before["traits"] and m.hero_name == before["name"] and m.background_text == before["bg"],
        "the mirror changes the hair, never race, class, trait, name or background")
    var me := MasterCreator.new(true)
    add_child(me)
    await get_tree().process_frame
    check(me.edit_mode and me._tabs.get_tab_count() == 1 and not me._rows.has("race") and me._first == null, "the mirror shows only the looks, without race")
    me.queue_free()

    # 6. in the tower: damage, Leadership radius, panic, commands
    var sb := await _squad(3, crew)
    check(sb.master_hero.dmg_mult == MasterDefs.DAMAGE_MULT and MasterDefs.DAMAGE_MULT < 1.0, "the Master deals less damage (leader, not carry)")
    var near: SandboxHero = sb.heroes[1]
    var far: SandboxHero = sb.heroes[2]
    near.position = sb.master_hero.position + Vector2(20, 0)
    far.position = sb.master_hero.position + Vector2(3000, 0)
    check(near.in_master_radius() and not far.in_master_radius(), "the radius is around the Master")
    var base_near := near.hero.obedience + int(MasterRules.bond_tier(near.hero.bond_master)["obey"])
    var base_far := far.hero.obedience + int(MasterRules.bond_tier(far.hero.bond_master)["obey"])
    check(near.effective_obedience() - base_near == MasterRules.obey_bonus(m) and MasterRules.obey_bonus(m) > 0 and far.effective_obedience() == base_far,
        "Leadership adds Obedience inside the radius (+%d) and not outside" % MasterRules.obey_bonus(m))
    sb.shake(near, "ally_down")
    sb.shake(far, "ally_down")
    check(near.hero.composure > far.hero.composure, "Leadership spares Composure inside the radius (%d vs %d)" % [near.hero.composure, far.hero.composure])
    for i in 4:
        sb.shake(far, "ally_died")
    check(far.has_status("panicked") and not far.obeys(), "low Composure: the hero panics and ignores orders")
    check(sb.use_command(1) == -1, "Regroup is locked at level 1")
    far.position = near.position + Vector2(12, 0)
    var n := sb.use_command(0, near.position)
    check(n >= 1 and near.has_status("focused"), "Focus fire: the heroes in range answer (%d)" % n)
    check(sb.use_command(0) == -1 and float(sb.command_cd["focus_fire"]) > 0.0, "then it waits for its cooldown")
    sb.master_hero.hero.level = 10
    check(sb.use_command(2) >= 1 and not far.has_status("panicked") and far.obeys(), "Hold fast ends the panic")
    sb.master_hero.hero.level = 1
    sb.queue_free()

    # 7. hardcore
    Game.hardcore = false
    check(not Game.record_death(Game.master(), "test") and not Game.game_over, "normal game: the Master cannot die")
    Game.new_game()
    var hm := Game.create_master({"first": "Hard", "last": "Core", "hardcore": true})
    check(Game.hardcore, "hardcore is chosen when the game is created")
    Game.gems = 100000
    var hc_crew: Array = Game.pull(3)
    Game.onboarded = true
    var sb2 := await _squad(3, hc_crew)
    sb2.master_hero.go_down()
    sb2.master_hero.agony = 0.01
    for i in 3:
        sb2.tick(0.05)
    check(sb2.master_hero.dead and Game.game_over and Game.master() == null and sb2.mission_state == SandboxScreen.Mission.FAILED,
        "hardcore: the Master bleeds out, dies and the game is over")
    check(int(Game.game_over_info.get("heroes", -1)) == 3 and String(Game.game_over_info.get("name", "")) == hm.display_name(), "the end screen has its summary")
    sb2.queue_free()
    Game.save_game()
    Game.new_game()
    Game.load_game()
    check(Game.game_over and Game.hardcore, "the game stays over after loading")
    Game.new_game()
    Game.onboarded = true
    Game.create_master({"first": "Late", "last": "Choice", "hardcore": true})
    check(not Game.hardcore, "hardcore cannot be switched on after the game was created")

