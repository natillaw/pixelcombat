extends Control
## D-082: the two test bots ("loco" and "tactical", MasterBot) play whole expeditions with no help: they
## drive only the Master and lead the other four with pings, Commands and skills. Writes per-run stats
## (outcome, time, deaths, downs, pings, Commands) to tests/out/bot_stats.csv.
##   godot --headless --path . res://tests/smoke_bots.tscn --quit-after 3000      (1 run per style)
##   BOT_RUNS=5 BOT_FLOOR=5 godot --headless --path . res://tests/smoke_bots.tscn   (statistics)
## BOT_FLOOR: 0 = the Wilds (tier 1, default), N = tower floor N. MAX_SIM caps each run.
const DT := 1.0 / 30.0
const THINK := 0.25
var RUNS := int(OS.get_environment("BOT_RUNS")) if OS.get_environment("BOT_RUNS") != "" else 1
var FLOOR := int(OS.get_environment("BOT_FLOOR")) if OS.get_environment("BOT_FLOOR") != "" else 0
var MAX_SIM := float(OS.get_environment("BOT_MAX_SIM")) if OS.get_environment("BOT_MAX_SIM") != "" else 360.0
const LEAVE_AFTER := 150.0           # the Wilds have no end: the bot heads home after this long
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Bot tests (D-082) ==")
    Game.autosave = false
    Game.save_path = "user://smoke_bots_%d.json" % OS.get_process_id()
    var rows: Array = ["style,content,run,outcome,time_s,deaths,downs,killed,pings,commands,skills,revives"]
    for style in ["loco", "tactical"]:
        for run in RUNS:
            var r: Dictionary = await _run(style, run)
            rows.append("%s,%d,%d,%s,%.0f,%d,%d,%d,%d,%d,%d,%d" % [style, FLOOR, run, r["outcome"], r["time"], r["deaths"], r["downs"], r["killed"],
                r["stats"]["pings"], r["stats"]["commands"], r["stats"]["skills"], r["stats"]["revives"]])
            print("  %s run %d: %s in %.0f s, deaths %d, downs %d, killed %d, pings %d, commands %d, skills %d, revives %d" % [style, run, r["outcome"], r["time"],
                r["deaths"], r["downs"], r["killed"], r["stats"]["pings"], r["stats"]["commands"], r["stats"]["skills"], r["stats"]["revives"]])
            if not (r["causes"] as Array).is_empty():
                print("    deaths by: %s" % str(r["causes"]))
            check(r["outcome"] != "ACTIVE", "%s bot run %d finished the expedition on its own (%s)" % [style, run, r["outcome"]])
            check(int(r["stats"]["pings"]) > 0, "%s bot led the squad with pings (%d)" % [style, int(r["stats"]["pings"])])
            check(int(r["auto_damage"]) > 0, "%s run %d: the four autonomous heroes did damage on their own (%d)" % [style, run, int(r["auto_damage"])])
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
    var f := FileAccess.open("res://tests/out/bot_stats.csv", FileAccess.WRITE)
    if f != null:
        f.store_string("\n".join(rows) + "\n")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)


func _new_account(seed_value: int) -> void:
    Game.new_game()
    Game.rng.seed = seed_value
    Game.create_master({"first": "Bot", "last": "Master", "class": "class.warrior", "trait": "trait.stubborn",
        "look": {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}})
    Game.starter_summons()
    if FLOOR > 0:
        for f0 in range(1, FLOOR):
            Game.tower_cleared[str(f0)] = 1


func _run(style: String, run: int) -> Dictionary:
    _new_account(9100 + run)
    var sb := SandboxScreen.new(-1 if FLOOR <= 0 else FLOOR)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    await get_tree().process_frame
    sb.set_physics_process(false)
    var bot := MasterBot.new(style)
    var t := 0.0
    var think := 0.0
    var downs := 0
    var seen_down := {}
    var leaving := false
    while sb.mission_state == SandboxScreen.Mission.ACTIVE and t < MAX_SIM:
        sb.tick(DT)
        t += DT
        think -= DT
        if think > 0.0:
            continue
        think = THINK
        for h in sb.heroes:
            if h.downed and not seen_down.has(h):
                seen_down[h] = true
                downs += 1
            elif not h.downed:
                seen_down.erase(h)
        if sb.master_hero != null and not sb.master_hero.alive and sb.living_heroes().is_empty():
            continue
        if not leaving and (t > LEAVE_AFTER or (style == "tactical" and _broken(sb))) and sb.is_wilds():
            leaving = true
        if leaving:
            bot.retreat(sb)
            continue
        bot.think(sb, _goal(sb), THINK)
    var auto_damage := 0.0
    for h in sb.heroes:
        if h != sb.master_hero:
            auto_damage += float(h.contrib.get("damage", 0.0))
    var out := {"outcome": String(SandboxScreen.Mission.keys()[sb.mission_state]), "time": t,
        "deaths": sb.heroes.filter(func(h): return h.dead).size(), "downs": downs, "killed": sb.defeated,
        "stats": bot.stats, "auto_damage": auto_damage,
        "causes": sb.heroes.filter(func(h): return h.dead).map(func(h): return h.killed_by)}
    sb.queue_free()
    await get_tree().process_frame
    return out


func _broken(sb: SandboxScreen) -> bool:
    var standing := sb.heroes.filter(func(h): return h.alive)
    return standing.size() <= 2 and sb.heroes.size() >= 4


## Where the squad should head: the nearest gathering spot in sight, else the nearest unexplored edge.
func _goal(sb: SandboxScreen) -> Vector2:
    var m: SandboxHero = sb.master_hero
    if m == null:
        return Vector2.INF
    var best := Vector2.INF
    for g in sb.nodes:
        if is_instance_valid(g) and not g.taken and g.visible and (best == Vector2.INF or g.position.distance_to(m.position) < best.distance_to(m.position)):
            best = g.position
    if best != Vector2.INF:
        return best
    for e in sb.living_enemies():
        if e.visible and (best == Vector2.INF or e.position.distance_to(m.position) < best.distance_to(m.position)):
            best = e.position
    if best != Vector2.INF:
        return best
    return sb._fog_frontier(sb.map.cell_of(m.position))
