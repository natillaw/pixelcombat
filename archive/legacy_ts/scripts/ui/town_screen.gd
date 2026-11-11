class_name TownScreen
extends Control
## The town is the first screen of the game (D-030). Everything starts from a building:
## click it to enter (summon, roster, party, tower, memorial, town hall) or to build / upgrade it.
## Drag to pan, mouse wheel to zoom. Heroes walk around on their own.

signal navigate(screen: String, arg: int)

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEPS := [0.5, 1.0, 2.0]       # D-063: whole pixel steps only (the first fit view may be in between)

var map: TownMap
var view: TownView
var camera: Camera2D
var heroes: Array[TownHero] = []
var selected: String = ""
var hero_panel: HeroInfoPanel = null
var selected_hero_id: String = ""

var _viewport: SubViewport
var _world: Node2D
## D-072 revision (owner 2026-10-31): ground, buildings and props are drawn x2 against the LPC heroes
## (each TownHero is scaled back by 1/WORLD_SCALE). Logic stays in map pixels; the camera works in
## scaled pixels.
const WORLD_SCALE := 2
var _res: Label
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _drag_from: Vector2 = Vector2.ZERO
var _cam_from: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _moved: bool = false
var moving: String = ""            # D-050: building being placed ("" = not in move mode)
var placing_new: bool = false
var _res_row: HBoxContainer = null
var _menu: GameMenu = null
## Owner 2026-11-02: the town is walked with the Master (camera on the Master, no free camera). Click the
## ground to walk, click a building to walk to its door and go in; F at a door goes in too.
var master_th: TownHero = null
var _master_pos: Vector2 = Vector2.ZERO
var _goal_bid: String = ""
const DOOR_REACH := 26.0                 # map px from a door's centre that counts as "at the door"
const RES_ICONS := [["res_food", "food", "Meals: everyone eats every day"], ["res_wood", "wood", "Wood: construction and the workshop"],
    ["res_stone", "stone", "Stone: construction"], ["res_gem", "@gems", "Gems: summoning"],
    ["res_promotion_stone", "@stones", "Promotion stones"], ["res_skill_book", "@books", "Training books"]]


## [icon, resource key, name]: every resource of the warehouse with its own picture.
const RES_CHIPS := [
    ["res://assets/pixel/ui/ts_kit/icons/res_food.png", "food", "Meals: everyone eats every day"],
    ["res://assets/pixel/ui/ts_kit/icons/res_wood.png", "wood", "Wood: construction and the workshop"],
    ["res://assets/pixel/ui/ts_kit/icons/res_stone.png", "stone", "Stone: construction"],
    ["res://assets/pixel/packs/rpg_icons/Icon291.png", "materials", "Building materials"],
    ["res://assets/pixel/packs/rpg_icons/Icon386.png", "ore", "Mineral: smelted into iron"],
    ["res://assets/pixel/packs/rpg_icons/Icon271.png", "herb", "Herbs: potions and medicine"],
    ["res://assets/pixel/packs/rpg_icons/Icon343.png", "ingot", "Iron ingots: forging"],
    ["res://assets/pixel/packs/rpg_icons/Icon302.png", "potion", "Potions"],
    ["res://assets/pixel/ui/ts_kit/icons/res_gem.png", "@gems", "Gems: summoning"],
    ["res://assets/pixel/ui/ts_kit/icons/res_promotion_stone.png", "@stones", "Promotion stones"],
    ["res://assets/pixel/ui/ts_kit/icons/res_skill_book.png", "@books", "Training books"],
]


static func _short(v: int) -> String:
    if v >= 100000:
        return "%dk" % (v / 1000)
    if v >= 10000:
        return "%.1fk" % (float(v) / 1000.0)
    return str(v)


## A resource chip: 16 px icon + value, tooltip with the name.
func _chip(icon_path: String, text: String, tip: String, col: Color) -> Control:
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 2)
    hb.tooltip_text = StringsEs.tx(tip)
    hb.mouse_filter = Control.MOUSE_FILTER_PASS
    if icon_path == "":
        var only := UIKit.label(text, 14, col)
        only.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hb.add_child(only)
        return hb
    var ic := TextureRect.new()
    ic.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
    ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ic.custom_minimum_size = Vector2(16, 16)
    ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hb.add_child(ic)
    var l := UIKit.label(text, 14, col)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hb.add_child(l)
    return hb


static func _res_value(key: String) -> int:
    match key:
        "@gems":
            return Game.gems
        "@stones":
            return Game.stones
        "@books":
            return Game.books
    return int(Game.hq_outputs.get(key, 0))      # the building being placed is a NEW construction (free placement)
var _move_msg: Label


func _ready() -> void:
    UIKit.music("town")
    clip_contents = true
    var container := SubViewportContainer.new()
    container.stretch = true
    container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(container)
    UIKit.fill(container)
    _viewport = SubViewport.new()
    _viewport.handle_input_locally = false
    _viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    container.add_child(_viewport)
    _world = Node2D.new()
    _world.scale = Vector2.ONE * WORLD_SCALE          # D-072 revision: the town's art x2 against the heroes
    _world.y_sort_enabled = true                      # 2026-11-02: heroes walk behind buildings and trees
    _viewport.add_child(_world)
    var grade := CanvasModulate.new()                 # the tower floors' warm, slightly muted palette
    grade.color = Color(1.0, 0.97, 0.9)
    _viewport.add_child(grade)
    camera = Camera2D.new()
    _viewport.add_child(camera)
    camera.make_current()
    camera.zoom = Vector2.ONE
    Ambience.add_particles(camera, Vector2(640, 360))  # leaves and fireflies, like the tower floors
    Ambience.add_dust(camera, Vector2(640, 360))
    _build_ui()
    rebuild()
    Game.changed.connect(_on_changed)


## (Re)builds the map and heroes from the current save (called again after a building changes).
func rebuild() -> void:
    for c in _world.get_children():
        c.queue_free()
    heroes.clear()
    map = TownMap.new(Game.town_buildings, Game.town_layout.duplicate())
    view = TownView.new(map)
    view.selected = selected
    _world.add_child(view)
    for piece in view.building_pieces():              # buildings, Y-sorted with the heroes
        _world.add_child(piece)
    if not view.tall.is_empty():
        _world.add_child(BosqueArt.prop_sprites(view.tall))   # the forest ring
    _world.add_child(view.plaza_props())              # stalls, lamps, barrels, benches
    if not SimMode.on:                                # the tower floors' life: birds, cloud shadows, lights
        _world.add_child(WorldLife.create(self, map.world_size(), 0x70e1))
        for p in view.lamp_spots:
            Ambience.add_light(_world, p, Color(1.0, 0.8, 0.45), 36, true)
    var i := 0
    for id in Game.heroes:
        var th := TownHero.new(Game.heroes[id], map)
        th.scale = Vector2.ONE / WORLD_SCALE
        th.position = map.center_of(map.spawn_cells[i % map.spawn_cells.size()]) + Vector2((i / map.spawn_cells.size()) * 7, 0)
        _world.add_child(th)
        heroes.append(th)
        i += 1
    for th in heroes:
        th.town_heroes = heroes
    master_th = null
    for th in heroes:
        if th.hero.is_master:
            master_th = th
            th.player_controlled = true
            th.position = _master_pos if _master_pos != Vector2.ZERO else map.center_of(map.door_of("town_hall")) + Vector2(0, 14)
            camera.position = _clamp_cam(th.position * WORLD_SCALE)
    if camera.position == Vector2.ZERO:
        # first view: the whole town fits on screen
        var ws := map.world_size()
        var vs := Vector2(_viewport.size) if _viewport.size.x > 0 else Vector2(1280, 670)
        camera.zoom = Vector2.ONE                 # 2026-11-02 (owner: "se ven muy lejos"): start close on the plaza (wheel = 0.5 / 1 / 2)
        camera.position = _clamp_cam(map.center_of(Vector2i(17, 10)) * WORLD_SCALE)
    _refresh()


