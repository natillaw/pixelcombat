extends Control
## D-130 Sim Lab: a window over the D-083 simulator. It only builds the config JSON, runs run_sim.gd as a
## separate Godot process (OS.execute_with_pipe) and reads its results.json; it never plays a run itself.
## Every list comes from the game's data (HeroTables, MasterDefs, SkillDefs, ItemDefs, TowerExpedition) and
## from tools/sim/configs (gear_presets, progress_profiles, archetypes). Open it from the main menu
## (Debug: "Sim Lab") or: godot --path . res://tools/sim/sim_lab.tscn

const SimConfig := preload("res://tools/sim/sim_config.gd")
const SimParty := preload("res://tools/sim/sim_party.gd")
const CONFIG_DIR := "res://tools/sim/configs"
const ARCHETYPES_PATH := "res://tools/sim/configs/archetypes.json"
const REPORTS_DIR := "res://docs/reports/sim"
const DATA_SCRIPTS := ["res://scripts/data", "res://scripts/sandbox", "res://scripts/core", "res://scripts/combat"]
const NOT_CONFIGS := ["gear_presets.json", "progress_profiles.json", "archetypes.json"]
const SLOTS := 5
const COL_RED := Color(0.95, 0.35, 0.3)
const COL_GREEN := Color(0.4, 0.9, 0.45)
const COL_GREY := Color(0.6, 0.6, 0.6)

var presets: Dictionary = {}
var profiles: Dictionary = {}
var archetypes: Dictionary = {}
var constants: Array = []                 # "Class.CONST" with a numeric value (overrides autocomplete)
var rng := RandomNumberGenerator.new()

var name_edit: LineEdit
var config_pick: OptionButton
var floor_checks: Array = []
var floor_range: LineEdit
var bot_pick: OptionButton
var adv_box: GridContainer
var adv: Dictionary = {}                  # bot key -> control
var rows: Array = []                      # party rows (Dictionary of controls + data)
var archetype_pick: OptionButton
var progress_pick: OptionButton
var gear_style_pick: OptionButton
var enemy_sliders: Dictionary = {}
var overrides_box: VBoxContainer
var sweep_on: CheckBox
var sweep_param: LineEdit
var sweep_from: SpinBox
var sweep_to: SpinBox
var sweep_step: SpinBox
var runs_spin: SpinBox
var seed_spin: SpinBox
var workers_spin: SpinBox
var max_time_spin: SpinBox
var suggest: PopupMenu
var suggest_target: LineEdit
var items_popup: PopupPanel
var items_row: int = -1

var progress_bar: ProgressBar
var status_label: Label
var errors_label: Label
var cancel_btn: Button
var results_tree: Tree
var versus_tree: Tree
var heroes_tree: Tree
var history_list: ItemList
var compare_tree: Tree

var _pid := -1
var _threads: Array = []
var _lines: Array = []
var _mutex := Mutex.new()
var _out_dir := ""
var _cancel_file := ""
var _err_lines: Array = []
var _cancel_at := 0
var history: Array = []                  # [{"label", "dir", "summary"}]


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    rng.seed = 1301
    presets = SimParty.load_presets()
    profiles = SimParty.load_progress()
    archetypes = SimConfig.load_file(ARCHETYPES_PATH).get("data", {})
    constants = _collect_constants()
    var bg := ColorRect.new()
    bg.color = Color(0.08, 0.09, 0.11)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var split := HSplitContainer.new()
    split.set_anchors_preset(Control.PRESET_FULL_RECT)
    split.split_offset = 140
    add_child(split)
    var left := ScrollContainer.new()
    left.custom_minimum_size = Vector2(620, 0)
    left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    split.add_child(left)
    var lv := VBoxContainer.new()
    lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_child(lv)
    _build_config(lv)
    var rv := VBoxContainer.new()
    rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    split.add_child(rv)
    _build_results(rv)
    suggest = PopupMenu.new()
    suggest.id_pressed.connect(func(id: int):
        if suggest_target != null:
            suggest_target.text = suggest.get_item_text(suggest.get_item_index(id)))
    add_child(suggest)
    _build_items_popup()
    _refresh_configs()
    _refresh_history()


# ---------------------------------------------------------------- configuration panel

