extends RefCounted
## D-083 simulator worker: plays the runs of one job (one variant, some floors x seeds) with the game's
## own SandboxScreen ticked at a fixed step, the MasterBot driving the Master, and writes one result file.
## Started by sim_main.gd as a separate Godot process (run_sim.gd --child <job.json>).

const SimParty := preload("res://tools/sim/sim_party.gd")
const STUCK_SKIP := 25.0
const DEAD_END := 20.0            # s without revealing or killing anything: that frontier is a dead end          # a target the squad cannot reach for this long is skipped (playthrough rule)


func run_job(tree: SceneTree, job: Dictionary, job_path: String) -> void:
    await tree.process_frame                     # the Game autoload is ready
    var out := {"variant": job["label"], "runs": [], "error": ""}
    var cfg: Dictionary = job["config"]
    SimMode.on = true
    Ambience.quality = 0
    SimMode.enemy_hp = float(cfg["enemies"]["hp"])
    SimMode.enemy_dmg = float(cfg["enemies"]["damage"])
    SimMode.enemy_count = float(cfg["enemies"]["count"])
    SimMode.aim_error_mult = float(cfg["bot"]["aim_error_mult"])
    out["effective"] = _effective(cfg["overrides"])
    var presets := SimParty.load_presets()
    var host := Node.new()
    host.name = "SimHost"
    tree.root.add_child(host)
    for r in job["runs"]:
        var res: Dictionary = await _run(tree, host, cfg, int(r["floor"]), int(r["seed"]), presets)
        res["index"] = int(r["index"])
        (out["runs"] as Array).append(res)
        if String(res.get("error", "")) != "":
            out["error"] = res["error"]
            break
    var f := FileAccess.open(String(job["result"]), FileAccess.WRITE)
    f.store_string(JSON.stringify(out))
    f.close()
    SimMode.reset()
    host.queue_free()
    await tree.process_frame
    tree.quit(0 if String(out["error"]) == "" else 4)