func _on_changed() -> void:
    var count_changed := heroes.size() != Game.heroes.size()
    if count_changed or map == null or _levels_changed():
        rebuild()
    else:
        _refresh()


func _levels_changed() -> bool:
    if map.layout != Game.town_layout:
        return true
    for id in TownTables.ids():
        var built := Game.building_level(id) > 0
        if built != map.is_blocked_cell(map.plot_of(id).position):
            return true
    return false


## D-047: the town clock runs while the player is here.
var _occ_t: float = 0.0


func _process(delta: float) -> void:
    Game.town_tick(delta)
    if master_th != null and is_instance_valid(master_th):
        _master_pos = master_th.position
        camera.position = _clamp_cam(master_th.position * WORLD_SCALE)
        if _goal_bid != "" and not master_th.walking():
            var bid := _goal_bid
            _goal_bid = ""
            if master_th.position.distance_to(map.center_of(map.door_of(bid))) <= DOOR_REACH * 1.5:
                select_building(bid)             # arrived: go in
    _occ_t -= delta
    if _occ_t <= 0.0 and view != null:
        _occ_t = 0.5
        var occ := {}
        for th in heroes:
            if th.visible or th.activity == "away" or th.activity_target == "":
                continue
            var key := "sleep" if th.activity == "sim_sleep" else "busy"
            var o: Dictionary = occ.get(th.activity_target, {})
            o[key] = int(o.get(key, 0)) + 1
            occ[th.activity_target] = o
        view.occupancy = occ
        view.empty_hint = "Nobody lives here yet: summon your first heroes (Summoner's Hall)" if Game.heroes.is_empty() else ""
        view.queue_redraw()


## 2026-11-02 (owner: "interfaz muy fea, no se sabe de qué van esos iconos"): resources as chips with their
## own icon (top), and a dock at the bottom with big labelled buttons for every screen.
const RPG := "res://assets/pixel/packs/rpg_icons/Icon%d.png"
const UIC := "res://assets/pixel/packs/ui_icons/PNG/Separately/%s.png"


func _build_ui() -> void:
    var top := PanelContainer.new()
    top.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.05, 0.09, 0.82), Color(ArtPalette.GOLD[2], 0.55), 1, 0, 3))
    top.position = Vector2(4, 4)
    add_child(top)
    _res_row = HBoxContainer.new()
    _res_row.add_theme_constant_override("separation", 8)
    top.add_child(_res_row)
    _res = UIKit.label("", 12, UIKit.MUTED)
    var dock := PanelContainer.new()
    dock.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.05, 0.09, 0.85), Color(ArtPalette.GOLD[2], 0.55), 1, 0, 3))
    add_child(dock)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 2)
    dock.add_child(row)
    for q in [[RPG % 372, "Summon", "Summon heroes (gems)", func(): navigate.emit("summon", 0)],
            [RPG % 173, "Heroes", "Heroes: roster, training, ascension", func(): navigate.emit("roster", 0)],
            [RPG % 97, "Party", "Party: the five who go up the tower", func(): navigate.emit("party", 0)],
            [RPG % 289, "Inventory", "Inventory and equipment stash", func(): navigate.emit("inventory", 0)],
            [RPG % 294, "Build", "Build: place a building near the village", show_build_menu],
            [AssetCatalog.world("tower_portal"), "Tower", "Tower gate: the Master walks there", func(): walk_to_building("tower_gate")],
            [UIC % "Icon42_1", "Memorial", "Memorial of the fallen", func(): navigate.emit("memorial", 0)],
            [UIC % "Icon55_1", "Menu", "Menu (Esc)", func(): open_menu()]]:
        row.add_child(_dock_button(String(q[0]), String(q[1]), String(q[2]), q[3]))
    dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
    dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
    dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
    dock.position.y -= 4
    _move_msg = UIKit.label("", 15, UIKit.ACCENT)
    _move_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _move_msg.position += Vector2(-100, 26)  # px
    _move_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_move_msg)


    _panel = PanelContainer.new()
    _panel.custom_minimum_size = Vector2(212, 0)  # px
    _panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    _panel.position = Vector2(-218, 26)  # px
    _panel.visible = false
    add_child(_panel)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(206, 252)  # px (ends above the dock)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _panel.add_child(scroll)
    _panel_box = VBoxContainer.new()
    _panel_box.add_theme_constant_override("separation", 3)  # px
    _panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_panel_box)


## A dock button: a 20 px icon over its name (the name is the explanation; the tooltip adds the detail).
func _dock_button(icon_path: String, text: String, tip: String, cb: Callable) -> Button:
    var b := Button.new()
    b.tooltip_text = StringsEs.tx(tip)
    b.custom_minimum_size = Vector2(58, 48)
    b.pressed.connect(cb)
    b.mouse_entered.connect(func(): UIKit.sound("hover"))
    b.pressed.connect(func(): UIKit.sound("click"))
    var normal := UIKit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 1)
    var hover := UIKit.box(Color(ArtPalette.GOLD[1], 0.28), ArtPalette.GOLD[3], 1, 0, 1)
    for st in ["normal", "focus", "disabled"]:
        b.add_theme_stylebox_override(st, normal)
    for st in ["hover", "pressed", "hover_pressed"]:
        b.add_theme_stylebox_override(st, hover)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 0)
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    b.add_child(v)
    UIKit.fill(v)
    var ic := TextureRect.new()
    var tex: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
    if tex != null and tex.get_width() == 192:            # the tower portal sheet: its first frame
        var at := AtlasTexture.new()
        at.atlas = tex
        at.region = Rect2(0, 0, 32, 48)
        tex = at
    ic.texture = tex
    ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ic.custom_minimum_size = Vector2(32, 32)            # whole steps: 32 px icons x1, 16 px icons x2
    ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(ic)
    var l := UIKit.label(text, 12, Color(0.92, 0.88, 0.78))
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(l)
    UIKit.react(b)
    return b


func _refresh() -> void:
    var st := Game.hq_outputs
    if _res_row != null:
        for c in _res_row.get_children():
            c.queue_free()
        var h := Game.town_clock % 24
        var day := h >= 6 and h < 20
        _res_row.add_child(_chip(UIC % ("Icon3_1" if day else "Icon2_1"), Game.town_time_text(), "Time of day in the village", UIKit.ACCENT))
        for r in RES_CHIPS:
            var v := _res_value(String(r[1]))
            _res_row.add_child(_chip(String(r[0]), _short(v), "%s: %d" % [tr(String(r[2])), v], UIKit.TEXT if v > 0 else UIKit.MUTED))
        _res_row.add_child(_chip("", "%s %d/%d" % [tr("Beds"), Game.heroes.size(), Game.max_hero_capacity()],
            "Heroes / beds. More beds: build or upgrade dormitories.", UIKit.BAD if Game.heroes.size() >= Game.max_hero_capacity() else UIKit.TEXT))
    _res.text = Game.town_time_text()
    if selected != "":
        _show_panel(selected)


