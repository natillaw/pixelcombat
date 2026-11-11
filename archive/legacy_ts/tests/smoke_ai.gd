extends Control
## D-082: combat AI. The four heroes the player does not drive act on their own (the autonomy bug), the
## layered AI decides every 0.2-0.8 s, pings (one hero vs the whole party, anti-spam, personality),
## revive by proximity + holding F (4 s, a hit interrupts) and death after 120 s, the AI lifting the
## fallen, two daggers (two blows, DPS ~ a warrior's), real arrows that a moving target dodges, no elves
## in 1000 summons, bandit roles (assassin, brute threat, leader morale, horn) and the ping wheel.
##   godot --headless --path . res://tests/smoke_ai.tscn --quit-after 3000
const DT := 1.0 / 30.0
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _master_account(seed_value: int) -> void:
    Game.new_game()
    Game.rng.seed = seed_value
    Game.create_master({"first": "Test", "last": "Master", "class": "class.warrior", "trait": "trait.stubborn",
        "look": {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}})
    Game.starter_summons()


func _screen(floor_num: int) -> SandboxScreen:
    var sb := SandboxScreen.new(floor_num)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    return sb


func _clear(sb: SandboxScreen, keep: Array) -> void:
    for e in sb.enemies:
        if not keep.has(e):
            e.position = Vector2(-90000, -90000)
            e.dormant = true
            e.visible = false


func _run(sb: SandboxScreen, seconds: float) -> void:
    var t := 0.0
    while t < seconds and sb.mission_state == SandboxScreen.Mission.ACTIVE:
        sb.tick(DT)
        t += DT


## A hero of `cls` with plain numbers (no personal variance, no traits): fair class comparisons.
func _plain(cls: String, lvl: int, seed_value: int) -> HeroData:
    var h := HeroGenerator.generate(seed_value, 3)
    h.hero_class = cls
    h.level = lvl
    h.variance = {}
    h.traits = []
    h.equipment = {}
    return h


## A creature that never moves nor strikes, with no armour (unless asked) and plenty of health.
func _dummy(sb: SandboxScreen, at: Vector2, armor: int = 0) -> SandboxEnemy:
    var e := sb._spawn_enemy(sb.map.cell_of(at), "bandido_maton")
    e.position = at
    e.job = "totem"
    e.armor = armor
    e.base_max_hp = 9999999
    e.max_hp = 9999999
    e.hp = 9999999
    e.visible = true
    e.dormant = false
    return e


func _ready() -> void:
    print("== Combat AI tests (D-082) ==")
    Game.autosave = false
    Game.save_path = "user://smoke_ai_%d.json" % OS.get_process_id()
    await _autonomy()
    await _layers()
    await _pings()
    await _revive()
    await _weapons()
    await _arrows()
    _elves()
    await _bandits()
    _wheel_and_keys()
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)


# --- 1. the autonomy bug ---------------------------------------------------------------------------

