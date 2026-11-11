class_name HeroSheet
extends VBoxContainer
## A hero's sheet in tabs (D-063): Summary, Skills, Equipment, Progression (ascension, synthesis,
## sacrifice with a preview of what is gained and lost before confirming), Profession, Relations.
## Every action calls Game; the sheet rebuilds from the data after it.

signal changed

var hero: HeroData
var _tabs: TabContainer
var _msg: String = ""
var _sources: Array = []              # heroes picked to be absorbed by a synthesis
var _tab_index: int = 0


func _init(h: HeroData = null, tab: int = 0) -> void:
    hero = h
    _tab_index = tab
    add_theme_constant_override("separation", 4)


func _ready() -> void:
    rebuild()


func rebuild() -> void:
    for c in get_children():
        c.queue_free()
    if hero == null or not Game.heroes.has(hero.id):
        add_child(UIKit.label("Choose a hero.", 16, UIKit.MUTED))
        return
    var head := HBoxContainer.new()
    add_child(head)
    head.add_child(HeroPortrait.new(hero, 1.0))
    var info := VBoxContainer.new()
    info.add_theme_constant_override("separation", 1)
    head.add_child(info)
    info.add_child(UIKit.label(hero.display_name(), 24, ArtPalette.rarity_color(ArtPalette.rarity_of_stars(hero.stars))))
    info.add_child(StarRow.new(hero.stars, 9.0))
    info.add_child(UIKit.label("%s · Lv %d/%d · Power %d" % [hero.class_title(), hero.level, hero.level_cap(), hero.power()], 14, UIKit.TEXT))
    if _msg != "":
        add_child(_wrap(_msg, UIKit.ACCENT))
    _tabs = TabContainer.new()
    _tabs.custom_minimum_size = Vector2(300, 220)
    _tabs.clip_tabs = true                       # many tabs scroll with the arrows instead of widening the sheet
    add_child(_tabs)
    _tabs.add_child(_scroll("Summary", _summary()))
    _tabs.add_child(_scroll("Skills", _skills()))
    _tabs.add_child(_scroll("Equipment", _equipment()))
    _tabs.add_child(_scroll("Progression", _progression()))
    _tabs.add_child(_scroll("Profession", _profession()))
    _tabs.add_child(_scroll("Relations", _relations()))
    if hero.is_master:
        _tabs.add_child(_scroll("Master memories", _memories()))     # D-081
    _tabs.current_tab = clampi(_tab_index, 0, _tabs.get_tab_count() - 1)
    _tabs.tab_changed.connect(func(i): _tab_index = i)


func _scroll(title: String, content: Control) -> ScrollContainer:
    var s := ScrollContainer.new()
    s.name = title
    s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.add_child(content)
    return s


