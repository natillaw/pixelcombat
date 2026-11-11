class_name HeroInfoPanel
extends PanelContainer
## Everything about one hero, opened by clicking the hero in the town: portrait, identity, stats,
## social state, personality, equipment slots, appearance colours, what they are doing now,
## relationships and recent memories. The Skills section is interactive: level-up choices (D-045),
## reading skill books (D-046) and the W/E/R loadout (D-059).

signal open_barracks
signal closed

const LAYER_NAMES := {"body": "Skin", "eyes": "Eyes", "rear_hair": "Hair (back)", "front_hair": "Hair",
    "facial_hair": "Beard", "top": "Top", "bottom": "Bottom", "shoes": "Shoes", "hat": "Hat", "held": "Held item"}

var hero: HeroData
var activity: String = ""
var _skills_box: VBoxContainer
var _life_box: VBoxContainer
var _gear_box: VBoxContainer


func _init(h: HeroData = null, current_activity: String = "") -> void:
    hero = h
    activity = current_activity


func _ready() -> void:
    custom_minimum_size = Vector2(190, 0)  # px
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(185, 280)  # px
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var vb := VBoxContainer.new()
    vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vb.add_theme_constant_override("separation", 3)  # px
    scroll.add_child(vb)
    if hero == null:
        return
    var h := hero

    var head := HBoxContainer.new()
    var portrait := TextureRect.new()
    portrait.texture = SpriteComposer.pose_texture(h)
    portrait.custom_minimum_size = Vector2(48, 48)  # px
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    head.add_child(portrait)
    var id_box := VBoxContainer.new()
    id_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var name_lbl := UIKit.label(h.display_name(), 18, h.star_color())
    name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    id_box.add_child(name_lbl)
    id_box.add_child(UIKit.label("%d-star %s  ·  Lv %d / %d" % [h.stars, h.class_title(), h.level, h.level_cap()], 14, UIKit.TEXT))
    id_box.add_child(UIKit.label("Power %d   ·   XP %d / %d" % [h.power(), h.xp, h.xp_to_next()], 13, UIKit.MUTED))
    var prof: Dictionary = HeroTables.PROFESSIONS.get(h.profession, {})
    if not prof.is_empty():
        id_box.add_child(UIKit.label("Past life: " + String(prof["name"]), 13, UIKit.MUTED))
        var best: Array = TownTables.best_workplaces(h.profession).map(func(b): return String(TownTables.info(b)["name"]))
        if not best.is_empty():
            id_box.add_child(UIKit.label("Expert at: " + ", ".join(best), 13, UIKit.ACCENT))
    head.add_child(id_box)
    var close := UIKit.button("x", func(): closed.emit(), Vector2(32, 30))
    close.focus_mode = Control.FOCUS_NONE
    head.add_child(close)
    vb.add_child(head)

    if activity != "":
        vb.add_child(_wrap("Now: " + activity, 14, UIKit.ACCENT))
    if h.hq_assignment != "":
        vb.add_child(_wrap("Works at: " + String(TownTables.info(h.hq_assignment).get("name", h.hq_assignment)), 13, UIKit.TEXT))

    vb.add_child(_section("Stats"))
    var st := h.get_stats()
    var at := h.attributes()
    vb.add_child(UIKit.label("FUE %d   AGI %d   VIT %d   INT %d   TEM %d" % [at["fue"], at["agi"], at["vit"], at["int"], at["tem"]], 14, UIKit.ACCENT))
    vb.add_child(UIKit.label("HP %d   P.ATK %d   M.ATK %d   ARMOR %d   M.RES %d" % [st["hp"], st["atk"], st["mag"], st["def"], st["mres"]], 14, UIKit.TEXT))
    vb.add_child(UIKit.label("Crit %d%%   Attack every %.2fs   %s basic attacks" % [roundi(float(st["crit"]) * 100.0), float(st["interval"]), String(st["kind"]).capitalize()], 13, UIKit.MUTED))
    for pair in [["Trust", h.trust], ["Obedience", h.obedience], ["Composure", h.composure]]:
        vb.add_child(_bar(String(pair[0]), int(pair[1])))

    vb.add_child(_section("Skills"))
    _skills_box = VBoxContainer.new()
    _skills_box.add_theme_constant_override("separation", 2)  # px
    vb.add_child(_skills_box)
    _fill_skills()

    vb.add_child(_section("Personality"))
    for t in h.traits:
        var td: Dictionary = HeroTables.TRAITS.get(t, {})
        vb.add_child(_wrap("%s — %s" % [td.get("name", t), td.get("desc", "")], 13, UIKit.TEXT))
    for p in h.passives:
        var pd: Dictionary = HeroTables.PASSIVES.get(p, {})
        vb.add_child(_wrap("Passive: %s — %s" % [pd.get("name", p), pd.get("desc", "")], 12, UIKit.MUTED))
    if h.background_text != "":
        vb.add_child(_wrap(h.background_text, 12, UIKit.MUTED))

    vb.add_child(_section("Town life"))
    _life_box = VBoxContainer.new()
    vb.add_child(_life_box)
    vb.add_child(_section("Equipment"))
    _gear_box = VBoxContainer.new()
    _gear_box.add_theme_constant_override("separation", 2)  # px
    vb.add_child(_gear_box)
    _fill_life()
    _fill_gear()

    vb.add_child(_section("Appearance & colours"))
    for key in SpriteComposer.LAYER_ORDER:
        var rel := String(h.appearance.get(key, ""))
        if rel == "":
            continue
        var row := HBoxContainer.new()
        var sw := ColorRect.new()
        sw.color = dominant_color(rel)
        sw.custom_minimum_size = Vector2(9, 9)  # px
        row.add_child(sw)
        row.add_child(UIKit.label("  %s  (%s)" % [LAYER_NAMES.get(key, key), rel.get_file()], 13, UIKit.TEXT))
        vb.add_child(row)

    vb.add_child(_section("Relationships"))
    var rels: Array = []
    for other_id in h.relationships:
        rels.append([other_id, int((h.relationships[other_id] as Dictionary).get("level", 0))])
    rels.sort_custom(func(a, b): return absi(a[1]) > absi(b[1]))
    if rels.is_empty():
        vb.add_child(UIKit.label("No bonds yet.", 13, UIKit.MUTED))
    for i in mini(4, rels.size()):
        var oid: String = rels[i][0]
        var other: HeroData = Game.heroes.get(oid)
        var nm := other.display_name() if other != null else "(fallen)"
        vb.add_child(UIKit.label("%s — %s (%d)" % [nm, h.get_relationship(oid)["status"], rels[i][1]], 13, UIKit.TEXT))

    vb.add_child(_section("Recent memories"))
    if h.memories.is_empty():
        vb.add_child(UIKit.label("Nothing remembered yet.", 13, UIKit.MUTED))
    for m in h.memories.slice(-4):
        vb.add_child(_wrap("• " + String((m as Dictionary).get("text", "")), 12, UIKit.TEXT))

    var btn := UIKit.button("Open in Barracks", func(): open_barracks.emit(), Vector2(340, 38))
    btn.focus_mode = Control.FOCUS_NONE
    vb.add_child(btn)


