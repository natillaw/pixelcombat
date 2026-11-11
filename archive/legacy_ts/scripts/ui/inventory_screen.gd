class_name InventoryScreen
extends Control
## The Master's global inventory (vertical slice, D-063 UI). Redone 2026-11-02 (owner: "interfaz horrible"):
##   left   - the chosen hero as a paper doll, every equipment slot around them (click a worn piece: take it off)
##   centre - the stash as a backpack grid with filters (click: equip on the hero; right click: salvage)
##   right  - tabs: resources (icon grid), books and kept loot, forge and alchemy recipes
## One inventory: heroes only wear equipment.

signal back_requested

const RPG := "res://assets/pixel/packs/rpg_icons/Icon%d.png"
## Resource id -> icon (rpg_icons number, or "item:<id>" for ItemIcons, or a kit path).
const RES_ICON := {"materials": 291, "grain": 275, "herb": 271, "ore": 386, "ingot": 343, "medicine": 284,
    "potion": 302, "antidote": 282, "hide": 290, "fang": 15, "gel": 278, "spore": 280, "silk": 288, "venom": 279,
    "bone": 179, "core": 340, "starsteel": 344, "essence": 372, "mat_enchanted_cloth": 288, "mat_iron_ore": 386,
    "mat_resonant_crystal": 338, "mat_moon_flower": 279, "mat_rune_plate": 261, "key_guardian_heart": 257,
    "key_legendary_fragment": 375, "con_potion_major": 303, "elixir_strength": 305, "elixir_speed": 312,
    "elixir_defense": 316, "meal_stew": "item:meal_stew", "meal_roast": "item:meal_roast", "camp_kit": "item:camp_kit",
    "food": "res://assets/pixel/ui/ts_kit/icons/res_food.png", "wood": "res://assets/pixel/ui/ts_kit/icons/res_wood.png",
    "stone": "res://assets/pixel/ui/ts_kit/icons/res_stone.png", "book_xp": "item:book_xp", "book_skill": "item:book_skill",
    "book_trade": "item:book_trade", "book_plan": "item:book_plan", "arrows": "item:arrows"}
## Paper doll: slot -> position around the hero (base px, inside the doll box).
const DOLL := {"head": Vector2(4, 8), "chest": Vector2(4, 46), "hands": Vector2(4, 84), "legs": Vector2(4, 122),
    "feet": Vector2(4, 160), "main_hand": Vector2(140, 8), "off_hand": Vector2(140, 46), "amulet": Vector2(140, 84),
    "ring1": Vector2(140, 122), "bag": Vector2(140, 160), "special": Vector2(72, 160)}
const FILTERS := [["all", "All"], ["weapon", "Weapons"], ["armor", "Armour"], ["jewel", "Jewels"], ["junk", "Junk"]]

var _hero_i: int = 0
var _hero_ids: Array = []
var _filter: String = "all"
var _tab: String = "res"
var _body: HBoxContainer
var _msg: Label


func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.09, 0.07, 0.06)
    add_child(bg)
    UIKit.fill(bg)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 3)
    add_child(root)
    UIKit.fill(root)
    var top := HBoxContainer.new()
    root.add_child(top)
    top.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(100, 32)))
    top.add_child(UIKit.label("Inventory", 28, UIKit.ACCENT))
    _msg = UIKit.label("", 12, UIKit.ACCENT)
    _msg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    top.add_child(_msg)
    for id in Game.heroes:
        _hero_ids.append(id)
    var m := Game.master()
    if m != null and _hero_ids.has(m.id):
        _hero_i = _hero_ids.find(m.id)
    _body = HBoxContainer.new()
    _body.add_theme_constant_override("separation", 4)
    _body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_body)
    Game.changed.connect(refresh)
    refresh()


func _hero() -> HeroData:
    if _hero_ids.is_empty():
        return null
    _hero_i = posmod(_hero_i, _hero_ids.size())
    return Game.heroes.get(_hero_ids[_hero_i])