func _wrap(text: String, color: Color = UIKit.TEXT, size: int = 14) -> Label:
    var l := UIKit.label(text, size, color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(280, 0)
    return l


func _done(msg: String) -> void:
    _msg = msg
    rebuild()
    changed.emit()


# --- D-081: Leadership (the Master) or the bond with the Master (everybody else) -------------------

func _leader_line() -> Control:
    if hero.is_master:
        var known: Array = MasterRules.commands(hero).map(func(c): return tr(String(MasterDefs.COMMANDS[c]["name"])))
        return _wrap("%s %d  ·  %s %d px  ·  %s: %s" % [tr("Leadership"), roundi(MasterRules.leadership(hero)), tr("radius"),
            roundi(MasterRules.leadership_radius(hero)), tr("Commands"), ", ".join(known) if not known.is_empty() else "-"], UIKit.ACCENT, 13)
    var row := HBoxContainer.new()
    row.add_child(UIKit.label(tr("Bond with the Master"), 12, UIKit.MUTED))
    row.add_child(UIKit.bar("xp", float(hero.bond_master), 100.0, 60, false))
    row.add_child(UIKit.label("%d · %s" % [hero.bond_master, tr(String(MasterRules.bond_tier(hero.bond_master)["name"]))], 12, UIKit.TEXT))
    return row


## Memories of the Former Master: the unlocked ones with their scene and reward, the others as "???".
func _memories() -> VBoxContainer:
    var v := VBoxContainer.new()
    for mem in MasterMemories.MEMORIES:
        var id := String(mem["id"])
        if hero.master_memories.has(id):
            v.add_child(UIKit.label("%s %d  -  %s" % [tr("Floor"), int(mem["floor"]), tr(String(mem["title"]))], 14, UIKit.ACCENT))
            v.add_child(_wrap(tr(String(mem["text"])), UIKit.TEXT, 12))
            v.add_child(_wrap(_reward_text(mem["reward"]), UIKit.MUTED, 12))
        else:
            v.add_child(UIKit.label("%s %d  -  ???" % [tr("Floor"), int(mem["floor"])], 14, UIKit.MUTED))
    return v


static func _reward_text(r: Dictionary) -> String:
    if r.has("leadership"):
        return "+%d %s" % [int(r["leadership"]), TranslationServer.translate("Leadership")]
    if r.has("passive") and HeroTables.PASSIVES.has(String(r["passive"])):
        return "%s: %s" % [TranslationServer.translate("Passive"), TranslationServer.translate(String(HeroTables.PASSIVES[r["passive"]]["name"]))]
    if r.has("command") and MasterDefs.COMMANDS.has(String(r["command"])):
        return "%s: %s" % [TranslationServer.translate("Command"), TranslationServer.translate(String(MasterDefs.COMMANDS[r["command"]]["name"]))]
    return ""


# --- Summary --------------------------------------------------------------------------------------

## 2026-11-02 (owner: "interfaz feísima, ponerle sus slots de items"): the summary opens with the hero
## wearing their gear (every slot around them) next to their numbers as bars.
const STAT_BAR_MAX := {"hp": 400, "atk": 60, "mag": 60, "def": 40, "spd": 30}


func _summary() -> VBoxContainer:
    var v := VBoxContainer.new()
    var stats := hero.get_stats()
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 6)
    v.add_child(top)
    top.add_child(InventoryScreen.paper_doll(hero, func(t: String): _done(t)))
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 2)
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(col)
    for k in HeroTables.STAT_KEYS:
        var row := HBoxContainer.new()
        var name := UIKit.label(String(HeroTables.STAT_NAMES[k]), 12, UIKit.MUTED)
        name.custom_minimum_size = Vector2(30, 0)
        row.add_child(name)
        var val := UIKit.label(str(stats[k]), 14, UIKit.TEXT)
        val.custom_minimum_size = Vector2(26, 0)
        row.add_child(val)
        var bar := ProgressBar.new()
        bar.show_percentage = false
        bar.custom_minimum_size = Vector2(60, 6)
        bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        bar.max_value = float(STAT_BAR_MAX.get(String(k), 100))
        bar.value = float(stats[k])
        bar.add_theme_stylebox_override("fill", UIKit.box([Color(0.8, 0.3, 0.3), Color(0.9, 0.6, 0.25), Color(0.5, 0.5, 0.95), Color(0.6, 0.65, 0.7), Color(0.4, 0.8, 0.5)][HeroTables.STAT_KEYS.find(k) % 5], Color(0, 0, 0, 0), 0, 0, 0))
        row.add_child(bar)
        col.add_child(row)
    for s in [["social_trust", "Trust", hero.trust, Color(0.9, 0.35, 0.4)], ["social_obedience", "Obedience", hero.obedience, Color(0.85, 0.7, 0.4)], ["social_composure", "Composure", hero.composure, Color(0.35, 0.6, 0.95)]]:
        var row := HBoxContainer.new()
        row.tooltip_text = tr(String(s[1]))
        row.add_child(UIKit.icon(AssetCatalog.icon(String(s[0])), tr(String(s[1]))))
        var val := UIKit.label(str(int(s[2])), 14, UIKit.TEXT)
        val.custom_minimum_size = Vector2(26, 0)
        row.add_child(val)
        var bar := ProgressBar.new()
        bar.show_percentage = false
        bar.custom_minimum_size = Vector2(60, 6)
        bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        bar.value = float(s[2])
        bar.add_theme_stylebox_override("fill", UIKit.box(s[3], Color(0, 0, 0, 0), 0, 0, 0))
        row.add_child(bar)
        col.add_child(row)
    v.add_child(_leader_line())
    v.add_child(UIKit.label("Personality", 20, UIKit.ACCENT))
    for t in hero.traits:
        var td: Dictionary = HeroTables.TRAITS[t]
        v.add_child(_wrap("%s — %s" % [td["name"], td["desc"]]))
    for p in hero.passives:
        var pd: Dictionary = HeroTables.PASSIVES[p]
        v.add_child(_wrap("Passive %s: %s" % [pd["name"], pd["desc"]], UIKit.MUTED, 12))
    for g in hero.innate:                     # D-079: combat gifts only (trade gifts stay hidden, like aptitude)
        var gd: Dictionary = PowerDefs.GIFTS.get(String(g), {})
        if String(gd.get("kind", "")) == "combat":
            v.add_child(_wrap("%s: %s — %s" % [tr("Gifts"), tr(String(gd["name"])), tr(String(gd["desc"]))], UIKit.ACCENT, 12))
    v.add_child(UIKit.label("Background", 20, UIKit.ACCENT))
    v.add_child(_wrap(hero.background_text, UIKit.MUTED, 12))
    return v