func _build_config(lv: VBoxContainer) -> void:
    var top := HBoxContainer.new()
    top.add_child(_btn("< Back", func(): get_tree().change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))))
    name_edit = LineEdit.new()
    name_edit.text = "sim_lab"
    name_edit.custom_minimum_size.x = 140
    top.add_child(name_edit)
    config_pick = OptionButton.new()
    config_pick.custom_minimum_size.x = 160
    top.add_child(config_pick)
    top.add_child(_btn("Load", func(): _load_config(config_pick.get_item_text(config_pick.selected))))
    top.add_child(_btn("Save", func(): _save_config(name_edit.text)))
    top.add_child(_btn("Duplicate", func():
        name_edit.text += "_copy"
        _save_config(name_edit.text)))
    lv.add_child(top)

    lv.add_child(_title("Floors"))
    var fg := GridContainer.new()
    fg.columns = 10
    var keys: Array = TowerExpedition.FLOORS.keys()
    keys.sort()
    for f in keys:
        var c := CheckBox.new()
        c.text = str(f)
        c.tooltip_text = "%s (%s)" % [TowerExpedition.FLOORS[f]["name"], TowerExpedition.FLOORS[f]["mission"]]
        c.set_meta("floor", int(f))
        c.button_pressed = int(f) == 1
        floor_checks.append(c)
        fg.add_child(c)
    lv.add_child(fg)
    var fr := HBoxContainer.new()
    fr.add_child(_lbl("Range:"))
    floor_range = LineEdit.new()
    floor_range.placeholder_text = "1-10"
    floor_range.custom_minimum_size.x = 80
    fr.add_child(floor_range)
    fr.add_child(_btn("Apply", func(): _set_floors(SimConfig.floors_of(floor_range.text.split(",")))))
    fr.add_child(_btn("All", func(): _set_floors(keys)))
    fr.add_child(_btn("None", func(): _set_floors([])))
    lv.add_child(fr)

    lv.add_child(_title("Master's bot"))
    var bh := HBoxContainer.new()
    bot_pick = OptionButton.new()
    for t in ["Tactical", "Loco", "Both (compare)"]:
        bot_pick.add_item(t)
    bh.add_child(bot_pick)
    var adv_toggle := CheckButton.new()
    adv_toggle.text = "Advanced"
    bh.add_child(adv_toggle)
    lv.add_child(bh)
    adv_box = GridContainer.new()
    adv_box.columns = 4
    adv_box.visible = false
    adv_toggle.toggled.connect(func(on: bool): adv_box.visible = on)
    var bot_def: Dictionary = SimConfig.DEFAULTS["bot"]
    for k in ["retreat_hp", "retreat_standing", "ping_every", "aim_error_mult", "use_commands", "use_skills", "revive", "gather", "knows_map"]:
        adv_box.add_child(_lbl(k))
        var v: Variant = bot_def[k]
        if v is bool:
            var cb := CheckBox.new()
            cb.button_pressed = v
            adv[k] = cb
            adv_box.add_child(cb)
        else:
            var sp := _spin(-1.0, 10.0, 0.05 if v is float else 1.0, float(v))
            adv[k] = sp
            adv_box.add_child(sp)
    lv.add_child(adv_box)

    lv.add_child(_title("Party (row 1 = Master)"))
    var ph := HBoxContainer.new()
    archetype_pick = OptionButton.new()
    for k in archetypes:
        if not String(k).begins_with("_"):
            archetype_pick.add_item(String(archetypes[k].get("label", k)))
            archetype_pick.set_item_metadata(archetype_pick.item_count - 1, String(k))
    ph.add_child(archetype_pick)
    ph.add_child(_btn("Use archetype", func(): _apply_archetype(String(archetype_pick.get_item_metadata(archetype_pick.selected)))))
    ph.add_child(_btn("Random party", func():
        for i in SLOTS:
            _random_row(i)))
    lv.add_child(ph)
    for i in SLOTS:
        lv.add_child(_build_row(i))
    var d: Array = SimConfig.DEFAULTS["party"]
    for i in d.size():
        _fill_row(i, d[i])

    lv.add_child(_title("Progress"))
    var pr := HBoxContainer.new()
    progress_pick = OptionButton.new()
    progress_pick.add_item("none")
    for k in profiles:
        if not String(k).begins_with("_"):
            progress_pick.add_item(String(k))
    pr.add_child(progress_pick)
    pr.add_child(_lbl("gear_style"))
    gear_style_pick = OptionButton.new()
    for g in ["mix", "def", "atk"]:
        gear_style_pick.add_item(g)
    pr.add_child(gear_style_pick)
    lv.add_child(pr)

    lv.add_child(_title("Enemies"))
    for k in SimConfig.ENEMY_KEYS:
        var eh := HBoxContainer.new()
        eh.add_child(_lbl({"hp": "Health", "damage": "Damage", "count": "Count"}[k]))
        var sl := HSlider.new()
        sl.min_value = 0.25
        sl.max_value = 3.0
        sl.step = 0.05
        sl.value = 1.0
        sl.custom_minimum_size.x = 260
        var vl := _lbl("x1.00")
        sl.value_changed.connect(func(v: float): vl.text = "x%.2f" % v)
        enemy_sliders[k] = sl
        eh.add_child(sl)
        eh.add_child(vl)
        lv.add_child(eh)

    lv.add_child(_title("Overrides"))
    overrides_box = VBoxContainer.new()
    lv.add_child(overrides_box)
    lv.add_child(_btn("+ Override", func(): _add_override("", "")))

    lv.add_child(_title("Sweep"))
    var sw := HBoxContainer.new()
    sweep_on = CheckBox.new()
    sweep_on.text = "On"
    sw.add_child(sweep_on)
    sweep_param = _const_edit("Class.CONSTANT or bot.retreat_hp")
    sweep_param.custom_minimum_size.x = 200
    sw.add_child(sweep_param)
    sweep_from = _spin(-1000, 1000, 0.01, 0.0)
    sweep_to = _spin(-1000, 1000, 0.01, 1.0)
    sweep_step = _spin(0.0, 1000, 0.01, 0.25)
    for p in [["from", sweep_from], ["to", sweep_to], ["step", sweep_step]]:
        sw.add_child(_lbl(p[0]))
        sw.add_child(p[1])
    lv.add_child(sw)

    lv.add_child(_title("Run"))
    var rg := GridContainer.new()
    rg.columns = 4
    runs_spin = _spin(1, 500, 1, 10)
    seed_spin = _spin(0, 999999, 1, 1000)
    workers_spin = _spin(1, 16, 1, clampi(OS.get_processor_count() - 1, 1, 8))
    max_time_spin = _spin(30, 7200, 30, 1200)
    for p in [["runs", runs_spin], ["seed", seed_spin], ["workers", workers_spin], ["max_time", max_time_spin]]:
        rg.add_child(_lbl(p[0]))
        rg.add_child(p[1])
    lv.add_child(rg)
    var rb := HBoxContainer.new()
    rb.add_child(_btn("Quick (5 runs)", func(): start(5)))
    rb.add_child(_btn("Full", func(): start(int(runs_spin.value))))
    lv.add_child(rb)