func _run(tree: SceneTree, host: Node, cfg: Dictionary, floor_num: int, seed_v: int, presets: Dictionary) -> Dictionary:
    var bc: Dictionary = cfg["bot"]
    cfg = SimParty.with_progress(cfg, floor_num)        # D-084: level and gear of a town that progressed like this
    var err := SimParty.build(cfg, seed_v, presets)
    if err != "":
        return {"error": err, "floor": floor_num, "seed": seed_v}
    for f0 in range(1, floor_num):
        Game.tower_cleared[str(f0)] = 1           # the floors below are done (the gate lets the squad in)
    SimMode.run_seed = absi(hash([seed_v, floor_num])) | 1
    seed(seed_v)                                  # cosmetic randf() calls (chatter) stay reproducible too
    var bag_before := _bag_total()
    var wall0 := Time.get_ticks_usec()
    var sb := SandboxScreen.new(floor_num)
    host.add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    sb.set_process(false)
    var bot := MasterBot.new(String(bc["style"]))
    bot.engage = float(bc["engage"])
    bot.ping_every = float(bc["ping_every"])
    bot.retreat_hp = float(bc["retreat_hp"])
    bot.use_commands = bool(bc["use_commands"])
    bot.use_skills = bool(bc["use_skills"])
    bot.revive = bool(bc["revive"])
    bot.regroup_wait = float(bc["regroup_wait"])
    bot.camp = bool(bc["camp"])
    bot.camp_below = float(bc["camp_below"])
    bot.loot = bool(bc.get("loot", true))            # pista D: loots the bodies (hold F)
    var knows_map := bool(bc["knows_map"])
    var seen := {}
    var lost_t := 0.0
    var dead_ends := {}
    var explored_ref := 0.0
    var kills_ref := 0
    var dt := 1.0 / float(cfg["tick_hz"])
    var think_every := float(bc["think_every"])
    var max_t := float(cfg["max_time"])
    var t := 0.0
    var think := 0.0
    var downs := {}
    var seen_down := {}
    var retreating := false
    var skip_targets: Array = []
    var stuck_ref := Vector2.ZERO
    var stuck_t := 0.0
    var first_contact := -1.0
    while sb.mission_state == SandboxScreen.Mission.ACTIVE and t < max_t:
        sb.tick(dt)
        t += dt
        think -= dt
        if think > 0.0:
            continue
        think = think_every
        for h in sb.heroes:
            if h.downed and not seen_down.has(h):
                seen_down[h] = true
                downs[h] = int(downs.get(h, 0)) + 1
            elif not h.downed:
                seen_down.erase(h)
        var standing: Array = sb.heroes.filter(func(h): return h.alive and not h.downed)
        if standing.is_empty():
            continue
        var c := Vector2.ZERO
        for h in standing:
            c += h.position
        c /= float(standing.size())
        if first_contact < 0.0 and sb.visible_enemies().any(func(e): return e.position.distance_to(c) < 380.0):
            first_contact = t
        # the tactical player leaves a lost fight; the "loco" never does
        if not retreating and bot.tactical() and int(bc["retreat_standing"]) > 0 and standing.size() <= int(bc["retreat_standing"]) \
                and sb.heroes.size() >= 4:
            retreating = true
        if retreating:
            bot.retreat(sb)
            continue
        for e in sb.visible_enemies():
            seen[e] = true
        # D-084: neither bot knows the way: they explore with the fog like a new player. A frontier the squad
        # stands at for DEAD_END s without revealing anything is a dead end and is skipped from then on.
        var goal := MasterBot.mission_goal(sb, c, skip_targets) if knows_map else MasterBot.known_goal(sb, c, skip_targets, seen, dead_ends)
        var explored := sb.fog.explored_fraction()
        if explored > explored_ref + 0.002 or sb.defeated > kills_ref:
            explored_ref = explored
            kills_ref = sb.defeated
            lost_t = 0.0
        else:
            lost_t += think_every
            if lost_t > DEAD_END and goal != Vector2.INF:
                dead_ends[sb.map.cell_of(goal)] = true
                lost_t = 0.0
        if bool(bc["gather"]):
            for g in sb.nodes:                    # a gathering spot close by, if the squad is not carrying the relic
                if is_instance_valid(g) and not g.taken and g.visible and g.position.distance_to(c) < 260.0 \
                        and (sb.carrier == null or sb.mission_type == "combat"):
                    goal = g.position
                    break
        if goal != Vector2.INF:
            if c.distance_to(stuck_ref) < 24.0:
                stuck_t += think_every
            else:
                stuck_t = 0.0
                stuck_ref = c
            if stuck_t > STUCK_SKIP:
                stuck_t = 0.0
                for e in sb.living_enemies():
                    if e.position.distance_to(goal) < 10.0:
                        skip_targets.append(e)
        bot.think(sb, goal, think_every)
    var wall_ms := float(Time.get_ticks_usec() - wall0) / 1000.0
    var res := _collect(sb, cfg, floor_num, seed_v, t, retreating, downs, bot, first_contact, bag_before)
    res["wall_ms"] = wall_ms
    sb.queue_free()
    await tree.process_frame
    return res