# --- Skills ---------------------------------------------------------------------------------------

func _skills() -> VBoxContainer:
    var v := VBoxContainer.new()
    var res := String(SkillDefs.RESOURCES[SkillDefs.resource_of(hero.hero_class)]["name"])
    v.add_child(UIKit.label("Q = basic attack · W E R = skills · resource: %s" % res, 12, UIKit.MUTED))
    v.add_child(UIKit.button(tr("Synergy codex"), func(): _overlay(SynergyCodex.new()), Vector2(140, 26)))   # D-090
    for sid in hero.skills:
        var sk := SkillDefs.info(sid)
        var row := HBoxContainer.new()
        var icon := TextureRect.new()
        icon.texture = ItemIcons.skill_texture(String(sid))
        row.add_child(icon)
        var slot_i := hero.loadout.find(sid)
        var col := VBoxContainer.new()
        col.add_theme_constant_override("separation", 0)
        col.add_child(UIKit.label("[%s] %s" % [SandboxScreen.SKILL_KEYS[slot_i] if slot_i >= 0 and slot_i < SkillDefs.MAX_SLOTS else "-", String(sk["name"])], 14,
            UIKit.ACCENT if slot_i >= 0 else UIKit.TEXT))
        var d := UIKit.label("%d %s · %.0fs · %s" % [int(sk["cost"]), res.to_lower(), float(sk["cd"]), String(sk["desc"])], 12, UIKit.MUTED)
        d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        d.custom_minimum_size = Vector2(220, 0)
        col.add_child(d)
        row.add_child(col)
        if slot_i != 0:
            var id := String(sid)
            row.add_child(UIKit.button("→W", func():
                hero.equip_skill(0, id)
                Game._commit()
                _done("%s now on W." % String(sk["name"])), Vector2(50, 28)))
        v.add_child(row)
    for i in hero.skill_choices.size():
        var c: Dictionary = hero.skill_choices[i]
        var idx := i
        v.add_child(UIKit.button(tr("Level %d: choose a skill (%d options)") % [int(c["level"]), (c["options"] as Array).size()], func():
            var scr := SkillChoiceScreen.make(hero, idx)          # D-090 choice screen
            scr.chosen.connect(func(id: String): _done("Learned %s." % String(SkillDefs.info(id)["name"])))
            _overlay(scr), Vector2(240, 30)))
    var tb := Game.training_block(hero)
    v.add_child(UIKit.label("Training Grounds", 20, UIKit.ACCENT))
    if tb != "":
        v.add_child(_wrap(tb, UIKit.MUTED, 12))
    else:
        v.add_child(_wrap("Choose ONE to learn (%s):" % SandboxScreen._res_line(ProgressionDefs.TRAIN_COST), UIKit.TEXT, 12))
        var row := HBoxContainer.new()
        for sid in Game.training_options(hero):
            var id := String(sid)
            var b := UIKit.button(String(SkillDefs.info(id)["name"]), func():
                var why := Game.train_skill(hero, id)
                _done(why if why != "" else "Trained %s." % String(SkillDefs.info(id)["name"])), Vector2(140, 30))
            b.tooltip_text = String(SkillDefs.info(id)["desc"])
            row.add_child(b)
        v.add_child(row)
    return v


## D-090: a panel over everything (skill choice, synergy codex), centred on the screen.
func _overlay(panel: Control) -> void:
    var layer := CanvasLayer.new()
    layer.layer = 50
    get_tree().root.add_child(layer)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.55)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(dim)
    var centre := CenterContainer.new()
    centre.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(centre)
    centre.add_child(panel)
    panel.tree_exited.connect(func(): layer.queue_free())


# --- Equipment (8 open slots, D-060) --------------------------------------------------------------

