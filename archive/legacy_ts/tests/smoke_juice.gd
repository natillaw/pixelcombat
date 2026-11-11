extends Control
## Pista C (D-110..D-117): juice profiles, the shake/freeze filter, whole-pixel positions, floating
## numbers, party frame bars and gathering spots that run out. Run:
##   godot --headless --path . res://tests/smoke_juice.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Juice tests (pista C) ==")
    Game.autosave = false
    Game.save_path = "user://smoke_juice.json"
    Game.new_game()

    # --- every skill and basic attack has a profile --------------------------------------------
    var missing: Array = SkillDefs.SKILLS.keys().filter(func(id): return not JuiceDefs.has_skill(String(id)))
    check(missing.is_empty(), "every skill has its own juice profile %s" % str(missing))
    var classes: Array = ["warrior", "rogue", "archer", "mage", "cleric", "commoner"]
    check(classes.all(func(c): return JuiceDefs.BASIC.has("basic." + c)), "every class has a basic-attack profile")
    var bad: Array = JuiceDefs.all_ids().filter(func(id): return JuiceProfile.get_profile(String(id)) == null)
    check(bad.is_empty(), "every profile id builds a JuiceProfile %s" % str(bad))
    var fire := JuiceProfile.get_profile("skill.fire_burst")
    check(fire.particles.to_html(false).to_lower() == "ff4400" and is_equal_approx(fire.flash.a, 0.6), "fireball is #FF4400 at intensity 0.6")
    check(JuiceDefs.all_ids().all(func(id): return JuiceProfile.get_profile(String(id)).flash_frames >= 2 and JuiceProfile.get_profile(String(id)).flash_frames <= 4), "flashes last 2-4 frames")
    var saved := JuiceProfile.file_name("skill.meteor")
    check(ResourceLoader.exists(saved) and load(saved) is JuiceProfile, "profiles are saved as .tres (%s)" % saved)

    # --- the filter --------------------------------------------------------------------------------
    var sb := SandboxScreen.new(5)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    await get_tree().process_frame
    var h: SandboxHero = sb.heroes[0]
    var e: SandboxEnemy = null
    for x in sb.enemies:
        if not x.is_boss:
            e = x
            break
    e.base_max_hp = 99999
    e.max_hp = 99999
    e.hp = 99999
    var normal := DamageInfo.make(10.0, "physical", h)
    h.blows += 1                                       # what _land_basic does before a basic hit
    var r := JuicePlayer.resolve(e, normal, false)
    check(not r["heavy"] and (r["profile"] as JuiceProfile).shake == 0.0 and (r["profile"] as JuiceProfile).freeze == 0.0, "a normal blow never shakes nor freezes (%s)" % r["id"])
    check(String(r["id"]).begins_with("basic."), "a basic attack uses the class's basic profile (%s)" % r["id"])
    var crit := DamageInfo.make(10.0, "physical", h)
    crit.crit = true
    h.blows += 1
    var rc := JuicePlayer.resolve(e, crit, false)
    var pc: JuiceProfile = rc["profile"]
    check(rc["heavy"] and pc.shake > 0.0 and pc.shake <= JuiceDefs.MAX_SHAKE, "a crit shakes, at most 2 px (%.1f)" % pc.shake)
    check(pc.freeze >= JuiceDefs.FREEZE_MIN and pc.freeze <= JuiceDefs.FREEZE_MAX, "a crit freezes 0.03-0.05 s (%.3f)" % pc.freeze)
    h.blows += 1
    check(JuicePlayer.resolve(e, DamageInfo.make(10.0, "physical", h), true)["heavy"], "the finishing blow gets the heavy treatment")
    h._firing = "earthshatter"                         # a skill resolving: blows did not move
    check(JuicePlayer.resolve(e, DamageInfo.make(10.0, "physical", h), false)["id"] == "skill.earthshatter", "a skill hit uses that skill's profile")
    check(JuicePlayer.resolve(e, DamageInfo.make(10.0, "physical", h), false)["heavy"], "a heavy skill shakes")
    h._firing = "quick_slash"
    check(not JuicePlayer.resolve(e, DamageInfo.make(10.0, "physical", h), false)["heavy"], "a light skill does not")
    var from_enemy := JuicePlayer.resolve(h, DamageInfo.make(10.0, "physical", e), false)
    check(not from_enemy["heavy"], "a common creature's blow is light (%s)" % from_enemy["id"])
    check(not CombatFeel.shake_allowed(e), "CombatFeel drops the camera shake of a common creature's ordinary blow")
    var dot := DamageInfo.make(3.0, "true", e)
    dot.tags.append("dot")
    check(JuicePlayer.resolve(h, dot, true)["id"] == "dot" and not JuicePlayer.resolve(h, dot, true)["heavy"], "damage over time is light, even when it kills")
    check(CombatFeel.SHAKE.values().all(func(s): return float(s[0]) <= JuiceDefs.MAX_SHAKE), "every camera shake is at most 2 px")
    check(CombatFeel.FREEZE.values().all(func(f): return float(f) <= JuiceDefs.FREEZE_MAX), "every impact freeze is at most 0.05 s")

    # --- live hit: pieces appear, positions stay whole pixels ----------------------------------------
    var world: Node = e.get_parent()
    var before := world.get_children().filter(func(c): return c is CPUParticles2D).size()
    e.visible = true                                 # numbers never pop out of the fog of war
    var ep := e.position
    h.blows += 1
    e.take_hit(DamageInfo.make(20.0, "physical", h))
    var parts: Array = world.get_children().filter(func(c): return c is CPUParticles2D)
    check(parts.size() > before, "a hit throws juice particles (%d)" % (parts.size() - before))
    check(parts.all(func(p): return (p as Node2D).position == (p as Node2D).position.round()), "particles start on whole pixels")
    check(e.position == ep, "juice never moves the unit itself")
    var spr: AnimatedSprite2D = e.get("_sprite")
    check(spr == null or spr.offset == spr.offset.round(), "the sprite kick is whole pixels")
    var layer := world.get_node_or_null("WorldTextLayer")
    check(layer != null and layer.get_child_count() > 0, "damage numbers live in their own world-text layer")
    await get_tree().process_frame
    await get_tree().process_frame
    var nums: Array = layer.get_children() if layer != null else []
    check(nums.all(func(n): return (n as Node2D).position == (n as Node2D).position.round()), "floating numbers are drawn on whole pixels")

    # --- numbers ---------------------------------------------------------------------------------------
    check(FloatingText.text_scale(500, "normal", false) == 1.0, "a big hit between creatures stays small (only the Master / party get big numbers)")
    check(FloatingText.text_scale(500, "normal", true) > FloatingText.text_scale(5, "normal", true), "big numbers grow with the damage")
    FloatingText.compact = true
    check(FloatingText.text_scale(500, "crit", true) == 1.0, "the compact option keeps every number small")
    FloatingText.compact = false
    e.visible = true
    var a := FloatingText.number(e, 5, "normal", false)
    var b := FloatingText.number(e, 6, "normal", false)
    check(a != null and b != null and a._side != b._side and a.position.y != b.position.y, "two numbers in a row go on opposite arcs and do not overlap")
    check(FloatingText.COLORS["crit"] != FloatingText.COLORS["normal"] and FloatingText.COLORS.has("dot") and FloatingText.COLORS.has("mana"), "crit, damage over time and mana have their own colours")

    # --- party frames and smooth bars ----------------------------------------------------------------
    var hud: ExpeditionHud = null
    for c in sb.get_children():
        if c is ExpeditionHud:
            hud = c
    check(hud != null and hud._frames != null and hud._frames.get_child_count() == sb.heroes.size(), "one party frame per hero down the left edge")
    var bar := PartyFrames.SmoothBar.new(Vector2(60, 5), true)
    add_child(bar)
    bar.set_value(100.0, 100.0)
    bar.set_value(40.0, 100.0)
    check(is_equal_approx(bar.shown, 0.4) and is_equal_approx(bar.trail, 1.0), "damage drops the bar at once and leaves a white chunk")
    bar._process(0.2)
    check(is_equal_approx(bar.trail, 1.0), "the white chunk waits ~0.3 s")
    for i in 30:
        bar._process(0.05)
    check(bar.trail < 0.45, "then it drains down (%.2f)" % bar.trail)
    bar.set_value(90.0, 100.0)
    bar._process(0.1)
    check(bar.shown > 0.4 and bar.shown < 0.9, "healing fills smoothly (%.2f)" % bar.shown)
    check(PartyFrames.hp_color(0.9) != PartyFrames.hp_color(0.4) and PartyFrames.hp_color(0.4) != PartyFrames.hp_color(0.1), "health goes green, yellow, red")

    # --- gathering spots run out -----------------------------------------------------------------------
    var g := GatherNode.new("ore", {"ore": 7, "stone": 2}, 4)
    add_child(g)
    var total := {}
    var cycles := 0
    var guard := 0
    while not g.taken and guard < 2000:
        guard += 1
        var got := g.work(0.1, [h])
        if not got.is_empty():
            cycles += 1
        for res in got:
            total[res] = int(total.get(res, 0)) + int(got[res])
    check(g.taken and cycles == 4, "a spot with 4 charges gives 4 units and runs out (%d)" % cycles)
    check(int(total.get("ore", 0)) == 7 and int(total.get("stone", 0)) == 2, "its total yield is unchanged %s" % str(total))
    check(absf(float(guard) * 0.1 - GatherDefs.CYCLE * 4.0) < 0.5, "each charge takes one ~5 s cycle (%.1f s)" % (float(guard) * 0.1))
    check(g.work(0.1, [h]).is_empty(), "an empty spot gives nothing more")
    await get_tree().create_timer(GatherDefs.FADE + 0.2).timeout
    check(not is_instance_valid(g), "an empty spot fades away")
    var g2 := GatherNode.new("herb", {"herb": 3})
    g2.position = Vector2(123, 456)
    g2.roll_charges()
    check(g2.charges >= 3 and g2.charges <= 6, "spots have 3-6 charges (%d)" % g2.charges)
    var g3 := GatherNode.new("herb", {"herb": 3})
    g3.position = Vector2(123, 456)
    g3.roll_charges()
    check(g3.charges == g2.charges, "the same spot always has the same charges")
    var syn := GatherNode.synergy()                  # integration: pista A's "Two on a Vein" drives the pair speed-up
    check(is_equal_approx(float(syn.get("speed", 0.0)), float(SynergyDefs.SYNERGIES["gather_pair"]["mult"])), "two on a spot use SynergyDefs' Two on a Vein")
    g2.free()
    g3.free()
    var g4 := GatherNode.new("wood", {"wood": 3}, 3)
    add_child(g4)
    g4.work(1.0, [h])
    check(g4.progress > 0.0, "a hero working a spot fills its cycle")
    g4.work(0.1, [])
    check(g4.progress == 0.0, "walking away resets the current cycle")
    g4.queue_free()

    # --- the shader --------------------------------------------------------------------------------------
    var wm := Ambience.wind_material(true)
    check(wm != null and wm.shader != null, "the wind shader loads (sprite mode, for pista B's town)")
    check(Ambience.wind_material(false) != null, "the wind shader loads (baked map mode)")

    sb.queue_free()
    print("== ALL PASSED ==" if fails == 0 else "== %d FAILED ==" % fails)
    get_tree().quit(0 if fails == 0 else 1)