func refresh() -> void:
    if not is_inside_tree():
        return
    for c in _body.get_children():
        c.queue_free()
    _body.add_child(_doll())
    _body.add_child(_stash())
    _body.add_child(_side())


func _panel(title: String, w: int) -> Array:
    var pc := PanelContainer.new()
    pc.custom_minimum_size = Vector2(w, 0)
    pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 2)
    pc.add_child(v)
    if title != "":
        v.add_child(UIKit.label(title, 20, UIKit.ACCENT))
    return [pc, v]


func _scroll(v: VBoxContainer) -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(scroll)
    var inner := VBoxContainer.new()
    inner.add_theme_constant_override("separation", 2)
    inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(inner)
    return inner


# --- the hero and what they wear --------------------------------------------------------------

func _doll() -> Control:
    var pv := _panel("", 176)
    var v: VBoxContainer = pv[1]
    var h := _hero()
    var pick := HBoxContainer.new()
    pick.add_child(UIKit.button("<", func():
        _hero_i -= 1
        refresh(), Vector2(30, 26)))
    var name := UIKit.label(h.display_name() if h != null else "-", 14, h.star_color() if h != null else UIKit.MUTED)
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name.clip_text = true
    pick.add_child(name)
    pick.add_child(UIKit.button(">", func():
        _hero_i += 1
        refresh(), Vector2(30, 26)))
    v.add_child(pick)
    if h == null:
        return pv[0]
    var cls: String = String(HeroTables.CLASSES.get(h.hero_class, HeroTables.CLASSES["class.none"])["name"])
    var sub := UIKit.label("%s · %s %d · %s %d" % [tr(cls), tr("Lv"), h.level, tr("Power"), int(PowerCalc.hero_power(h).get("total", 0))], 12, UIKit.MUTED)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(sub)
    v.add_child(paper_doll(h, func(t: String): _msg.text = t))
    var locked: Array = ItemDefs.SLOTS.filter(func(s): return not ItemDefs.slot_open(String(s)))
    if not locked.is_empty():
        var l := UIKit.label(tr("Locked for now: ") + ", ".join(locked.map(func(s): return tr(String(ItemDefs.SLOT_NAMES.get(s, s))))), 12, UIKit.MUTED)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(176, 0)
        v.add_child(l)
    return pv[0]


## The hero standing on a lit plate with every open equipment slot around them (inventory, hero sheet).
## Clicking a worn piece takes it off; `say` gets the result text.
static func paper_doll(h: HeroData, say: Callable) -> Control:
    var doll := Control.new()
    doll.custom_minimum_size = Vector2(172, 196)
    var plate := Panel.new()                                  # a lit stage behind the hero
    plate.add_theme_stylebox_override("panel", UIKit.box(Color(0.16, 0.12, 0.09), Color(ArtPalette.GOLD[2], 0.35), 1, 0, 0))
    plate.position = Vector2(40, 8)
    plate.size = Vector2(96, 148)
    plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    doll.add_child(plate)
    var spr := AnimatedSprite2D.new()
    spr.sprite_frames = SpriteComposer.build_frames(h)
    spr.play("idle_down")
    spr.scale = Vector2(2, 2)
    spr.position = Vector2(88, 84)
    doll.add_child(spr)
    for slot in DOLL:
        if not ItemDefs.slot_open(String(slot)):
            continue
        var item: Dictionary = h.equipment.get(slot, {})
        var c := ItemIcons.slot_control(String(slot), item)
        c.position = DOLL[slot]
        c.tooltip_text = "%s\n%s" % [StringsEs.tx(String(ItemDefs.SLOT_NAMES.get(slot, slot))), ItemIcons.tooltip(item) + "\n" + TranslationServer.translate("Click: take it off") if not item.is_empty() else TranslationServer.translate("empty")]
        c.mouse_filter = Control.MOUSE_FILTER_STOP
        var sl := String(slot)
        c.gui_input.connect(func(e):
            if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not h.equipment.get(sl, {}).is_empty():
                var why := Game.unequip(h, sl)
                say.call(why if why != "" else TranslationServer.translate("Back in the stash."))
                UIKit.sound("click"))
        doll.add_child(c)
    return doll