## Root cause: with a Master in the squad every hero stayed selected (select_all at the start), so each
## right-click to move the Master (repeated every 0.12 s while held) gave the other four a direct "move"
## order: no target, no skills, no dodging; and H/F/X gave them hold/follow/retreat orders that never
## ended. Now only the Master takes direct orders; the others get pings, which expire.
func _autonomy() -> void:
    _master_account(4242)
    var sb := _screen(-1)
    await get_tree().process_frame
    var m := sb.master_hero
    check(m != null and m.is_controlled() and sb.selected == [m], "a Master squad selects only the Master (the others are autonomous)")
    var foe: SandboxEnemy = null
    for e in sb.enemies:
        if foe == null or e.position.distance_to(m.position) < foe.position.distance_to(m.position):
            foe = e
    _clear(sb, [foe])
    foe.position = sb.map.nearest_walkable(m.position + Vector2(120, 0))
    foe.dormant = false
    foe.alert()
    foe.scale_stats(40.0)
    foe.atk = 0
    var others: Array = sb.heroes.filter(func(h): return h != m)
    for h in others:                                             # D-142: level-1 heroes have only Q; give them W E R
        for sid in SkillDefs.KITS.get(h.hero.hero_class, SkillDefs.KITS["class.none"])["start"]:
            h.hero.learn_skill(String(sid), false)
        h._setup_skills()
    var res0 := {}
    for h in others:
        res0[h] = h.res
    var t := 0.0
    var skilled := {}
    var held_h := false
    while t < 14.0:
        if fmod(t, 0.5) < DT:
            sb.order_context(m.position + Vector2(10, 0))        # the player keeps steering the Master
        if t > 3.0 and not held_h:
            held_h = true
            sb.squad_key(KEY_H)                                  # and asks the squad to defend here
        sb.tick(DT)
        t += DT
        for h in others:
            for sid in h.cds:
                if float(h.cds[sid]) > 0.0:
                    skilled[h] = true
    var fought := others.filter(func(h): return float(h.contrib.get("damage", 0.0)) > 0.0)
    check(fought.size() == others.size(), "while the Master is steered, all %d autonomous heroes attack on their own (%d did)" % [others.size(), fought.size()])
    check(skilled.size() >= 2, "the autonomous heroes use their skills on their own (%d of %d used one)" % [skilled.size(), others.size()])
    check(others.all(func(h): return h.order != "move"), "right-clicks move only the Master: no hero is stuck on a move order")
    _run(sb, AiDefs.PING_ORDER_TIME + 1.0)
    check(others.all(func(h): return h.order == "auto" or h.order == "rescue"), "a ping order (defend) ends and every hero is back to Auto")
    sb.queue_free()
    await get_tree().process_frame


# --- 2. layers and imperfection -----------------------------------------------------------------------

func _layers() -> void:
    check(is_equal_approx(AiDefs.decide_interval(100), AiDefs.DECIDE_MIN) and is_equal_approx(AiDefs.decide_interval(0), AiDefs.DECIDE_MAX),
        "decision interval: %.1f s calm, %.1f s at Composure 0" % [AiDefs.decide_interval(100), AiDefs.decide_interval(0)])
    check(AiDefs.aim_error_deg(10, 20, true) > AiDefs.aim_error_deg(10, 20, false) and AiDefs.aim_error_deg(20, 100, false) < AiDefs.aim_error_deg(4, 100, false),
        "aim error grows with panic and low Composure, shrinks with AGI")
    _master_account(777)
    var sb := _screen(-1)
    await get_tree().process_frame
    _clear(sb, [])
    var h: SandboxHero = sb.heroes[1]
    var before := h.decisions
    _run(sb, 10.0)
    var n := h.decisions - before
    check(n >= int(10.0 / (AiDefs.DECIDE_MAX + AiDefs.DECIDE_JITTER)) and n <= int(10.0 / AiDefs.DECIDE_MIN) + 1 and n < int(10.0 / DT) / 3,
        "an autonomous hero decides %d times in 10 s (every 0.2-0.8 s, not every frame)" % n)
    check(sb.heroes.all(func(x): return x == sb.master_hero or AiDefs.ROLE_BY_CLASS.has(x.hero.hero_class) and x.role == AiDefs.role_of(x.hero.hero_class)),
        "every autonomous hero has its class role (tank, dps, healer, scout, support)")
    var reck := AiDefs.personality(["trait.reckless"])
    var coward := AiDefs.personality(["trait.cautious"])
    var loyal := AiDefs.personality(["trait.loyal"])
    check(float(reck["ahead"]) > 0.0 and float(coward["ahead"]) < 0.0 and float(coward["attack_delay"]) > 0.0 and float(loyal["delay"]) < 0.0 and bool(loyal["follows_master"]),
        "personality: reckless ahead, cautious behind and slow to attack, loyal answers sooner and stays by the Master")
    sb.queue_free()
    await get_tree().process_frame


# --- 3. pings ------------------------------------------------------------------------------------------