## Most common opaque colour of a sprite layer in the standing pose (what the player sees).
static func dominant_color(rel: String) -> Color:
    var img := SpriteComposer._layer_image(rel)
    if img == null:
        return Color(0, 0, 0, 0)
    var counts := {}
    var col := int(SpriteComposer.ANIMS["idle"]["cols"][0])
    for y in SpriteComposer.FRAME:
        for x in SpriteComposer.FRAME:
            var c := img.get_pixel(col * SpriteComposer.FRAME + x, y)
            if c.a < 0.5 or c.v < 0.12:
                continue
            var k := c.to_html(false)
            counts[k] = int(counts.get(k, 0)) + 1
    var best := ""
    var best_n := 0
    for k in counts:
        if int(counts[k]) > best_n:
            best_n = int(counts[k])
            best = String(k)
    return Color.html(best) if best != "" else Color(0, 0, 0, 0)


## Known skills by slot, pending level choices and readable books. Rebuilt after every action.
func _fill_skills() -> void:
    for c in _skills_box.get_children():
        c.queue_free()
    var h := hero
    var res := String(SkillDefs.RESOURCES[SkillDefs.resource_of(h.hero_class)]["name"])
    _skills_box.add_child(UIKit.label("Resource: " + res, 13, UIKit.MUTED))
    var keys := ["W", "E", "R"]                  # D-059: Q is the basic attack, 3 skill slots
    for sid in h.skills:
        var sk := SkillDefs.info(sid)
        var slot_i := h.loadout.find(sid)
        var row := HBoxContainer.new()
        row.add_child(_wrap("[%s] %s — %d %s, %.0fs%s. %s" % [keys[slot_i] if slot_i >= 0 else "-", sk["name"], int(sk["cost"]), res.to_lower(),
            float(sk["cd"]), (", cast %.1fs" % float(sk["cast"])) if float(sk["cast"]) > 0.0 else "", sk["desc"]], 13, UIKit.TEXT if slot_i >= 0 else UIKit.MUTED))
        if slot_i != 0:
            var skill_id := String(sid)
            var to_q := UIKit.button("→W", _on_equip.bind(skill_id), Vector2(44, 26))
            to_q.tooltip_text = "Put this skill on W (swaps)"
            row.add_child(to_q)
        _skills_box.add_child(row)
    for i in h.skill_choices.size():
        var c: Dictionary = h.skill_choices[i]
        _skills_box.add_child(UIKit.label("Level %d: choose one" % int(c["level"]), 13, UIKit.ACCENT))
        var opts := HBoxContainer.new()
        for sid in c["options"]:
            var idx := i
            var skill_id := String(sid)
            var b := UIKit.button(String(SkillDefs.info(skill_id)["name"]), _on_choose.bind(idx, skill_id), Vector2(110, 28))
            b.tooltip_text = String(SkillDefs.info(skill_id)["desc"])
            opts.add_child(b)
        _skills_box.add_child(opts)
    for sid in Game.skill_books:
        if h.skills.has(sid) or not SkillDefs.usable_by(String(sid), h.hero_class):
            continue
        var skill_id := String(sid)
        var rb := UIKit.button("Read book: %s (x%d)" % [SkillDefs.info(skill_id)["name"], int(Game.skill_books[sid])], _on_read.bind(skill_id), Vector2(300, 28))
        rb.tooltip_text = String(SkillDefs.info(skill_id)["desc"])
        _skills_box.add_child(rb)


