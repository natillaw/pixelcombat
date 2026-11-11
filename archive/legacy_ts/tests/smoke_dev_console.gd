extends Control
## D-146 dev console: locked without the key, wrong key, lockout after 3, right key, "cheated" flag
## (save + migration + local log), the key never shown, and a few cheats on a live floor.
## The real key is never in the repo: the right-key case swaps in the hash of a test key.
##   godot --headless --path . res://tests/smoke_dev_console.tscn
const TEST_KEY := "test-key-123"
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Dev console tests (D-146) ==")
    Game.autosave = false
    Game.save_path = "user://smoke_dev_console_%d.json" % OS.get_process_id()
    Game.new_game()
    Game.rng.seed = 4242
    Game.create_master({"first": "Dev", "last": "Master", "class": "class.warrior", "trait": "trait.stubborn",
        "look": {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}})
    Game.starter_summons()
    DevCommands.reset_session()
    _locked()
    _keys()
    _save()
    await _cheats()
    await _floors()
    DevCommands.reset_session()
    DirAccess.remove_absolute(Game.save_path)
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)


func _console() -> Node:
    return get_tree().root.get_node_or_null("DevConsole")


func _locked() -> void:
    var con = _console()
    check(con != null, "DevConsole autoload exists")
    check(DevCommands.KEY_HASH.length() == 64 and DevCommands.KEY_HASH.is_valid_hex_number(), "only a SHA-256 hash of the key is stored in the code")
    con.set_open(true)
    check(con.is_open() and DevCommands.console_open and not DevCommands.unlocked and not Game.cheated,
        "opening the console enables nothing and does not mark the game")
    var out: String = con.submit("/god")
    check(out == "bloqueado" and not DevCommands.god, "a cheat without the key answers 'bloqueado' (%s)" % out)
    check(con.submit("/help") == "bloqueado" and con.submit("/floor goto 3") == "bloqueado", "every other command is locked too")
    check(DevCommands.complete("") == ["key"], "autocomplete offers only /key while locked")
    con.set_open(false)
    check(not con.is_open() and not DevCommands.console_open, "the console closes")


func _keys() -> void:
    var con = _console()
    DevCommands.key_hash = DevCommands.hash_key(TEST_KEY)
    var out: String = con.submit("/key wrong-one")
    check(out.begins_with("Clave incorrecta") and not DevCommands.unlocked and not Game.cheated, "a wrong key is refused (%s)" % out)
    con.submit("/key wrong-two")
    out = con.submit("/key wrong-three")
    check(out.contains("30 s"), "3 wrong keys lock the console for 30 s (%s)" % out)
    out = con.submit("/key " + TEST_KEY)
    check(out.begins_with("Bloqueada") and not DevCommands.unlocked, "while locked out even the right key is refused (%s)" % out)
    DevCommands.lock_until = 0                     # the 30 s pass
    var log_before := FileAccess.get_file_as_string(DevCommands.LOG_PATH) if FileAccess.file_exists(DevCommands.LOG_PATH) else ""
    out = con.submit("/key " + TEST_KEY)
    check(DevCommands.unlocked and out.begins_with("Consola desbloqueada"), "the right key unlocks (%s)" % out)
    check(Game.cheated, "unlocking marks the game as cheated")
    var shown: String = con._log.get_parsed_text()
    check(not shown.contains(TEST_KEY) and not con.history.any(func(h): return String(h).contains(TEST_KEY)),
        "the key is never shown in the console log or kept in the history")
    var log_now := FileAccess.get_file_as_string(DevCommands.LOG_PATH)
    check(log_now.length() > log_before.length() and log_now.contains("unlock") and not log_now.contains(TEST_KEY),
        "the local cheat log records the unlock, never the key")
    check(DevCommands.complete("floor").has("floor goto") and DevCommands.complete("floor").has("floor reset"), "autocomplete lists the commands")
    check(con.submit("/help").contains("/quickload"), "/help lists every command")


func _save() -> void:
    Game.save_game()
    Game.cheated = false
    Game.load_game()
    check(Game.cheated, "the cheated flag survives save/load (v%d)" % Game.SAVE_VERSION)
    var m := Game._migrate({"version": 20})
    check(int(m["version"]) == Game.SAVE_VERSION and Game.SAVE_VERSION >= 21 and m.has("cheated") and not bool(m["cheated"]),
        "save v20 -> v21: old games are not cheated")
    Game.new_game()
    check(not Game.cheated, "a new game starts clean")
    Game.rng.seed = 4243
    Game.create_master({"first": "Dev", "last": "Again", "class": "class.warrior", "trait": "trait.stubborn",
        "look": {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}})
    Game.starter_summons()


