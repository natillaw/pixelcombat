extends Control
## Automated playthrough (not a pass/fail suite): a scripted "player" starts a new account, builds the
## village, and plays floors 1-5 for real. D-082: in the field it is a MasterBot (tests/master_bot.gd): it
## drives ONLY the Master and leads the other four with pings, Commands and skills, like a player (no
## direct orders to the other heroes). No damage cheats. Prints a report for balance review.
##   godot --headless --path . res://tests/playthrough_bot.tscn
const DT := 1.0 / 30.0
const THINK := 0.25
const MAX_SIM := 30.0 * 60.0          # seconds of game time per attempt
var ATTEMPTS := int(OS.get_environment("PT_ATTEMPTS")) if OS.get_environment("PT_ATTEMPTS") != "" else 3

var log_lines: Array = []
const MAX_FARM_RUNS := 12
const FARM_TIME := 420.0                 # seconds a Wilds run lasts before the bot heads home
var total_farm_runs := 0
var _next_floor := 1
var BLIND := OS.get_environment("PT_BLIND") != ""      # first-time player: knows only what the fog revealed
## PT_STYLE=tactical: a thinking player (see _tactical_*). Default "naive": attack whatever is nearest and
## let the heroes' autonomy do the rest (no focus, no dodging, no interrupts).
var TACTICAL := OS.get_environment("PT_STYLE") == "tactical"
## PT_MATRIX=1 (2026-10-31): balance matrix instead of the playthrough. Profiles TACTICO (TACTICAL above +
## formation: tank in front, backline at range, hurt heroes fall back behind the tank) and LOCO (all five
## attack the nearest creature; no micro, no focus, no retreat), each with a bare town and an upgraded one
## (crafted gear + potions), on the Wilds and floors 1, 3, 5, 10. PT_N runs per cell (fixed seeds).
## Writes tests/out/balance_matrix.csv and prints one line per run plus the summary table.
var MATRIX := OS.get_environment("PT_MATRIX") != ""
var LOCO := false
var QUIET := false
const MATRIX_CONTENT := [0, 1, 3, 5, 10]          # 0 = the Wilds (tier 1)
const MATRIX_SQUAD := ["class.warrior", "class.warrior", "class.archer", "class.mage", "class.cleric"]
## D-080: the Master the bot creates; it drives the Master like a player (the other four act on their own).
const BOT_MASTER := {"first": "Bot", "last": "Master", "class": "class.warrior", "trait": "trait.stubborn",
    "look": {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}}


func say(s: String) -> void:
    if QUIET:
        return
    print(s)
    log_lines.append(s)


func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://playthrough_%d.json" % OS.get_process_id()
    if MATRIX:
        await _run_matrix()
        get_tree().quit(0)
        return
    Game.new_game()
    Game.create_master(BOT_MASTER)                  # D-080: a new account starts with the creator
    var first: Array = Game.starter_summons()
    say("== STYLE %s%s" % ["tactical" if TACTICAL else "naive", " (blind)" if BLIND else ""])
    say("== NEW ACCOUNT: %d starter heroes, gems %d, capacity %d" % [first.size(), Game.gems, Game.max_hero_capacity()])
    for h in Game.heroes.values():
        say("  %s" % _hero_line(h))
    say("  stock: %s" % str(Game.hq_outputs))
    _town_turn("start")
    var from_floor := int(OS.get_environment("PT_FROM")) if OS.get_environment("PT_FROM") != "" else 1
    for f0 in range(1, from_floor):
        Game.tower_cleared[str(f0)] = 1
    var to_floor := int(OS.get_environment("PT_TO")) if OS.get_environment("PT_TO") != "" else 10
    for floor_num in range(from_floor, to_floor + 1):
        var done := false
        _next_floor = floor_num
        # D-066: a floor opens only with the town grown enough; materials come from the Wilds
        var farm_runs := 0
        while Game.floor_block(floor_num) != "" and farm_runs < MAX_FARM_RUNS:
            farm_runs += 1
            total_farm_runs += 1
            say("  -> floor %d locked (%s): Wilds run %d" % [floor_num, Game.floor_block(floor_num), farm_runs])
            _pick_party()
            await _play_floor(-Game.wilds_tier(), farm_runs)
            _town_turn("after Wilds run %d" % farm_runs)
        if Game.floor_block(floor_num) != "":
            say("!! FLOOR %d STILL LOCKED after %d Wilds runs — stopping" % [floor_num, farm_runs])
            break
        say("  floor %d open after %d Wilds runs (town day %d)" % [floor_num, farm_runs, Game.town_day()])
        for attempt in range(1, ATTEMPTS + 1):
            _pick_party()
            _gear_up()
            var r: Dictionary = await _play_floor(floor_num, attempt)
            _town_turn("after floor %d attempt %d" % [floor_num, attempt])
            if r["outcome"] == "SUCCESS":
                done = true
                break
            say("  -> Wilds runs for experience and materials before retrying")
            for farm in 2:                            # a player grinds a little before retrying
                _next_floor_saved = _next_floor
                _next_floor = -1                       # Wilds: four go, the smith stays at the forge
                _pick_party()
                _next_floor = _next_floor_saved
                _gear_up()
                await _play_floor(-Game.wilds_tier(), 0)
                total_farm_runs += 1
                _town_turn("after a Wilds run")
            if Game.party_heroes().size() < Game.PARTY_SIZE and Game.heroes.size() < Game.PARTY_SIZE:
                say("!! fewer than 5 heroes left: cannot field a squad")
                break
        if not done:
            say("!! FLOOR %d NOT CLEARED after %d attempts — stopping" % [floor_num, ATTEMPTS])
            break
    say("== FINAL: heroes %d, memorial %d, gems %d, stash %d, cleared %s, Wilds runs %d, town day %d" % [Game.heroes.size(), Game.memorial.size(), Game.gems, Game.stash.size(),
        str(Game.tower_cleared), total_farm_runs, Game.town_day()])
    say("  buildings: %s" % str(Game.town_buildings))
    say("  stock: %s" % str(Game.hq_outputs))
    for h in Game.heroes.values():
        say("  %s" % _hero_line(h))
    var f := FileAccess.open("user://playthrough_report.txt", FileAccess.WRITE)
    if f != null:
        f.store_string("\n".join(log_lines))
    get_tree().quit(0)