# --- the stash ---------------------------------------------------------------------------------

func _stash() -> Control:
    var pv := _panel("", 246)
    var v: VBoxContainer = pv[1]
    var h := _hero()
    var head := HBoxContainer.new()
    head.add_child(UIKit.label("Equipment stash", 20, UIKit.ACCENT))
    var cap := UIKit.label("  %d / %d" % [Game.stash.size(), Game.stash_cap()], 12, UIKit.MUTED)
    cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(cap)
    v.add_child(head)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 1)
    for f in FILTERS:
        var id: String = f[0]
        var b := UIKit.button(tr(String(f[1])), func():
            _filter = id
            refresh(), Vector2(60, 26))
        b.disabled = _filter == id
        b.add_theme_font_size_override("font_size", UIKit.fpx(12))
        tabs.add_child(b)
    v.add_child(tabs)
    var shown: Array = Game.stash.filter(func(it): return _passes(it))
    var inner := _scroll(v)
    var grid := GridContainer.new()
    grid.columns = 7
    grid.add_theme_constant_override("h_separation", 2)
    grid.add_theme_constant_override("v_separation", 2)
    inner.add_child(grid)
    var cells := maxi(Game.stash_cap() if _filter == "all" else shown.size(), 28)
    grid.columns = 6
    for i in cells:
        if i < shown.size():
            grid.add_child(_stash_cell(shown[i], h))
        else:
            var empty := Panel.new()                         # an empty pocket of the backpack
            empty.custom_minimum_size = Vector2(32, 32)
            empty.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.05, 0.05, 0.7), Color(0.3, 0.22, 0.15), 1, 0, 0))
            grid.add_child(empty)
    var junk: Array = Game.stash.filter(func(it): return ItemDefs.is_junk(it))
    var foot := VBoxContainer.new()
    var hint := UIKit.label("Click: equip · Right click: salvage", 12, UIKit.MUTED)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.custom_minimum_size = Vector2(220, 0)
    foot.add_child(hint)
    if not junk.is_empty():                                   # D-123: grey junk is only good for materials
        foot.add_child(UIKit.button(tr("Salvage all junk (%d)") % junk.size(), func():
            var got := {}
            for it in junk:
                var g := Game.salvage(int(it["uid"]))
                for k in g:
                    got[k] = int(got.get(k, 0)) + int(g[k])
            _msg.text = tr("Salvaged: %s") % SandboxScreen._res_line(got), Vector2(0, 26)))
    v.add_child(foot)
    return pv[0]


func _passes(it: Dictionary) -> bool:
    if _filter == "all":
        return true
    if _filter == "junk":
        return ItemDefs.is_junk(it)
    var base: Dictionary = ItemDefs.BASES.get(String(it.get("base", "")), {})
    return String(base.get("kind", "")) == _filter and not ItemDefs.is_junk(it)


func _stash_cell(it: Dictionary, h: HeroData) -> Control:
    var slots := ItemDefs.slots_for(String(it["base"]))
    var slot := String(slots[0]) if not slots.is_empty() else ""
    var cell := ItemIcons.slot_control(slot, it)
    var vs: Dictionary = h.equipment.get(slot, {}) if h != null and slot != "" else {}
    cell.tooltip_text = ItemIcons.tooltip(it, vs) + ("\n" + tr("Click: equip on %s · Right click: salvage") % h.display_name() if h != null else "")
    cell.mouse_filter = Control.MOUSE_FILTER_STOP
    var uid := int(it["uid"])
    cell.gui_input.connect(func(e):
        if e is InputEventMouseButton and e.pressed:
            if e.button_index == MOUSE_BUTTON_LEFT and _hero() != null:
                var why := Game.equip(_hero(), uid)
                _msg.text = why if why != "" else tr("Equipped on %s.") % _hero().display_name()
            elif e.button_index == MOUSE_BUTTON_RIGHT:
                var got := Game.salvage(uid)
                _msg.text = tr("Salvaged: %s") % SandboxScreen._res_line(got)
            UIKit.sound("click"))
    if not vs.is_empty() or slot == "":
        return cell
    # an upgrade arrow when this would raise the hero's power in that slot (empty slot: always)
    var arrow := Label.new()
    arrow.text = "▲"
    arrow.add_theme_color_override("font_color", UIKit.GOOD)
    arrow.add_theme_font_size_override("font_size", 8)
    arrow.position = Vector2(23, -2)
    arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cell.add_child(arrow)
    return cell