func _build_row(i: int) -> Control:
    var r := {}
    var h := HBoxContainer.new()
    var on := CheckBox.new()
    on.button_pressed = true
    on.disabled = i == 0                    # the Master is always there
    on.tooltip_text = "Master" if i == 0 else "On / off"
    h.add_child(on)
    var cls := OptionButton.new()
    for c in (MasterDefs.CLASSES if i == 0 else HeroTables.CLASSES):
        if String(c) != "class.none":
            cls.add_item(String(c).trim_prefix("class."))
    h.add_child(cls)
    var lvl := _spin(1, 70, 1, 1)
    lvl.tooltip_text = "Level"
    h.add_child(lvl)
    var rar := OptionButton.new()
    for k in SimConfig.RARITY_STARS:
        if ItemDefs.RARITY_ORDER.has(String(k)):
            rar.add_item(String(k))
    h.add_child(rar)
    var traits := MenuButton.new()
    traits.text = "Traits (0)"
    for t in HeroTables.TRAITS:
        traits.get_popup().add_check_item(String(t).trim_prefix("trait."))
    traits.get_popup().hide_on_checkable_item_selection = false
    traits.get_popup().index_pressed.connect(func(idx: int): _toggle_check(traits, idx, "Traits"))
    h.add_child(traits)
    var skills := MenuButton.new()
    skills.text = "Skills (0)"
    skills.get_popup().hide_on_checkable_item_selection = false
    skills.get_popup().index_pressed.connect(func(idx: int): _toggle_check(skills, idx, "Skills"))
    h.add_child(skills)
    var gear := OptionButton.new()
    for k in presets:
        if not String(k).begins_with("_"):
            gear.add_item(String(k))
    gear.add_item("items")
    h.add_child(gear)
    var items_btn := _btn("Items", func(): _open_items(i))
    h.add_child(items_btn)
    h.add_child(_btn("Random", func(): _random_row(i)))
    r = {"on": on, "class": cls, "level": lvl, "rarity": rar, "traits": traits, "skills": skills, "gear": gear, "items": []}
    cls.item_selected.connect(func(_x: int): _fill_skills(i, []))
    rows.append(r)
    _fill_skills(i, [])
    return h


func _toggle_check(mb: MenuButton, idx: int, title: String) -> void:
    var p := mb.get_popup()
    p.set_item_checked(idx, not p.is_item_checked(idx))
    mb.text = "%s (%d)" % [title, _checked(mb).size()]


func _checked(mb: MenuButton) -> Array:
    var out: Array = []
    var p := mb.get_popup()
    for k in p.item_count:
        if p.is_item_checked(k):
            out.append(p.get_item_text(k))
    return out


func _set_checked(mb: MenuButton, ids: Array, title: String) -> void:
    var p := mb.get_popup()
    for k in p.item_count:
        p.set_item_checked(k, ids.has(p.get_item_text(k)))
    mb.text = "%s (%d)" % [title, _checked(mb).size()]


func _fill_skills(i: int, keep: Array) -> void:
    var r: Dictionary = rows[i]
    var cid := SimParty.class_id(_opt_text(r["class"]))
    var p: PopupMenu = (r["skills"] as MenuButton).get_popup()
    p.clear()
    for s in SkillDefs.SKILLS:
        if SkillDefs.usable_by(String(s), cid):
            p.add_check_item(String(s))
    _set_checked(r["skills"], keep, "Skills")