func _hero_line(h: HeroData) -> String:
    var p: Array = []
    for k in h.professions:
        p.append("%s%d" % [k, int(h.professions[k]["lvl"])])
    return "%s %d* Lv%d %s pow=%d hp=%d profs=%s job=%s hunger=%d fat=%d stress=%d dis=%s skills=%s eq=%d" % [h.display_name(), h.stars, h.level,
        h.hero_class.replace("class.", ""), h.power(), int(h.get_stats().get("hp", 0)), ",".join(p), h.hq_assignment, h.hunger, h.fatigue, h.stress,
        str(h.diseases.map(func(d): return d["id"])), str(h.loadout), h.equipment.size()]


# --- town ---------------------------------------------------------------------------------------

# beta pass: a player who uses the town builds the forge early and keeps a smith at it (gear for floor 5)
const BUILD_ORDER := ["workshop", "blacksmith", "mine", "lumber_camp", "kitchen", "farm", "alchemy", "town_hall", "warehouse", "ascension", "dorm_3",
    "training_grounds", "infirmary", "common", "library", "barracks", "war_room", "memorial"]
const WORK_ORDER := ["workshop", "blacksmith", "mine", "lumber_camp", "mine", "kitchen", "farm", "alchemy", "infirmary", "workshop", "blacksmith", "farm"]