# --- building panel ---------------------------------------------------------------------

var interior: BuildingInterior = null


func select_building(id: String) -> void:
    selected = id
    if view != null:
        view.selected = id
    if interior != null:
        interior.queue_free()
        interior = null
    if id == "":
        _panel.visible = false
    else:
        _show_panel(id)
        if Game.building_level(id) > 0:
            _enter(id)


var recipes_win: ProfessionWindow = null


## WoW-style profession window for a building (owner, 2026-10-31).
func open_recipes(id: String) -> void:
    if recipes_win != null:
        recipes_win.queue_free()
    recipes_win = ProfessionWindow.new(id)
    add_child(recipes_win)
    recipes_win.anchor_left = 0.5
    recipes_win.anchor_right = 0.5
    recipes_win.anchor_top = 0.5
    recipes_win.anchor_bottom = 0.5
    recipes_win.offset_left = -300
    recipes_win.offset_right = 140
    recipes_win.offset_top = -150
    recipes_win.offset_bottom = 150
    recipes_win.closed.connect(func(): recipes_win.queue_free(); recipes_win = null; _show_panel(id))


## Owner, 2026-10-31: clicking a building opens its interior with the heroes who work there.
func _enter(id: String) -> void:
    var room := BuildingInterior.new(id)
    if not room.has_scene():
        room.free()
        return
    interior = room
    add_child(room)
    room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    move_child(room, _panel.get_index())                 # under the building panel
    room.closed.connect(func(): select_building(""))


func _show_panel(id: String) -> void:
    for c in _panel_box.get_children():
        c.queue_free()
    var b := TownTables.info(id)
    var level := Game.building_level(id)
    _panel_box.add_child(_panel_header(id, b, level))
    var desc := UIKit.label(String(b["desc"]), 12, UIKit.MUTED)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.custom_minimum_size = Vector2(190, 0)  # px
    _panel_box.add_child(desc)
    _panel_construction(id, level)
    if TownTables.is_dorm(id) and level > 0:
        _panel_dorm(id, level)
    if id == "infirmary" and level > 0:
        _panel_hospital(level)
    if id == "warehouse" and level > 0:
        _panel_storage()
    if id == "town_hall":
        _panel_hall()
        if Game.master() != null:                # D-081: the mirror (barber) re-opens only the looks
            var mirror := UIKit.button("Mirror: change your looks", func(): navigate.emit("master_edit", 0), Vector2(150, 24))
            mirror.tooltip_text = "Hair, beard, skin and eyes. Not the race, class, trait or name."
            _panel_box.add_child(mirror)
    if not (b.get("jobs", []) as Array).is_empty() and level > 0:
        _panel_jobs(id)
    if level > 0 and (TownTables.worker_slots(id, level) > 0):
        _panel_workers(id, TownTables.worker_slots(id, level))
    if level > 0 and id == "library":
        var books := 0
        for k in Game.skill_books:
            books += int(Game.skill_books[k])
        _panel_box.add_child(UIKit.label("Skill books in the archive: %d (heroes read them from their panel)" % books, 13, UIKit.MUTED))
        _panel_box.add_child(UIKit.label("Transcribe a book (%d materials) for class:" % Game.library_cost(), 13, UIKit.TEXT))
        var grid := GridContainer.new()
        grid.columns = 3
        _panel_box.add_child(grid)
        for cls in Game.roster_classes():
            var trans_btn := UIKit.button(String(HeroTables.CLASSES[cls]["name"]), _on_transcribe.bind(id, String(cls)), Vector2(96, 32))
            trans_btn.focus_mode = Control.FOCUS_NONE
            trans_btn.disabled = int(Game.hq_outputs.get("materials", 0)) < Game.library_cost()
            grid.add_child(trans_btn)
    if level > 0 and String(b["open"]) == "tower":
        _add_tower_buttons()
    elif level > 0 and String(b["open"]) != "":
        var open_screen := String(b["open"])
        var enter := UIKit.button("Enter", func(): navigate.emit(open_screen, 0), Vector2(300, 40))
        enter.focus_mode = Control.FOCUS_NONE
        _panel_box.add_child(enter)
    var cost := Game.next_building_cost(id)
    if cost >= 0 and Game.under_construction(id).is_empty():
        _section("Build" if level == 0 else "Upgrade")
        var label := ("Build (%d materials)" if level == 0 else "Upgrade to Lv %d (%%d materials)" % (level + 1)) % cost
        var up := UIKit.button(label, func(): Game.build_or_upgrade(id), Vector2(320, 38))
        up.focus_mode = Control.FOCUS_NONE
        var why := Game.construction_block(id)
        up.disabled = why != ""
        _panel_box.add_child(up)
        if why != "":
            var lock := HBoxContainer.new()
            var li := TextureRect.new()
            li.texture = load(UIC % "Icon10_1") if ResourceLoader.exists(UIC % "Icon10_1") else null
            li.custom_minimum_size = Vector2(16, 16)
            li.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
            lock.add_child(li)
            var lw := _wrap(why, 12, Color(1.0, 0.6, 0.5))
            lw.custom_minimum_size = Vector2(170, 0)
            lock.add_child(lw)
            _panel_box.add_child(lock)
        elif Game.builders().is_empty():
            _panel_box.add_child(_wrap("No builder assigned yet: the work waits until someone builds (Summoner's Hall).", 13, Color(1.0, 0.8, 0.5)))
    var mv := UIKit.button("Move building", func(): start_move(id), Vector2(320, 32))
    mv.focus_mode = Control.FOCUS_NONE
    _panel_box.add_child(mv)
    _panel.visible = true


## 2026-11-02 (owner: "interfaz de dormitorio y sus iguales, malísimas"): the building panel opens with
## the building's picture and badge, its name, and the level as pips; sections have titled rules; heroes
## show their face.
func _panel_header(id: String, b: Dictionary, level: int) -> Control:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 2)
    var top := HBoxContainer.new()
    var pic_box := Panel.new()
    pic_box.custom_minimum_size = Vector2(64, 52)
    pic_box.add_theme_stylebox_override("panel", UIKit.box(Color(0.1, 0.12, 0.08), ArtPalette.PANEL_RIM, 1, 0, 0))
    var pic := TextureRect.new()
    pic.texture = TownView.building_thumb(id)
    pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    pic.position = Vector2(2, 2)
    pic.size = Vector2(60, 48)
    pic_box.add_child(pic)
    var badge := TextureRect.new()
    badge.texture = building_badge(id)
    badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    badge.position = Vector2(-6, 30)
    badge.size = Vector2(24, 24)
    pic_box.add_child(badge)
    top.add_child(pic_box)
    var right := VBoxContainer.new()
    right.add_theme_constant_override("separation", 1)
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title_row := HBoxContainer.new()
    var t := UIKit.label(String(b["name"]), 20, UIKit.ACCENT)
    t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(t)
    var close := UIKit.button("x", func(): select_building(""), Vector2(28, 26))
    close.focus_mode = Control.FOCUS_NONE
    title_row.add_child(close)
    right.add_child(title_row)
    if level > 0:
        var pips := HBoxContainer.new()
        pips.add_theme_constant_override("separation", 2)
        pips.add_child(UIKit.label(tr("Level"), 12, UIKit.MUTED))
        for i in int(b["max"]):
            var pip := ColorRect.new()
            pip.custom_minimum_size = Vector2(8, 8)
            pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            pip.color = ArtPalette.GOLD[3] if i < level else Color(0.2, 0.17, 0.14)
            pips.add_child(pip)
        right.add_child(pips)
    else:
        right.add_child(UIKit.label("Not built yet", 12, UIKit.MUTED))
    top.add_child(right)
    box.add_child(top)
    return box


