class_name DevCommands
extends RefCounted
## D-146: the one developer-command layer (console `/…`). Every command calls the API of the system it
## touches (Game, SandboxScreen, Combatant, HeroData…); nothing here re-implements game rules.
## Locked until `/key <clave>`: only the SHA-256 of the key is stored and compared. The unlock lives in
## static memory (this run only, never saved). Unlocking or running any cheat marks the game "cheated"
## (Game.cheated in the save + a line in user://cheat_log.txt).

const KEY_HASH := "a42d0b6c6e8116866b7fb3f9c141af58bcf812c233fca237eb8c5ed6e2ee838f"
const MAX_FAILS := 3
const LOCKOUT_MS := 30000
const LOG_PATH := "user://cheat_log.txt"
const QUICKSAVE_PATH := "user://dev_quicksave.json"   # its own slot: never the normal save
const BIG_DAMAGE := 999999

# session state (static: shared by every console instance, lost when the game closes)
static var key_hash: String = KEY_HASH     # tests swap in the hash of a test key (the real key is never in the repo)
static var unlocked: bool = false
static var fails: int = 0
static var lock_until: int = 0            # Time.get_ticks_msec() until which /key is refused
static var console_open: bool = false     # screens skip their key input while the console has it
static var god: bool = false
static var fly: bool = false
static var speed_mult: float = 1.0
static var quick_floor: int = 0           # floor the quicksave was taken on (0 = none / not in a floor)

## name -> [args, help, method]. Two-word names ("floor goto") win over one-word ones.
const COMMANDS := {
    "help": ["[comando]", "Lista de comandos", "_c_help"],
    "key": ["<clave>", "Desbloquea la consola", "_c_key"],
    "god": ["", "Máster invulnerable (on/off)", "_c_god"],
    "fly": ["", "Máster atraviesa muros (on/off)", "_c_fly"],
    "heal": ["", "Cura al escuadrón", "_c_heal"],
    "kill": ["", "Derriba al Máster", "_c_kill"],
    "speed": ["<N>", "Velocidad del Máster xN (1 = normal)", "_c_speed"],
    "lvl up": ["", "Máster +1 nivel", "_c_lvl_up"],
    "lvl set": ["<N>", "Máster a nivel N", "_c_lvl_set"],
    "xp": ["<N>", "Máster +N XP", "_c_xp"],
    "skill learn": ["<id>", "El Máster aprende la skill", "_c_skill_learn"],
    "additem": ["<base> [rareza]", "Objeto al almacén", "_c_additem"],
    "gold": ["<N>", "+N gemas (la moneda)", "_c_gold"],
    "floor goto": ["<1-10>", "Entra al piso N", "_c_floor_goto"],
    "floor reset": ["", "Reinicia el piso (misma seed)", "_c_floor_reset"],
    "floor complete": ["", "Termina el piso con éxito", "_c_floor_complete"],
    "objective complete": ["", "Cumple el objetivo (falta extraer si aplica)", "_c_objective_complete"],
    "fog": ["off|on", "Niebla de guerra", "_c_fog"],
    "tp": ["<x> <y>", "Teletransporta al Máster a la celda", "_c_tp"],
    "killall": ["", "Mata a todos los enemigos", "_c_killall"],
    "spawn": ["<tipo> [n]", "Invoca enemigos junto al Máster", "_c_spawn"],
    "ai freeze": ["", "Congela la IA enemiga (on/off)", "_c_ai_freeze"],
    "mechanism open": ["", "Abre mecanismos (altares, secreto)", "_c_mechanism_open"],
    "boss hp": ["<%>", "Vida del jefe al %", "_c_boss_hp"],
    "altar on": ["", "Rompe el escudo del jefe (altares hechos)", "_c_altar_on"],
    "seed": ["[N]", "Muestra la seed o regenera el piso con N", "_c_seed"],
    "party add": ["<id|nombre>", "Añade un héroe al escuadrón", "_c_party_add"],
    "party remove": ["<hueco 2-5>", "Saca un héroe del escuadrón", "_c_party_remove"],
    "revive": ["", "Levanta a los derribados (los muertos siguen muertos, D-011)", "_c_revive"],
    "trait set": ["<hueco> <trait>", "Fija el rasgo de un héroe", "_c_trait_set"],
    "panic": ["[hueco]", "Pánico a los autónomos (o a uno)", "_c_panic"],
    "morale": ["<N>", "Composure del escuadrón a N", "_c_morale"],
    "hero bring": ["", "Trae al escuadrón junto al Máster", "_c_hero_bring"],
    "res add": ["<tipo> <N>", "Recurso al almacén", "_c_res_add"],
    "build instant": ["", "Termina todas las obras", "_c_build_instant"],
    "time skip": ["[horas]", "Avanza el pueblo (24 h)", "_c_time_skip"],
    "summon force": ["<1-5>", "Invoca un héroe de esas estrellas", "_c_summon_force"],
    "pity set": ["<N>", "Pity 4★ y 5★ a N", "_c_pity_set"],
    "hitboxes": ["", "Overlay de cuerpos y rangos", "_c_hitboxes"],
    "ai state": ["", "Estado de la IA", "_c_ai_state"],
    "aggro": ["", "Amenaza de los enemigos cercanos", "_c_aggro"],
    "fps": ["", "Contador de FPS", "_c_fps"],
    "quicksave": ["", "Guarda en el slot de pruebas", "_c_quicksave"],
    "quickload": ["", "Carga el slot de pruebas", "_c_quickload"],
    "class set": ["<clase> [hueco]", "Cambia la clase (Máster o hueco 1-5)", "_c_class_set"],
    "newgame": ["", "Borra la partida y vuelve al creador (escribirlo 2 veces)", "_c_newgame"],
    "respawn": ["", "Vuelve al inicio del piso sin perder la partida", "_c_respawn"],
}