func _town_turn(why: String) -> void:
    say("-- TOWN (%s) day %d %s" % [why, Game.town_day(), Game.town_time_text()])
    # pending skill choices: take the first option
    for h in Game.heroes.values():
        while not (h as HeroData).skill_choices.is_empty():
            var c: Dictionary = h.skill_choices[0]
            if not h.choose_skill(0, String(c["options"][0])):
                break
        for s in h.skills:
            if h.loadout.size() < SkillDefs.MAX_SLOTS and not h.loadout.has(s):
                h.equip_skill(h.loadout.size(), String(s))
    # D-066: when the next tower floor needs a bigger Summoner's Hall, that comes first
    if Game.floor_block(_next_floor) != "" and Game.construction_block("town_hall") == "":
        Game.build_or_upgrade("town_hall")
        say("  build town_hall -> %d for floor %d (materials left %d)" % [Game.building_level("town_hall") + 1, _next_floor, int(Game.hq_outputs.get("materials", 0))])
    var saving := Game.floor_block(_next_floor) != "" and Game.under_construction("town_hall").is_empty()
    # build what we can afford, in order (when saving for the Hall, only cheap essentials)
    for bid in BUILD_ORDER:
        if saving and not bid in ["workshop", "lumber_camp", "mine"]:
            continue
        if not TownTables.BUILDINGS.has(bid):
            continue
        # the forge before anything else (after the workshop): its gear is what floor 5 asks for
        if bid != "workshop" and bid != "blacksmith" and Game.building_level("blacksmith") == 0 and Game.under_construction("blacksmith").is_empty():
            continue
        if Game.construction_block(bid) == "":
            var lvl := Game.building_level(bid)
            if Game.build_or_upgrade(bid):
                say("  build %s -> %d (materials left %d)" % [bid, lvl + 1, int(Game.hq_outputs.get("materials", 0))])
            else:
                say("  build %s refused: %s" % [bid, Game.last_reason])
    _gear_up()
    # jobs for everyone not in the party
    var party_ids: Array = Game.party.duplicate()
    for h in Game.heroes.values():
        if party_ids.has(h.id) or h.hq_assignment == "construction":
            continue
        if h.hq_assignment != "":
            continue
        var placed := false
        for k in h.professions:
            for bid in TownTables.ids():
                if Game.building_level(bid) > 0 and Game.workplace_prof(bid) == String(k) and Game.assign_work(h, bid) == "":
                    placed = true
                    break
            if placed:
                break
        if not placed:
            for bid in WORK_ORDER:
                if Game.building_level(bid) > 0 and Game.assign_work(h, bid) == "":
                    placed = true
                    break
        say("  job %s (%s) -> %s" % [h.display_name(), ",".join(h.professions.keys()), h.hq_assignment if h.hq_assignment != "" else "NONE: " + Game.last_reason])
    # set default jobs on producing buildings
    var want := {"workshop": "make_materials", "lumber_camp": "fell_wood", "mine": "dig_stone", "kitchen": "cook_meal", "farm": "grow_grain",
        "blacksmith": "smelt_iron", "alchemy": "brew_potion"}
    for bid in want:
        if Game.building_level(bid) > 0 and Game.job_of(bid) != want[bid]:
            if not Game.set_job(bid, String(want[bid])):
                say("  set_job %s %s refused: %s" % [bid, want[bid], Game.last_reason])
    if int(Game.hq_outputs.get("ingot", 0)) >= 4 and Game.building_level("blacksmith") > 0:
        Game.set_job("blacksmith", "forge_weapon")
    # training grounds: 2-star heroes learn a class skill
    for h in Game.heroes.values():
        if Game.training_block(h) == "":
            var opts := Game.training_options(h)
            if not opts.is_empty():
                say("  train %s: %s -> %s" % [h.display_name(), String(opts[0]), Game.train_skill(h, String(opts[0]))])
    # skill books
    for b in Game.skill_books.keys():
        for h in Game.heroes.values():
            if Game.use_skill_book(h, String(b)) == "":
                say("  %s read the book %s" % [h.display_name(), b])
                break
    # equip loot on the party
    for h in Game.party_heroes():
        for it in Game.stash.duplicate():
            var allowed := ItemDefs.slots_for(String(it["base"]))
            for s in allowed:
                if not h.equipment.has(s):
                    var why_eq := Game.equip(h, int(it["uid"]), String(s))
                    if why_eq == "":
                        say("  equip %s on %s" % [ItemDefs.item_label(it), h.display_name()])
                    break
        for res in ["potion", "antidote"]:
            if int(Game.hq_outputs.get(res, 0)) > 0:
                Game.pack_consumable(h, res)
    # ascension
    for h in Game.heroes.values():
        if h.is_max_level() and h.stars < 5:
            say("  %s at level cap %d: ascension blocked: %s" % [h.display_name(), h.level, Game.promotion_block(h)])
        if Game.promotion_block(h) == "":
            var r := Game.attempt_promotion(h)
            say("  ascension %s: %s" % [h.display_name(), str(r)])
    # summon if beds and gems
    var before := Game.heroes.size()
    if Game.can_summon(1) and Game.gems >= int(SummonConfig.BANNERS[SummonConfig.DEFAULT_BANNER].get("cost_single", 999999)):
        Game.pull(1)
    if Game.heroes.size() > before:
        say("  summoned %d hero(es)" % (Game.heroes.size() - before))
    var rep := Game.pass_time(12)
    say("  12h passed: produced %s events %s" % [str(rep.get("produced", {})), str((rep.get("events", []) as Array).slice(0, 6))])
    say("  stock: %s" % str(Game.hq_outputs))
    say("  problems: %s" % str(Game.town_problems))
    say("  construction: %s  builders %d" % [str(Game.construction), Game.builders().size()])