func _fill_row(i: int, spec: Dictionary) -> void:
    var r: Dictionary = rows[i]
    (r["on"] as CheckBox).button_pressed = true
    _select(r["class"], SimParty.class_id(String(spec.get("class", "warrior"))).trim_prefix("class."))
    (r["level"] as SpinBox).value = int(spec.get("level", 1))
    var rar := String(spec.get("rarity", ""))
    if rar == "" and spec.has("stars"):
        for k in SimConfig.RARITY_STARS:
            if int(SimConfig.RARITY_STARS[k]) == int(spec["stars"]) and ItemDefs.RARITY_ORDER.has(String(k)):
                rar = String(k)
                break
    _select(r["rarity"], rar if rar != "" else "common")
    _set_checked(r["traits"], (spec.get("traits", []) as Array).map(func(t): return String(t).trim_prefix("trait.")), "Traits")
    _fill_skills(i, spec.get("skills", []))
    var g: Variant = spec.get("gear", "kit_blanco")
    if g is Dictionary:
        _select(r["gear"], "items")
        r["items"] = (g as Dictionary).get("items", []).duplicate(true)
    else:
        _select(r["gear"], String(g))
        r["items"] = []


func _random_row(i: int) -> void:
    var r: Dictionary = rows[i]
    var cls: OptionButton = r["class"]
    cls.select(rng.randi_range(0, cls.item_count - 1))
    (r["level"] as SpinBox).value = rng.randi_range(1, 10)
    var rar: OptionButton = r["rarity"]
    rar.select(rng.randi_range(0, rar.item_count - 1))
    var tp: PopupMenu = (r["traits"] as MenuButton).get_popup()
    var tr_ids: Array = []
    for k in rng.randi_range(0, 2):
        tr_ids.append(tp.get_item_text(rng.randi_range(0, tp.item_count - 1)))
    _set_checked(r["traits"], tr_ids, "Traits")
    _fill_skills(i, [])
    var sp: PopupMenu = (r["skills"] as MenuButton).get_popup()
    var sk: Array = []
    for k in mini(2, sp.item_count):
        sk.append(sp.get_item_text(rng.randi_range(0, sp.item_count - 1)))
    _set_checked(r["skills"], sk, "Skills")
    var g: OptionButton = r["gear"]
    g.select(rng.randi_range(0, g.item_count - 2))      # a preset, not the item list
    if i > 0:
        (r["on"] as CheckBox).button_pressed = true


func _apply_archetype(key: String) -> void:
    var a: Dictionary = archetypes.get(key, {})
    var cl: Array = a.get("classes", [])
    for i in SLOTS:
        var r: Dictionary = rows[i]
        (r["on"] as CheckBox).button_pressed = i < cl.size()
        if i < cl.size():
            _select(r["class"], SimParty.class_id(String(cl[i])).trim_prefix("class."))
            _fill_skills(i, [])


func _build_items_popup() -> void:
    items_popup = PopupPanel.new()
    var v := VBoxContainer.new()
    items_popup.add_child(v)
    var list := ItemList.new()
    list.custom_minimum_size = Vector2(360, 140)
    v.add_child(list)
    var h := HBoxContainer.new()
    var base := OptionButton.new()
    var bases: Array = ItemDefs.BASES.keys()
    bases.sort()
    for b in bases:
        base.add_item(String(b))
    h.add_child(base)
    var rar := OptionButton.new()
    for k in ItemDefs.RARITY_ORDER:
        rar.add_item(String(k))
    h.add_child(rar)
    var ilvl := _spin(1, 70, 1, 1)
    h.add_child(ilvl)
    var refresh := func():
        list.clear()
        if items_row >= 0:
            for it in rows[items_row]["items"]:
                list.add_item("%s  %s  ilvl %d" % [it["base"], it.get("rarity", "common"), int(it.get("ilvl", 1))])
    h.add_child(_btn("Add", func():
        rows[items_row]["items"].append({"base": _opt_text(base), "rarity": _opt_text(rar), "ilvl": int(ilvl.value)})
        _select(rows[items_row]["gear"], "items")
        refresh.call()))
    h.add_child(_btn("Clear", func():
        rows[items_row]["items"].clear()
        refresh.call()))
    v.add_child(h)
    v.add_child(_lbl("With \"items\" the hero gets the white kit plus these items."))
    items_popup.set_meta("refresh", refresh)
    add_child(items_popup)


func _open_items(i: int) -> void:
    items_row = i
    (items_popup.get_meta("refresh") as Callable).call()
    items_popup.popup_centered()


func _add_override(key: String, value: String) -> void:
    var h := HBoxContainer.new()
    var k := _const_edit("Class.CONSTANT")
    k.text = key
    k.custom_minimum_size.x = 300
    var v := LineEdit.new()
    v.text = value
    v.custom_minimum_size.x = 100
    h.add_child(k)
    h.add_child(v)
    h.add_child(_btn("x", func(): h.queue_free()))
    overrides_box.add_child(h)


func _const_edit(hint: String) -> LineEdit:
    var e := LineEdit.new()
    e.placeholder_text = hint
    e.text_changed.connect(func(t: String): _show_suggest(e, t))
    return e


