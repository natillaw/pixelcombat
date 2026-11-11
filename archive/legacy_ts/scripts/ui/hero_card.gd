class_name HeroCard
extends PanelContainer
## Clickable summary card: portrait, name, stars, level and class.

signal card_pressed(hero: HeroData)

var hero: HeroData
var selected: bool = false : set = _set_selected
var _style: StyleBoxFlat


func _init(h: HeroData = null) -> void:
    hero = h
    custom_minimum_size = Vector2(68, 74)       # D-063 base pixels: x1 portrait, rarity frame
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
    if hero == null:
        return
    _style = UIKit.box(ArtPalette.PANEL, ArtPalette.rarity_color(ArtPalette.rarity_of_stars(hero.stars)), 1, 0, 2)
    add_theme_stylebox_override("panel", _style)
    gui_input.connect(_on_gui_input)

    var vb := VBoxContainer.new()
    vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_theme_constant_override("separation", 1)  # px
    add_child(vb)

    var portrait := HeroPortrait.new(hero, 1.0)
    portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vb.add_child(portrait)

    var name_l := UIKit.label(hero.hero_name.split(" ")[0], 12, ArtPalette.rarity_color(ArtPalette.rarity_of_stars(hero.stars)))
    name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(name_l)

    var stars := StarRow.new(hero.stars, 9.0, hero.star_color())
    stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vb.add_child(stars)

    var info := UIKit.label("Lv%d %s" % [hero.level, hero.class_title().left(8)], 12, UIKit.MUTED)
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(info)
    _set_selected(selected)


func _set_selected(v: bool) -> void:
    selected = v
    if _style == null:
        return
    if selected:
        _style.border_color = ArtPalette.TEXT
        _style.set_border_width_all(2)
    else:
        _style.border_color = ArtPalette.rarity_color(ArtPalette.rarity_of_stars(hero.stars))
        _style.set_border_width_all(1)


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        card_pressed.emit(hero)