## Like a player who uses the town (beta pass, 2026-11-01): the smith works on the missing piece of the
## current tier (armour first), and before every outing each squad hero wears the best stash item it
## may use (ItemLibrary.equip_block) for every slot.
func _gear_up() -> void:
    var tier := ItemLibrary.tier_of_floor(maxi(1, _next_floor))
    if Game.building_level("blacksmith") > 0 and Game.workers_at("blacksmith").is_empty():
        # the smith fell or was drafted: the best free hero takes the forge (a player would)
        var free: Array = Game.heroes.values().filter(func(h): return (h as HeroData).knows_prof("blacksmith") and Game.party_slot_of((h as HeroData).id) < 0)
        free.sort_custom(func(a, b): return (a as HeroData).prof_level("blacksmith") > (b as HeroData).prof_level("blacksmith"))
        if not free.is_empty():
            Game.assign_work(free[0], "blacksmith")
            say("  smith: %s takes the forge" % (free[0] as HeroData).display_name())
    if Game.building_level("blacksmith") > 0:
        var want := ""
        for base in ["mail", "helm", "greaves", "boots", "gloves", "sword", "shield"]:
            var have := Game.stash.any(func(it): return String(it.get("base", "")) == base) or Game.party_heroes().any(func(h): return (h as HeroData).equipment.values().any(func(it): return it is Dictionary and String(it.get("base", "")) == base))
            if not have:
                want = base
                break
        if want != "":
            var rid := ItemLibrary.recipe_id("blacksmith", want, tier)
            var best := 0
            for w in Game.workers_at("blacksmith"):
                best = maxi(best, int((w as HeroData).professions.get("blacksmith", {}).get("lvl", 0)))
            var need := int(ItemLibrary.recipes().get(rid, {}).get("min", 0))
            # a novice smith learns on the level-0 job first (smelting), like a player would
            Game.set_job("blacksmith", rid if best >= need else "smelt_iron")
    for h in Game.party_heroes():
        var hd: HeroData = h
        for it in Game.stash.duplicate():
            if ItemLibrary.equip_block(hd, it) != "":
                continue
            var slots := ItemDefs.slots_for(String(it["base"]))
            if slots.is_empty():
                continue
            var cur = hd.equipment.get(String(slots[0]), null)
            if cur == null or int(it.get("ilvl", 0)) * 10 + ItemDefs.RARITY_ORDER.find(String(it.get("rarity", "common"))) > int(cur.get("ilvl", 0)) * 10 + ItemDefs.RARITY_ORDER.find(String(cur.get("rarity", "common"))):
                Game.equip(hd, int(it["uid"]), String(slots[0]))


var _next_floor_saved := 1


func _party_score(h: HeroData) -> int:
    var s := (100000 if Game.is_fighter(h) else 0) + h.power()
    if h.hq_assignment == "blacksmith":
        s -= 1000000                                  # the smith is the last to be drafted
    elif h.hq_assignment != "":
        s -= 50000
    return s


func _pick_party() -> void:
    Game.clear_party()                              # keeps the Master in slot 1 (D-080)
    var first := 1 if Game.master() != null else 0
    var pool: Array = Game.heroes.values().filter(func(h): return h.hq_assignment != "construction" and not h.is_master)
    # beta pass: only as many as the floor lets in, and town workers (the smith first) stay home when
    # others can go; a player keeps the forge running
    var need := TowerExpedition.party_max(_next_floor) if _next_floor > 0 else Game.PARTY_SIZE - 1
    pool.sort_custom(func(a, b): return _party_score(a) > _party_score(b))
    if pool.size() < need:
        pool = Game.heroes.values()
    for i in mini(need - first, pool.size()):
        var h: HeroData = pool[i]
        if h.hq_assignment != "" and h.hq_assignment != "construction":
            Game.assign_work(h, "")
        Game.assign_party(first + i, h.id)


# --- expedition ---------------------------------------------------------------------------------

func _centre(list: Array) -> Vector2:
    var c := Vector2.ZERO
    for h in list:
        c += h.position
    return c / float(maxi(1, list.size()))


## Objective with full knowledge of the map (a replay: the player already knows the floor).
func _goal(sb: SandboxScreen, c: Vector2, skip_targets: Array) -> Vector2:
    return MasterBot.mission_goal(sb, c, skip_targets)   # D-083: shared with the simulator