func _pings() -> void:
    _master_account(3131)
    var sb := _screen(-1)
    await get_tree().process_frame
    _clear(sb, [])
    var m := sb.master_hero
    var others: Array = sb.heroes.filter(func(h): return h != m)
    for h in others:
        h.hero.obedience = 80
        h.hero.traits = []
        h.persona = AiDefs.personality([])
    var spot := sb.map.nearest_walkable(m.position + Vector2(0, 160))
    # one hero (portrait click) vs the whole party
    var one: SandboxHero = others[1]
    sb.select_slot(one.slot)
    check(sb.ping_to == one, "clicking a hero's portrait picks them as the only recipient of the next ping")
    var n1 := sb.ping("move", spot)
    _run(sb, 1.5)
    check(n1 == 1 and one.order_left > 0.0 and others.filter(func(h): return h.order_left > 0.0).size() == 1,
        "a ping to one hero moves only that hero")
    check(sb.ping_to == null, "after the ping the recipient goes back to the whole party")
    for h in others:
        h.stop()
    var n2 := sb.ping("move", spot)
    _run(sb, 1.5)
    check(n2 == others.size() and others.all(func(h): return h.order_left > 0.0), "a ping to the party reaches all %d heroes" % others.size())
    check(others.all(func(h): return h.chatter_timer > 0.0 or h.chatter_text != ""), "every recipient answers with a short line")
    check(sb.markers.any(func(mk): return is_instance_valid(mk)), "the ping leaves a marker on the map")
    # personality and leadership: answer delays (deterministic)
    var a_loyal := {"persona": AiDefs.personality(["trait.loyal"])}
    var h0: SandboxHero = others[0]
    h0.persona = AiDefs.personality(["trait.cautious"])
    var slow := float(sb.ping_answer(h0, "attack")["delay"])
    h0.persona = a_loyal["persona"]
    var fast := float(sb.ping_answer(h0, "attack")["delay"])
    check(slow > fast, "a cautious hero is slower to answer an attack ping (%.1f s) than a loyal one (%.1f s)" % [slow, fast])
    h0.persona = AiDefs.personality(["trait.reckless"])
    h0.hp = h0.max_hp
    check(not bool(sb.ping_answer(h0, "danger")["obeys"]), "a reckless hero with health to spare ignores a retreat ping")
    h0.hp = roundi(float(h0.max_hp) * 0.3)
    check(bool(sb.ping_answer(h0, "danger")["obeys"]), "...but obeys it when badly hurt")
    h0.persona = AiDefs.personality([])
    h0.position = m.position + Vector2(MasterRules.leadership_radius(m.hero) + 200.0, 0)
    var far_d := float(sb.ping_answer(h0, "move")["delay"])
    h0.position = m.position + Vector2(40, 0)
    check(far_d > float(sb.ping_answer(h0, "move")["delay"]), "outside the Master's Leadership radius a hero answers later")
    # anti-spam
    h0.hero.obedience = CombatRules.OBEY_MIN + 8
    check(bool(sb.ping_answer(h0, "move")["obeys"]), "a hero just above the Obedience line obeys a calm ping")
    for i in 10:
        sb.ping("move", spot)
    check(sb.spam_penalty > 0.0 and not bool(sb.ping_answer(h0, "move")["obeys"]),
        "spamming pings lowers Obedience for a while (penalty %.0f): the same hero now refuses" % sb.spam_penalty)
    _run(sb, AiDefs.SPAM_MAX / AiDefs.SPAM_DECAY + 1.0)
    check(sb.spam_penalty <= 0.0, "the spam penalty fades with time")
    # enemy spotted: visible to everyone, a focus hint
    var foe := sb.enemies[0]
    foe.position = sb.map.nearest_walkable(m.position + Vector2(700, 0))
    foe.dormant = false
    foe.alert()
    foe.atk = 0
    sb.fog = FogMap.new(sb.map.width, sb.map.height)       # nothing explored: it is in the dark
    sb.update_fog()
    sb.ping("spotted", foe.position, foe)
    sb.update_fog()
    check(foe.visible and foe.spotted_t > 0.0, "an 'enemy spotted' ping shows the foe to everyone through the fog")
    _run(sb, 1.5)
    check(others.any(func(h): return h.focus_hint == foe), "spotted: the heroes take it as their focus")
    # quick ping is contextual
    var kind := ""
    sb.quick_ping(foe.position + Vector2(0, -10))
    kind = (sb.markers[sb.markers.size() - 1] as PingMarker).kind
    check(kind == "attack", "Shift + click on a foe = attack ping (%s)" % kind)
    sb.quick_ping(spot)
    check((sb.markers[sb.markers.size() - 1] as PingMarker).kind == "move", "Shift + click on the ground = go there")
    sb.queue_free()
    await get_tree().process_frame


# --- 5. revive -----------------------------------------------------------------------------------------

