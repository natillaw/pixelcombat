extends Control
## D-082b fixes: the squad that enters is the one the floor says; minimum floor content and reachable
## creatures; the camera never zooms on its own, free camera keeps the Master obeying, F1-F5; the white
## starter kit (new heroes and migrated saves, what is seen = what is worn); the shield blocks only in front.
##   godot --headless --path . res://tests/smoke_fixes.tscn --quit-after 3000
const DT := 1.0 / 30.0
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _account(seed_value: int) -> void:
    Game.new_game()
    Game.rng.seed = seed_value
    Game.create_master({"first": "Fix", "last": "Master", "class": "class.warrior", "trait": "trait.stubborn",
        "look": {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}})
    Game.starter_summons()


func _screen(f: int) -> SandboxScreen:
    var sb := SandboxScreen.new(f)
    add_child(sb)
    sb.size = Vector2(640, 360)
    sb.set_physics_process(false)
    return sb


func _ready() -> void:
    print("== Fixes tests (D-082b) ==")
    Game.autosave = false
    Game.save_path = "user://smoke_fixes_%d.json" % OS.get_process_id()
    await _party()
    _density()
    await _camera()
    _kit()
    await _shield()
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)


func _party() -> void:
    _account(101)
    check(Game.party_heroes().size() == 5, "a new account fills the party: Master + 4")
    for f in range(1, 11):
        Game.tower_cleared[str(f)] = 1
    var sb := _screen(5)
    await get_tree().process_frame
    check(sb.heroes.size() == 5 and sb.real_squad, "floor 5 takes 5: with 5 heroes in the party, 5 are deployed (%d)" % sb.heroes.size())
    sb.queue_free()
    await get_tree().process_frame
    var r1 := TowerExpedition.squad_report(1, Game.party_heroes())
    sb = _screen(1)
    await get_tree().process_frame
    check(int(r1["size"]) == TowerExpedition.party_max(1) and sb.heroes.size() == int(r1["goes"]) and bool(r1["extra"]),
        "floor 1: what the gate says (%d of %d) is what is deployed (%d)" % [int(r1["goes"]), int(r1["have"]), sb.heroes.size()])
    sb.queue_free()
    await get_tree().process_frame
    for i in range(3, 5):
        Game.party[i] = ""
    var r5 := TowerExpedition.squad_report(5, Game.party_heroes())
    sb = _screen(5)
    await get_tree().process_frame
    check(bool(r5["short"]) and sb.real_squad and sb.heroes.size() == 3, "a short party enters as itself (3 real heroes), not as a throwaway test squad")
    sb.queue_free()
    await get_tree().process_frame


func _density() -> void:
    var bad := []
    for f in range(1, 11):
        var cfg := TowerExpedition.get_floor_config(f)
        for s in [11, 222, 3333]:
            var m := ProceduralMap.new(int(cfg["width"]), int(cfg["height"]), s * 7 + f, f)
            var rooms: Array = m.room_zones.filter(func(z): return String(z["zone"]) != "entrance")
            var want := maxi(EnemyDefs.ENCOUNTER_MIN, ceili(float(rooms.size()) * EnemyDefs.ENCOUNTER_MIN_SHARE))
            var start: Vector2 = m.center_of(m.spawn_cells[0])
            var unreach := 0
            for e in m.encounters:
                for c in e["cells"]:
                    if m.find_path(start, m.center_of(c)).is_empty():
                        unreach += 1
            var gap := 0.0
            for z in rooms:
                gap = maxf(gap, m._nearest_encounter(m.center_of((z["rect"] as Rect2i).get_center())))
            if m.encounters.size() < want or unreach > 0 or gap > EnemyDefs.ENCOUNTER_MAX_GAP:
                bad.append("F%d/%d: %d enc (min %d), %d unreachable, gap %.0f" % [f, s, m.encounters.size(), want, unreach, gap])
    check(bad.is_empty(), "floors 1-10, 3 seeds: every floor has its minimum encounters, every creature reachable, no room further than %.0f px from a group %s" % [EnemyDefs.ENCOUNTER_MAX_GAP, str(bad)])


