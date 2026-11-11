extends Node
## Quick visual check (not a pass/fail suite, no simulator): opens the real screens and saves PNGs.
##   CAPTURE_DIR=<dir> SHOTS=floor,title,town,ui xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --resolution 1280x720 res://tests/capture_quick.tscn
## Uses its own save file; never touches the player's save.

var _dir: String = ""
var _main: Control = null
var _shots: PackedStringArray = []


func _ready() -> void:
    _dir = OS.get_environment("CAPTURE_DIR")
    if _dir == "":
        _dir = ProjectSettings.globalize_path("user://captures")
    DirAccess.make_dir_recursive_absolute(_dir)
    _shots = OS.get_environment("SHOTS").split(",", false)
    if _shots.is_empty():
        _shots = PackedStringArray(["floor"])
    Game.autosave = false
    Game.save_path = "user://capture_quick_save.json"
    Game.new_game()
    Game.gems = 100000
    var pulled: Array = Game.pull(10)
    for i in mini(5, pulled.size()):
        Game.assign_party(i, (pulled[i] as HeroData).id)
    var scene: PackedScene = load("res://scenes/main.tscn")
    _main = scene.instantiate() as Control
    add_child(_main)
    await get_tree().create_timer(0.5).timeout
    for s in _shots:
        if has_method("_shots_" + s):
            await call("_shots_" + s)
    print("CAPTURE DONE -> ", _dir)
    get_tree().quit(0)


func _shots_title() -> void:
    _main.call("show_screen", "title", 0)
    await _shot("title", 1.5)


func _shots_town() -> void:
    _main.call("show_screen", "town", 0)
    await _shot("town", 4.0)
    await _shot("town_later", 6.0)


func _shots_build() -> void:
    _main.call("show_screen", "town", 0)
    await get_tree().create_timer(1.5).timeout
    _find("TownScreen").call("show_build_menu")
    await _shot("build_menu", 0.8)


func _shots_memorial() -> void:
    _main.call("show_screen", "memorial", 0)
    await _shot("memorial_empty", 1.0)
    var ids: Array = Game.heroes.keys()
    var causes := ["slain by a bandit captain", "fell to an orc warband", "lost in the dark", "poisoned by spiders", "left behind"]
    for i in range(5, mini(ids.size(), 11)):
        var h: HeroData = Game.heroes[ids[i]]
        if not h.is_master:
            Game.record_death(h, causes[i % causes.size()], "Floor %d" % (i - 3))
    _main.call("show_screen", "memorial", 0)
    await _shot("memorial_graves", 1.0)
    var ms: Node = _find("MemorialScreen")
    ms.call("_show_epitaph", Game.memorial[Game.memorial.size() - 1])
    await _shot("memorial_epitaph", 0.6)


func _shots_inventory() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var r := ["common", "uncommon", "rare", "epic", "legendary", "junk"]
    var bases := ["sword", "bow", "staff", "helm", "mail", "robe", "gloves", "boots", "ring", "amulet", "shield", "dagger", "greaves", "hood"]
    for i in 14:
        var it := ItemGen.generate(rng, 5000 + i, 5, r[i % r.size()] if r[i % r.size()] != "junk" else "common", bases[i])
        if i % 6 == 5:
            it["rarity"] = "junk"
        Game.stash.append(it)
    Game.changed.emit()
    _main.call("show_screen", "inventory", 0)
    await _shot("inventory", 1.0)
    var inv: Node = _find("InventoryScreen")
    inv.set("_tab", "forge")
    inv.call("refresh")
    await _shot("inventory_forge", 0.5)


func _shots_screens() -> void:
    for scr in ["memorial", "inventory", "roster", "party"]:
        _main.call("show_screen", scr, 0)
        await _shot("screen_" + scr, 1.0)
    _main.call("show_screen", "town", 0)
    await get_tree().create_timer(1.5).timeout
    var town: Node = _find("TownScreen")
    for b in ["dorm_1", "town_hall", "blacksmith"]:
        town.call("select_building", b)
        await _shot("panel_" + b, 0.6)