func _revive() -> void:
    _master_account(5151)
    var sb := _screen(-1)
    await get_tree().process_frame
    _clear(sb, [])
    var m := sb.master_hero
    var d: SandboxHero = sb.heroes[1]
    for h in sb.heroes:
        if h != m and h != d:
            h.position = m.position + Vector2(-3000, 0)        # nobody else helps
            h.auto_skills = false
    d.position = sb.map.nearest_walkable(m.position + Vector2(30, 0))
    d.take_hit(DamageInfo.make(99999.0, "true", null))
    check(d.downed and is_equal_approx(d.agony, 120.0), "a downed hero has 120 s before dying")
    check(d.agony_text() == "2:00", "the counter reads 2:00 (over the hero and on its portrait)")
    sb.tick(DT)
    check(d.revive_prompt, "standing next to the fallen shows 'Hold F'")
    check(String(StringsEs.ES.get("Hold F", "")) == "Mantén F", "the prompt is 'Mantén F' in Spanish (interaction is F; QWER = combat)")
    sb.interact_held = true
    _run(sb, 2.0)
    check(d.downed and m.rescue_progress > 1.5, "holding F lifts them over time (%.1f s so far)" % m.rescue_progress)
    m.take_hit(DamageInfo.make(1.0, "true", null))
    check(m.rescue_progress == 0.0, "a hit on the Master interrupts the lift")
    _run(sb, CombatRules.RESCUE_TIME + 0.3)
    check(not d.downed and d.alive, "held ~4 s without being hit: the ally is back on their feet")
    # letting go of F stops it
    d.take_hit(DamageInfo.make(99999.0, "true", null))
    sb.interact_held = false
    _run(sb, 5.0)
    check(d.downed, "without F nothing happens (the right click no longer rescues for the Master)")
    # D-142: a cleric's F is Resurrection, a 4 s channel
    var cls0 := m.hero.hero_class
    m.hero.hero_class = "class.cleric"
    check(String(m.f_action().get("name", "")) == "Resurrection" and is_equal_approx(m.revive_time(), 4.0), "a cleric's F is Resurrection: a 4 s channel (D-142)")
    sb.interact_held = true
    _run(sb, 4.3)
    check(not d.downed and d.alive, "the cleric's Resurrection lifts the fallen ally")
    sb.interact_held = false
    m.hero.hero_class = cls0
    d.take_hit(DamageInfo.make(99999.0, "true", null))
    # nobody lifts them: death at 120 s
    m.position = m.position + Vector2(0, 2000)
    m.position = sb.map.nearest_walkable(m.position)
    for i in roundi(121.0 / 0.5):
        d.tick(0.5)
    check(d.dead, "nobody lifts them: the hero dies after 120 s")
    sb.queue_free()
    await get_tree().process_frame
    # the AI lifts the fallen on its own (healer first)
    _master_account(6161)
    sb = _screen(-1)
    await get_tree().process_frame
    _clear(sb, [])
    m = sb.master_hero
    var cleric: SandboxHero = sb.heroes[2]
    var fallen: SandboxHero = sb.heroes[3]
    cleric.hero.hero_class = "class.cleric"
    cleric.role = "healer"
    cleric.hero.traits = []
    for h in sb.heroes:
        if h != m and h != cleric and h != fallen:
            h.position = m.position + Vector2(-3000, 0)
    fallen.position = sb.map.nearest_walkable(m.position + Vector2(0, 120))
    fallen.take_hit(DamageInfo.make(99999.0, "true", null))
    cleric.position = sb.map.nearest_walkable(m.position + Vector2(60, 0))
    _run(sb, 9.0)
    check(not fallen.downed and fallen.alive, "an autonomous cleric lifts a fallen ally on its own")
    check(cleric.revive_score(fallen) > AiDefs.REVIVE_MIN_SCORE, "the healer's revive priority is high (%.1f)" % cleric.revive_score(fallen))
    var rogue_h: SandboxHero = sb.heroes[4]
    rogue_h.role = "dps"
    rogue_h.hero.traits = []
    var base_s := rogue_h.revive_score(fallen)
    rogue_h.hero.relationships[fallen.hero.id] = {"level": 80, "status": "friend", "interactions": 10}
    check(rogue_h.revive_score(fallen) > base_s, "a high bond with the fallen raises the priority to lift them")
    # the help ping on a fallen ally sends someone
    fallen.take_hit(DamageInfo.make(99999.0, "true", null))
    var helper: SandboxHero = sb.heroes[4]
    helper.position = sb.map.nearest_walkable(fallen.position + Vector2(80, 0))
    cleric.position = m.position + Vector2(-3000, 0)
    sb.set_ping_target(helper)
    sb.ping("help", fallen.position)
    _run(sb, 1.0)
    check(helper.order == "rescue" and helper.rescue_target == fallen, "the 'Help / lift' ping on a fallen ally sends the hero to lift them")
    sb.queue_free()
    await get_tree().process_frame


