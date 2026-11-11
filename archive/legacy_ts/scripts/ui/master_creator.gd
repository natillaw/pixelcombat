class_name MasterCreator
extends Control
## D-080: "Create your character". Big animated preview on the left (turn it with < >), four tabs on the
## right (identity, looks, class, trait), Random and Confirm below. Only LPC options that exist in the
## imported sheets; clothes are the plain starter outfit of every summon. Confirm -> Game.create_master.
## D-081: edit mode (the barber / mirror in the Summoner's Hall) shows only the Looks tab, without the race
## row; Confirm -> Game.restyle_master. Hardcore is a checkbox of a new game only.

signal finished

const TAB_NAMES := ["Identity", "Looks", "Class", "Trait"]
const PREVIEW_SCALE := 3.0
## Look rows: [look key, row title, option list]. "" in a list = none.
const LOOK_ROWS := [
    ["race", "Race", MasterDefs.RACES],
    ["body", "Body", MasterDefs.BODIES],
    ["skin", "Skin tone", LpcWardrobe.SKINS],
    ["eyes", "Eyes", LpcWardrobe.EYES],
    ["hair", "Hairstyle", ["", "hair_buzzcut", "hair_bob", "hair_long", "hair_bedhead", "hair_messy1", "hair_parted", "hair_pixie", "hair_plain"]],
    ["hair_color", "Hair colour", LpcWardrobe.HAIR_COLORS],
    ["beard", "Facial hair", MasterDefs.BEARDS],
]
## Option names shown in the rows (English keys; Spanish in StringsEs).
const OPTION_NAMES := {
    "human": "Human", "elf": "Elf", "male": "Male", "female": "Female",
    "light": "Light", "amber": "Amber", "olive": "Olive", "taupe": "Taupe", "bronze": "Bronze", "brown": "Brown", "black": "Black",
    "blue": "Blue", "green": "Green", "gray": "Grey",
    "": "None", "hair_buzzcut": "Buzzcut", "hair_bob": "Bob", "hair_long": "Long", "hair_bedhead": "Bedhead", "hair_messy1": "Messy",
    "hair_parted": "Parted", "hair_pixie": "Pixie", "hair_plain": "Plain",
    "dark_brown": "Dark brown", "chestnut": "Chestnut", "light_brown": "Light brown", "blonde": "Blonde", "ginger": "Ginger",
    "white": "White", "red": "Red", "beard_trimmed": "Trimmed beard",
}

var choices := {"first": "", "last": "", "class": "class.warrior", "trait": "trait.brave", "look": {}}
var hero_seed: int = 0
var _dir: int = 2                                  # LpcComposer.DIRS index: down
var _frame: int = 0
var _frame_t: float = 0.0
var _sheets := {}                                  # layers key -> composed idle sheet (Image -> ImageTexture)
var _preview: TextureRect
var _tabs: TabContainer
var _rows := {}                                    # look key -> value Label
var _first: LineEdit
var _last: LineEdit
var _error: Label
var _class_info: Label
var _class_btns := {}                              # class id -> Button
var _trait_box: VBoxContainer
var edit_mode: bool = false                        # D-081: the mirror (looks only)


func _init(p_edit: bool = false) -> void:
    edit_mode = p_edit and Game.master() != null
    hero_seed = Game.rng.randi()
    if edit_mode:
        var m := Game.master()
        hero_seed = m.hero_seed
        choices["look"] = m.look.duplicate()
        choices["class"] = m.hero_class
        choices["trait"] = String(m.traits[0]) if not m.traits.is_empty() else "trait.brave"
        return
    var r := RandomNumberGenerator.new()
    r.seed = hero_seed
    choices["look"] = LpcWardrobe.random_look(r, "human")


