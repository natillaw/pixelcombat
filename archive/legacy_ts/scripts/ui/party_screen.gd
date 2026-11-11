class_name PartyScreen
extends Control
## Squad editor. D-080: slot 1 is always the Master (crowned, cannot be changed); the party is the Master + 4.
## 2026-11-02 (owner: "ya no es un juego de turnos y filas"): no front / back rows any more (the heroes move
## on their own in real time): five places in a line, each with the hero's figure, class, level and power,
## a summary of the squad's reach, and the roster below. Pick a place, then click a hero.

signal back_requested

var _slot_box: HBoxContainer
var _grid: GridContainer
var _power: Label
var _hint: Label
var _selected_slot: int = 1 if Game.master() != null else 0
var _group := ButtonGroup.new()


func _ready() -> void:
    var margin := UIKit.margin(20)
    add_child(margin)
    UIKit.fill(margin)
    var root := VBoxContainer.new()
    margin.add_child(root)
    root.add_theme_constant_override("separation", 3)

    var header := HBoxContainer.new()
    header.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(110, 40)))
    header.add_child(UIKit.label("Party", 32, UIKit.ACCENT))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)
    _power = UIKit.label("", 20, UIKit.TEXT)
    header.add_child(_power)
    header.add_child(UIKit.button("Clear all", func(): Game.clear_party(), Vector2(110, 40)))
    root.add_child(header)

    var band := PanelContainer.new()
    root.add_child(band)
    var band_v := VBoxContainer.new()
    band.add_child(band_v)
    _slot_box = HBoxContainer.new()
    _slot_box.alignment = BoxContainer.ALIGNMENT_CENTER
    _slot_box.add_theme_constant_override("separation", 6)  # px
    band_v.add_child(_slot_box)
    _hint = UIKit.label("", 12, UIKit.MUTED)
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hint.custom_minimum_size = Vector2(560, 0)
    band_v.add_child(_hint)

    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    root.add_child(scroll)
    _grid = GridContainer.new()
    _grid.columns = 8
    _grid.add_theme_constant_override("h_separation", 5)  # px
    _grid.add_theme_constant_override("v_separation", 5)  # px
    scroll.add_child(_grid)

    Game.changed.connect(_rebuild)
    _rebuild()


func _rebuild() -> void:
    for c in _slot_box.get_children():
        c.queue_free()
    for c in _grid.get_children():
        c.queue_free()

    for i in Game.PARTY_SIZE:
        _slot_box.add_child(_place(i))

    var power := 0
    var melee := 0
    var ranged := 0
    for h in Game.party_heroes():
        power += h.power()
        if String(HeroTables.CLASSES.get(h.hero_class, {}).get("reach", "melee")) == "melee":
            melee += 1
        else:
            ranged += 1
    _power.text = "%s %d   (%d / %d)" % [tr("Party power:"), power, Game.party_heroes().size(), Game.PARTY_SIZE]
    _hint.text = "%s %d · %s %d\n%s" % [tr("Melee"), melee, tr("Ranged"), ranged,
        tr("Pick a place, then a hero below. Right click: empty it. In the tower they act on their own; you lead the Master.")]

    var list: Array = Game.heroes.values()
    list.sort_custom(func(a, b): return a.stars > b.stars or (a.stars == b.stars and a.level > b.level))
    for h in list:
        var card := HeroCard.new(h)
        card.scale = Vector2.ONE
        if Game.party_slot_of(h.id) >= 0:
            card.modulate = Color(1, 1, 1, 0.45)
        if h.is_master:
            continue                              # always in slot 1
        card.card_pressed.connect(_on_hero)
        _grid.add_child(card)


## One place of the squad: the hero's figure on a small stage, name, class and level, power.
func _place(i: int) -> Control:
    var id: String = Game.party[i]
    var h: HeroData = Game.heroes[id] if Game.heroes.has(id) else null
    var master := i == 0 and h != null and h.is_master
    var b := Button.new()
    b.custom_minimum_size = Vector2(102, 104)
    b.focus_mode = Control.FOCUS_NONE
    var rim: Color = ArtPalette.GOLD[3] if master else (ArtPalette.GOLD[2] if i == _selected_slot else ArtPalette.PANEL_RIM)
    var bg := Color(0.14, 0.1, 0.08) if h != null else Color(0.08, 0.06, 0.05)
    b.add_theme_stylebox_override("normal", UIKit.box(bg, rim, 2 if (master or i == _selected_slot) else 1, 0, 2))
    b.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.08), ArtPalette.GOLD[3], 2, 0, 2))
    b.add_theme_stylebox_override("pressed", UIKit.box(bg.lightened(0.12), ArtPalette.GOLD[3], 2, 0, 2))
    if not master:
        b.pressed.connect(func():
            _selected_slot = i
            _rebuild())
        b.gui_input.connect(func(e):
            if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
                Game.clear_slot(i))
    var v := VBoxContainer.new()
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_theme_constant_override("separation", 0)
    b.add_child(v)
    UIKit.fill(v)
    var tag := UIKit.label(("Master" if master else "%s %d" % [tr("Place"), i + 1]), 12, ArtPalette.GOLD[3] if master else UIKit.MUTED)
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(tag)
    var stage := Control.new()
    stage.custom_minimum_size = Vector2(98, 50)
    stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(stage)
    if h == null:
        var plus := UIKit.label("+", 32, Color(0.5, 0.42, 0.32))
        plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        plus.size = Vector2(98, 50)
        plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stage.add_child(plus)
        var free := UIKit.label("Free place", 12, UIKit.MUTED)
        free.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        free.mouse_filter = Control.MOUSE_FILTER_IGNORE
        v.add_child(free)
        return b
    var spr := AnimatedSprite2D.new()
    spr.sprite_frames = SpriteComposer.build_frames(h)
    spr.play("idle_down")
    spr.position = Vector2(49, 28)
    stage.add_child(spr)
    var name := UIKit.label(h.hero_name.split(" ")[0], 14, h.star_color())
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(name)
    var cls: String = String(HeroTables.CLASSES.get(h.hero_class, HeroTables.CLASSES["class.none"])["name"])
    var sub := UIKit.label("%s %d · %s %d" % [tr("Lv"), h.level, tr("Power"), h.power()], 12, UIKit.MUTED)
    sub.tooltip_text = tr(cls)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(sub)
    return b


func _on_hero(h: HeroData) -> void:
    Game.last_reason = ""
    Game.assign_party(_selected_slot, h.id)
    if Game.last_reason != "":
        UIKit.toast(self, tr(Game.last_reason))
        return
    # move on to the next empty slot, if any
    for step in range(1, Game.PARTY_SIZE + 1):
        var nxt := (_selected_slot + step) % Game.PARTY_SIZE
        if Game.party[nxt] == "" and not (nxt == 0 and Game.master() != null):
            _selected_slot = nxt
            break
    _rebuild()