# --- 7. weapons ------------------------------------------------------------------------------------------

func _dps(sb: SandboxScreen, cls: String, lvl: int, armor: int, seconds: float) -> Dictionary:
    var hd := _plain(cls, lvl, 1200 + lvl)
    var h := SandboxHero.new(hd, 0)
    h.position = sb.map.nearest_walkable(sb.map.center_of(sb.map.spawn_cells[0]))
    sb._world.add_child(h)
    h.crit_chance = 0.0
    h.auto_skills = false
    h.controller = "ai"
    var foe := _dummy(sb, h.position + Vector2(30, 0), armor)
    var t := 0.0
    while t < seconds:
        h.tick(DT)
        h.combat_tick([foe], sb.map)
        t += DT
    var out := {"dps": float(foe.max_hp - foe.hp) / seconds, "attacks": h.basic_attacks, "blows": h.blows}
    h.queue_free()
    foe.alive = false
    foe.queue_free()
    return out


func _weapons() -> void:
    Game.new_game()
    var sb := _screen(-1)
    await get_tree().process_frame
    _clear(sb, [])
    for lvl in [1, 5, 10]:
        var w := _dps(sb, "class.warrior", lvl, 0, 30.0)
        var r := _dps(sb, "class.rogue", lvl, 0, 30.0)
        var ratio := float(r["dps"]) / maxf(0.01, float(w["dps"]))
        check(absf(ratio - 1.0) <= 0.15, "level %d, no armour: rogue %.1f vs warrior %.1f damage/s (%.0f %%, within 15 %%)" % [lvl, r["dps"], w["dps"], ratio * 100.0])
        if lvl == 1:
            check(int(r["blows"]) >= 2 * int(r["attacks"]) - 1 and int(r["attacks"]) > 0 and int(w["blows"]) == int(w["attacks"]),
                "two daggers: two blows per attack (%d attacks, %d blows); the warrior one (%d / %d)" % [r["attacks"], r["blows"], w["attacks"], w["blows"]])
    var w8 := _dps(sb, "class.warrior", 5, 8, 20.0)
    var r8 := _dps(sb, "class.rogue", 5, 8, 20.0)
    var w0 := _dps(sb, "class.warrior", 5, 0, 20.0)
    var r0 := _dps(sb, "class.rogue", 5, 0, 20.0)
    check(float(r8["dps"]) / float(r0["dps"]) < float(w8["dps"]) / float(w0["dps"]),
        "flat armour applies to every blow: daggers keep %.0f %% against armour 8, the sword %.0f %%" % [float(r8["dps"]) / float(r0["dps"]) * 100.0, float(w8["dps"]) / float(w0["dps"]) * 100.0])
    var archer := _plain("class.archer", 5, 77)
    var rh := SandboxHero.new(archer, 0)
    sb._world.add_child(rh)
    check(rh.uses_bow() and LpcWardrobe.STARTER_WEAPON_BY_CLASS["class.archer"] == "weapon_bow" and rh.attack_range() > CombatRules.HERO_RANGED_RANGE,
        "the archer carries the plain LPC bow and shoots further (%.0f px > %.0f)" % [rh.attack_range(), CombatRules.HERO_RANGED_RANGE])
    check(rh.attack_range() <= float(rh.vision_cells() * NavMap.CELL), "the bow never reaches beyond what the hero sees in the fog")
    rh.queue_free()
    sb.queue_free()
    await get_tree().process_frame


# --- arrows: real projectiles ---------------------------------------------------------------------------