func _ready() -> void:
    var margin := UIKit.margin(16)
    add_child(margin)
    UIKit.fill(margin)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 4)  # px
    margin.add_child(root)
    root.add_child(UIKit.label("The mirror: change your looks" if edit_mode else "Create your character", 16, UIKit.ACCENT))

    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 8)  # px
    root.add_child(body)

    var left := PanelContainer.new()
    left.custom_minimum_size = Vector2(200, 0)  # px
    body.add_child(left)
    var lv := VBoxContainer.new()
    lv.alignment = BoxContainer.ALIGNMENT_CENTER
    left.add_child(lv)
    _preview = TextureRect.new()
    _preview.custom_minimum_size = Vector2(LpcComposer.FRAME, LpcComposer.FRAME) * PREVIEW_SCALE
    _preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    lv.add_child(_preview)
    var turn := HBoxContainer.new()
    turn.alignment = BoxContainer.ALIGNMENT_CENTER
    turn.add_child(UIKit.button("<", func(): _turn(1), Vector2(36, 22)))
    turn.add_child(UIKit.button(">", func(): _turn(-1), Vector2(36, 22)))
    lv.add_child(turn)

    _tabs = TabContainer.new()
    _tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(_tabs)
    if edit_mode:
        _tabs.add_child(_looks_tab())
        _tabs.set_tab_title(0, tr(TAB_NAMES[1]))
    else:
        _tabs.add_child(_identity_tab())
        _tabs.add_child(_looks_tab())
        _tabs.add_child(_class_tab())
        _tabs.add_child(_trait_tab())
        for i in TAB_NAMES.size():
            _tabs.set_tab_title(i, tr(TAB_NAMES[i]))

    var foot := HBoxContainer.new()
    foot.add_theme_constant_override("separation", 8)  # px
    root.add_child(foot)
    _error = UIKit.label("", 13, UIKit.BAD)
    _error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    foot.add_child(_error)
    if edit_mode:
        foot.add_child(UIKit.button("Cancel", func(): finished.emit(), Vector2(110, 26)))
    foot.add_child(UIKit.button("Random", randomize_all, Vector2(110, 26)))
    foot.add_child(UIKit.button("Confirm", confirm, Vector2(110, 26)))
    _refresh()


func _process(delta: float) -> void:
    _frame_t += delta
    if _frame_t >= 1.0 / float(LpcComposer.FPS["idle"]):
        _frame_t = 0.0
        _frame += 1
        _show_frame()


# --- tabs ----------------------------------------------------------------------------------------

func _identity_tab() -> Control:
    var v := VBoxContainer.new()
    v.name = "Identity"
    _first = _name_edit(v, "Name")
    _last = _name_edit(v, "Surname")
    v.add_child(UIKit.label("Background", 13, UIKit.MUTED))
    v.add_child(UIKit.label(MasterDefs.BACKGROUND_TITLE, 16, UIKit.ACCENT))
    var lore := UIKit.label(MasterDefs.BACKGROUND_TEXT, 13, UIKit.TEXT)
    lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(lore)
    if not Game.onboarded:                           # D-081: only when the game is created
        var hc := CheckBox.new()
        hc.text = "Hardcore: if your Master dies, the game ends"
        hc.toggled.connect(func(on): choices["hardcore"] = on)
        v.add_child(hc)
    return v


func _name_edit(parent: Control, title: String) -> LineEdit:
    var row := HBoxContainer.new()
    var l := UIKit.label(title, 13, UIKit.MUTED)
    l.custom_minimum_size = Vector2(70, 0)  # px
    row.add_child(l)
    var e := LineEdit.new()
    e.max_length = MasterDefs.NAME_MAX
    e.custom_minimum_size = Vector2(160, 0)  # px
    e.text_changed.connect(func(_t): _sync_names())
    row.add_child(e)
    parent.add_child(row)
    return e


func _looks_tab() -> Control:
    var v := VBoxContainer.new()
    v.name = "Looks"
    for row in LOOK_ROWS:
        var key := String(row[0])
        if edit_mode and key == "race":
            continue                                 # D-081: the mirror never changes the race
        var h := HBoxContainer.new()
        var l := UIKit.label(String(row[1]), 13, UIKit.MUTED)
        l.custom_minimum_size = Vector2(90, 0)  # px
        h.add_child(l)
        h.add_child(UIKit.button("<", func(): step_look(key, -1), Vector2(24, 18)))
        var val := UIKit.label("", 13, UIKit.TEXT)
        val.custom_minimum_size = Vector2(110, 0)  # px
        val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        h.add_child(val)
        h.add_child(UIKit.button(">", func(): step_look(key, 1), Vector2(24, 18)))
        _rows[key] = val
        v.add_child(h)
    var note := UIKit.label("Clothes: the plain outfit of every newcomer. Gear changes it later.", 13, UIKit.MUTED)
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(note)
    return v