func _show_suggest(e: LineEdit, t: String) -> void:
    suggest.clear()
    if t.length() < 2:
        suggest.hide()
        return
    var low := t.to_lower()
    for c in constants:
        if String(c).to_lower().contains(low):
            suggest.add_item(String(c))
            if suggest.item_count >= 15:
                break
    if suggest.item_count == 0:
        suggest.hide()
        return
    suggest_target = e
    suggest.position = Vector2i(e.get_screen_position() + Vector2(0, e.size.y))
    suggest.popup()
    e.grab_focus.call_deferred()
    e.caret_column = e.text.length()


func _collect_constants() -> Array:
    var out: Array = []
    for c in ProjectSettings.get_global_class_list():
        var path := String(c["path"])
        if not DATA_SCRIPTS.any(func(d): return path.begins_with(d)):
            continue
        var scr := load(path) as Script
        if scr == null:
            continue
        var m := scr.get_script_constant_map()
        for k in m:
            if (m[k] is float or m[k] is int) and not (m[k] is bool):
                out.append("%s.%s" % [c["class"], k])
    out.sort()
    return out


# ---------------------------------------------------------------- config <-> UI

func build_config(runs: int) -> Dictionary:
    var cfg := {"name": name_edit.text.strip_edges().validate_filename(), "floors": selected_floors(), "runs": runs,
        "seed": int(seed_spin.value), "workers": int(workers_spin.value), "max_time": float(max_time_spin.value)}
    var bot := {}
    if adv_box.visible:
        for k in adv:
            bot[k] = (adv[k] as CheckBox).button_pressed if adv[k] is CheckBox else _num(adv[k].value, SimConfig.DEFAULTS["bot"][k])
    match bot_pick.selected:
        0: bot["style"] = "tactico"
        1: bot["style"] = "loco"
        _: cfg["compare"] = [{"label": "tactico", "bot": {"style": "tactico"}}, {"label": "loco", "bot": {"style": "loco"}}]
    if not bot.is_empty():
        cfg["bot"] = bot
    var party: Array = []
    for i in SLOTS:
        var r: Dictionary = rows[i]
        if not (r["on"] as CheckBox).button_pressed:
            continue
        var h := {"class": _opt_text(r["class"]), "level": int((r["level"] as SpinBox).value), "rarity": _opt_text(r["rarity"])}
        if i == 0:
            h["master"] = true
        var t := _checked(r["traits"])
        if not t.is_empty():
            h["traits"] = t
        var s := _checked(r["skills"])
        if not s.is_empty():
            h["skills"] = s
        var g := _opt_text(r["gear"])
        h["gear"] = {"preset": "kit_blanco", "items": (r["items"] as Array).duplicate(true)} if g == "items" else g
        party.append(h)
    cfg["party"] = party
    if progress_pick.selected > 0:
        cfg["progress"] = _opt_text(progress_pick)
        cfg["gear_style"] = _opt_text(gear_style_pick)
    var en := {}
    for k in enemy_sliders:
        en[k] = snappedf((enemy_sliders[k] as HSlider).value, 0.01)
    cfg["enemies"] = en
    var ov := {}
    for h in overrides_box.get_children():
        if h.is_queued_for_deletion():
            continue
        var k := (h.get_child(0) as LineEdit).text.strip_edges()
        if k != "":
            ov[k] = _parse_value((h.get_child(1) as LineEdit).text)
    if not ov.is_empty():
        cfg["overrides"] = ov
    if sweep_on.button_pressed:
        cfg["sweep"] = {"param": sweep_param.text.strip_edges(), "from": sweep_from.value, "to": sweep_to.value, "step": sweep_step.value}
    return cfg


func load_config_data(d: Dictionary) -> void:
    name_edit.text = String(d.get("name", name_edit.text))
    _set_floors(SimConfig.floors_of(d.get("floors", d.get("floor", [1]))))
    var bot: Dictionary = d.get("bot", {})
    var styles: Array = (d.get("compare", []) as Array).map(func(c): return String((c as Dictionary).get("bot", {}).get("style", "")))
    bot_pick.select(2 if styles.has("tactico") and styles.has("loco") else (1 if String(bot.get("style", "tactico")) == "loco" else 0))
    for k in adv:
        var v: Variant = bot.get(k, SimConfig.DEFAULTS["bot"][k])
        if adv[k] is CheckBox:
            (adv[k] as CheckBox).button_pressed = bool(v)
        else:
            (adv[k] as SpinBox).value = float(v)
    adv_box.visible = adv_box.visible or bot.size() > 1
    var party: Array = d.get("party", SimConfig.DEFAULTS["party"])
    for i in SLOTS:
        if i < party.size():
            _fill_row(i, party[i])
        else:
            (rows[i]["on"] as CheckBox).button_pressed = false
    _select(progress_pick, String(d.get("progress", "none")) if String(d.get("progress", "")) != "" else "none")
    _select(gear_style_pick, String(d.get("gear_style", "mix")))
    var en: Dictionary = d.get("enemies", {})
    for k in enemy_sliders:
        (enemy_sliders[k] as HSlider).value = float(en.get(k, 1.0))
    for c in overrides_box.get_children():
        c.queue_free()
    var ov: Dictionary = d.get("overrides", {})
    for k in ov:
        _add_override(String(k), JSON.stringify(ov[k]))
    var sw: Dictionary = d.get("sweep", {})
    sweep_on.button_pressed = not sw.is_empty()
    sweep_param.text = String(sw.get("param", ""))
    sweep_from.value = float(sw.get("from", 0.0))
    sweep_to.value = float(sw.get("to", 1.0))
    sweep_step.value = float(sw.get("step", 0.25))
    runs_spin.value = int(d.get("runs", 10))
    seed_spin.value = int(d.get("seed", 1000))
    max_time_spin.value = float(d.get("max_time", 1200))
    if d.has("workers"):
        workers_spin.value = int(d["workers"])