var tree: SceneTree = null
static var _newgame_armed: bool = false


func _init(p_tree: SceneTree = null) -> void:
    tree = p_tree


## Tests: forget the unlock and every toggle (as if the game had just started).
static func reset_session() -> void:
    unlocked = false
    fails = 0
    lock_until = 0
    god = false
    fly = false
    speed_mult = 1.0
    key_hash = KEY_HASH


static func hash_key(text: String) -> String:
    return text.sha256_text()


# --- entry point -------------------------------------------------------------------------------

## Runs one console line and returns what the console prints.
func run(line: String) -> String:
    var text := line.strip_edges()
    if text.begins_with("/"):
        text = text.substr(1)
    if text == "":
        return ""
    var words: PackedStringArray = text.split(" ", false)
    var name := String(words[0]).to_lower()
    var args: Array = []
    if words.size() > 1 and COMMANDS.has(name + " " + String(words[1]).to_lower()):
        name = name + " " + String(words[1]).to_lower()
        for i in range(2, words.size()):
            args.append(String(words[i]))
    else:
        for i in range(1, words.size()):
            args.append(String(words[i]))
    if name == "key":
        return _c_key(args)
    if not unlocked:
        return "bloqueado"
    if not COMMANDS.has(name):
        return "Comando desconocido: /%s (usa /help)" % name
    if name != "help":
        mark_cheated(name)
    return String(call(String(COMMANDS[name][2]), args))


## Autocomplete: every command name starting with what is typed (without "/").
static func complete(prefix: String) -> Array:
    var p := prefix.strip_edges(false, true).trim_prefix("/").to_lower()
    var out: Array = []
    if not unlocked:
        if "key".begins_with(p):
            out.append("key")
        return out
    for n in COMMANDS:
        if String(n).begins_with(p):
            out.append(String(n))
    out.sort()
    return out


static func mark_cheated(what: String) -> void:
    var game: Node = _game()
    if game != null and not bool(game.get("cheated")):
        game.set("cheated", true)
        if game.has_method("save_game") and bool(game.get("autosave")):
            game.call("save_game")
    var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
    if f != null:
        f.seek_end()
        f.store_line("%s  %s" % [Time.get_datetime_string_from_system(), what])   # never the key itself
        f.close()