func _section(title: String) -> void:
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 1)
    var l := UIKit.label(title, 14, ArtPalette.GOLD[3])
    v.add_child(l)
    var rule := ColorRect.new()
    rule.color = Color(ArtPalette.GOLD[2], 0.5)
    rule.custom_minimum_size = Vector2(0, 1)
    v.add_child(rule)
    _panel_box.add_child(v)


const STATE_NAMES := {"idle": "free", "working": "working", "sleeping": "sleeping", "eating": "eating",
    "socializing": "at the tavern", "in_treatment": "in hospital", "deployed": "in the tower"}


## A hero line: small face, first name, a second muted line, and an optional button.
func _hero_line(hd: HeroData, note: String, btn: Button = null) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 3)
    var face := HeroPortrait.new(hd, 0.5)
    face.custom_minimum_size = Vector2(24, 24)
    var clip := Control.new()
    clip.custom_minimum_size = Vector2(24, 24)
    clip.clip_contents = true
    clip.add_child(face)
    face.position = Vector2(0, 2)
    row.add_child(clip)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", -2)
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_child(UIKit.label(hd.hero_name.split(" ")[0], 14, hd.star_color()))
    var n := UIKit.label(note, 12, UIKit.MUTED)
    n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    n.custom_minimum_size = Vector2(110, 0)
    col.add_child(n)
    row.add_child(col)
    if btn != null:
        btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(btn)
    return row