func _load_config(file: String) -> void:
    var r := SimConfig.load_file(CONFIG_DIR.path_join(file))
    if r.has("error"):
        _show_errors([r["error"]])
        return
    load_config_data(r["data"])
    _show_errors([])
    status_label.text = "Loaded %s" % file


func _save_config(cname: String) -> void:
    cname = cname.strip_edges().validate_filename()
    if cname == "":
        _show_errors(["Write a name first."])
        return
    var path := CONFIG_DIR.path_join(cname + ".json")
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        _show_errors(["Could not write %s" % path])
        return
    f.store_string("// D-130: saved by the Sim Lab\n" + JSON.stringify(build_config(int(runs_spin.value)), "    "))
    f.close()
    status_label.text = "Saved %s" % path
    _refresh_configs()


func _refresh_configs() -> void:
    config_pick.clear()
    for fn in DirAccess.get_files_at(CONFIG_DIR):
        if fn.ends_with(".json") and not NOT_CONFIGS.has(fn):
            config_pick.add_item(fn)


func selected_floors() -> Array:
    var out: Array = []
    for c in floor_checks:
        if (c as CheckBox).button_pressed:
            out.append(int(c.get_meta("floor")))
    return out


func _set_floors(list: Array) -> void:
    var want: Array = list.map(func(x): return int(x))
    for c in floor_checks:
        (c as CheckBox).button_pressed = want.has(int(c.get_meta("floor")))


# ---------------------------------------------------------------- running

func validate(cfg: Dictionary) -> Array:
    var e: Array = []
    if (cfg["floors"] as Array).is_empty():
        e.append("Choose at least one floor.")
    if cfg.has("sweep") and String(cfg["sweep"]["param"]) == "":
        e.append("sweep needs a parameter.")
    if cfg.has("sweep") and float(cfg["sweep"]["step"]) <= 0.0:
        e.append("sweep: \"step\" must be > 0")
    return e


func start(runs: int) -> void:
    if _pid > 0:
        return
    var cfg := build_config(runs)
    var errs := validate(cfg)
    if not errs.is_empty():
        _show_errors(errs)
        return
    _show_errors([])
    var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("T", "_")
    var work := ProjectSettings.globalize_path("user://sim_lab")
    DirAccess.make_dir_recursive_absolute(work)
    var cfg_path := work.path_join("run_%s.json" % stamp)
    var f := FileAccess.open(cfg_path, FileAccess.WRITE)
    f.store_string(JSON.stringify(cfg, "  "))
    f.close()
    _out_dir = ProjectSettings.globalize_path(REPORTS_DIR).path_join("%s_%s" % [stamp, cfg["name"]])
    _cancel_file = work.path_join("cancel_%s" % stamp)
    var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/sim/run_sim.gd", "--",
        "--config", cfg_path, "--out", _out_dir, "--cancel-file", _cancel_file])
    var p := OS.execute_with_pipe(OS.get_executable_path(), args)
    if p.is_empty():
        _show_errors(["Could not start Godot (%s)." % OS.get_executable_path()])
        return
    _pid = int(p["pid"])
    _err_lines.clear()
    _cancel_at = 0
    for pipe in [p["stdio"], p["stderr"]]:
        var t := Thread.new()
        t.start(_read_pipe.bind(pipe, pipe == p["stderr"]))
        _threads.append(t)
    progress_bar.value = 0
    status_label.text = "Starting %d runs..." % (runs * (cfg["floors"] as Array).size())
    cancel_btn.disabled = false


func cancel() -> void:
    if _pid <= 0:
        return
    var f := FileAccess.open(_cancel_file, FileAccess.WRITE)
    if f != null:
        f.store_string("1")
        f.close()
    _cancel_at = Time.get_ticks_msec()
    status_label.text = "Cancelling..."


func is_running() -> bool:
    return _pid > 0


func _read_pipe(pipe: FileAccess, is_err: bool) -> void:
    while pipe.is_open() and pipe.get_error() == OK:
        var line := pipe.get_line()
        if line == "" and pipe.get_error() != OK:
            break
        _mutex.lock()
        _lines.append([is_err, line])
        _mutex.unlock()


