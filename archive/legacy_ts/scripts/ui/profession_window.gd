class_name ProfessionWindow
extends PanelContainer
## Owner, 2026-10-31: a recipe book like World of Warcraft's professions. Left: the building's recipes
## by category, coloured by difficulty for the best worker (orange = just learnt, yellow, green, grey =
## trivial, red = too hard). Right: the chosen recipe with its reagents (have / need), the worker,
## the time, one affix to choose for crafted gear, a count and Create / Create all. Nobody assigned =
## nothing can be ordered.

signal closed

var building_id := ""
var _list: VBoxContainer
var _detail: VBoxContainer
var _sel := ""
var _count := 1
var _affix := ""

const DIFF := {"red": Color(0.85, 0.3, 0.3), "orange": Color(1.0, 0.55, 0.2), "yellow": Color(1.0, 0.9, 0.3),
    "green": Color(0.4, 0.9, 0.4), "grey": Color(0.6, 0.6, 0.6)}


func _init(bid: String = "") -> void:
    building_id = bid


func best_level() -> int:
    var prof := Game.workplace_prof(building_id)
    var best := -1
    for h in Game.workers_at(building_id):
        for rid in TownTables.info(building_id).get("jobs", []):
            best = maxi(best, (h as HeroData).prof_level(String(EconomyDefs.recipe(String(rid))["prof"])))
    if prof != "":
        for h in Game.workers_at(building_id):
            best = maxi(best, (h as HeroData).prof_level(prof))
    return best


static func difficulty(level: int, need: int) -> String:
    if level < need:
        return "red"
    if level <= need:
        return "orange"
    if level <= need + 2:
        return "yellow"
    if level <= need + 5:
        return "green"
    return "grey"


func _ready() -> void:
    custom_minimum_size = Vector2(420, 260)
    var root := VBoxContainer.new()
    add_child(root)
    var head := HBoxContainer.new()
    root.add_child(head)
    head.add_child(UIKit.label("%s — recipes" % TownTables.info(building_id)["name"], 18, UIKit.ACCENT))
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(sp)
    head.add_child(UIKit.button("x", func(): closed.emit(), Vector2(22, 18)))
    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body)
    var ls := ScrollContainer.new()
    ls.custom_minimum_size = Vector2(170, 220)
    ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(ls)
    _list = VBoxContainer.new()
    _list.add_theme_constant_override("separation", 1)
    ls.add_child(_list)
    _detail = VBoxContainer.new()
    _detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(_detail)
    _fill()


func _fill() -> void:
    for c in _list.get_children():
        c.queue_free()
    var lvl := best_level()
    var cats := {}
    for rid in TownTables.info(building_id).get("jobs", []):
        var r := EconomyDefs.recipe(String(rid))
        if r.is_empty() or r.get("service", false):
            continue
        var cat := String(r.get("category", "Materials" if not r.has("item") else "Gear"))
        if not cats.has(cat):
            cats[cat] = []
        (cats[cat] as Array).append(String(rid))
    for cat in cats:
        _list.add_child(UIKit.label(String(cat), 13, UIKit.MUTED))
        var ids: Array = cats[cat]
        ids.sort_custom(func(a, b): return int(EconomyDefs.recipe(a)["min"]) < int(EconomyDefs.recipe(b)["min"]))
        for rid in ids:
            var r := EconomyDefs.recipe(rid)
            var b := Button.new()
            b.text = "  " + String(r["name"])
            b.alignment = HORIZONTAL_ALIGNMENT_LEFT
            b.flat = true
            b.add_theme_color_override("font_color", DIFF[difficulty(lvl, int(r["min"]))])
            b.add_theme_font_size_override("font_size", 12)
            var id := String(rid)
            b.pressed.connect(func(): _select(id))
            _list.add_child(b)
            if _sel == "":
                _sel = id
    if _sel != "":
        _select(_sel)


func _have(res: String) -> int:
    return int(Game.hq_outputs.get(res, 0))