func _wrap(text: String, size_px: int, color: Color) -> Label:
    var l := UIKit.label(text, size_px, color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(160, 0)  # px
    return l


func _small_btn(text: String, cb: Callable, w: float = 70.0) -> Button:
    var b := UIKit.button(text, cb, Vector2(w, 26))
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", UIKit.fpx(12))  # px
    return b


func _panel_construction(id: String, level: int) -> void:
    var p := Game.under_construction(id)
    if p.is_empty():
        return
    var total := EconomyDefs.BUILD_HOURS_PER_LEVEL * float(p["to"])
    _panel_box.add_child(_wrap("Under construction → Lv %d: %.0f of %.0f work-hours left. Builders on site: %d" % [int(p["to"]), float(p["work_left"]), total, Game.builders().size()], 14, Color(0.95, 0.8, 0.4)))


func _panel_dorm(id: String, level: int) -> void:
    var beds := TownTables.beds_at(id, level)
    var used := Game.beds_used(id)
    _section("%s  %d / %d" % [tr("Beds"), used, beds])
    var row := HFlowContainer.new()
    row.add_theme_constant_override("h_separation", 2)
    for i in beds:
        var bi := BedPip.new()
        bi.taken = i < used
        bi.tooltip_text = tr("Taken") if i < used else tr("Free")
        row.add_child(bi)
    _panel_box.add_child(row)
    _panel_box.add_child(UIKit.label("%s x%.1f" % [tr("Rest quality:"), 0.8 + 0.1 * float(level)], 12, UIKit.MUTED))
    _section("Residents")
    for hid in Game.heroes:
        var h: HeroData = Game.heroes[hid]
        if h.bed == id:
            _panel_box.add_child(_hero_line(h, tr(String(STATE_NAMES.get(h.activity_state, h.activity_state)))))
    var rough := Game.heroes.values().filter(func(h): return (h as HeroData).bed == "").size()
    if rough > 0:
        _panel_box.add_child(_wrap("%d hero(es) sleep rough: build or upgrade a dormitory." % rough, 13, Color(1.0, 0.6, 0.5)))


func _panel_hospital(level: int) -> void:
    var beds: int = TownTables.info("infirmary")["sick_beds"][clampi(level, 0, 5)]
    _panel_box.add_child(UIKit.label("Sick beds: %d / %d   Medicine %d   Antidotes %d" % [Game.patients.size(), beds,
        int(Game.hq_outputs.get("medicine", 0)), int(Game.hq_outputs.get("antidote", 0))], 14, UIKit.TEXT))
    var docs: Array = Game.workers_at("infirmary").filter(func(h): return (h as HeroData).knows_prof("doctor")).map(func(h): return "%s (Lv %d)" % [h.hero_name.split(" ")[0], h.prof_level("doctor")])
    _panel_box.add_child(_wrap("Doctors: " + (", ".join(docs) if not docs.is_empty() else "none — patients only rest"), 13, UIKit.TEXT if not docs.is_empty() else Color(1.0, 0.6, 0.5)))
    for hid in Game.patients:
        var h: HeroData = Game.heroes[hid]
        for dz in h.diseases:
            _panel_box.add_child(_wrap("• %s — %s, ~%.0f h left (%s)" % [h.hero_name.split(" ")[0], EconomyDefs.DISEASES[String(dz["id"])]["name"], float(dz["hours"]), dz["cause"]], 13, UIKit.TEXT))
    var waiting := Game.heroes.values().filter(func(h): return not (h as HeroData).diseases.is_empty() and not Game.patients.has(h.id)).size()
    if waiting > 0:
        _panel_box.add_child(_wrap("%d sick hero(es) waiting for a bed." % waiting, 13, Color(1.0, 0.6, 0.5)))


func _panel_storage() -> void:
    _panel_box.add_child(UIKit.label("Capacity per resource: %d" % Game.storage_cap(), 14, UIKit.TEXT))
    for res in EconomyDefs.RESOURCES:
        _panel_box.add_child(UIKit.label("%s: %d" % [EconomyDefs.RESOURCES[res]["name"], int(Game.hq_outputs.get(res, 0))], 13, UIKit.TEXT))
    _panel_box.add_child(UIKit.label("Equipment stash: %d / %d items (open a hero to equip)" % [Game.stash.size(), Game.stash_cap()], 14, UIKit.TEXT))


func _panel_hall() -> void:
    _panel_box.add_child(_wrap("Every other building can reach at most this level. Some buildings need a higher Hall to be built.", 13, UIKit.MUTED))
    var queue: Array = Game.construction.map(func(p): return "%s → Lv %d (%.0f h)" % [TownTables.info(String(p["bid"]))["name"], int(p["to"]), float(p["work_left"])])
    _panel_box.add_child(_wrap("Construction queue: " + (", ".join(queue) if not queue.is_empty() else "empty"), 13, UIKit.TEXT))
    _panel_workers("construction", 99)
    _panel_box.add_child(UIKit.label("Town log", 15, UIKit.ACCENT))
    var n := Game.town_log.size()
    for i in range(maxi(0, n - 8), n):
        _panel_box.add_child(_wrap(String(Game.town_log[i]), 12, UIKit.MUTED))


func _panel_jobs(id: String) -> void:
    var current := Game.job_of(id)
    if Game.workers_at(id).is_empty():
        _panel_box.add_child(_wrap("Nobody works here: assign a hero (Workers below) or nothing is made.", 13, Color(1.0, 0.65, 0.5)))
    if not (TownTables.info(id).get("jobs", []) as Array).is_empty():
        _panel_box.add_child(UIKit.button("Recipe book", func(): open_recipes(id), Vector2(150, 22)))
        return
    var row := HFlowContainer.new()
    for rid in TownTables.info(id)["jobs"]:
        var r: Dictionary = EconomyDefs.recipe(rid)
        if r.get("service", false):
            continue
        var recipe := String(rid)
        var btn := _small_btn(("● " if recipe == current else "") + String(r["name"]), func(): Game.set_job(id, recipe), 150.0)
        btn.tooltip_text = "%s → %s. %s level %d+, %.0f work-hours." % [_res_text(r["in"]), (_res_text(r["out"]) if not r.has("item") else "a %s" % r["item"]),
            ProfessionDefs.info(String(r["prof"]))["name"], int(r["min"]), float(r["work"])]
        row.add_child(btn)
    if row.get_child_count() > 0:
        _panel_box.add_child(UIKit.label("Job", 15, UIKit.ACCENT))
        _panel_box.add_child(row)
        var cr: Dictionary = EconomyDefs.recipe(current)
        _panel_box.add_child(_wrap("%s: %s → %s" % [cr["name"], _res_text(cr["in"]), (_res_text(cr["out"]) if not cr.has("item") else "a %s (quality from smith and forge level)" % cr["item"])], 13, UIKit.TEXT))
        var bt: Dictionary = Game.town_batches.get(id, {})
        if not bt.is_empty():
            _panel_box.add_child(UIKit.label("In progress: %.1f / %.0f work-hours" % [float(bt["progress"]), float(EconomyDefs.recipe(String(bt["recipe"]))["work"])], 13, UIKit.TEXT))
    var problem := String(Game.town_problems.get(id, ""))
    if problem != "":
        _panel_box.add_child(_wrap("Problem: " + problem, 13, Color(1.0, 0.6, 0.5)))


## Apprentice line: the hidden aptitude stays "???" until a master has watched them (AptitudeDefs).
func _aptitude_note(hd: HeroData, prof: String) -> String:
    var known := String(hd.aptitude_known.get(prof, ""))
    var p = hd.apprenticeship.get(prof)
    var prog := ("  %d%%" % int(float(p.get("progress", 0.0)) * 100.0)) if p is Dictionary else ""
    if known == "":
        return "apprentice  ·  talent ???" + prog
    return "apprentice  ·  %s" % AptitudeDefs.TIER_NAMES[known] + prog


func _res_text(d: Dictionary) -> String:
    if d.is_empty():
        return "nothing"
    var parts: Array = []
    for k in d:
        parts.append("%d %s" % [int(d[k]), String(EconomyDefs.RESOURCES[k]["name"]).to_lower()])
    return ", ".join(parts)


## Workers of a workplace (or the construction crew) with remove buttons, then candidates to assign.
func _panel_workers(id: String, slots: int) -> void:
    var prof := Game.workplace_prof(id)
    var here := Game.workers_at(id)
    _section(("Builders" if id == "construction" else "Workers") + (" %d / %d" % [here.size(), slots] if slots < 99 else " %d" % here.size()))
    for h in here:
        var hd := h as HeroData
        _panel_box.add_child(_hero_line(hd, "%s Lv %d · %s" % [ProfessionDefs.info(prof).get("name", prof), hd.prof_level(prof), tr(String(STATE_NAMES.get(hd.activity_state, hd.activity_state)))],
            _small_btn("Remove", func(): Game.assign_work(hd, ""), 56.0)))
    if here.is_empty():
        _panel_box.add_child(UIKit.label("Nobody works here yet.", 12, Color(1.0, 0.8, 0.5)))
    if here.size() >= slots:
        return
    var cands: Array = Game.heroes.values().filter(func(h): return (h as HeroData).hq_assignment != id)
    cands.sort_custom(func(a, b): return a.prof_level(prof) > b.prof_level(prof))
    if not cands.is_empty():
        _section("Can work here")
    for i in mini(5, cands.size()):
        var hd := cands[i] as HeroData
        var lvl := hd.prof_level(prof)
        var note := ("%s Lv %d" % [ProfessionDefs.info(prof).get("name", prof), lvl]) if lvl >= 0 else ((_aptitude_note(hd, prof) if TownTables.SPECIALIST_ONLY.has(id) else "can learn it") if hd.professions.size() < ProfessionDefs.MAX_KNOWN else "knows 2 professions")
        var b := _small_btn("Assign", func(): Game.assign_work(hd, id), 56.0)
        b.disabled = lvl < 0 and hd.professions.size() >= ProfessionDefs.MAX_KNOWN
        _panel_box.add_child(_hero_line(hd, note + (" · now: " + hd.hq_assignment if hd.hq_assignment != "" else ""), b))


# --- build menu: new buildings go wherever the player places them (owner, 2026-10-31) -----------

## Buildings that are not built yet, each with its price and whatever stops it right now.
## 2026-11-02 (owner: "pésima interfaz; cada construcción debería tener una imagen del edificio"): a window
## of cards, each with the building's picture, name, cost and what it is for; blocked ones say why.
var _build_win: Control = null
## A badge per building (what it is for, at a glance): rpg_icons number, or a ui_icons name.
const BUILDING_BADGE := {"barracks": 97, "war_room": "Icon45_1", "memorial": "Icon42_1", "kitchen": "Icon65_1",
    "infirmary": 302, "blacksmith": 294, "workshop": 101, "jeweler": 249, "alchemy": 309, "common": "Icon60_1",
    "library": 297, "farm": 271, "lumber_camp": 295, "mine": 292, "warehouse": 290, "dorm_1": 288, "dorm_2": 288,
    "dorm_3": 288, "dorm_4": 288, "training_grounds": 3, "ascension": 372, "town_hall": 173, "summon_circle": 343}


static func building_badge(id: String) -> Texture2D:
    var ref = BUILDING_BADGE.get(id, null)
    if ref == null:
        return null
    var path := (RPG % int(ref)) if ref is int else (UIC % String(ref))
    return load(path) if ResourceLoader.exists(path) else null


func show_build_menu() -> void:
    select_building("")
    _panel.visible = false
    if _build_win != null and is_instance_valid(_build_win):
        _build_win.queue_free()
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.5)
    add_child(dim)
    UIKit.fill(dim)
    _build_win = dim
    dim.gui_input.connect(func(e):
        if e is InputEventMouseButton and e.pressed:
            dim.queue_free())
    var pc := PanelContainer.new()
    dim.add_child(pc)
    pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    pc.custom_minimum_size = Vector2(600, 300)
    pc.position = Vector2(20, 24)
    var vb := VBoxContainer.new()
    pc.add_child(vb)
    var head := HBoxContainer.new()
    head.add_child(UIKit.label("Build", 28, UIKit.ACCENT))
    var mats := UIKit.label("   %s: %d" % [tr("Building materials"), int(Game.hq_outputs.get("materials", 0))], 14, UIKit.TEXT)
    head.add_child(mats)
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(sp)
    head.add_child(UIKit.button("x", func(): dim.queue_free(), Vector2(32, 30)))
    vb.add_child(head)
    var hint := "Pick a building, then click where it goes (near the town). Builders raise it over time."
    if Game.builders().is_empty():
        hint = "No builder at work: assign one at the Summoner's Hall."
    vb.add_child(UIKit.label(hint, 12, UIKit.MUTED if not Game.builders().is_empty() else Color(1.0, 0.8, 0.5)))
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(590, 240)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vb.add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    scroll.add_child(grid)
    for id in TownTables.ids():
        if Game.is_placed(id):
            continue
        grid.add_child(_build_card(id, dim))