func _process(_delta: float) -> void:
    if _pid <= 0:
        return
    _mutex.lock()
    var got := _lines.duplicate()
    _lines.clear()
    _mutex.unlock()
    var rx := RegEx.create_from_string("\\[(\\d+)/(\\d+) runs\\]")
    for l in got:
        var line := String(l[1])
        var m := rx.search(line)
        if m != null:
            progress_bar.max_value = int(m.get_string(2))
            progress_bar.value = int(m.get_string(1))
            status_label.text = "%s / %s runs" % [m.get_string(1), m.get_string(2)]
        if line.begins_with("SIM ERROR: "):
            _err_lines.append(line.trim_prefix("SIM ERROR: "))
    if _cancel_at > 0 and Time.get_ticks_msec() - _cancel_at > 5000 and OS.is_process_running(_pid):
        OS.kill(_pid)                       # the simulator did not stop by itself
    if OS.is_process_running(_pid):
        return
    var code := OS.get_process_exit_code(_pid)
    _pid = -1
    for t in _threads:
        (t as Thread).wait_to_finish()
    _threads.clear()
    cancel_btn.disabled = true
    if _cancel_at > 0:
        status_label.text = "Cancelled."
    elif FileAccess.file_exists(_out_dir.path_join("results.json")):
        status_label.text = "Done. Report: %s" % _out_dir
        progress_bar.value = progress_bar.max_value
        _refresh_history()
        show_results(_out_dir)
    else:
        status_label.text = "Failed (exit %d)." % code
        _show_errors(_err_lines if not _err_lines.is_empty() else ["The simulator stopped without a report."])
    if FileAccess.file_exists(_cancel_file):
        DirAccess.remove_absolute(_cancel_file)


func _exit_tree() -> void:
    if _pid > 0 and OS.is_process_running(_pid):
        cancel()
        OS.kill(_pid)
    for t in _threads:
        (t as Thread).wait_to_finish()


# ---------------------------------------------------------------- results panel

func _build_results(rv: VBoxContainer) -> void:
    var h := HBoxContainer.new()
    progress_bar = ProgressBar.new()
    progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    progress_bar.custom_minimum_size.y = 22
    h.add_child(progress_bar)
    cancel_btn = _btn("Cancel", cancel)
    cancel_btn.disabled = true
    h.add_child(cancel_btn)
    h.add_child(_btn("Open report folder", func():
        if _out_dir != "":
            OS.shell_open(_out_dir)))
    rv.add_child(h)
    status_label = _lbl("")
    rv.add_child(status_label)
    errors_label = _lbl("")
    errors_label.add_theme_color_override("font_color", COL_RED)
    errors_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rv.add_child(errors_label)
    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rv.add_child(tabs)
    results_tree = _tree(["Variant", "Floor", "Mission", "Win", "Duration s", "Downs", "Deaths", "Top loss reason"])
    results_tree.name = "By floor"
    tabs.add_child(results_tree)
    versus_tree = _tree(["Floor", "Pair", "Tactical", "Loco", "Difference", ""])
    versus_tree.name = "Tactical vs loco"
    tabs.add_child(versus_tree)
    heroes_tree = _tree(["Variant", "Floor", "Hero", "Damage", "Healing", "Taken"])
    heroes_tree.name = "Heroes"
    tabs.add_child(heroes_tree)
    var hv := VBoxContainer.new()
    hv.name = "History"
    history_list = ItemList.new()
    history_list.select_mode = ItemList.SELECT_MULTI
    history_list.custom_minimum_size.y = 180
    history_list.item_activated.connect(func(i: int): show_results(String(history[i]["dir"])))
    hv.add_child(history_list)
    var hb := HBoxContainer.new()
    hb.add_child(_btn("Show", func():
        var s := history_list.get_selected_items()
        if s.size() >= 1:
            show_results(String(history[s[0]]["dir"]))))
    hb.add_child(_btn("Compare 2", _compare_selected))
    hb.add_child(_btn("Refresh", _refresh_history))
    hv.add_child(hb)
    compare_tree = _tree(["Variant", "Floor", "A", "B", "B - A"])
    compare_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    hv.add_child(compare_tree)
    tabs.add_child(hv)


func read_summary(dir: String) -> Array:
    var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("results.json")))
    return (d as Dictionary).get("summary", []) if d is Dictionary else []


