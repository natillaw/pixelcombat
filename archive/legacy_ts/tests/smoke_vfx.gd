extends Control
## Combat visuals: every effect in the catalog loads from the packs, every skill / weapon / status /
## creature has a look, and in a live fight attacks, projectiles, casts, auras, zones and creature
## attack/hurt animations really appear. Run:
##   godot --headless --path . res://tests/smoke_vfx.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _fx_count(parent: Node) -> int:
    return parent.get_children().filter(func(c): return c is AnimatedSprite2D).size()


func _ready() -> void:
    print("== VFX tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_vfx.json"
    Game.new_game()

    # --- catalog ----------------------------------------------------------------------------
    var broken: Array = []
    for k in CombatVFX.FX:
        var sf := CombatVFX.frames_for(String(k))
        if sf == null or sf.get_frame_count("fx") < 2:
            broken.append(k)
    check(broken.is_empty(), "all %d catalog effects load from the packs %s" % [CombatVFX.FX.size(), str(broken)])
    var light := CombatVFX.frames_for("lightning_holy")
    check(light != null and light.get_frame_count("fx") == 9 and int(light.get_frame_texture("fx", 0).get_width()) == 24, "non-square strips are cut by their frame count (lightning: 9 x 24 px)")
    check(SkillDefs.SKILLS.keys().all(func(id): return CombatVFX.SKILL_FX.has(id)), "every skill has its own look")
    check(HeroTables.CLASSES.keys().all(func(c): return CombatVFX.WEAPON_FX.has(String(CombatVFX.CLASS_WEAPON.get(c, "")))), "every class has a basic-attack look")
    var weapons: Array = ItemDefs.BASES.keys().filter(func(b): return String(ItemDefs.BASES[b]["kind"]) == "weapon")
    check(weapons.all(func(b): return CombatVFX.WEAPON_FX.has(String(ItemDefs.BASES[b].get("visual_base", b)))), "every weapon base has a basic-attack look (the kit's through its visual base)")
    check(CombatVFX.STATUS_FX.keys().all(func(s): return CombatRules.STATUS.has(s)), "status auras map to real statuses")

    # --- creature animations (and the 48 / 144 px frame fix) ----------------------------------------
    # D-063: tower creatures come from normalised strips (square frames, drawn at an integer scale)
    var rat := EnemySprites.build_frames("rat")
    check(rat != null and int(rat.get_frame_texture("idle", 0).get_width()) == 16 and rat.get_frame_count("run") == 4 and is_equal_approx(EnemySprites.scale_for("rat"), 2.0),
        "Ninja creatures are cut into 16 px frames and drawn at x2 (rat)")
    var golem := EnemySprites.build_frames("golem")
    var gs := EnemySprites.scale_for("golem")
    check(golem != null and gs == floorf(gs) and gs > EnemySprites.scale_for("rat"), "big creatures are drawn bigger, at a whole-number scale (golem x%d)" % int(gs))
    var no_attack: Array = []
    for f in range(1, 11):
        for foe in TowerExpedition.get_floor_config(f)["foes"]:
            var fr := EnemySprites.build_frames(String(foe))
            if fr == null or not fr.has_animation("hurt"):
                no_attack.append("%s(hurt)" % foe)
            elif not fr.has_animation("attack") and not String(foe).begins_with("mushroom"):
                no_attack.append(foe)
    check(no_attack.is_empty(), "every tower creature has its attack and hurt animations (mushrooms only hurt) %s" % str(no_attack))

    # --- live fight ----------------------------------------------------------------------------------
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
    var world: Node = sb.heroes[0].get_parent()
    var base := map.center_of(Vector2i(6, 15))
    var h: SandboxHero = sb.heroes[0]
    h.position = base
    h.combat_tick([], map)
    var e1: SandboxEnemy = sb.enemies[0]
    e1.alive = true
    e1.visible = true
    e1.base_max_hp = 5000
    e1.max_hp = 5000
    e1.hp = 5000
    e1.position = base + Vector2(40, 0)

    var n0 := _fx_count(world)
    h._basic_attack(e1)
    check(_fx_count(world) > n0, "a basic attack shows its weapon effect (%s)" % h.weapon_id())
    h.hero.hero_class = "class.archer"
    n0 = _fx_count(world)
    e1.position = base + Vector2(160, 0)
    h._basic_attack(e1)
    for i in 12:                                     # D-082: the bow is drawn ~0.3 s, then the arrow leaves
        h.tick(1.0 / 30.0)
    var flying := world.get_children().filter(func(c): return c is ArrowShot and not c.done and c.position.distance_to(h.position) < 120.0)
    check(not flying.is_empty(), "a ranged attack launches a real projectile from the hero (after drawing the bow)")
    await get_tree().create_timer(0.5).timeout
    check(world.get_children().filter(func(c): return c is AnimatedSprite2D and c.position.distance_to(h.position + Vector2(0, -16)) < 30.0).is_empty(), "the projectile flies off and lands")

    h.slots.clear()
    h.slots.append("fire_burst")
    h.res = h.res_max
    h.cds.clear()
    check(h.use_skill_slot(0, [e1], sb.heroes) and h._cast_fx != null and h._cast_fx.get_parent() == h, "casting shows a magic circle under the caster")
    h.tick(float(SkillDefs.info("fire_burst")["cast"]) + 0.05)
    check(h._cast_fx == null, "the circle goes away when the spell is released")
    await get_tree().create_timer(0.6).timeout
    check(_fx_count(world) > 0, "the fireball lands with its explosion")

    e1.apply_status("burn", 2.0, 1.0)
    check(e1._status_fx.has("burn") and is_instance_valid(e1._status_fx["burn"]) and e1._status_fx["burn"].get_parent() == e1, "a burning foe shows flames")
    e1.statuses.clear()
    e1.tick_combat(0.01)
    check(not e1._status_fx.has("burn"), "the flames go out with the status")
    h.apply_status("shield", 5.0, 30.0)
    check(h._status_fx.has("shield"), "a shield shows its bubble")

    var z := CombatZone.spawn(world, base, 90.0, 2.0, "weaken", 1.0, 0.0, [e1], h)
    check(z.get_children().filter(func(c): return c is AnimatedSprite2D).size() >= 2, "a smoke zone is drawn with smoke puffs")
    z.queue_free()

    var fe := sb._spawn_enemy(Vector2i(6, 15), "goblin")
    fe.position = base + Vector2(20, 0)
    for x in sb.heroes:
        x.alive = x == h
    fe.tick(0.016, [h], map)
    check(fe.is_telegraphing() and fe._sprite != null and fe._sprite.animation == "attack", "a goblin winds up with its real attack animation")
    fe._timer = 0.0
    var n1 := _fx_count(world)
    fe.tick(0.016, [h], map)
    check(_fx_count(world) > n1, "the blow lands with the creature's strike effect")
    fe._anim_lock = 0.0
    fe.state = SandboxEnemy.State.IDLE
    fe.take_hit(DamageInfo.make(5.0, "true", h))
    check(fe._sprite.animation == "hurt", "a hit creature flinches with its hurt animation")

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)