func _build_card(id: String, win: Control) -> Control:
    var b := TownTables.info(id)
    var why := Game.construction_block(id)
    var cost := Game.next_building_cost(id)
    var ok := why == ""
    var card := Button.new()
    card.custom_minimum_size = Vector2(142, 112)
    card.tooltip_text = StringsEs.tx(String(b["desc"])) + ("" if ok else "\n" + tr("Cannot start: ") + why)
    card.add_theme_stylebox_override("normal", UIKit.box(Color(0.12, 0.09, 0.07, 0.95), ArtPalette.PANEL_RIM, 1, 0, 3))
    card.add_theme_stylebox_override("hover", UIKit.box(Color(0.2, 0.15, 0.1, 0.95), ArtPalette.GOLD[3], 1, 0, 3))
    card.add_theme_stylebox_override("pressed", UIKit.box(Color(0.25, 0.18, 0.1, 0.95), ArtPalette.GOLD[3], 1, 0, 3))
    card.add_theme_stylebox_override("disabled", UIKit.box(Color(0.08, 0.07, 0.07, 0.95), Color(0.3, 0.25, 0.25), 1, 0, 3))
    card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    card.pressed.connect(func():
        win.queue_free()
        start_place(id))
    card.disabled = not ok
    UIKit.react(card)
    var v := VBoxContainer.new()
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_theme_constant_override("separation", 1)
    card.add_child(v)
    UIKit.fill(v)
    var pic := TextureRect.new()
    pic.texture = TownView.building_thumb(id)
    pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    pic.custom_minimum_size = Vector2(130, 62)
    pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if not ok:
        pic.modulate = Color(0.45, 0.42, 0.42)
    v.add_child(pic)
    var badge := TextureRect.new()
    badge.texture = building_badge(id)
    badge.position = Vector2(4, 4)
    badge.size = Vector2(32, 32)
    badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var badge_bg := Panel.new()
    badge_bg.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.04, 0.06, 0.8), ArtPalette.GOLD[2], 1, 0, 0))
    badge_bg.position = Vector2(3, 3)
    badge_bg.size = Vector2(34, 34)
    badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(badge_bg)
    card.add_child(badge)
    var name := UIKit.label(String(b["name"]), 14, ArtPalette.GOLD[3] if ok else UIKit.MUTED)
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(name)
    var cl := UIKit.label("%d %s" % [cost, tr("materials")], 12, UIKit.TEXT if int(Game.hq_outputs.get("materials", 0)) >= cost else UIKit.BAD)
    if not ok:
        cl = UIKit.label(why, 12, Color(1.0, 0.6, 0.5))
        cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        cl.custom_minimum_size = Vector2(130, 0)
    cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(cl)
    return card


func start_place(id: String) -> void:
    _panel.visible = false
    placing_new = true
    moving = id
    view.ghost_id = id
    _move_msg.text = "Building the %s: click a spot near the town (green = valid). Right-click or Esc to cancel." % TownTables.info(id)["name"]


# --- move mode (D-050) ------------------------------------------------------------------------

func start_move(id: String) -> void:
    moving = id
    select_building("")
    view.ghost_id = id
    _move_msg.text = "Placing the %s: click a spot (green = valid). Right-click or Esc to cancel." % TownTables.info(id)["name"]


func cancel_move() -> void:
    moving = ""
    placing_new = false
    if view != null:
        view.ghost_id = ""
    _move_msg.text = ""


## Places the building being moved with its top-left at the cell under `world`. Returns the reason
## when it cannot go there ("" = moved).
func place_at(world: Vector2) -> String:
    var cell := _ghost_cell(world)
    var why := Game.place_and_build(moving, cell) if placing_new else Game.move_building(moving, cell)
    if why == "":
        cancel_move()
        rebuild()
    else:
        _move_msg.text = "Cannot place it there: " + why
    return why


func _ghost_cell(world: Vector2) -> Vector2i:
    var p := map.plot_of(moving)
    return map.cell_of(world) - Vector2i(p.size.x / 2, p.size.y / 2)


func _on_transcribe(id: String, class_id: String) -> void:
    Game.library_transcribe(class_id)
    _show_panel(id)


## 2026-11-02 (owner: "pésima interfaz"): the tower gate lists floors as cards: a medallion with the floor
## number, the name, the mission with its icon, difficulty pips, squad size and the risk in its colour.
const MISSION_ICON := {"combat": 3, "exploration": "Icon43_1", "defense": 152, "escape": 226, "boss": 179,
    "retrieval": 255, "rescue": "Icon60_1", "survival": 302, "sabotage": 294}
const DIFF_PIPS := {"Tutorial": 1, "Easy": 2, "Normal": 3, "Hard": 4, "Very hard": 5, "Boss": 5}


func _icon_tex(ref) -> Texture2D:
    var path := (RPG % int(ref)) if ref is int else (UIC % String(ref))
    return load(path) if ResourceLoader.exists(path) else null


func _floor_card(f: int, title: String, line2: String, mission: String, pips: int, cb: Callable, special: bool = false) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(200, 40)
    b.focus_mode = Control.FOCUS_NONE
    var base := Color(0.1, 0.16, 0.1) if special else Color(0.12, 0.09, 0.07)
    b.add_theme_stylebox_override("normal", UIKit.box(base, ArtPalette.PANEL_RIM, 1, 0, 2))
    b.add_theme_stylebox_override("hover", UIKit.box(base.lightened(0.1), ArtPalette.GOLD[3], 1, 0, 2))
    b.add_theme_stylebox_override("pressed", UIKit.box(base.lightened(0.15), ArtPalette.GOLD[3], 1, 0, 2))
    b.pressed.connect(cb)
    b.mouse_entered.connect(func(): UIKit.sound("hover"))
    UIKit.react(b)
    var med := Panel.new()                                     # the floor medallion
    med.add_theme_stylebox_override("panel", UIKit.box(Color(0.2, 0.14, 0.3) if not special else Color(0.15, 0.3, 0.15), ArtPalette.GOLD[3], 1, 0, 0))
    med.position = Vector2(3, 4)
    med.size = Vector2(32, 32)
    med.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(med)
    var num := UIKit.label("W" if special else ("·" if f == 0 else str(f)), 20, ArtPalette.GOLD[3])
    num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    num.size = Vector2(32, 32)
    num.mouse_filter = Control.MOUSE_FILTER_IGNORE
    med.add_child(num)
    var t := UIKit.label(title, 14, UIKit.TEXT)
    t.position = Vector2(40, 1)
    t.size = Vector2(118, 16)
    t.clip_text = true
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(t)
    var mi := TextureRect.new()
    mi.texture = _icon_tex(MISSION_ICON.get(mission, 3))
    mi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    mi.position = Vector2(40, 20)
    mi.size = Vector2(16, 16)
    mi.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(mi)
    var l2 := UIKit.label(line2, 12, UIKit.MUTED)
    l2.position = Vector2(58, 20)
    l2.size = Vector2(136, 14)
    l2.clip_text = true
    l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(l2)
    for i in 5:                                                 # difficulty pips
        var pip := ColorRect.new()
        pip.color = Color(0.9, 0.35, 0.3) if i < pips else Color(0.25, 0.2, 0.18)
        pip.position = Vector2(162 + i * 6, 6)
        pip.size = Vector2(5, 5)
        pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(pip)
    return b