func show_results(dir: String) -> void:
    _out_dir = dir
    var sum := read_summary(dir)
    results_tree.clear()
    var root := results_tree.create_item()
    for r in sum:
        var it := results_tree.create_item(root)
        var reasons: Dictionary = r.get("reasons", {})
        var top := ""
        for k in reasons:
            if top == "" or int(reasons[k]) > int(reasons[top]):
                top = String(k)
        var cells := [String(r["variant"]), str(r["floor"]), String(r["mission"]), "%.0f %%" % (float(r["win_rate"]) * 100.0),
            _mean(r["time"], 0), _mean(r["downs"], 1), _mean(r["deaths"], 2), top]
        for c in cells.size():
            it.set_text(c, cells[c])
        var col := win_color(float(r["win_rate"]))
        if col != Color.TRANSPARENT:
            it.set_custom_color(3, col)
    versus_tree.clear()
    root = versus_tree.create_item()
    var by := {}
    for r in sum:
        var key := "%s|%d" % [r.get("pair", ""), int(r["floor"])]
        if not by.has(key):
            by[key] = {}
        by[key][String(r["style"])] = r
    for key in by:
        var pr: Dictionary = by[key]
        if not (pr.has("tactico") and pr.has("loco")) or String(pr["tactico"]["variant"]) == String(pr["loco"]["variant"]):
            continue
        var a := float(pr["tactico"]["win_rate"]) * 100.0
        var b := float(pr["loco"]["win_rate"]) * 100.0
        var it := versus_tree.create_item(root)
        for c in 5:
            it.set_text(c, [str(pr["tactico"]["floor"]), String(key).get_slice("|", 0), "%.0f %%" % a, "%.0f %%" % b, "%+.0f" % (a - b)][c])
        if a - b < 30.0:
            it.set_text(5, "ALERT < 30")
            it.set_custom_color(5, COL_RED)
    heroes_tree.clear()
    root = heroes_tree.create_item()
    for r in sum:
        var pc: Dictionary = r.get("classes", {})
        for c in pc:
            var it := heroes_tree.create_item(root)
            for k in 6:
                it.set_text(k, [String(r["variant"]), str(r["floor"]), String(c), _mean(pc[c]["damage"], 0), _mean(pc[c]["healing"], 0), _mean(pc[c]["taken"], 0)][k])


static func win_color(w: float) -> Color:
    if w < 0.10:
        return COL_RED
    if w > 0.95:
        return COL_GREY
    if w >= 0.40 and w <= 0.80:
        return COL_GREEN
    return Color.TRANSPARENT


func _refresh_history() -> void:
    history.clear()
    history_list.clear()
    var base := ProjectSettings.globalize_path(REPORTS_DIR)
    var dirs := Array(DirAccess.get_directories_at(base))
    dirs.sort()
    dirs.reverse()
    for dn in dirs:
        var dir := base.path_join(String(dn))
        if FileAccess.file_exists(dir.path_join("results.json")):
            history.append({"label": String(dn), "dir": dir})
            history_list.add_item(String(dn))


func _compare_selected() -> void:
    var s := history_list.get_selected_items()
    compare_tree.clear()
    if s.size() != 2:
        _show_errors(["Select exactly 2 runs in the history."])
        return
    _show_errors([])
    var a := read_summary(String(history[s[0]]["dir"]))
    var b := read_summary(String(history[s[1]]["dir"]))
    var root := compare_tree.create_item()
    for ra in a:
        for rb in b:
            if String(ra["variant"]) == String(rb["variant"]) and int(ra["floor"]) == int(rb["floor"]):
                var wa := float(ra["win_rate"]) * 100.0
                var wb := float(rb["win_rate"]) * 100.0
                var it := compare_tree.create_item(root)
                for c in 5:
                    it.set_text(c, [String(ra["variant"]), str(ra["floor"]), "%.0f %%" % wa, "%.0f %%" % wb, "%+.0f" % (wb - wa)][c])


# ---------------------------------------------------------------- small helpers

func _show_errors(list: Array) -> void:
    errors_label.text = "\n".join(list.map(func(e): return "SIM ERROR: " + String(e)))


func _tree(cols: Array) -> Tree:
    var t := Tree.new()
    t.columns = cols.size()
    t.column_titles_visible = true
    t.hide_root = true
    for i in cols.size():
        t.set_column_title(i, String(cols[i]))
    return t


func _title(t: String) -> Label:
    var l := UIKit.label(t, 16, UIKit.TEXT)
    l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
    return l


func _lbl(t: String) -> Label:
    return UIKit.label(t, 14, UIKit.TEXT)


func _btn(t: String, cb: Callable) -> Button:
    return UIKit.button(t, cb)


func _spin(lo: float, hi: float, step: float, v: float) -> SpinBox:
    var s := SpinBox.new()
    s.min_value = lo
    s.max_value = hi
    s.step = step
    s.value = v
    return s


func _opt_text(o: OptionButton) -> String:
    return o.get_item_text(o.selected) if o.selected >= 0 else ""


func _select(o: OptionButton, text: String) -> void:
    for i in o.item_count:
        if o.get_item_text(i) == text:
            o.select(i)
            return


static func _num(v: float, like: Variant) -> Variant:
    return int(v) if like is int else v


static func _parse_value(s: String) -> Variant:
    var j: Variant = JSON.parse_string(s)
    return j if j != null else s


static func _mean(d: Variant, decimals: int) -> String:
    if not (d is Dictionary) or int((d as Dictionary).get("n", 0)) == 0:
        return "—"
    return String.num(float(d["mean"]), decimals)