func _camera() -> void:
    _account(202)
    var sb := _screen(-1)
    await get_tree().process_frame
    var m := sb.master_hero
    for i in 60:
        sb.tick(DT)
        sb._step_camera(DT)
    check(is_equal_approx(sb.camera_zoom_target, float(CameraDefs.ZOOM_STEPS[CameraDefs.ZOOM_DEFAULT])), "the camera starts at a whole zoom step")
    sb.heroes[2].position = sb.map.nearest_walkable(m.position + Vector2(900, 600))   # the squad spreads (a hero sent far)
    for i in 30:
        sb._step_camera(DT)
    check(is_equal_approx(sb.camera_zoom_target, float(CameraDefs.ZOOM_STEPS[CameraDefs.ZOOM_DEFAULT])) and is_equal_approx(sb.camera.zoom.x, float(CameraDefs.ZOOM_STEPS[CameraDefs.ZOOM_DEFAULT])),
        "sending a hero far away does not zoom the camera out (zoom %.2f)" % sb.camera.zoom.x)
    check(sb.cam_mode == "locked" and sb.camera_target.distance_to(m.position) < 120.0, "locked camera: it follows the Master")
    # framing: walking down, the Master stays well above the bottom of the view
    m.velocity = Vector2(0, 120)
    var view := Vector2(sb._viewport.size)
    var ys := view.y * 0.5 + (m.position.y - sb._framed(m).y) * sb.camera_zoom_target
    check(ys <= view.y - sb.hud_bottom() - view.y * CameraDefs.BOTTOM_MIN + 0.5, "walking down, the Master stays %.0f px above the HUD (>= %.0f %% of the screen)" % [view.y - sb.hud_bottom() - ys, CameraDefs.BOTTOM_MIN * 100.0])
    m.velocity = Vector2.ZERO
    # free camera: the Master still obeys
    sb.toggle_camera_mode()
    sb.camera_pan(Vector2(300, 0))
    check(sb.cam_mode == "free", "Y: free camera")
    var dest := sb.map.nearest_walkable(m.position + Vector2(120, 0))
    sb.order_context(dest)
    for i in 60:
        sb.tick(DT)
    check(m.position.distance_to(dest) < 40.0, "with the free camera the Master still walks where the player clicks (%.0f px left)" % m.position.distance_to(dest))
    # F1-F5
    for i in sb.heroes.size():
        sb.camera_hero_key(i, 100.0 + float(i) * 10.0)
        sb.update_camera_targets()
        if sb.camera_target.distance_to(sb.heroes[i].position) > 140.0:
            check(false, "F%d centres on hero %d" % [i + 1, i + 1])
    check(true, "F1-F5 centre the camera on each party member (F1 = the Master: %s)" % str(sb.heroes[0] == m))
    sb.camera_hero_key(3, 200.0)
    sb.camera_hero_key(3, 200.2)
    check(sb.cam_mode == "follow" and sb.cam_follow == 3, "a double tap follows that hero")
    sb.camera_pan(Vector2(10, 0))
    check(sb.cam_mode == "free" and sb.cam_follow == -1, "moving the camera ends the follow")
    sb.toggle_camera_mode()
    check(sb.cam_mode == "locked", "Y again: locked on the Master")
    for k in [CameraDefs.KEY_TOGGLE, CameraDefs.KEY_CENTER, CameraDefs.KEY_DEBUG, CameraDefs.KEY_FULLSCREEN] + CameraDefs.HERO_KEYS:
        if k in [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_F, KEY_1, KEY_2, KEY_3, KEY_H, KEY_X, KEY_C, KEY_V, KEY_SPACE]:
            check(false, "camera key %d collides with a combat / order key" % k)
    check(true, "no camera key takes QWER, F, 1/2/3, H/X/C/V or Space")
    sb.queue_free()
    await get_tree().process_frame