## Professions (D-049), needs, illness, bed, workplace: the real simulation state.
func _fill_life() -> void:
    for c in _life_box.get_children():
        c.queue_free()
    var h := hero
    var profs: Array = []
    for p in h.professions:
        var pd: Dictionary = h.professions[p]
        profs.append("%s Lv %d (%d/%d xp)%s" % [ProfessionDefs.info(p)["name"], int(pd["lvl"]), int(pd["xp"]), ProfessionDefs.xp_to_next(int(pd["lvl"])), " (passion)" if p == h.passion else ""])
    _life_box.add_child(_wrap("Professions (%d/%d): %s" % [h.professions.size(), ProfessionDefs.MAX_KNOWN, ", ".join(profs) if not profs.is_empty() else "none yet"], 13, UIKit.TEXT))
    for p in h.professions.keys():
        if h.hq_assignment == "" or Game.workplace_prof(h.hq_assignment) != p:
            var prof_id := String(p)
            var fb := UIKit.button("Forget %s" % ProfessionDefs.info(prof_id)["name"], _on_forget.bind(prof_id), Vector2(200, 26))
            fb.tooltip_text = "Frees a profession slot (the experience is lost)"
            _life_box.add_child(fb)
    var work := "nowhere"
    if h.hq_assignment == "construction":
        work = "construction crew"
    elif h.hq_assignment != "":
        work = String(TownTables.info(h.hq_assignment).get("name", h.hq_assignment))
    _life_box.add_child(_wrap("Now: %s · works at: %s · bed: %s" % [h.activity_state, work, TownTables.info(h.bed).get("name", "none (sleeps rough)") if h.bed != "" else "none (sleeps rough)"], 13, UIKit.TEXT))
    _life_box.add_child(_wrap("Hunger %d · Fatigue %d · Stress %d · Mood %d" % [h.hunger, h.fatigue, h.stress, h.mood()], 13, UIKit.ACCENT))
    for d in h.diseases:
        var dd: Dictionary = EconomyDefs.DISEASES[String(d["id"])]
        _life_box.add_child(_wrap("Ill: %s (~%.0f h, %s). %s" % [dd["name"], float(d["hours"]), d["cause"], dd["desc"]], 13, Color(1.0, 0.6, 0.5)))