func _equipment() -> VBoxContainer:
    var v := VBoxContainer.new()
    var top := HBoxContainer.new()
    v.add_child(top)
    top.add_child(InventoryScreen.paper_doll(hero, func(t: String): _done(t)))
    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(right)
    right.add_child(UIKit.label("From the master's stash (click to equip):", 12, UIKit.ACCENT))
    var grid := GridContainer.new()
    grid.columns = 3
    right.add_child(grid)
    var any := false
    for it in Game.stash:
        var slots := ItemDefs.slots_for(String(it["base"]))
        if slots.is_empty():
            continue
        any = true
        var vs: Dictionary = hero.equipment.get(String(slots[0]), {})
        var cell := ItemIcons.slot_control(String(slots[0]), it)
        cell.tooltip_text = ItemIcons.tooltip(it, vs)
        cell.mouse_filter = Control.MOUSE_FILTER_STOP
        var uid := int(it["uid"])
        cell.gui_input.connect(func(e):
            if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
                var why := Game.equip(hero, uid)
                _done(why if why != "" else "Equipped."))
        grid.add_child(cell)
    if not any:
        v.add_child(UIKit.label("The stash is empty: the tower and the forge fill it.", 12, UIKit.MUTED))
    return v


# --- Progression: level, ascension, synthesis, sacrifice -------------------------------------------

func _progression() -> VBoxContainer:
    var v := VBoxContainer.new()
    v.add_child(UIKit.label("Level %d / %d" % [hero.level, hero.level_cap()], 14, UIKit.TEXT))
    v.add_child(UIKit.bar("xp", hero.xp, hero.xp_to_next(), 200, true))
    var row := HBoxContainer.new()
    v.add_child(row)
    var t1 := UIKit.button("Read 1 book (+XP)", func():
        Game.train(hero, 1)
        _done("Studied."), Vector2(200, 30))
    t1.disabled = hero.is_max_level() or Game.books < 1
    row.add_child(t1)
    # ascension
    v.add_child(UIKit.label("Ascension", 20, UIKit.ACCENT))
    var why := Game.promotion_block(hero)
    v.add_child(_wrap("Needs: %s · Luck %d · failures %d (sure after %d)" % [SandboxScreen._res_line(Game.ascension_cost(hero)), hero.luck(),
        hero.ascension_fails, ProgressionDefs.ASCENSION_PITY_HARD], UIKit.MUTED, 12))
    var asc := UIKit.button("Ascend to %d★ (%d%%)" % [hero.stars + 1, roundi(Game.promotion_chance(hero) * 100.0)], func():
        var r := Game.attempt_promotion(hero)
        UIKit.sound("level_up" if bool(r.get("ok", false)) else "error")
        _done(("Ascended to %d stars!" % hero.stars) if bool(r.get("ok", false)) else "%s (next try %d%%)." % [String(r.get("reason", "failed")), roundi(Game.promotion_chance(hero) * 100.0)]), Vector2(300, 32))
    asc.disabled = why != ""
    asc.tooltip_text = why if why != "" else "Gained: +1 star, higher level cap, training. A failure keeps the level and half the tower materials."
    v.add_child(asc)
    if why != "":
        v.add_child(_wrap(why, UIKit.BAD, 12))
    # synthesis
    v.add_child(UIKit.label("Synthesis", 20, UIKit.ACCENT))
    v.add_child(_wrap("Absorb 1-3 heroes: %d%% of their experience (%d%% same class) and +1 to their best attribute if same class. They go to the memorial. Irreversible." % [
        roundi(ProgressionDefs.SYNTH_EFFICIENCY * 100.0), roundi(ProgressionDefs.SYNTH_SAME_CLASS * 100.0)], UIKit.MUTED, 12))
    var pick := GridContainer.new()
    pick.columns = 2
    v.add_child(pick)
    for other in Game.heroes.values():
        var o := other as HeroData
        if o == hero:
            continue
        var cb := CheckBox.new()
        cb.text = "%s %s Lv%d" % ["*".repeat(o.stars), o.display_name(), o.level]
        cb.button_pressed = _sources.has(o)
        cb.disabled = Game.consumable_block(o) != ""
        cb.tooltip_text = Game.consumable_block(o)
        cb.toggled.connect(func(on):
            if on and not _sources.has(o) and _sources.size() < ProgressionDefs.SYNTH_MAX_SOURCES:
                _sources.append(o)
            elif not on:
                _sources.erase(o)
            _done(""))
        pick.add_child(cb)
    if not _sources.is_empty():
        var p := Game.synthesis_preview(hero, _sources)
        if bool(p.get("ok", false)):
            v.add_child(_wrap("Gain: +%d XP (%d level%s)%s · Lose: %s%s" % [int(p["xp"]), int(p["levels"]), "" if int(p["levels"]) == 1 else "s",
                (" · +%s" % str(p["attrs"])) if not (p["attrs"] as Dictionary).is_empty() else "", ", ".join(p["lost"]),
                ("\nWarning: " + String(p["warning"])) if String(p["warning"]) != "" else ""], UIKit.TEXT, 12))
            v.add_child(UIKit.button("Confirm synthesis", func():
                var src := _sources.duplicate()
                _sources.clear()
                var r := Game.synthesize(hero, src)
                _done("Synthesis done: +%d XP." % int(r.get("xp", 0)) if bool(r.get("ok", false)) else String(r.get("reason", ""))), Vector2(300, 32)))
        else:
            v.add_child(_wrap(String(p.get("reason", "")), UIKit.BAD, 12))
    # sacrifice
    v.add_child(UIKit.label("Sacrifice", 20, UIKit.ACCENT))
    var sp := Game.sacrifice_preview(hero)
    if bool(sp.get("ok", false)):
        v.add_child(_wrap("Gain: %s · Lose: %s for good (memorial).%s" % [SandboxScreen._res_line(sp["gain"]), hero.display_name(),
            ("\nWarning: " + String(sp["warning"])) if String(sp["warning"]) != "" else ""], UIKit.TEXT, 12))
        var sac := UIKit.button("Sacrifice %s…" % hero.display_name(), _confirm_sacrifice, Vector2(300, 32))
        v.add_child(sac)
    else:
        v.add_child(_wrap(String(sp.get("reason", "")), UIKit.MUTED, 12))
    return v