## Objective as a first-time player knows it: only what the squad has seen (fog of war).
func _known_goal(sb: SandboxScreen, c: Vector2, skip_targets: Array, seen: Dictionary) -> Vector2:
    var known := func(p: Vector2) -> bool: return sb.fog.is_explored(sb.map.cell_of(p))
    var goal := Vector2.INF
    match sb.mission_type:
        "combat":
            var best_d := INF
            for e in sb.living_enemies():
                if skip_targets.has(e) or not (seen.has(e) or sb.revealed_enemies().has(e)):
                    continue
                var d: float = e.position.distance_to(c)
                if d < best_d:
                    best_d = d
                    goal = e.position
        "exploration":
            var best_d := INF
            for cl in sb.clues:
                if cl.visible and known.call(cl.position) and cl.position.distance_to(c) < best_d:
                    best_d = cl.position.distance_to(c)
                    goal = cl.position
        "retrieval", "rescue":
            if sb.carrier != null:
                goal = sb.map.center_of(sb.map.extract_cell)
            elif known.call(sb.relic.position):
                goal = sb.relic.position
        "boss":
            if sb.boss != null and (seen.has(sb.boss) or known.call(sb.boss.position)):
                goal = sb.boss.position
    return goal


## Nearest explored walkable cell next to never-seen fog (breadth-first from the squad).
func _frontier(sb: SandboxScreen, from: Vector2i) -> Vector2:
    var m := sb.map
    var seen_c := {from: true}
    var queue: Array[Vector2i] = [from]
    var head := 0
    while head < queue.size():
        var cc: Vector2i = queue[head]
        head += 1
        for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var n: Vector2i = cc + d
            if seen_c.has(n) or m.is_blocked_cell(n):
                continue
            seen_c[n] = true
            if not sb.fog.is_explored(n):
                return m.center_of(cc)
            queue.append(n)
    return Vector2.INF


# --- balance matrix (PT_MATRIX) -----------------------------------------------------------------

func _matrix_squad(seed_base: int, lvl: int, upgraded: bool) -> void:
    Game.new_game()
    Game.onboarded = true
    Game.rng.seed = seed_base
    var n := 0
    for cls in MATRIX_SQUAD:
        var h: HeroData = null
        var k := 0
        if n == 0:                                    # D-080: the first warrior is the Master
            var mc: Dictionary = BOT_MASTER.duplicate(true)
            mc["seed"] = seed_base * 131 + 7
            mc["class"] = cls
            h = Game.create_master(mc)
        while h == null or String(h.hero_class) != cls:
            k += 1
            h = HeroGenerator.generate(seed_base * 131 + k * 7 + n, 3)
            if k > 400:
                break
        h.level = mini(lvl, h.level_cap())
        Game.heroes[h.id] = h
        if not h.is_master:
            Game.assign_party(n, h.id)
        n += 1
        if upgraded:
            _matrix_gear(h, lvl)
    Game.rng.seed = seed_base


## "Pueblo con mejoras": crafted gear in every open slot (rare, item level = hero level + 2) and potions.
func _matrix_gear(h: HeroData, lvl: int) -> void:
    var used := {}
    for bid in ItemDefs.BASES:
        var b: Dictionary = ItemDefs.BASES[bid]
        var slots := ItemDefs.slots_for(String(bid))
        if slots.is_empty() or used.has(slots[0]) or (b.has("classes") and not (b["classes"] as Array).has(h.hero_class)):
            continue
        var it := ItemGen.generate(Game.rng, Game._next_uid(), lvl + 2, "rare", String(bid))
        Game.stash.append(it)
        if Game.equip(h, int(it["uid"]), String(slots[0])) == "":
            used[slots[0]] = true
    Game.hq_outputs["potion"] = int(Game.hq_outputs.get("potion", 0)) + 3
    for i in 2:
        Game.pack_consumable(h, "potion")