## Worn items with unequip, the stash items that fit, and the consumable bag.
func _fill_gear() -> void:
    for c in _gear_box.get_children():
        c.queue_free()
    var h := hero
    for slot in ItemDefs.SLOTS:
        if not h.equipment.has(slot):
            continue
        var it: Dictionary = h.equipment[slot]
        var row := HBoxContainer.new()
        var l := _wrap("%s: %s — %s" % [ItemDefs.SLOT_NAMES[slot], it["name"], ItemGen.describe(it)], 12, ItemDefs.rarity_color(String(it["rarity"])))
        l.custom_minimum_size = Vector2(135, 0)  # px
        row.add_child(l)
        row.add_child(UIKit.button("Off", _on_unequip.bind(String(slot)), Vector2(44, 24)))
        _gear_box.add_child(row)
    if h.equipment.is_empty():
        _gear_box.add_child(UIKit.label("Nothing equipped.", 13, UIKit.MUTED))
    var shown := 0
    for it in Game.stash:
        if shown >= 8:
            _gear_box.add_child(UIKit.label("… more in the warehouse stash", 12, UIKit.MUTED))
            break
        shown += 1
        var trained: Array = ItemDefs.BASES[String(it["base"])].get("classes", [])
        var note := "" if trained.is_empty() or trained.has(h.hero_class) else " (untrained: 75%)"
        var row := HBoxContainer.new()
        var l := _wrap("%s — %s%s" % [ItemDefs.item_label(it), ItemGen.describe(it), note], 12, ItemDefs.rarity_color(String(it["rarity"])))
        l.custom_minimum_size = Vector2(115, 0)  # px
        row.add_child(l)
        row.add_child(UIKit.button("Equip", _on_equip_item.bind(int(it["uid"])), Vector2(54, 24)))
        row.add_child(UIKit.button("Scrap", _on_salvage.bind(int(it["uid"])), Vector2(50, 24)))
        _gear_box.add_child(row)
    var bag: Array = []
    for k in h.bag:
        bag.append("%s x%d" % [EconomyDefs.RESOURCES[k]["name"], int(h.bag[k])])
    _gear_box.add_child(_wrap("Bag (used on their own in the tower): " + (", ".join(bag) if not bag.is_empty() else "empty"), 13, UIKit.TEXT))
    var brow := HBoxContainer.new()
    for res in ["potion", "antidote"]:
        brow.add_child(UIKit.button("+%s (%d)" % [res, int(Game.hq_outputs.get(res, 0))], _on_pack.bind(res), Vector2(110, 26)))
        brow.add_child(UIKit.button("-", _on_unpack.bind(res), Vector2(28, 26)))
    _gear_box.add_child(brow)
    _gear_msg = UIKit.label("", 12, Color(1.0, 0.6, 0.5))
    _gear_box.add_child(_gear_msg)


var _gear_msg: Label


func _after_gear(why: String) -> void:
    _fill_gear()
    if why != "" and _gear_msg != null:
        _gear_msg.text = why


func _on_equip_item(uid: int) -> void:
    _after_gear(Game.equip(hero, uid))


func _on_unequip(slot: String) -> void:
    _after_gear(Game.unequip(hero, slot))


func _on_salvage(uid: int) -> void:
    Game.salvage(uid)
    _after_gear("")


func _on_pack(res: String) -> void:
    _after_gear(Game.pack_consumable(hero, res))


func _on_unpack(res: String) -> void:
    _after_gear(Game.unpack_consumable(hero, res))


func _on_forget(prof: String) -> void:
    hero.forget_prof(prof)
    Game._commit()
    _fill_life()


func _on_equip(skill_id: String) -> void:
    hero.equip_skill(0, skill_id)
    Game._commit()
    _fill_skills()


func _on_choose(idx: int, skill_id: String) -> void:
    hero.choose_skill(idx, skill_id)
    Game._commit()
    _fill_skills()


func _on_read(skill_id: String) -> void:
    Game.use_skill_book(hero, skill_id)
    _fill_skills()


func _section(title: String) -> Label:
    var l := UIKit.label(title, 16, UIKit.ACCENT)
    return l


func _wrap(text: String, size_px: int, color: Color) -> Label:
    var l := UIKit.label(text, size_px, color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(170, 0)  # px
    return l


func _bar(label_text: String, value: int) -> HBoxContainer:
    var row := HBoxContainer.new()
    var l := UIKit.label(label_text, 13, UIKit.TEXT)
    l.custom_minimum_size = Vector2(45, 0)  # px
    row.add_child(l)
    var pb := ProgressBar.new()
    pb.min_value = 0
    pb.max_value = 100
    pb.value = value
    pb.custom_minimum_size = Vector2(100, 7)  # px
    pb.show_percentage = false
    row.add_child(pb)
    row.add_child(UIKit.label(" %d" % value, 13, UIKit.TEXT))
    return row