func _class_tab() -> Control:
    var v := VBoxContainer.new()
    v.name = "Class"
    var grid := GridContainer.new()
    grid.columns = 3
    for cid in MasterDefs.CLASSES:
        var c := String(cid)
        var b := UIKit.button("%s (%s)" % [tr(String(HeroTables.CLASSES[c]["name"])), tr(String(MasterDefs.CLASSES[c]["role"]))],
            func(): choose_class(c), Vector2(120, 22))
        _class_btns[c] = b
        grid.add_child(b)
    v.add_child(grid)
    _class_info = UIKit.label("", 13, UIKit.TEXT)
    _class_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _class_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(_class_info)
    return v


func _trait_tab() -> Control:
    var scroll := ScrollContainer.new()
    scroll.name = "Trait"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _trait_box = VBoxContainer.new()
    _trait_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_trait_box)
    return scroll


# --- choices -------------------------------------------------------------------------------------

func step_look(key: String, d: int) -> void:
    var opts: Array = _options(key)
    var look: Dictionary = choices["look"]
    var i := opts.find(look.get(key, opts[0]))
    look[key] = opts[posmod(i + d, opts.size())]
    choices["look"] = HeroGenerator.master_look(look)
    _refresh()


func _options(key: String) -> Array:
    for row in LOOK_ROWS:
        if row[0] == key:
            if key == "beard" and String(choices["look"].get("body", "male")) != "male":
                return [""]                       # beards only on male bodies, like the summoned
            return row[2]
    return [""]


func choose_class(cid: String) -> void:
    if MasterDefs.CLASSES.has(cid):
        choices["class"] = cid
        _refresh()


func choose_trait(tid: String) -> void:
    if HeroTables.TRAITS.has(tid):
        choices["trait"] = tid
        _refresh()


func randomize_all() -> void:
    var r := RandomNumberGenerator.new()
    r.seed = Game.rng.randi()
    var look: Dictionary = choices["look"]
    for row in LOOK_ROWS:
        if edit_mode and row[0] == "race":
            continue
        var opts: Array = _options(String(row[0]))
        look[row[0]] = opts[r.randi() % opts.size()]
    choices["look"] = HeroGenerator.master_look(look)
    if edit_mode:
        _refresh()
        return
    var cls: Array = MasterDefs.CLASSES.keys()
    choices["class"] = String(cls[r.randi() % cls.size()])
    var tr_ids: Array = HeroTables.TRAITS.keys()
    choices["trait"] = String(tr_ids[r.randi() % tr_ids.size()])
    _first.text = String(HeroTables.NAME_START[r.randi() % HeroTables.NAME_START.size()]) + String(HeroTables.NAME_END[r.randi() % HeroTables.NAME_END.size()])
    _last.text = String(HeroTables.FAMILY_NAMES[r.randi() % HeroTables.FAMILY_NAMES.size()])
    _sync_names()
    _refresh()


func _sync_names() -> void:
    choices["first"] = _first.text.strip_edges()
    choices["last"] = _last.text.strip_edges()
    _error.text = ""


## "" when the choices make a valid Master, else what is missing.
func block() -> String:
    if String(choices["first"]) == "" or String(choices["last"]) == "":
        return "Write a name and a surname."
    return ""


func confirm() -> void:
    if edit_mode:
        var why_not := Game.restyle_master(choices["look"])
        if why_not != "":
            _error.text = tr(why_not)
            return
        finished.emit()
        return
    _sync_names()
    var why := block()
    if why != "":
        _error.text = tr(why)
        _tabs.current_tab = 0
        return
    var c := choices.duplicate(true)
    c["seed"] = hero_seed
    Game.create_master(c)
    finished.emit()


# --- display -------------------------------------------------------------------------------------