func _shots_gate() -> void:
    _main.call("show_screen", "town", 0)
    await get_tree().create_timer(1.5).timeout
    _find("TownScreen").call("select_building", "tower_gate")
    await _shot("tower_gate", 0.8)


func _shots_wilds() -> void:
    _main.call("show_screen", "sandbox", -1)
    await _shot("wilds", 3.0)


func _shots_options() -> void:
    _main.call("show_screen", "title", 0)
    await get_tree().create_timer(0.5).timeout
    var t: Node = _find("TitleScreen")
    t.call("_open_menu", "options")
    await _shot("options_display", 0.6)
    var menu: Node = t.get("_menu")
    menu.set("_tab", "game")
    menu.call("show_options")
    await _shot("options_game", 0.4)


func _shots_floor() -> void:
    _main.call("show_screen", "sandbox", 3)
    await get_tree().create_timer(1.5).timeout
    var sb: Node = _find("SandboxScreen")
    if sb == null:
        return
    var hs: Array = sb.get("heroes")
    var es: Array = sb.get("enemies")
    for e in es:
        e.position = Vector2(-5000, -5000)       # a calm look at the art
    var m: Node2D = hs[0]
    # put the squad around a tall prop (a tree or rock) next to open ground: one behind it, one in front
    var props: Node2D = null
    for c in sb.get("_world").get_children():
        if c.y_sort_enabled and c.get_child_count() > 20:
            props = c
    if props != null:
        var best: Sprite2D = null
        var bd := INF
        for p in props.get_children():
            if p is Sprite2D and (p as Sprite2D).region_rect.size.y >= 14:
                var d: float = p.position.distance_to(m.position)
                if d < bd:
                    bd = d
                    best = p
        if best != null:
            m.position = best.position + Vector2(0, -6)          # behind (feet above the prop's feet)
            if hs.size() > 1:
                hs[1].position = best.position + Vector2(14, 10)  # in front
            for i in range(2, hs.size()):
                hs[i].position = best.position + Vector2(-30 + i * 12, 30)
            print("prop at ", best.position, " size ", best.region_rect.size)
    sb.call("update_fog")
    await _shot("floor_props_behind", 0.6)
    # loot in a clearing near the Master
    var spot: Vector2 = sb.get("map").nearest_walkable(m.position + Vector2(160, 40))
    m.position = spot
    for i in range(1, hs.size()):
        hs[i].position = spot + Vector2(-50 + i * 22, -30)
    var items: Array = []
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    for pair in [["rare", "bow"], ["epic", "helm"], ["uncommon", "sword"]]:
        items.append(ItemGen.generate(rng, 900 + items.size(), 5, pair[0], pair[1]))
    sb.call("drop_loot", m.position + Vector2(40, 20), [items[0]], {})
    sb.call("drop_loot", m.position + Vector2(-40, 24), [items[1]], {})
    sb.call("drop_loot", m.position + Vector2(0, 50), [items[2]], {})
    sb.call("drop_loot", m.position + Vector2(70, -10), [], {"mineral": 3})
    sb.call("update_fog")
    await _shot("floor_loot_a", 0.25)
    await _shot("floor_loot_b", 1.0)
    var shrine = sb.get("shrine")
    if shrine != null:
        shrine.progress = 0.35
        m.position = shrine.position + Vector2(30, 40)
        for i in range(1, hs.size()):
            hs[i].position = shrine.position + Vector2(-40 + i * 25, 60)
        sb.call("update_fog")
        await _shot("floor_shrine_exit", 1.5)


func _find(cls: String) -> Node:
    for n in _main.find_children("*", "", true, false):
        var s: Script = n.get_script()
        if s != null and s.get_global_name() == cls:
            return n
    return null


func _shot(shot_name: String, wait: float) -> void:
    await get_tree().create_timer(wait).timeout
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    var path := _dir.path_join(shot_name + ".png")
    img.save_png(path)
    print("shot ", shot_name, " -> ", path)