static func _game() -> Node:
    var ml := Engine.get_main_loop()
    if ml is SceneTree:
        return (ml as SceneTree).root.get_node_or_null("Game")
    return null


# --- helpers -----------------------------------------------------------------------------------

func _screen() -> SandboxScreen:
    if tree == null:
        return null
    return _find_screen(tree.root)


func _find_screen(n: Node) -> SandboxScreen:
    if n is SandboxScreen and n.is_inside_tree() and not n.is_queued_for_deletion():
        return n
    for c in n.get_children():
        var s := _find_screen(c)
        if s != null:
            return s
    return null


func _main() -> Node:
    if tree == null:
        return null
    for c in tree.root.get_children():
        if c.has_method("show_screen"):
            return c
    return null


func _master_unit() -> SandboxHero:
    var s := _screen()
    if s == null:
        return null
    if s.master_hero != null:
        return s.master_hero
    return s.heroes[0] if not s.heroes.is_empty() else null


func _master_data() -> HeroData:
    var u := _master_unit()
    if u != null and u.hero != null:
        return u.hero
    return Game.master()


func _toggle(cur: bool, args: Array) -> bool:
    if not args.is_empty():
        var a := String(args[0]).to_lower()
        if a in ["on", "1", "true", "si", "sí"]:
            return true
        if a in ["off", "0", "false", "no"]:
            return false
    return not cur


static func _onoff(v: bool) -> String:
    return "ON" if v else "OFF"


const NO_FLOOR := "Solo dentro de un piso"


## Applies the session toggles (god, fly, speed) to a mission's Master: a new floor keeps them.
static func apply_to(screen: SandboxScreen) -> void:
    if screen == null:
        return
    var m: SandboxHero = screen.master_hero if screen.master_hero != null else (screen.heroes[0] if not screen.heroes.is_empty() else null)
    if m == null:
        return
    m.dev_god = god
    m.dev_fly = fly
    if speed_mult != 1.0 and m.stats.has("move"):
        m.speed = float(m.stats["move"]) * speed_mult


# --- access ------------------------------------------------------------------------------------

func _c_key(args: Array) -> String:
    if unlocked:
        return "Ya desbloqueada"
    var now := Time.get_ticks_msec()
    if now < lock_until:
        return "Bloqueada %d s" % ceili(float(lock_until - now) / 1000.0)
    if args.is_empty():
        return "Uso: /key <clave>"
    if hash_key(String(args[0])) == key_hash:
        unlocked = true
        fails = 0
        mark_cheated("unlock")
        return "Consola desbloqueada. Partida marcada como cheated. /help"
    fails += 1
    if fails >= MAX_FAILS:
        fails = 0
        lock_until = now + LOCKOUT_MS
        return "Clave incorrecta. Bloqueada 30 s"
    return "Clave incorrecta (%d/%d)" % [fails, MAX_FAILS]


func _c_help(args: Array) -> String:
    var names: Array = COMMANDS.keys()
    if not args.is_empty():
        var p := String(args[0]).trim_prefix("/").to_lower()
        names = names.filter(func(n): return String(n).begins_with(p))
    names.sort()
    var lines: Array = []
    for n in names:
        var c: Array = COMMANDS[n]
        lines.append("/%s %s — %s" % [n, c[0], c[1]] if String(c[0]) != "" else "/%s — %s" % [n, c[1]])
    return "\n".join(lines)


# --- Master ------------------------------------------------------------------------------------

func _c_god(args: Array) -> String:
    god = _toggle(god, args)
    var m := _master_unit()
    if m != null:
        m.dev_god = god
        if god and m.alive:
            m.heal(m.max_hp)
    return "God " + _onoff(god)


func _c_fly(args: Array) -> String:
    fly = _toggle(fly, args)
    var m := _master_unit()
    if m != null:
        m.dev_fly = fly
        if not fly:
            var s := _screen()
            m.path.clear()
            if s != null and s.map.is_blocked(m.position):
                m.position = s.map.nearest_walkable(m.position)   # never left inside a wall
    return "Fly " + _onoff(fly)