func _add_tower_buttons() -> void:
    # D-066: the repeatable Wilds (the town's materials) and the tower (gear and rarities), gated by the Hall
    var tier := Game.wilds_tier()
    var wcfg := DungeonDefs.config(tier)
    _section("Outside the tower")
    var wilds := _floor_card(0, String(wcfg["name"]), tr("repeatable · materials"), "exploration", 0, func(): enter_floor(-tier), true)
    wilds.tooltip_text = "%s\nA new map every run; leave by the entrance (X) to keep what you carry. Half a day passes." % String(wcfg["intro"])
    _panel_box.add_child(wilds)
    var train := _floor_card(0, tr("Training ground"), tr("fixed map, no risk"), "combat", 0, func(): navigate.emit("sandbox", 0))
    _panel_box.add_child(train)
    _section("The tower")
    # vertical slice: floors 1-5, each known before entering (mission, difficulty, squad size, what it is)
    for f in range(1, TowerExpedition.SLICE_FLOORS + 1):
        var floor_num := f
        var cfg := TowerExpedition.get_floor_config(f)
        var done := int(Game.tower_cleared.get(str(f), 0))
        var nm := String(cfg["name"])
        if nm.contains(": "):
            nm = nm.split(": ", true, 1)[1]
        var mission := String(cfg["mission"])
        var btn := _floor_card(f, nm + ("  ✓" if done > 0 else ""), "%s · %s %d" % [tr(mission.capitalize()), tr("squad"), TowerExpedition.party_max(f)],
            mission, int(DIFF_PIPS.get(String(cfg["difficulty"]), 3)), func(): enter_floor(floor_num))
        btn.tooltip_text = "%s · %s\n%s\nSquad: %d heroes (the first ones of your party go in). Explored: %s" % [String(cfg["name"]), tr(String(cfg["difficulty"])), String(cfg.get("intro", "")),
            TowerExpedition.party_max(f), "yes" if Game.floor_explored(f) != "" else "not yet"]
        _show_risk(btn, f, false)
        var r := PowerCalc.floor_risk(f, Game.party_heroes(), Game.hq_outputs, Game.town_buildings)
        var risk := ColorRect.new()                               # risk stripe on the left edge
        risk.color = PowerCalc.band_color(String(r["band"]))
        risk.position = Vector2(0, 2)
        risk.size = Vector2(2, 36)
        risk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(risk)
        _panel_box.add_child(btn)
    var grid := GridContainer.new()
    grid.columns = 5
    _panel_box.add_child(UIKit.label("Floors 6-10 (beyond the demo)", 12, UIKit.MUTED))
    _panel_box.add_child(grid)
    for f in range(TowerExpedition.SLICE_FLOORS + 1, 11):
        var floor_num := f
        var btn := UIKit.button(str(f), func(): enter_floor(floor_num), Vector2(70, 30))
        btn.focus_mode = Control.FOCUS_NONE
        btn.tooltip_text = String(TowerExpedition.get_floor_config(f)["name"]) + " (beyond the demo: not tuned yet)"
        _show_risk(btn, f, false)
        grid.add_child(btn)
    if Game.party_heroes().size() < Game.PARTY_SIZE:
        var warn := UIKit.label("Each floor takes its own squad size: the first heroes of your party go in (Menu -> Party).", 13, Color(1.0, 0.7, 0.5))
        warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        warn.custom_minimum_size = Vector2(150, 0)  # px
        _panel_box.add_child(warn)
    _add_expedition_buttons()
    _add_merchant_buttons()


## D-082b: before entering, the floor's squad size against the party. Short: a clear warning with
## "Complete the party" or "Enter anyway" (the design allows a smaller squad). More heroes than the floor
## takes: says who stays out. What this says is what SandboxScreen deploys (TowerExpedition.squad_report).
var _squad_dialog: Control = null


func enter_floor(floor_num: int) -> void:
    var r := TowerExpedition.squad_report(floor_num, Game.party_heroes())
    if not bool(r["short"]) and not bool(r["extra"]):
        navigate.emit("sandbox", floor_num)
        return
    if _squad_dialog != null and is_instance_valid(_squad_dialog):
        _squad_dialog.queue_free()
    var center := CenterContainer.new()
    add_child(center)
    UIKit.fill(center)
    center.z_index = 90
    _squad_dialog = center
    var pc := PanelContainer.new()
    center.add_child(pc)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 8)
    pc.add_child(vb)
    var text := ""
    if bool(r["short"]):
        text = tr("This floor takes %d heroes and your party has %d. %d will go in.") % [int(r["size"]), int(r["have"]), int(r["goes"])]
    else:
        text = tr("This floor takes %d heroes: only the first %d of your party go in (the Master first); the other %d stay in town.") % [int(r["size"]), int(r["goes"]), int(r["have"]) - int(r["goes"])]
    var l := UIKit.label(text, 15)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(380, 0)
    vb.add_child(l)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    vb.add_child(row)
    if bool(r["short"]):
        row.add_child(UIKit.button("Complete the party", func():
            center.queue_free()
            navigate.emit("party", 0), Vector2(170, 34)))
    row.add_child(UIKit.button("Enter anyway" if bool(r["short"]) else "Enter", func():
        center.queue_free()
        navigate.emit("sandbox", floor_num), Vector2(130, 34)))
    row.add_child(UIKit.button("Cancel", func(): center.queue_free(), Vector2(100, 34)))


## D-079: the only thing the player sees of the soft block: "Risk: N% (band)" in the band's colour and at
## most 3 qualitative hints in the tooltip. Never power numbers (only with PowerDefs.DEBUG_SHOW_NUMBERS).
func _show_risk(btn: Button, f: int, in_text: bool) -> void:
    var r := PowerCalc.floor_risk(f, Game.party_heroes(), Game.hq_outputs, Game.town_buildings)
    var band := String(r["band"])
    var line := "%s: %d%% (%s)" % [tr("Risk"), int(r["risk"]), tr(PowerCalc.band_name(band))]
    if in_text:
        btn.text += "  ·  " + line
    btn.add_theme_color_override("font_color", PowerCalc.band_color(band))
    btn.add_theme_color_override("font_hover_color", PowerCalc.band_color(band).lightened(0.2))
    btn.tooltip_text += "
" + line
    for h in r["hints"]:
        btn.tooltip_text += "
· " + tr(String(h))
    if r.has("debug"):
        btn.tooltip_text += "
[debug] " + String(r["debug"])


## Master prompt C: offline expeditions (idle heroes outside the squad go back to a cleared floor).
func _add_expedition_buttons() -> void:
    var now := Time.get_unix_time_from_system()
    for r in OfflineExpeditions.claim(Game, now):
        _panel_box.add_child(_wrap("Back from floor %d: %s" % [int(r["floor"]), _res_text(r["loot"])], 12, Color(0.7, 1.0, 0.7)))
    OfflineExpeditions.refresh_charges(Game, now)
    _panel_box.add_child(UIKit.label("Offline expeditions  ·  charges %d/%d  ·  away %d" % [Game.exp_charges, OfflineExpeditions.charges_max(Game), Game.expeditions.size()], 13))
    var idle: Array = Game.heroes.values().filter(func(h): return (h as HeroData).hq_assignment == "" and Game.party_slot_of((h as HeroData).id) < 0)
    for f in range(1, 11):
        if int(Game.tower_cleared.get(str(f), 0)) <= 0:
            continue
        var n := mini(idle.size(), TowerExpedition.party_max(f))
        var ids: Array = idle.slice(0, n).map(func(h): return (h as HeroData).id)
        var floor_num := f
        var btn := _small_btn("F%d (%d min)" % [f, roundi(float(f) * ExpeditionDefs.MINUTES_PER_FLOOR)], func():
            var why := OfflineExpeditions.start(Game, floor_num, ids, Time.get_unix_time_from_system())
            if why != "":
                UIKit.toast(self, why)
            Game._commit()
            rebuild(), 90.0)
        btn.tooltip_text = OfflineExpeditions.block(Game, f, ids, now)
        btn.disabled = btn.tooltip_text != ""
        _panel_box.add_child(btn)