func _run_matrix() -> void:
    var n_runs := int(OS.get_environment("PT_N")) if OS.get_environment("PT_N") != "" else 10
    var only := OS.get_environment("PT_ONLY")            # e.g. "5" or "0,1": only these contents
    var profiles: Array = ["TACTICO", "LOCO"] if OS.get_environment("PT_PROFILE") == "" else [OS.get_environment("PT_PROFILE")]
    var rows: Array = []
    QUIET = true
    for profile in profiles:
        TACTICAL = profile == "TACTICO"
        LOCO = profile == "LOCO"
        for upgraded in [false, true]:
            var contents: Array = MATRIX_CONTENT if only == "" else Array(only.split(",")).map(func(x): return int(x))
            for content in contents:
                var wins := 0
                var t_sum := 0.0
                var d_sum := 0
                var xp_sum := 0.0
                for i in n_runs:
                    var seed_v: int = 1000 + content * 100 + i
                    _matrix_squad(seed_v, 1 + content if content > 0 else 2, upgraded)
                    var fl: int = content if content > 0 else -1
                    var r: Dictionary = await _play_floor(fl, i + 1)
                    var win: bool = r["outcome"] == "SUCCESS" or (content == 0 and r["outcome"] == "ESCAPED" and int(r["dead"]) == 0)
                    wins += 1 if win else 0
                    t_sum += float(r["time"])
                    d_sum += int(r["dead"])
                    xp_sum += float(r["xp"])
                    print("RUN %s %s %s #%d %s t=%.0f dead=%d xp=%.0f breaks=%d boss=%.2f" % [profile, "mej" if upgraded else "sin", "wilds" if content == 0 else "F%d" % content,
                        i + 1, r["outcome"], r["time"], r["dead"], r["xp"], r["breaks"], r["boss_hp"]])
                rows.append([profile, "si" if upgraded else "no", "wilds" if content == 0 else "piso%d" % content,
                    float(wins) / float(n_runs), t_sum / float(n_runs), float(d_sum) / float(n_runs), xp_sum / float(n_runs)])
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
    var csv := OS.get_environment("PT_CSV") if OS.get_environment("PT_CSV") != "" else "res://tests/out/balance_matrix.csv"
    var f := FileAccess.open(csv, FileAccess.WRITE)
    f.store_line("perfil,mejoras,contenido,winrate,tiempo_medio,muertes_medias,xp_media")
    print("RESULT perfil   mej contenido winrate  t_medio muertes xp")
    for r in rows:
        f.store_line("%s,%s,%s,%.2f,%.0f,%.2f,%.0f" % r)
        print("RESULT %-8s %-3s %-9s %5.0f%%  %6.0f  %5.2f  %4.0f" % [r[0], r[1], r[2], float(r[3]) * 100.0, r[4], r[5], r[6]])
    f.close()