func _shoot_at(sb: SandboxScreen, moving: bool, shots: int) -> Dictionary:
    var hd := _plain("class.archer", 5, 4321)
    var h := SandboxHero.new(hd, 0)
    var base := sb.map.center_of(sb.map.spawn_cells[0])
    h.position = base
    sb._world.add_child(h)
    h.auto_skills = false
    h.controller = "ai"
    hd.set_composure(100)                                   # a calm archer: its aim error is small
    var foe := _dummy(sb, base + Vector2(190, 0))
    var lane := foe.position
    var t := 0.0
    var dir := 1.0
    var drawn_seen := false
    while h.shots_fired < shots and t < 60.0:
        h.tick(DT)
        h.combat_tick([foe], sb.map)
        drawn_seen = drawn_seen or h.is_drawing()
        if moving:                                          # strafes up and down across the line of fire
            foe.position.y += dir * 95.0 * DT
            if absf(foe.position.y - lane.y) > 70.0:
                dir = -dir
        t += DT
    for i in 30:
        h.tick(DT)
        if moving:
            foe.position.y += dir * 95.0 * DT
    var out := {"fired": h.shots_fired, "hit": h.shots_hit, "drawn": drawn_seen}
    h.queue_free()
    foe.alive = false
    foe.queue_free()
    return out


func _arrows() -> void:
    Game.new_game()
    var sb := _screen(-1)
    await get_tree().process_frame
    _clear(sb, [])
    var still := _shoot_at(sb, false, 12)
    var moving := _shoot_at(sb, true, 12)
    check(bool(still["drawn"]), "the archer draws the bow (~0.3 s) before every shot")
    check(int(still["hit"]) >= int(still["fired"]) * 0.7, "arrows hit a target that stands still (%d / %d)" % [still["hit"], still["fired"]])
    check(int(moving["hit"]) <= int(moving["fired"]) * 0.4, "arrows are not homing: a target moving across the line dodges most (%d / %d hit)" % [moving["hit"], moving["fired"]])
    var shot := ArrowShot.make(Vector2.ZERO, Vector2.RIGHT, 300.0, "arrow")
    add_child(shot)
    for i in 20:                                            # 300 px at 520 px/s: lands on the 18th tick
        shot.step(DT, [], null)
    check(shot.done and shot.stuck_t > 0.0, "a spent arrow lands and stays stuck for a moment before it fades")
    shot.queue_free()
    sb.queue_free()
    await get_tree().process_frame


# --- elves ---------------------------------------------------------------------------------------------

func _elves() -> void:
    var elves := 0
    for i in 1000:
        var h := HeroGenerator.generate(500000 + i * 13, 1 + i % 5)
        if String(h.look.get("race", "human")) == "elf" or String(h.look.get("ears", "")) != "":
            elves += 1
    check(elves == 0, "no elves in 1000 summons (%d)" % elves)
    var old := HeroGenerator.generate(42, 3).to_dict()
    old["look"]["race"] = "elf"
    old["look"]["ears"] = "ears_elven"
    var back := HeroData.from_dict(old)
    check(String(back.look["race"]) == "elf" and String(back.look["ears"]) == "ears_elven", "an elf already in a save keeps its look")


# --- 6. bandits -----------------------------------------------------------------------------------------