## Master prompt B: the merchant's offers of the day.
func _add_merchant_buttons() -> void:
    _panel_box.add_child(UIKit.label("Merchant (today)", 13))
    for i in Game.merchant_offers():
        var o: Dictionary = MerchantDefs.OFFERS[int(i)]
        var offer := int(i)
        _panel_box.add_child(_small_btn("%s -> %s" % [_res_text(o["give"]), _res_text(o["get"])], func():
            var why := Game.merchant_trade(offer)
            if why != "":
                UIKit.toast(self, why)
            rebuild(), 220.0))


# --- input -----------------------------------------------------------------------------

func screen_to_world(p: Vector2) -> Vector2:
    var vsize := Vector2(_viewport.size)
    return (camera.position + (p - vsize * 0.5) / camera.zoom.x) / WORLD_SCALE


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed:
                _dragging = true
                _moved = false
                _drag_from = mb.position
                _cam_from = camera.position
            else:
                _dragging = false
                if not _moved:
                    if moving != "":
                        place_at(screen_to_world(mb.position))
                    else:
                        click_at(screen_to_world(mb.position))
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and moving != "":
            cancel_move()
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(1.1)
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(1.0 / 1.1)
    elif event is InputEventMouseMotion:
        var mm := event as InputEventMouseMotion
        if _dragging and (mm.position - _drag_from).length() > 6.0:
            _moved = true
            if master_th == null:                   # owner 2026-11-02: with a Master the camera stays on him
                camera.position = _clamp_cam(_cam_from - (mm.position - _drag_from) / camera.zoom.x)
        _update_hover(screen_to_world(mm.position))
        if moving != "" and view != null:
            view.ghost_cell = _ghost_cell(screen_to_world(mm.position))
            view.ghost_ok = Game.placement_block(moving, view.ghost_cell) == "" and (not placing_new or Game.construction_block(moving) == "")


func click_at(world: Vector2) -> void:
    if map == null:
        return
    var th := hero_at(world)
    if th != null and th != master_th:
        open_hero(th)
        return
    var bid := map.building_at(map.cell_of(world))
    if master_th == null:
        select_building(bid)                      # no Master yet (new account, tests): the old direct view
    elif bid != "":
        walk_to_building(bid)
    else:
        select_building("")
        _goal_bid = ""
        master_th.go_to(world)


## The Master walks to a building's door and goes in on arrival (owner 2026-11-02).
func walk_to_building(bid: String) -> void:
    if master_th == null or map == null:
        select_building(bid)
        return
    select_building("")
    var door := map.center_of(map.door_of(bid))
    if master_th.position.distance_to(door) <= DOOR_REACH:
        select_building(bid)
        return
    _goal_bid = bid
    if not master_th.go_to(door + Vector2(0, 10)):
        _goal_bid = ""
        UIKit.toast(self, tr("No way there"))


## F: go into the building whose door the Master stands at.
func enter_nearest() -> String:
    if master_th == null or map == null:
        return ""
    var best := ""
    var best_d := DOOR_REACH
    for bid in TownTables.ids():
        if not map.is_placed(bid):
            continue
        var d := master_th.position.distance_to(map.center_of(map.door_of(bid)))
        if d <= best_d:
            best_d = d
            best = bid
    if best != "":
        select_building(best)
    return best


## Visible town hero under a world point (feet at the node origin, body ~30 px above).
func hero_at(world: Vector2) -> TownHero:
    var best: TownHero = null
    var best_d := 22.0
    for th in heroes:
        if not th.visible:
            continue
        var d := (th.position + Vector2(0, -14)).distance_to(world)
        if d < best_d:
            best_d = d
            best = th
    return best


## Opens the hero panel (equipment, colours, stats, personality, bonds, memories).
func open_hero(th: TownHero) -> void:
    close_hero()
    selected_hero_id = th.hero.id
    hero_panel = HeroInfoPanel.new(th.hero, th.activity_text())
    hero_panel.position = Vector2(6, 26)  # px
    hero_panel.closed.connect(close_hero)
    hero_panel.open_barracks.connect(func(): navigate.emit("roster", 0))
    add_child(hero_panel)


func close_hero() -> void:
    if hero_panel != null and is_instance_valid(hero_panel):
        hero_panel.queue_free()
    hero_panel = null
    selected_hero_id = ""


func _update_hover(world: Vector2) -> void:
    if map == null or view == null:
        return
    view.hovered = map.building_at(map.cell_of(world))
    for th in heroes:
        th.hovered = th.position.distance_to(world + Vector2(0, 16)) < 20.0
        th.queue_redraw()


func _zoom(f: float) -> void:
    var z := camera.zoom.x
    var next := z
    if f > 1.0:
        for s in ZOOM_STEPS:
            if float(s) > z + 0.01:
                next = float(s)
                break
    else:
        for i in range(ZOOM_STEPS.size() - 1, -1, -1):
            if float(ZOOM_STEPS[i]) < z - 0.01:
                next = float(ZOOM_STEPS[i])
                break
    camera.zoom = Vector2.ONE * clampf(next, ZOOM_MIN, ZOOM_MAX)
    camera.position = _clamp_cam(camera.position)


func _clamp_cam(p: Vector2) -> Vector2:
    if map == null:
        return p
    var ws := map.world_size() * WORLD_SCALE
    return Vector2(clampf(p.x, 0.0, ws.x), clampf(p.y, 0.0, ws.y))


## Esc menu over the village (D-062: the town clock keeps running).
func open_menu() -> void:
    if _menu != null and is_instance_valid(_menu):
        _menu.close()
        return
    _menu = GameMenu.new()
    _menu.leave_label = "Title screen"
    _menu.leave_requested.connect(func(_to): navigate.emit("title", 0))
    add_child(_menu)


func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F and moving == "":
        enter_nearest()
        return
    if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE and moving == "":
        open_menu()
        return
    if moving != "" and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
        cancel_move()


## A tiny pixel bed for the dormitory panel: a sleeper's head on the pillow when it is taken.
class BedPip extends Control:
    var taken: bool = false

    func _init() -> void:
        custom_minimum_size = Vector2(18, 14)
        mouse_filter = Control.MOUSE_FILTER_PASS

    func _draw() -> void:
        draw_rect(Rect2(0, 2, 18, 11), Color(0.36, 0.22, 0.12))          # frame
        draw_rect(Rect2(1, 3, 16, 8), Color(0.92, 0.9, 0.84))             # sheet
        draw_rect(Rect2(2, 4, 5, 4), Color(1, 1, 1))                      # pillow
        draw_rect(Rect2(7, 4, 10, 7), Color(0.35, 0.45, 0.75) if taken else Color(0.55, 0.6, 0.75))   # blanket
        if taken:
            draw_rect(Rect2(3, 4, 3, 3), Color(0.85, 0.65, 0.5))           # head
            draw_rect(Rect2(8, 6, 8, 1), Color(0.28, 0.36, 0.62))          # body shape under the blanket
        draw_rect(Rect2(0, 0, 2, 13), Color(0.3, 0.18, 0.1))              # headboard