func _kit() -> void:
    _account(303)
    var all_ok := true
    for h in Game.heroes.values():
        var kit := ItemDefs.starter_kit(h.hero_class)
        for slot in kit:
            if String(h.equipment.get(slot, {}).get("base", "")) != String(kit[slot]):
                all_ok = false
    check(all_ok and Game.heroes.size() >= 5, "every new hero (and the Master) joins with its white kit equipped (%d heroes)" % Game.heroes.size())
    var any: HeroData = Game.heroes.values()[1]
    var shirt: Dictionary = any.equipment["chest"]
    check(String(shirt["rarity"]) == "common" and (shirt["stats"] as Dictionary).is_empty(), "the clothes are white items with no stats")
    var w := ItemGen.starter("plain_sword", 1)
    check(int(w["stats"].get("atk", 0)) <= 2, "starter weapons have minimal stats (%s)" % str(w["stats"]))
    check(not ItemDefs.base_open("plain_sword") and ItemDefs.base_open("sword"), "the kit is never looted nor crafted")
    # what is seen = what is worn
    var war: HeroData = null
    var rog: HeroData = null
    for h in Game.heroes.values():
        if h.hero_class == "class.warrior" and war == null:
            war = h
        if h.hero_class == "class.rogue" and rog == null:
            rog = h
    if war == null:
        war = Game.master()
    var lay := LpcWardrobe.layers_for(war.look, war.hero_class, ItemVisuals.equipment_layers(war.equipment))
    check(lay.has(["shield_round", "default"]) and lay.has(["weapon_arming", "default"]), "a warrior shows the sword and the round wooden shield")
    var eq2: Dictionary = war.equipment.duplicate()
    eq2.erase("main_hand")
    var lay2 := LpcWardrobe.layers_for(war.look, war.hero_class, ItemVisuals.equipment_layers(eq2))
    check(not lay2.any(func(p): return String(p[0]).begins_with("weapon_")), "taking the weapon off removes it from the sprite")
    if rog == null:
        rog = HeroGenerator.generate(4242, 2)
        rog.hero_class = "class.rogue"
        rog.equipment = {}
        Game.give_kit(rog)
    var rl := LpcWardrobe.layers_for(rog.look, rog.hero_class, ItemVisuals.equipment_layers(rog.equipment))
    check(rl.has(["weapon_dagger", "default"]) and rl.has(["weapon_dagger_offhand", "default"]), "a rogue shows two daggers (main + mirrored off hand)")
    check(LpcComposer.index()["pieces"].has("shield_round") and LpcComposer.index()["pieces"].has("weapon_dagger_offhand"), "the shield and the off-hand dagger are imported LPC pieces")
    # migration v18 -> v19
    Game.save_game()
    var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.save_path))
    d["version"] = 18
    for hd in d["heroes"]:
        hd["equipment"] = {}
    var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
    f.store_string(JSON.stringify(d))
    f.close()
    Game.load_game()
    var mig := true
    var uids := {}
    for h in Game.heroes.values():
        for slot in ItemDefs.starter_kit(h.hero_class):
            if not h.equipment.has(slot):
                mig = false
            else:
                uids[int(h.equipment[slot]["uid"])] = true
    check(mig, "loading an old save (v18) equips the kit on heroes with empty slots")
    var count := 0
    for h in Game.heroes.values():
        count += ItemDefs.starter_kit(h.hero_class).size()
    check(uids.size() == count, "every migrated kit item has its own id (%d / %d)" % [uids.size(), count])


func _shield() -> void:
    _account(404)
    var sb := _screen(-1)
    await get_tree().process_frame
    for e in sb.enemies:
        e.position = Vector2(-90000, -90000)
    var war := sb.master_hero
    check(war.item_mods.has("block"), "the warrior's starter shield gives a block chance (%s)" % str(war.item_mods.get("block", {})))
    war.item_mods["block"] = {"chance": 1.0, "reduce": 0.5, "arc_deg": 120.0}   # always, to test the direction
    war.facing = "right"
    var foe := sb._spawn_enemy(sb.map.cell_of(war.position), "bandido_maton")
    foe.position = war.position + Vector2(40, 0)
    var hp0 := war.hp
    war.take_hit(DamageInfo.make(20.0, "true", foe))
    var front := hp0 - war.hp
    foe.position = war.position + Vector2(-40, 0)
    hp0 = war.hp
    war.take_hit(DamageInfo.make(20.0, "true", foe))
    var back := hp0 - war.hp
    check(war.blocks == 1 and front < back, "the shield blocks a frontal blow (%d taken) but not one from behind (%d)" % [front, back])
    var rogue: SandboxHero = null
    for h in sb.heroes:
        if h.hero.hero_class == "class.rogue":
            rogue = h
    if rogue != null:
        check(int(rogue.weapon_pattern().get("hits", 1)) == 2, "a rogue with both kit daggers strikes twice")
        rogue.hero.equipment.erase("off_hand")
        check(rogue.weapon_pattern().is_empty(), "without the off-hand dagger it strikes once")
    sb.queue_free()
    await get_tree().process_frame