func _play_floor(floor_num: int, attempt: int) -> Dictionary:
    var cfg := TowerExpedition.get_floor_config(floor_num)
    var sb := SandboxScreen.new(floor_num)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    await get_tree().process_frame
    sb.set_physics_process(false)
    say("== FLOOR %d (%s, %s) attempt %d: map %dx%d, enemies %d, nodes %d" % [floor_num, cfg["mission"], cfg["difficulty"], attempt,
        sb.map.width, sb.map.height, sb.enemies.size(), sb.nodes.size()])
    for h in sb.heroes:
        say("  squad %s hp=%d range=%.0f res=%s slots=%s" % [h.hero.display_name(), h.max_hp, h.attack_range(), h.res_kind, str(h.slots)])
    var t := 0.0
    var think := 0.0
    var order_t := 0.0
    var last_goal := Vector2.INF
    var stuck_ref := Vector2.ZERO
    var stuck_t := 0.0
    var skills_used := 0
    var skill_refusals := {}
    var retreating := false
    var downs := 0
    var seen_down := {}
    var min_hp_frac := 1.0
    var skip_targets: Array = []
    var first_contact := -1.0
    var hp_seen := {}
    var seen := {}
    var skip_nodes: Array = []
    var first_full_explore := -1.0
    var hurt_by := {}
    var bot := MasterBot.new("tactical" if TACTICAL and not LOCO else "loco")   # D-082: Master + pings only
    while sb.mission_state == SandboxScreen.Mission.ACTIVE and t < MAX_SIM:
        sb.tick(DT)
        t += DT
        think -= DT
        order_t -= DT
        if think > 0.0:
            continue
        think = THINK
        # who hurts the squad: hits from creatures the heroes cannot see (fog) are counted apart
        for h in sb.heroes:
            var prev := int(hp_seen.get(h, h.max_hp))
            if h.alive and h.hp < prev:
                var src = null
                for e in sb.living_enemies():
                    if src == null or e.position.distance_to(h.position) < src.position.distance_to(h.position):
                        src = e
                if src != null:
                    var key := "%s %s" % [src.type_id, "VISIBLE" if src.visible else "HIDDEN"]
                    hurt_by[key] = int(hurt_by.get(key, 0)) + (prev - h.hp)
            hp_seen[h] = h.hp
        if OS.get_environment("PT_TRACE") != "" and fmod(t, 30.0) < THINK:
            var st: Array = sb.heroes.filter(func(h): return h.alive)
            say("    trace t=%.0f c=%s goal=%s orders=%s paths=%s targets=%s" % [t, str(sb.map.cell_of(_centre(st))), str(sb.map.cell_of(last_goal)) if last_goal != Vector2.INF else "-",
                str(st.map(func(h): return h.order)), str(st.map(func(h): return h.path.size())), str(st.map(func(h): return h.target.type_id if h.target != null else "-"))])
        var alive: Array = sb.heroes.filter(func(h): return h.alive)
        var standing: Array = alive.filter(func(h): return not h.downed)
        for h in sb.heroes:
            if h.downed and not seen_down.has(h):
                seen_down[h] = true
                downs += 1
            elif not h.downed:
                seen_down.erase(h)
            if h.alive:
                min_hp_frac = minf(min_hp_frac, float(h.hp) / float(h.max_hp))
        if standing.is_empty():
            continue
        var c := _centre(standing)
        var foes: Array = sb.visible_enemies()
        for e in foes:
            seen[e] = true
        var near_foes: Array = foes.filter(func(e): return e.position.distance_to(c) < 380.0)
        if not near_foes.is_empty() and first_contact < 0.0:
            first_contact = t
        # D-065 / D-082: both styles rely on the heroes' own autonomy; the bot only plays the Master and
        # leads with pings and Commands (MasterBot). It lifts the fallen itself by holding F (tactical).
        # D-066 Wilds: head home with the haul after a while, when everything is taken, or when hurt
        if sb.is_wilds() and not retreating:
            var hurt := 0.0
            for h in standing:
                hurt += float(h.hp) / float(h.max_hp)
            hurt /= float(maxi(1, standing.size()))
            var left: int = sb.nodes.filter(func(g): return is_instance_valid(g) and not g.taken).size()
            if t > FARM_TIME or left == 0 or (not LOCO and (hurt < 0.4 or standing.size() <= 3)):
                retreating = true
                bot.retreat(sb)
                say("  t=%.0fs Wilds: heading home (spots left %d, squad health %.0f%%, standing %d)" % [t, left, hurt * 100.0, standing.size()])
        # retreat when the squad is broken
        if not retreating and not LOCO and standing.size() <= 2 and sb.heroes.size() >= 4:
            retreating = true
            bot.retreat(sb)
            say("  t=%.0fs squad broken (%d standing): retreat" % [t, standing.size()])
        if retreating:
            bot.retreat(sb)
            continue
        if not near_foes.is_empty():
            skills_used += bot.think(sb, Vector2.INF, THINK)
            continue
        # objective
        var goal := _known_goal(sb, c, skip_targets, seen) if BLIND else _goal(sb, c, skip_targets)
        # a gathering spot close by first (only one the squad can see and walk to)
        for g in sb.nodes:
            if is_instance_valid(g) and not g.taken and g.visible and not skip_nodes.has(g) and g.position.distance_to(c) < 260.0 \
                    and (sb.carrier == null or sb.mission_type == "combat"):
                if sb.map.find_path(c, g.position).is_empty():
                    skip_nodes.append(g)
                    continue
                goal = g.position
                break
        if goal == Vector2.INF and BLIND:
            goal = _frontier(sb, sb.map.cell_of(c))
            if goal == Vector2.INF and first_full_explore < 0.0:
                first_full_explore = t
        if t > 90.0 and t < 90.0 + THINK and sb.defeated == 0:
            say("  !! no kill after 90 s: centre %s goal %s path %d boss %s at %s blocked=%s heroes %s" % [str(sb.map.cell_of(c)),
                str(sb.map.cell_of(goal)) if goal != Vector2.INF else "INF", sb.map.find_path(c, goal).size() if goal != Vector2.INF else -1,
                sb.boss.type_id if sb.boss != null else "null", str(sb.map.cell_of(sb.boss.position)) if sb.boss != null else "-",
                str(sb.map.is_blocked_cell(sb.map.cell_of(sb.boss.position))) if sb.boss != null else "-",
                str(sb.heroes.map(func(h): return "%s:%s:%d" % [str(sb.map.cell_of(h.position)), h.order, h.path.size()]))])
            for h in sb.heroes:
                say("    hero %s pos %s can_move %s can_act %s path0 %s d0 %.0f dodge %.2f casting '%s' target %s carrying %s vel %.1f" % [h.hero.hero_name,
                    str(h.position.round()), str(h.can_move()), str(h.can_act()), str(h.path[0].round()) if not h.path.is_empty() else "-",
                    h.position.distance_to(h.path[0]) if not h.path.is_empty() else -1.0, h._dodge_t, h.casting, h.target.type_id if h.target != null else "-",
                    str(h.carrying), h.velocity.length()])
            say("    goal is node: %s ; save user://stuck_floor%d_%d.json" % [str(sb.nodes.any(func(g): return is_instance_valid(g) and g.position == goal)), floor_num, OS.get_process_id()])
            Game.save_game()
            DirAccess.copy_absolute(ProjectSettings.globalize_path(Game.save_path), ProjectSettings.globalize_path("user://stuck_floor%d_%d.json" % [floor_num, OS.get_process_id()]))
        if goal == Vector2.INF:
            skills_used += bot.think(sb, Vector2.INF, THINK)
            continue
        if c.distance_to(stuck_ref) < 24.0:
            stuck_t += THINK
        else:
            stuck_t = 0.0
            stuck_ref = c
        if stuck_t > 25.0:
            say("  t=%.0fs squad stuck near %s heading to %s (mission %s)" % [t, str(sb.map.cell_of(c)), str(sb.map.cell_of(goal)), sb.mission_type])
            stuck_t = 0.0
            for e in sb.living_enemies():
                if e.position.distance_to(goal) < 10.0:
                    skip_targets.append(e)
        last_goal = goal
        skills_used += bot.think(sb, goal, THINK)
    var outcome: String = SandboxScreen.Mission.keys()[sb.mission_state]
    if sb.mission_state == SandboxScreen.Mission.ACTIVE:
        outcome = "TIMEOUT"
        say("  TIMEOUT after %.0f s: enemies left %d/%d, clues left %d, carrier %s" % [t, sb.living_enemies().size(), sb.enemies.size(),
            sb.clues.filter(func(x): return x.visible).size(), str(sb.carrier != null)])
        var cc := _centre(sb.heroes.filter(func(h): return h.alive))
        say("    squad centre %s" % str(sb.map.cell_of(cc)))
        Game.save_game()
        DirAccess.copy_absolute(ProjectSettings.globalize_path(Game.save_path), ProjectSettings.globalize_path("user://stuck_floor%d_%d.json" % [floor_num, OS.get_process_id()]))
        for e in sb.living_enemies():
            var p := sb.map.find_path(cc, e.position)
            say("    stuck foe %s at %s home %s path_len %d last_pt %s blocked=%s state=%s" % [e.type_id, str(sb.map.cell_of(e.position)),
                str(sb.map.cell_of(e.home)) if e.home != Vector2.INF else "-", p.size(), str(sb.map.cell_of(p[p.size() - 1])) if not p.is_empty() else "-",
                str(sb.map.is_blocked_cell(sb.map.cell_of(e.position))), str(e.get("state"))])
        for e in sb.living_enemies().slice(0, 6):
            say("    left: %s at %s dormant=%s visible=%s" % [e.type_id, str(sb.map.cell_of(e.position)), str(e.dormant), str(e.visible)])
    if BLIND:
        say("  explored %.0f%% of the floor" % (sb.fog.explored_fraction() * 100.0))
    say("  RESULT %s in %d:%02d (first contact %.0fs), killed %d/%d, downs %d, fallen %s, min hp %.0f%%, skills used %d, bot %s" % [outcome,
        int(t) / 60, int(t) % 60, first_contact, sb.defeated, sb.enemies.size(), downs, str(sb.fallen), min_hp_frac * 100.0, skills_used, str(bot.stats)])
    say("  damage taken by nearest source: %s" % str(hurt_by))
    for h in sb.heroes:
        if h.dead:
            say("    DEATH %s killed_by=%s" % [h.hero.display_name(), h.killed_by])
    if not skill_refusals.is_empty():
        say("  skill refusals: %s" % str(skill_refusals))
    for h in sb.heroes:
        say("    %s alive=%s hp=%d/%d contrib=%s" % [h.hero.display_name(), str(not h.dead), h.hp, h.max_hp, str(h.contrib)])
    say("  ledger %s  reward %s  mvp %s" % [str(sb.ledger), str(sb.results.get("reward", {})), str(sb.results.get("mvp", ""))])
    say("  xp %s" % str((sb.results.get("xp", []) as Array).map(func(x): return "%s +%d Lv%d->%d%s" % [x["name"], x["xp"], x["from"], x["to"], " CAP" if x["capped"] else ""])))
    if not sb.town_report.is_empty():
        say("  town while away: %s" % str((sb.town_report.get("events", []) as Array).slice(0, 8)))
    var dead_n: int = sb.heroes.filter(func(h): return h.dead).size()
    var xps: Array = (sb.results.get("xp", []) as Array).map(func(x): return float(x["xp"]))
    var xp_avg := 0.0
    for x in xps:
        xp_avg += float(x) / float(xps.size())
    var breaks := sb.shield_breaks
    var boss_hp := (float(sb.boss.hp) / float(sb.boss.max_hp)) if sb.boss != null else -1.0
    sb.queue_free()
    await get_tree().process_frame
    return {"outcome": outcome, "time": t, "dead": dead_n, "xp": xp_avg, "breaks": breaks, "boss_hp": boss_hp}