func _confirm_sacrifice() -> void:
    var dlg := ConfirmationDialog.new()
    dlg.title = "Sacrifice"
    dlg.dialog_text = "%s will be sacrificed for %s.\nThis cannot be undone." % [hero.display_name(), SandboxScreen._res_line(Game.sacrifice_preview(hero).get("gain", {}))]
    dlg.confirmed.connect(func():
        var name := hero.display_name()
        var r := Game.sacrifice(hero)
        _done("%s was sacrificed: %s." % [name, SandboxScreen._res_line(r.get("gain", {}))] if bool(r.get("ok", false)) else String(r.get("reason", ""))))
    add_child(dlg)
    dlg.popup_centered()


# --- Profession -----------------------------------------------------------------------------------

func _profession() -> VBoxContainer:
    var v := VBoxContainer.new()
    if hero.professions.is_empty():
        v.add_child(UIKit.label("No profession yet (the village teaches one on the job).", 12, UIKit.MUTED))
    for p in hero.professions:
        var info: Dictionary = ProfessionDefs.info(String(p))
        var lv := int(hero.professions[p]["lvl"])
        v.add_child(UIKit.label("%s · level %d / %d" % [String(info.get("name", p)), lv, ProfessionDefs.MAX_LEVEL], 14, UIKit.TEXT))
        v.add_child(UIKit.bar("xp", float(lv), float(ProfessionDefs.MAX_LEVEL), 200))
        v.add_child(_wrap(String(info.get("desc", "")), UIKit.MUTED, 12))
    v.add_child(UIKit.label("Works at: %s" % (hero.hq_assignment if hero.hq_assignment != "" else "nowhere (free time)"), 12, UIKit.MUTED))
    return v


# --- Relations ------------------------------------------------------------------------------------

func _relations() -> VBoxContainer:
    var v := VBoxContainer.new()
    var any := false
    for oid in hero.relationships:
        var rel: Dictionary = hero.relationships[oid]
        var other: HeroData = Game.heroes.get(oid)
        if other == null:
            continue
        any = true
        var lvl := int(rel.get("level", 0))
        var row := HBoxContainer.new()
        row.add_child(UIKit.icon(AssetCatalog.icon("social_bond" if lvl >= 0 else "social_rivalry"), "bond" if lvl >= 0 else "rivalry"))
        row.add_child(UIKit.label("%s · %s (%+d)" % [other.display_name(), String(rel.get("status", "")), lvl], 12, UIKit.TEXT if lvl >= 0 else UIKit.BAD))
        v.add_child(row)
    if not any:
        v.add_child(UIKit.label("No bonds or rivalries yet: they grow from shared missions and village life.", 12, UIKit.MUTED))
    v.add_child(UIKit.label("Memories", 20, UIKit.ACCENT))
    for m in hero.memories.slice(-4):
        v.add_child(_wrap("· %s" % String(m["text"]), UIKit.MUTED, 12))
    return v