# --- resources, books, forge -------------------------------------------------------------------

func _side() -> Control:
    var pv := _panel("", 150)
    var v: VBoxContainer = pv[1]
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    (pv[0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 1)
    for t in [["res", "Resources"], ["books", "Books"], ["forge", "Forge"]]:
        var id: String = t[0]
        var b := UIKit.button(tr(String(t[1])), func():
            _tab = id
            refresh(), Vector2(60, 26))
        b.disabled = _tab == id
        b.add_theme_font_size_override("font_size", UIKit.fpx(12))
        tabs.add_child(b)
    v.add_child(tabs)
    var inner := _scroll(v)
    match _tab:
        "res":
            _resources(inner)
        "books":
            _books_and_hoards(inner)
        _:
            _forge(inner)
    return pv[0]


static func res_icon(res: String) -> Texture2D:
    var ref = RES_ICON.get(res, null)
    if ref is int:
        var p := RPG % int(ref)
        return load(p) if ResourceLoader.exists(p) else null
    if ref is String and String(ref).begins_with("item:"):
        return ItemIcons.texture(String(ref).trim_prefix("item:"))
    if ref is String and ResourceLoader.exists(String(ref)):
        return load(String(ref))
    return null


func _resources(v: VBoxContainer) -> void:
    var cats := {"basic": "Gathered", "processed": "Processed", "consumable": "Supplies", "drop": "Creature drops",
        "rare": "Rare", "tower": "Tower materials", "key": "Keys"}
    for cat in cats:
        var ids: Array = []
        for res in EconomyDefs.RESOURCES:
            if String(EconomyDefs.RESOURCES[res]["cat"]) == cat:
                ids.append(res)
        if ids.is_empty():
            continue
        v.add_child(UIKit.label(String(cats[cat]), 14, ArtPalette.GOLD[3]))
        var grid := GridContainer.new()
        grid.columns = 3
        grid.add_theme_constant_override("h_separation", 2)
        grid.add_theme_constant_override("v_separation", 2)
        v.add_child(grid)
        for res in ids:
            var n := int(Game.hq_outputs.get(res, 0))
            var cell := Panel.new()
            cell.custom_minimum_size = Vector2(36, 36)
            cell.add_theme_stylebox_override("panel", UIKit.box(Color(0.07, 0.05, 0.05, 0.8), Color(0.35, 0.26, 0.17), 1, 0, 0))
            cell.tooltip_text = "%s: %d" % [tr(String(EconomyDefs.RESOURCES[res]["name"])), n]
            var ic := TextureRect.new()
            ic.texture = res_icon(String(res))
            ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            ic.position = Vector2(2, 2)
            ic.size = Vector2(32, 32)
            ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
            if n <= 0:
                ic.modulate = Color(0.35, 0.35, 0.35, 0.8)
            cell.add_child(ic)
            var num := UIKit.label(str(n), 12, UIKit.TEXT if n > 0 else UIKit.MUTED)
            num.add_theme_constant_override("outline_size", 2)
            num.add_theme_color_override("font_outline_color", Color(0, 0, 0))
            num.position = Vector2(2, 22)
            num.mouse_filter = Control.MOUSE_FILTER_IGNORE
            cell.add_child(num)
            grid.add_child(cell)
    v.add_child(UIKit.label(tr("Storage cap %d each") % Game.storage_cap(), 12, UIKit.MUTED))


## Pista D: books from the tower (D-129) and heroes caught keeping loot (D-125).
func _books_and_hoards(v: VBoxContainer) -> void:
    var h := _hero()
    var any := false
    for b in LootDefs.BOOKS:
        var n := int(Game.hq_outputs.get(b, 0))
        if n <= 0:
            continue
        any = true
        var row := HBoxContainer.new()
        var ic := TextureRect.new()
        ic.texture = ItemIcons.texture(String(b))
        row.add_child(ic)
        row.add_child(UIKit.label("%s ×%d" % [String(EconomyDefs.RESOURCES[b]["name"]), n], 12, UIKit.TEXT))
        v.add_child(row)
        var book := String(b)
        if book == "book_trade":
            for prof in (h.professions.keys() if h != null else []):
                var p := String(prof)
                v.add_child(UIKit.button(tr("+1 %s") % String(ProfessionDefs.info(p).get("name", p)), func(): _use_book(book, p), Vector2(190, 24)))
        else:
            v.add_child(UIKit.button(tr("Use") + (" · %s" % h.display_name() if h != null and book != "book_plan" else ""), func(): _use_book(book, ""), Vector2(190, 24)))
    if not any:
        var l := UIKit.label("Rare drops in the tower: experience, skill tomes, trade manuals, master plans.", 12, UIKit.MUTED)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(150, 0)
        v.add_child(l)
    var caught := Game.hoard_suspects()
    if not caught.is_empty():
        v.add_child(UIKit.label("Kept loot back", 16, UIKit.BAD))
        for x in caught:
            var hx: HeroData = x
            v.add_child(UIKit.label("%s: %d item(s)" % [hx.display_name(), hx.hoard.size()], 12, UIKit.TEXT))
            v.add_child(UIKit.button(tr("Confiscate"), func(): _msg.text = tr("%d item(s) back in the stash.") % Game.confiscate_hoard(hx), Vector2(190, 24)))
        var tip := UIKit.label("Or punish them: synthesis in the Summoner's Hall.", 11, UIKit.MUTED)
        tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        tip.custom_minimum_size = Vector2(150, 0)
        v.add_child(tip)


func _use_book(book: String, prof: String) -> void:
    var why := Game.use_book(book, _hero(), prof)
    _msg.text = why if why != "" else tr("Used: %s") % String(EconomyDefs.RESOURCES[book]["name"])
    UIKit.sound("click")


func _forge(v: VBoxContainer) -> void:
    for rid in EconomyDefs.RECIPES:
        var r: Dictionary = EconomyDefs.recipe(rid)
        if not (String(r["building"]) in ["blacksmith", "alchemy"]):
            continue
        var built := Game.building_level(String(r["building"])) > 0
        var who := Game.heroes.values().filter(func(x): return (x as HeroData).prof_level(String(r["prof"])) >= int(r["min"]))
        v.add_child(UIKit.label(String(r["name"]), 14, ArtPalette.GOLD[3] if built else UIKit.MUTED))
        var ins := HFlowContainer.new()
        for k in r["in"]:
            var have := int(Game.hq_outputs.get(k, 0))
            var chip := HBoxContainer.new()
            chip.add_theme_constant_override("separation", 1)
            chip.tooltip_text = String(EconomyDefs.RESOURCES.get(k, {}).get("name", k))
            var ic := TextureRect.new()
            ic.texture = res_icon(String(k))
            ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            ic.custom_minimum_size = Vector2(16, 16)
            chip.add_child(ic)
            chip.add_child(UIKit.label("%d/%d" % [have, int(r["in"][k])], 12, UIKit.GOOD if have >= int(r["in"][k]) else UIKit.BAD))
            ins.add_child(chip)
        v.add_child(ins)
        var need := "%s %d" % [String(ProfessionDefs.info(String(r["prof"])).get("name", r["prof"])), int(r["min"])]
        var st := UIKit.label(("%s · %d" % [need, who.size()]) if built else tr("Build the %s first") % String(TownTables.info(String(r["building"]))["name"]), 12,
            UIKit.GOOD if built and not who.is_empty() else UIKit.BAD)
        st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        st.custom_minimum_size = Vector2(150, 0)
        v.add_child(st)