func _collect(sb: SandboxScreen, cfg: Dictionary, floor_num: int, seed_v: int, t: float, retreated: bool, downs: Dictionary,
        bot: MasterBot, first_contact: float, bag_before: int) -> Dictionary:
    var state: String = SandboxScreen.Mission.keys()[sb.mission_state]
    var outcome := "TIMEOUT" if state == "ACTIVE" else state
    var reason := ""
    match outcome:
        "SUCCESS":
            reason = ""
        "TIMEOUT":
            reason = "timeout"
        "FAILED":
            if sb.master_lost:
                reason = "master_lost"
            elif float(TowerExpedition.get_floor_config(floor_num).get("time_limit", 0.0)) > 0.0 and sb.elapsed >= float(TowerExpedition.get_floor_config(floor_num).get("time_limit", 0.0)):
                reason = "time_limit"
            elif sb.living_heroes().is_empty() or sb.heroes.all(func(h): return h.dead or h.downed):
                reason = "wipe"
            else:
                reason = "failed"
        "ESCAPED":
            var limit := float(TowerExpedition.get_floor_config(floor_num).get("time_limit", 0.0))
            if limit > 0.0 and sb.elapsed >= limit:
                reason = "time_limit"
            elif retreated:
                reason = "retreat"
            else:
                reason = "escaped"
    var heroes: Array = []
    for h in sb.heroes:
        heroes.append({"name": h.hero.display_name(), "class": String(h.hero.hero_class).trim_prefix("class."), "master": h.hero.is_master,
            "level": h.hero.level, "damage": roundi(float(h.contrib.get("damage", 0.0))), "healing": roundi(float(h.contrib.get("healing", 0.0))),
            "shield": roundi(float(h.contrib.get("shield", 0.0))), "taken": roundi(float(h.contrib.get("tanked", 0.0))),
            "kills": roundi(float(h.contrib.get("kills", 0.0))), "downs": int(downs.get(h, 0)), "dead": h.dead,
            "killed_by": h.killed_by if h.dead else ""})
    var results: Dictionary = sb.results if sb.results is Dictionary else {}
    var reward: Dictionary = results.get("reward", {}) if results.get("reward", {}) is Dictionary else {}
    var reward_items := 0
    var reward_res := {}
    for k in reward:
        if reward[k] is int or reward[k] is float:
            reward_res[String(k)] = reward[k]
        elif reward[k] is Array:
            reward_items += (reward[k] as Array).size()
    return {
        "floor": floor_num, "seed": seed_v, "outcome": outcome, "win": outcome == "SUCCESS", "reason": reason,
        "mission": sb.mission_type, "time": snappedf(t, 0.01), "first_contact": snappedf(first_contact, 0.1),
        "party": sb.heroes.size(), "downs": downs.values().reduce(func(a, b): return a + b, 0),
        "deaths": sb.heroes.filter(func(h): return h.dead).size(),
        "killed": sb.defeated, "enemies": sb.enemies.size(),
        "bot": bot.stats.duplicate(), "heroes": heroes,
        "gathered": sb.ledger.duplicate(), "kept": (results.get("loot", {}) as Dictionary).duplicate(),
        "lost": (results.get("lost_loot", {}) as Dictionary).duplicate(), "reward": reward_res, "reward_items": reward_items,
        "unique": String(results.get("unique", "")), "stash_items": Game.stash.size(),
        "consumables_used": maxi(0, bag_before - _bag_total()), "kill_xp": sb.kill_xp,
        "pista_a": _pista_a_stats(sb),
        # pista D: bodies with loot, items on them (junk), looted, brought home, left/lost, kept by the greedy
        "loot": {"bodies": int(sb.loot_stats["bodies"]), "items": int(sb.loot_stats["items"]), "junk": int(sb.loot_stats["junk"]),
            "looted": int(sb.loot_stats["looted"]), "home": (sb.loot_report.get("items", []) as Array).size(),
            "lost": int(sb.loot_report.get("lost", 0)), "greedy_kept": int(sb.loot_report.get("kept", 0))},
    }


## D-090: synergies fired (by id), camps and arrows, for the report.
static func _pista_a_stats(sb: SandboxScreen) -> Dictionary:
    var out := {"camps": sb.camps_done, "camps_interrupted": sb.camps_interrupted, "arrows_left": 0, "combo_finishers": 0}
    for h in sb.heroes:
        if h.arrows >= 0:
            out["arrows_left"] = int(out["arrows_left"]) + h.arrows
        for k in h.contrib:
            if String(k).begins_with("syn_"):
                out[String(k)] = int(out.get(String(k), 0)) + int(h.contrib[k])
    return out


static func _bag_total() -> int:
    var n := 0
    for id in Game.party:
        if Game.heroes.has(id):
            for k in (Game.heroes[id] as HeroData).bag:
                n += int(Game.heroes[id].bag[k])
    return n


## The value each overridden constant really has in this worker (evidence that the pack was applied).
static func _effective(overrides: Dictionary) -> Dictionary:
    var paths := {}
    for c in ProjectSettings.get_global_class_list():
        paths[String(c["class"])] = String(c["path"])
    var out := {}
    for name in overrides:
        var parts := String(name).split(".")
        var scr := load(String(paths.get(parts[0], ""))) as Script if paths.has(parts[0]) else null
        var v: Variant = scr.get_script_constant_map().get(parts[1]) if scr != null else null
        for k in parts.slice(2):
            if v is Dictionary:
                v = v.get(k, v.get(int(k), null)) if String(k).is_valid_int() else v.get(k)
            elif v is Array and String(k).is_valid_int():
                v = v[int(k)]
        out[name] = v
    return out