func _c_heal(_args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    var n := 0
    for h in s.heroes:
        if h.dead:
            continue
        if h.lost:
            h.lost = false
        if h.downed:
            h.revive(1.0)
        h.cleanse()
        h.statuses.erase("wounded")
        h.hp = h.max_hp
        n += 1
    return "Curados: %d" % n


func _c_kill(_args: Array) -> String:
    var m := _master_unit()
    if m == null:
        return NO_FLOOR
    m.dev_god = false
    m.take_damage(BIG_DAMAGE)
    m.dev_god = god
    return "Máster derribado"


func _c_speed(args: Array) -> String:
    if args.is_empty() or not String(args[0]).is_valid_float():
        return "Uso: /speed <N>"
    speed_mult = clampf(float(args[0]), 0.1, 10.0)
    var m := _master_unit()
    if m != null and m.stats.has("move"):
        m.speed = float(m.stats["move"]) * speed_mult
    return "Velocidad x%.2f" % speed_mult


func _c_lvl_up(_args: Array) -> String:
    var h := _master_data()
    if h == null:
        return "Sin Máster"
    h.add_xp(h.xp_to_next() - h.xp)
    Game._commit()
    return "Nivel %d" % h.level


func _c_lvl_set(args: Array) -> String:
    var h := _master_data()
    if h == null:
        return "Sin Máster"
    if args.is_empty() or not String(args[0]).is_valid_int():
        return "Uso: /lvl set <N>"
    var target := clampi(int(args[0]), 1, h.level_cap())
    if target < h.level:
        h.level = target
        h.xp = 0
    while h.level < target:
        h.add_xp(h.xp_to_next() - h.xp)
    Game._commit()
    return "Nivel %d" % h.level


func _c_xp(args: Array) -> String:
    var h := _master_data()
    if h == null:
        return "Sin Máster"
    if args.is_empty() or not String(args[0]).is_valid_int():
        return "Uso: /xp <N>"
    var up := h.add_xp(int(args[0]))
    Game._commit()
    return "+%s XP (nivel %d, +%d)" % [args[0], h.level, up]


func _c_skill_learn(args: Array) -> String:
    var h := _master_data()
    if h == null:
        return "Sin Máster"
    if args.is_empty() or not SkillDefs.SKILLS.has(String(args[0])):
        return "Skill desconocida. Ej.: %s" % ", ".join(SkillDefs.SKILLS.keys().slice(0, 6))
    var ok := h.learn_skill(String(args[0]))
    Game._commit()
    return "Aprendida: %s" % args[0] if ok else "Ya la conocía o no puede aprenderla"


func _c_additem(args: Array) -> String:
    if args.is_empty() or not ItemDefs.BASES.has(String(args[0])):
        return "Base desconocida. Ej.: %s" % ", ".join(ItemDefs.BASES.keys().slice(0, 6))
    var rarity := String(args[1]).to_lower() if args.size() > 1 else "common"
    if not ItemDefs.RARITIES.has(rarity):
        return "Rareza: %s" % ", ".join(ItemDefs.RARITY_ORDER)
    var s := _screen()
    var ilvl := maxi(1, s.floor_number * 3) if s != null and s.floor_number > 0 else 1
    var item := ItemGen.generate(Game.rng, Game._next_uid(), ilvl, rarity, String(args[0]))
    Game.stash.append(item)
    Game._commit()
    return "Añadido al almacén: %s" % String(item.get("name", args[0]))


func _c_gold(args: Array) -> String:
    if args.is_empty() or not String(args[0]).is_valid_int():
        return "Uso: /gold <N>"
    Game.grant(int(args[0]), 0, 0)
    return "Gemas: %d" % Game.gems


# --- floor -------------------------------------------------------------------------------------

func _c_floor_goto(args: Array) -> String:
    if args.is_empty() or not String(args[0]).is_valid_int() or int(args[0]) < 1 or int(args[0]) > 10:
        return "Uso: /floor goto <1-10>"
    return _enter(int(args[0]), null)


## Leaves the current screen (it frees its nodes, timers, waves, fire and mechanisms with it) and opens floor n.
func _enter(n: int, keep_map: NavMap) -> String:
    var main := _main()
    if main == null:
        return "Sin pantalla principal"
    main.set("dev_next_map", keep_map)
    main.call("show_screen", "sandbox", n)
    return "Piso %d" % n


func _c_floor_reset(_args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    # tower floors are kept in Game.tower_maps (same seed); a Wilds run regenerates from its own seed
    var keep: NavMap = null
    if s.floor_number < 0 and s.map is ProceduralMap:
        var pm := s.map as ProceduralMap
        keep = ProceduralMap.new(pm.width, pm.height, pm.seed_value, pm.floor_number)
    return _enter(s.floor_number, keep) + " reiniciado"


func _c_respawn(_args: Array) -> String:
    var s := _screen()
    if s == null:
        if quick_floor != 0:
            return _enter(quick_floor, null)
        return NO_FLOOR
    return _c_floor_reset([]).replace("reiniciado", "— vuelta al inicio")


func _c_floor_complete(_args: Array) -> String:
    var s := _screen()
    if s == null or s.mission_state != SandboxScreen.Mission.ACTIVE:
        return NO_FLOOR
    s.dev_complete_objective()
    s._end_mission(SandboxScreen.Mission.SUCCESS)
    return "Piso completado"


func _c_objective_complete(_args: Array) -> String:
    var s := _screen()
    if s == null or s.mission_state != SandboxScreen.Mission.ACTIVE:
        return NO_FLOOR
    return s.dev_complete_objective()


func _c_fog(args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    var on := not (args.is_empty() or String(args[0]).to_lower() == "off")
    s.dev_set_fog(on)
    return "Niebla " + _onoff(on)


func _c_tp(args: Array) -> String:
    var s := _screen()
    var m := _master_unit()
    if s == null or m == null:
        return NO_FLOOR
    if args.size() < 2 or not String(args[0]).is_valid_int() or not String(args[1]).is_valid_int():
        var c := s.map.cell_of(m.position)
        return "Uso: /tp <x> <y>  (ahora %d %d, mapa %dx%d)" % [c.x, c.y, s.map.width, s.map.height]
    var cell := Vector2i(int(args[0]), int(args[1]))
    if not s.map.in_bounds(cell):
        return "Fuera del mapa (%dx%d)" % [s.map.width, s.map.height]
    var p := s.map.center_of(cell)
    if s.map.is_blocked(p) and not fly:
        p = s.map.nearest_walkable(p)
    m.stop()
    m.position = p
    s.camera_jump(p)
    return "TP a %d %d" % [s.map.cell_of(p).x, s.map.cell_of(p).y]


func _c_killall(_args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    var n := 0
    for e in s.living_enemies():
        e.immune = false
        e.die()
        n += 1
    return "Muertos: %d" % n


func _c_spawn(args: Array) -> String:
    var s := _screen()
    var m := _master_unit()
    if s == null or m == null:
        return NO_FLOOR
    if args.is_empty() or not EnemyDefs.TYPES.has(String(args[0])):
        return "Tipo desconocido. Ej.: %s" % ", ".join(EnemyDefs.TYPES.keys().slice(0, 8))
    var count := clampi(int(args[1]) if args.size() > 1 and String(args[1]).is_valid_int() else 1, 1, 30)
    for i in count:
        var spot := s.map.nearest_walkable(m.position + Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * 96.0)
        var e := s._spawn_enemy(s.map.cell_of(spot), String(args[0]))
        e.visible = s.fog == null or s.fog.is_visible(s.map.cell_of(e.position))
    return "Invocados %d %s" % [count, args[0]]


func _c_ai_freeze(args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    s.ai_frozen = _toggle(s.ai_frozen, args)
    return "IA congelada " + _onoff(s.ai_frozen)


func _c_mechanism_open(_args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    var out: Array = []
    if not s.altars.is_empty():
        out.append(_c_altar_on([]))
    if s.secret != null and not s.secret_done:
        s.dev_open_secret()
        out.append("secreto abierto")
    return "Nada que abrir" if out.is_empty() else ", ".join(out)


func _c_boss_hp(args: Array) -> String:
    var s := _screen()
    if s == null or s.boss == null or not s.boss.alive:
        return "Sin jefe vivo"
    if args.is_empty() or not String(args[0]).trim_suffix("%").is_valid_float():
        return "Jefe %d/%d" % [s.boss.hp, s.boss.max_hp]
    s.boss.hp = clampi(roundi(float(s.boss.max_hp) * float(String(args[0]).trim_suffix("%")) / 100.0), 1, s.boss.max_hp)
    return "Jefe %d/%d" % [s.boss.hp, s.boss.max_hp]


func _c_altar_on(_args: Array) -> String:
    var s := _screen()
    if s == null or s.altars.is_empty():
        return "Sin altares"
    for a in s.altars:
        a.done = true
    return "Altares activados"


func _c_seed(args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    var cur := (s.map as ProceduralMap).seed_value if s.map is ProceduralMap else 0
    if args.is_empty():
        return "Seed %d (piso %d)" % [cur, s.floor_number]
    if not String(args[0]).is_valid_int():
        return "Uso: /seed [N]"
    if s.floor_number > 0:
        Game.dev_regen_floor(s.floor_number, int(args[0]))
        return _enter(s.floor_number, null) + " con seed " + String(args[0])
    if s.floor_number < 0 and s.map is ProceduralMap:
        var pm := s.map as ProceduralMap
        return _enter(s.floor_number, ProceduralMap.new(pm.width, pm.height, int(args[0]), pm.floor_number)) + " con seed " + String(args[0])
    return "El campo de entrenamiento no tiene seed"


# --- heroes ------------------------------------------------------------------------------------

func _find_hero(key: String) -> HeroData:
    if Game.heroes.has(key):
        return Game.heroes[key]
    for id in Game.heroes:
        var h: HeroData = Game.heroes[id]
        if h.display_name().to_lower().begins_with(key.to_lower()):
            return h
    return null


func _c_party_add(args: Array) -> String:
    if args.is_empty():
        return "Uso: /party add <id|nombre>"
    var h := _find_hero(" ".join(args))
    if h == null:
        return "Héroe no encontrado"
    if Game.party.has(h.id):
        return "%s ya está en el escuadrón" % h.display_name()
    for i in range(1, Game.PARTY_SIZE):
        if String(Game.party[i]) == "":
            Game.assign_party(i, h.id)
            return "%s al hueco %d (desde el próximo piso)" % [h.display_name(), i + 1]
    return "Escuadrón lleno"


func _c_party_remove(args: Array) -> String:
    if args.is_empty() or not String(args[0]).is_valid_int() or int(args[0]) < 2 or int(args[0]) > Game.PARTY_SIZE:
        return "Uso: /party remove <hueco 2-5> (el 1 es el Máster)"
    Game.clear_slot(int(args[0]) - 1)
    return "Hueco %s vacío" % args[0]


func _c_revive(_args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    var n := 0
    for h in s.heroes:
        if h.dead:
            continue                         # D-011: permanent death, no resurrection
        if h.lost:
            h.lost = false
        if h.downed:
            h.revive(1.0)
            n += 1
    return "Levantados: %d" % n


func _slot_unit(arg: String) -> SandboxHero:
    var s := _screen()
    if s == null or not arg.is_valid_int():
        return null
    var i := int(arg) - 1
    return s.heroes[i] if i >= 0 and i < s.heroes.size() else null


func _c_trait_set(args: Array) -> String:
    if args.size() < 2:
        return "Uso: /trait set <hueco> <trait>. Ej.: %s" % ", ".join(HeroTables.TRAITS.keys().slice(0, 5))
    var t := String(args[1])
    if not HeroTables.TRAITS.has(t):
        return "Rasgo desconocido. Ej.: %s" % ", ".join(HeroTables.TRAITS.keys().slice(0, 5))
    var u := _slot_unit(String(args[0]))
    var h: HeroData = u.hero if u != null else null
    if h == null and String(args[0]).is_valid_int():
        var pid := String(Game.party[clampi(int(args[0]) - 1, 0, Game.PARTY_SIZE - 1)])
        h = Game.heroes.get(pid, null)
    if h == null:
        return "Hueco vacío"
    h.traits = [t]
    if u != null:
        u.persona = AiDefs.personality(h.traits)
    Game._commit()
    return "%s: rasgo %s" % [h.display_name(), t]


func _c_panic(args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    var list: Array = []
    if not args.is_empty():
        var u := _slot_unit(String(args[0]))
        if u != null:
            list.append(u)
    else:
        list = s.heroes.filter(func(h): return h != s.master_hero)
    for h in list:
        (h as SandboxHero).apply_status("panicked", MasterDefs.PANIC_TIME)
    return "Pánico: %d" % list.size()


func _c_morale(args: Array) -> String:
    var s := _screen()
    if args.is_empty() or not String(args[0]).is_valid_int():
        return "Uso: /morale <0-100>"
    var n := 0
    var list: Array = s.heroes.map(func(u): return u.hero) if s != null else Game.party_heroes()
    for h in list:
        if h != null:
            (h as HeroData).set_composure(int(args[0]))
            n += 1
    return "Composure %d en %d héroes" % [clampi(int(args[0]), 0, 100), n]


func _c_hero_bring(_args: Array) -> String:
    var s := _screen()
    var m := _master_unit()
    if s == null or m == null:
        return NO_FLOOR
    var n := 0
    for h in s.heroes:
        if h == m or h.dead:
            continue
        h.stop()
        h.position = s.map.nearest_walkable(m.position + Vector2.RIGHT.rotated(TAU * float(n) / 4.0) * 30.0)
        n += 1
    return "Traídos: %d" % n


# --- town --------------------------------------------------------------------------------------

func _c_res_add(args: Array) -> String:
    if args.size() < 2 or not String(args[1]).is_valid_int():
        return "Uso: /res add <tipo> <N>. Tipos: %s" % ", ".join(EconomyDefs.RESOURCES.keys().slice(0, 10))
    var r := String(args[0])
    if not EconomyDefs.RESOURCES.has(r) and not Game.hq_outputs.has(r):
        return "Recurso desconocido. Tipos: %s" % ", ".join(EconomyDefs.RESOURCES.keys().slice(0, 10))
    Game.hq_outputs[r] = int(Game.hq_outputs.get(r, 0)) + int(args[1])
    Game._commit()
    return "%s: %d" % [r, int(Game.hq_outputs[r])]


func _c_build_instant(_args: Array) -> String:
    var n := Game.construction.size()
    for c in Game.construction.duplicate():
        Game.complete_construction(String(c["bid"]), int(c["to"]))
    Game.construction.clear()
    Game._commit()
    return "Obras terminadas: %d" % n


func _c_time_skip(args: Array) -> String:
    var hours := int(args[0]) if not args.is_empty() and String(args[0]).is_valid_int() else 24
    Game.pass_time(clampi(hours, 1, 24 * 30))
    return "Pueblo: %s" % Game.town_time_text()


func _c_summon_force(args: Array) -> String:
    if args.is_empty() or not String(args[0]).is_valid_int() or int(args[0]) < 1 or int(args[0]) > 5:
        return "Uso: /summon force <1-5>"
    var banner := SummonConfig.get_banner(SummonConfig.DEFAULT_BANNER)
    var h := Game._generate_unique(int(args[0]))
    Game._accept_summon(h, SummonConfig.DEFAULT_BANNER, banner, Game.pity4, Game.pity5)
    Game.assign_beds()
    Game._commit()
    return "Invocado %s (%d★)" % [h.display_name(), h.stars]


func _c_pity_set(args: Array) -> String:
    if args.is_empty() or not String(args[0]).is_valid_int():
        return "Uso: /pity set <N>"
    Game.pity4 = maxi(0, int(args[0]))
    Game.pity5 = maxi(0, int(args[0]))
    Game._commit()
    return "Pity 4★ %d, 5★ %d" % [Game.pity4, Game.pity5]


# --- debug -------------------------------------------------------------------------------------

func _c_hitboxes(_args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    s.toggle_debug_overlay(true)
    return "Hitboxes " + _onoff(s.debug_overlay != null)


func _c_ai_state(_args: Array) -> String:
    var s := _screen()
    if s == null:
        return NO_FLOOR
    var lines: Array = []
    for h in s.heroes:
        lines.append("%s: %s, orden %s, capa %s" % [h.hero.display_name() if h.hero != null else "?", "muerto" if h.dead else ("derribado" if h.downed else "en pie"), h.order, h.ai_layer])
    var states := {}
    for e in s.living_enemies():
        var k := String(SandboxEnemy.State.keys()[e.state])
        states[k] = int(states.get(k, 0)) + 1
    lines.append("Enemigos: %s%s" % [str(states), " (congelados)" if s.ai_frozen else ""])
    return "\n".join(lines)


func _c_aggro(_args: Array) -> String:
    var s := _screen()
    var m := _master_unit()
    if s == null or m == null:
        return NO_FLOOR
    var foes := s.living_enemies()
    foes.sort_custom(func(a, b): return a.position.distance_to(m.position) < b.position.distance_to(m.position))
    var lines: Array = []
    for e in foes.slice(0, 5):
        var top: SandboxHero = e.attention()
        lines.append("%s a %d px → %s" % [e.type_id, roundi(e.position.distance_to(m.position)), top.hero.display_name() if top != null and top.hero != null else "nadie"])
    return "Sin enemigos" if lines.is_empty() else "\n".join(lines)


func _c_fps(_args: Array) -> String:
    GameMenu.show_fps = not GameMenu.show_fps
    return "FPS " + _onoff(GameMenu.show_fps)


# --- state -------------------------------------------------------------------------------------

func _c_quicksave(_args: Array) -> String:
    var keep := Game.save_path
    Game.save_path = QUICKSAVE_PATH
    var ok := Game.save_game()
    Game.save_path = keep
    var s := _screen()
    quick_floor = s.floor_number if s != null else 0
    return "Quicksave %s%s" % ["OK" if ok else "FALLÓ", " (piso %d)" % quick_floor if quick_floor != 0 else ""]


func _c_quickload(_args: Array) -> String:
    if not FileAccess.file_exists(QUICKSAVE_PATH):
        return "No hay quicksave"
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUICKSAVE_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        return "Quicksave ilegible"
    Game.apply_save(parsed)
    Game.cheated = true
    Game.changed.emit()
    if quick_floor != 0:
        return "Quickload OK. " + _enter(quick_floor, null)
    var main := _main()
    if main != null:
        main.call("show_screen", "town", 0)
    return "Quickload OK"


func _c_class_set(args: Array) -> String:
    if args.is_empty():
        return "Clases: %s" % ", ".join(HeroTables.CLASSES.keys())
    var cls := String(args[0])
    if not cls.begins_with("class."):
        cls = "class." + cls
    if not HeroTables.CLASSES.has(cls):
        return "Clase desconocida. Clases: %s" % ", ".join(HeroTables.CLASSES.keys())
    var h: HeroData = _master_data()
    if args.size() > 1 and String(args[1]).is_valid_int():
        var pid := String(Game.party[clampi(int(args[1]) - 1, 0, Game.PARTY_SIZE - 1)])
        h = Game.heroes.get(pid, null)
    if h == null:
        return "Sin héroe"
    h.hero_class = cls
    h.skills = h.skills.filter(func(id): return SkillDefs.usable_by(String(id), cls))
    for slot in ["main_hand", "off_hand"]:
        h.equipment.erase(slot)                   # the old class weapon goes; the new starter one comes
    Game.give_kit(h)
    h.ensure_skills()
    Game._commit()
    return "%s ahora es %s (efecto al entrar a un piso)" % [h.display_name(), h.class_title()]


func _c_newgame(_args: Array) -> String:
    if not _newgame_armed:
        _newgame_armed = true
        return "Esto BORRA la partida. Escribe /newgame otra vez para confirmar"
    _newgame_armed = false
    Game.new_game()
    var main := _main()
    if main != null:
        main.call("show_screen", "master", 0)
    return "Partida nueva"