func _refresh() -> void:
    var look: Dictionary = choices["look"]
    for key in _rows:
        (_rows[key] as Label).text = tr(String(OPTION_NAMES.get(String(look.get(key, "")), look.get(key, ""))))
    _show_frame()
    if _class_info == null:
        return                                       # edit mode: looks only
    var cid := String(choices["class"])
    for c in _class_btns:
        var cb: Button = _class_btns[c]
        cb.text = ("> " if c == cid else "") + cb.text.trim_prefix("> ")
        cb.add_theme_color_override("font_color", UIKit.ACCENT if c == cid else UIKit.TEXT)
    _class_info.text = "%s  -  %s\n%s\n%s\n\n%s" % [tr(String(HeroTables.CLASSES[cid]["name"])), tr(String(MasterDefs.CLASSES[cid]["role"])),
        tr(String(MasterDefs.CLASSES[cid]["text"])), tr(String(HeroTables.CLASSES[cid]["desc"])),
        tr("Skills: Q is the basic attack; choose W, E and R at levels 2, 5 and 10.")]   # D-142
    for c in _trait_box.get_children():
        c.queue_free()
    for tid in HeroTables.TRAITS:
        var t := String(tid)
        var pros := trait_pros(t)
        var cons := trait_cons(t)
        var b := UIKit.button("%s%s\n  + %s\n  - %s" % ["> " if t == choices["trait"] else "", tr(String(HeroTables.TRAITS[t]["name"])),
            ", ".join(pros), ", ".join(cons)], func(): choose_trait(t), Vector2(0, 40))
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if t == choices["trait"]:
            b.add_theme_color_override("font_color", UIKit.ACCENT)
        _trait_box.add_child(b)
    _show_frame()


## What a trait gives (stat bonuses, more Trust, its passive) and what it costs (stat penalties, less
## Trust). D-080: every trait has both (tests/test_master.gd).
static func trait_pros(tid: String) -> Array:
    var d: Dictionary = HeroTables.TRAITS[tid]
    var out: Array = []
    for k in d.get("mods", {}):
        if float(d["mods"][k]) > 1.0:
            out.append("+%d%% %s" % [roundi((float(d["mods"][k]) - 1.0) * 100.0), TranslationServer.translate(HeroTables.STAT_NAMES[k])])
    if int(d.get("loyalty", 0)) > 0:
        out.append(TranslationServer.translate("more Trust"))
    var p := String(d.get("passive", ""))
    if HeroTables.PASSIVES.has(p):
        out.append("%s (%s)" % [TranslationServer.translate(String(HeroTables.PASSIVES[p]["name"])), TranslationServer.translate(String(HeroTables.PASSIVES[p]["desc"]))])
    return out


static func trait_cons(tid: String) -> Array:
    var d: Dictionary = HeroTables.TRAITS[tid]
    var out: Array = []
    for k in d.get("mods", {}):
        if float(d["mods"][k]) < 1.0:
            out.append("-%d%% %s" % [roundi((1.0 - float(d["mods"][k])) * 100.0), TranslationServer.translate(HeroTables.STAT_NAMES[k])])
    if int(d.get("loyalty", 0)) < 0:
        out.append(TranslationServer.translate("less Trust"))
    return out


var _sheet_tex: Dictionary = {}                  # "<key>/<dir>/<frame>" -> Texture2D


func _turn(d: int) -> void:
    _dir = posmod(_dir + d, LpcComposer.DIRS.size())
    _show_frame()


## The idle sheet of the current look, composed once per look and kept (no stutter when going back).
func _show_frame() -> void:
    if _preview == null or not LpcComposer.available():
        return
    var layers := LpcComposer.visual_layers(choices["look"], String(choices["class"]))
    var key := str(layers.map(func(l): return str(l["piece"]) + ":" + str((l["anims"] as Dictionary).get("idle", l["anims"].get("walk", "")))).hash())
    if not _sheets.has(key):
        _sheets[key] = LpcComposer.compose_anim(layers, "idle")
    var img: Image = _sheets[key]
    if img == null:
        return
    var cols := maxi(1, img.get_width() / LpcComposer.FRAME)
    var rows := img.get_height() / LpcComposer.FRAME
    var row := _dir if rows > _dir else 0
    var col := _frame % cols
    var tk := "%s/%d/%d" % [key, row, col]
    if not _sheet_tex.has(tk):
        _sheet_tex[tk] = ImageTexture.create_from_image(img.get_region(Rect2i(col * LpcComposer.FRAME, row * LpcComposer.FRAME, LpcComposer.FRAME, LpcComposer.FRAME)))
    _preview.texture = _sheet_tex[tk]