func _select(rid: String) -> void:
    _sel = rid
    for c in _detail.get_children():
        c.queue_free()
    var r := EconomyDefs.recipe(rid)
    _detail.add_child(UIKit.label(String(r["name"]), 16, UIKit.TEXT))
    var lvl := best_level()
    _detail.add_child(UIKit.label("Needs %s %d  ·  %.0f work-hours" % [ProfessionDefs.info(String(r["prof"]))["name"], int(r["min"]), float(r["work"])], 12, DIFF[difficulty(lvl, int(r["min"]))]))
    if r.has("craft"):
        var b: Dictionary = ItemDefs.BASES[String(r["craft"])]
        _detail.add_child(UIKit.label("%s  ·  requires level %d%s" % [b["name"], int(ItemLibrary.TIERS[int(r["tier"])]["min_level"]),
            ("  ·  set piece" if ItemLibrary.SET_PIECES.has(String(r["craft"])) and String(r["line"]) == "blacksmith" else "")], 12, UIKit.MUTED))
    elif not (r["out"] as Dictionary).is_empty():
        _detail.add_child(UIKit.label("Makes: " + ", ".join((r["out"] as Dictionary).keys().map(func(k): return "%d %s" % [int(r["out"][k]), String(EconomyDefs.RESOURCES.get(k, {}).get("name", k)).to_lower()])), 12, UIKit.MUTED))
    _detail.add_child(UIKit.label("Reagents", 13, UIKit.ACCENT))
    var can := true
    for k in r["in"]:
        var need := int(r["in"][k]) * _count
        var have := _have(String(k))
        can = can and have >= need
        _detail.add_child(UIKit.label("  %s  %d / %d" % [String(EconomyDefs.RESOURCES.get(k, {}).get("name", k)), have, need], 12,
            UIKit.TEXT if have >= need else Color(1.0, 0.5, 0.45)))
    if r.has("craft"):
        _detail.add_child(UIKit.label("Choose one affix", 13, UIKit.ACCENT))
        var row := HBoxContainer.new()
        for a in ItemGen.craft_affix_choices(rid, Game.town_day()):
            var ab := UIKit.button(String(ItemDefs.AFFIXES[a]["name"]).trim_prefix("of "), func(): _affix = String(a); _select(rid))
            ab.add_theme_font_size_override("font_size", 11)
            if _affix == String(a):
                ab.add_theme_color_override("font_color", UIKit.ACCENT)
            row.add_child(ab)
        _detail.add_child(row)
    var workers: Array = Game.workers_at(building_id)
    if workers.is_empty():
        _detail.add_child(UIKit.label("Nobody works here: assign a hero first.", 12, Color(1.0, 0.6, 0.45)))
    else:
        _detail.add_child(UIKit.label("Made by " + ", ".join(workers.map(func(h): return (h as HeroData).display_name().get_slice(" ", 0))), 12, UIKit.MUTED))
    var qty := HBoxContainer.new()
    qty.add_child(UIKit.button("-", func(): _count = maxi(1, _count - 1); _select(rid), Vector2(18, 18)))
    qty.add_child(UIKit.label(" %d " % _count, 14, UIKit.TEXT))
    qty.add_child(UIKit.button("+", func(): _count += 1; _select(rid), Vector2(18, 18)))
    var create := UIKit.button("Create", func(): _order(rid, _count), Vector2(60, 18))
    create.disabled = workers.is_empty() or not can or lvl < int(r["min"])
    qty.add_child(create)
    var all := UIKit.button("Create all", func(): _order(rid, 0), Vector2(70, 18))
    all.disabled = create.disabled
    qty.add_child(all)
    _detail.add_child(qty)
    var cur := String(Game.town_jobs.get(building_id, ""))
    if cur != "":
        _detail.add_child(UIKit.label("Working on: %s%s" % [EconomyDefs.recipe(cur).get("name", cur),
            (" (%d left)" % int(Game.craft_left[building_id])) if Game.craft_left.has(building_id) else " (until stopped)"], 12, UIKit.MUTED))


func _order(rid: String, n: int) -> void:
    var why := Game.order_craft(building_id, rid, n, _affix)
    if why != "":
        UIKit.toast(self, why)
    _select(rid)
