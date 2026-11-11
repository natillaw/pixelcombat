extends Control
## Combat core (Phase 1): attributes -> stats, damage types and mitigation, crits, statuses,
## downed / agony / rescue / wipe, contextual orders. Run:
##   godot --headless --path . res://tests/smoke_combat_core.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Combat core tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_combat_core.json"
    Game.new_game()
    size = Vector2(1280, 720)

    # --- attributes -> derived stats (D-035)
    var w := HeroGenerator.generate(101, 3)
    w.hero_class = "class.warrior"
    var m := HeroGenerator.generate(101, 3)
    m.hero_class = "class.mage"
    var ws := w.get_stats()
    var ms := m.get_stats()
    check(w.attributes().size() == 5 and int(w.attributes()["vit"]) > int(m.attributes()["vit"]), "warrior has more VIT than a mage")
    check(int(ws["hp"]) > int(ms["hp"]) and int(ws["def"]) > int(ms["def"]), "warrior: more HP and armor")
    check(int(ms["mag"]) > int(ws["mag"]) and String(ms["kind"]) == "magical" and String(ws["kind"]) == "physical", "mage: more magic power, magical basic attacks")
    var lv1 := w.get_stats()
    w.level = 10
    check(int(w.get_stats()["hp"]) > int(lv1["hp"]), "levels raise attributes and stats")

    # --- mitigation by damage type
    check(CombatRules.mitigate(100.0, "physical", 20, 0) < CombatRules.mitigate(100.0, "physical", 0, 0), "armor reduces physical damage")
    check(CombatRules.mitigate(100.0, "magical", 20, 0) == 100, "armor does not stop magic")
    check(CombatRules.mitigate(100.0, "magical", 0, 20) < 100, "magic resistance reduces magic")
    check(CombatRules.mitigate(100.0, "true", 50, 50) == 100, "true damage ignores defences")

    var sb := SandboxScreen.new(0)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    await get_tree().process_frame
    await get_tree().process_frame
    for e in sb.enemies:
        e.alive = false
        e.visible = false
    var h0: SandboxHero = sb.heroes[0]
    var h1: SandboxHero = sb.heroes[1]
    var foe: SandboxEnemy = sb.enemies[0]
    foe.alive = true
    foe.visible = true

    # --- crits (D-037): never miss, some hits crit
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var crits := 0
    for i in 400:
        var info := DamageInfo.make(50.0, "physical", h0, 0.25, rng)
        CombatRules.resolve(info, foe)
        if info.crit:
            crits += 1
        if info.final <= 0:
            crits = -9999
    check(crits > 60 and crits < 140, "about 25%% of hits crit and none miss (%d / 400)" % crits)

    # --- statuses
    foe.hp = foe.max_hp
    foe.apply_status("poison", 3.0, 4.0, h0)
    var hp0 := foe.hp
    foe.tick_combat(1.0)
    check(foe.hp < hp0 and foe.has_status("poison"), "poison deals damage over time")
    foe.tick_combat(3.0)
    check(not foe.has_status("poison"), "statuses expire")
    foe.apply_status("stun", 2.0)
    check(not foe.can_act() and not foe.can_move(), "stun blocks acting and moving")
    foe.statuses.clear()
    foe.apply_status("slow", 2.0)
    check(foe.move_mult() < 1.0 and foe.can_move(), "slow reduces movement")
    foe.statuses.clear()
    h0.apply_status("shield", 10.0, 1000.0)
    var hph := h0.hp
    h0.take_hit(DamageInfo.make(80.0, "true", foe))
    check(h0.hp == hph and h0.has_status("shield"), "a shield absorbs damage first")
    h0.statuses.clear()
    h0.apply_status("weaken", 5.0)
    check(is_equal_approx(h0.outgoing_mult(), 0.75), "weaken lowers outgoing damage")
    h0.statuses.clear()

    # --- downed / agony / rescue (D-036)
    h0.take_damage(999999, foe)
    check(h0.downed and not h0.alive and not h0.dead and is_equal_approx(h0.agony, CombatRules.AGONY_TIME), "0 HP: the hero falls with a %d s agony" % int(CombatRules.AGONY_TIME))
    h1.position = h0.position + Vector2(120, 0)
    sb.select_only([h1])
    check(sb.order_context(h0.position) == "rescue" and h1.order == "rescue", "right-click on a fallen ally gives a rescue order")
    for i in 200:
        sb.tick(0.05)
        if h0.alive:
            break
    check(h0.alive and not h0.downed and h0.has_status("wounded") and h0.max_hp < h0.base_max_hp, "rescue brings the hero back wounded")
    check(h0.hp == maxi(1, roundi(float(h0.max_hp) * CombatRules.RESCUE_HP)), "rescued with 25% of max HP")
    check(h1.hero.memories.any(func(mm): return String(mm["type"]) == "rescue"), "the rescuer remembers the rescue")

    h0.take_damage(999999, foe)
    h1.position = h0.position + Vector2(10, 0)
    h1.order_rescue(h0)
    sb.tick(0.5)
    check(h1.rescue_progress > 0.0, "rescue channel started")
    h1.take_hit(DamageInfo.make(5.0, "true", foe))
    check(is_equal_approx(h1.rescue_progress, 0.0), "taking damage interrupts the rescue")
    h1.stop()
    h0.tick(CombatRules.AGONY_TIME + 1.0)
    check(h0.dead and not h0.downed, "if the agony runs out the hero dies for good")

    # --- contextual orders
    foe.position = h1.position + Vector2(200, 0)       # inside sight: hidden foes cannot be clicked (fog, D-056)
    sb.update_fog()
    sb.select_only([h1])
    check(sb.order_context(foe.position + Vector2(0, -14)) == "attack" and h1.order == "attack" and h1.target == foe, "right-click on an enemy gives an attack order")
    check(sb.order_context(h1.position + Vector2(0, 200)) == "move" and h1.order == "move", "right-click on the ground gives a move order")

    # --- wipe: everyone down -> mission failed, the fallen die
    for h in sb.heroes:
        if h.alive:
            h.take_damage(999999, foe)
    sb.tick(0.05)
    check(sb.mission_state == SandboxScreen.Mission.FAILED and sb.heroes.all(func(h): return h.dead), "whole squad down: mission failed and the fallen die")

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)