func _cheats() -> void:
    var con = _console()
    var sb := SandboxScreen.new(3)
    add_child(sb)
    sb.size = Vector2(640, 360)
    sb.set_physics_process(false)
    await get_tree().process_frame
    con.submit("/speed 1")
    check(Game.cheated, "using a cheat in a new game marks it cheated again")
    var m: SandboxHero = sb.master_hero
    check(m != null, "floor 3 has the Master")
    con.submit("/god")
    var hp := m.hp
    m.take_damage(500)
    check(m.dev_god and m.hp == hp and not m.downed, "/god: the Master takes no damage")
    con.submit("/god")
    m.take_damage(5)
    check(not m.dev_god and m.hp < hp, "/god off: damage lands again (nothing left behind)")
    con.submit("/heal")
    check(m.hp == m.max_hp, "/heal")
    con.submit("/fly")
    var wall := Vector2.INF
    for y in sb.map.height:
        for x in sb.map.width:
            if sb.map.is_blocked_cell(Vector2i(x, y)) and wall == Vector2.INF and x > 0 and y > 0:
                wall = sb.map.center_of(Vector2i(x, y))
    m.position = wall
    con.submit("/fly")
    check(not m.dev_fly and not sb.map.is_blocked(m.position), "/fly off never leaves the Master inside a wall")
    con.submit("/ai freeze")
    check(sb.ai_frozen, "/ai freeze")
    var e: SandboxEnemy = sb.living_enemies()[0]
    var at := e.position
    for i in 30:
        sb.tick(1.0 / 30.0)
    check(e.position == at, "frozen creatures do not move")
    con.submit("/ai freeze")
    con.submit("/fog off")
    check(sb.fog_off and sb.living_enemies().all(func(x): return x.visible or x.dormant), "/fog off shows the creatures")
    con.submit("/fog on")
    check(not sb.fog_off, "/fog on")
    var n := sb.living_enemies().size()
    con.submit("/spawn orc 2")
    check(sb.living_enemies().size() == n + 2, "/spawn orc 2")
    con.submit("/killall")
    check(sb.living_enemies().is_empty(), "/killall")
    con.submit("/floor complete")
    check(sb.mission_state == SandboxScreen.Mission.SUCCESS, "/floor complete ends the floor with success")
    con.submit("/time skip 2")
    con.submit("/res add wood 5")
    check(int(Game.hq_outputs.get("wood", 0)) >= 5, "/res add")
    sb.queue_free()
    await get_tree().process_frame


func _find(n: Node) -> SandboxScreen:
    if n is SandboxScreen and not n.is_queued_for_deletion():
        return n
    for c in n.get_children():
        var f := _find(c)
        if f != null:
            return f
    return null


func _floors() -> void:
    var con = _console()
    var main: Node = load("res://scenes/main.tscn").instantiate()
    get_tree().root.add_child(main)
    await get_tree().process_frame
    con.submit("/floor goto 2")
    await get_tree().process_frame
    await get_tree().process_frame
    var a := _find(get_tree().root)
    check(a != null and a.floor_number == 2, "/floor goto 2 opens floor 2")
    var seed_a := (a.map as ProceduralMap).seed_value if a != null and a.map is ProceduralMap else -1
    con.submit("/spawn orc 3")
    var old_id := a.get_instance_id() if a != null else 0
    con.submit("/floor reset")
    await get_tree().process_frame
    await get_tree().process_frame
    var b := _find(get_tree().root)
    check(b != null and b.get_instance_id() != old_id and not is_instance_valid(instance_from_id(old_id)),
        "/floor reset frees the old floor screen (its nodes, waves and zones go with it)")
    check(b != null and b.map is ProceduralMap and (b.map as ProceduralMap).seed_value == seed_a, "/floor reset keeps the same seed")
    con.submit("/god")
    con.submit("/respawn")
    await get_tree().process_frame
    await get_tree().process_frame
    var c := _find(get_tree().root)
    check(c != null and c != b and c.floor_number == 2 and c.master_hero != null and c.master_hero.dev_god, "/respawn: back to the floor start, /god carried over")
    con.submit("/god off")
    main.queue_free()
    await get_tree().process_frame