func _bandits() -> void:
    _master_account(8181)
    var sb := _screen(-1)
    await get_tree().process_frame
    _clear(sb, [])
    var m := sb.master_hero
    var cleric: SandboxHero = sb.heroes[1]
    var warrior: SandboxHero = sb.heroes[2]
    cleric.hero.hero_class = "class.cleric"
    warrior.hero.hero_class = "class.warrior"
    var at := sb.map.nearest_walkable(m.position + Vector2(0, 100))
    var assassin := sb._spawn_enemy(sb.map.cell_of(at), "bandido_degollador")
    assassin.position = at
    warrior.position = sb.map.nearest_walkable(at + Vector2(40, 0))
    cleric.position = sb.map.nearest_walkable(at + Vector2(0, 180))
    assassin.alert()
    check(assassin.ai_role == "assassin" and assassin._nearest_hero(sb.heroes) == cleric, "the bandit assassin goes for the cleric, not the nearer warrior")
    assassin.taunt(warrior, 3.0)
    check(assassin._nearest_hero(sb.heroes) == warrior, "...unless a taunt holds it")
    var brute := sb._spawn_enemy(sb.map.cell_of(at), "bandido_bruto")
    brute.position = at
    brute.alert()
    brute.take_hit(DamageInfo.make(30.0, "true", cleric))
    check(brute.ai_role == "brute" and brute._nearest_hero(sb.heroes) == cleric, "the brute follows the highest threat (whoever hurt it most)")
    # the leader buffs, and its death may break the others
    var leader := sb._spawn_enemy(sb.map.cell_of(at), "capitan_bandido")
    leader.position = at + Vector2(-20, 0)
    leader.alert()
    var band: Array = []
    for i in 12:
        var b := sb._spawn_enemy(sb.map.cell_of(at), "bandido_maton")
        b.position = at + Vector2(10 * i, 30)
        b.alert()
        band.append(b)
    leader._allies = sb.living_enemies()
    leader._leader_tick(99.0)
    check(band.all(func(b): return b.has_status("inspired")), "the bandit leader inspires the bandits around it")
    leader.take_hit(DamageInfo.make(999999.0, "true", warrior))
    var fled := band.filter(func(b): return b.flee_t > 0.0).size()
    check(fled > 0 and fled < band.size(), "the leader falls: each nearby bandit rolls to flee (%d of %d ran)" % [fled, band.size()])
    # horn: wakes the sleeping camp nearby
    var horn := sb._spawn_enemy(sb.map.cell_of(at), "bandido_arquero")
    horn.position = at
    horn.job = "horn"
    var sleeper := sb._spawn_enemy(sb.map.cell_of(at), "bandido_maton")
    sleeper.position = at + Vector2(300, 0)
    horn._allies = [horn, sleeper]
    horn.alert()
    horn.group_mates = [horn]
    for i in roundi((AiDefs.HORN_DELAY + 0.5) / 0.1):
        horn._horn_tick(0.1)
    check(sleeper.alerted, "a bandit's horn wakes the sleeping creatures nearby")
    # a low-health bandit may run (rolled once, seeded)
    var runners := 0
    for i in 20:
        var b := sb._spawn_enemy(sb.map.cell_of(at), "bandido_maton")
        b.take_hit(DamageInfo.make(float(b.max_hp) * 0.8, "true", warrior))
        runners += 1 if b.flee_t > 0.0 else 0
    check(runners > 0 and runners < 20, "under 25 %% health some bandits flee (%d of 20)" % runners)
    # a caster's cast is interruptible
    var mage := sb._spawn_enemy(sb.map.cell_of(at), "bandido_mago")
    check(mage.ai_role == "caster" and mage.skills.has("fireball"), "the bandit mage casts Fireball (a wind-up)")
    mage.casting_skill = "fireball"
    mage.state = SandboxEnemy.State.WINDUP
    check(mage.interrupt() and mage.casting_skill == "", "an interrupting blow cancels the enemy cast")
    check(mage.keep_distance() > EnemyDefs.BACK_OFF, "the caster backs off sooner when pressed (%.0f px)" % mage.keep_distance())
    sb.queue_free()
    await get_tree().process_frame


# --- wheel, keys ------------------------------------------------------------------------------------------

func _wheel_and_keys() -> void:
    var c := Vector2(400, 300)
    check(PingWheel.pick_at(c, c).is_empty(), "releasing the wheel in its centre cancels")
    check(String(PingWheel.pick_at(c, c + Vector2(0, -30)).get("ping", "")) == AiDefs.PING_ORDER[0], "the top of the inner ring is '%s'" % AiDefs.PING_ORDER[0])
    check(String(PingWheel.pick_at(c, c + Vector2(30, 0)).get("ping", "")) == AiDefs.PING_ORDER[2], "the right of the inner ring is '%s'" % AiDefs.PING_ORDER[2])
    check(int(PingWheel.pick_at(c, c + Vector2(0, -60)).get("command", -1)) == 0, "the outer ring holds the Commands (top = command 1)")
    check(AiDefs.PING_ORDER.size() == 9 and AiDefs.PING_ORDER.all(func(k): return AiDefs.PINGS.has(k)), "the wheel has the 9 pings (D-090: + camp)")
