class_name SummonScreen
extends Control
## Summon screen: banner odds/costs come from SummonConfig. Single / multi pulls with a reveal,
## then a result panel for the best hero (rarity, role, traits, background hook, Trust/Obedience).

signal back_requested

var _grid: GridContainer
var _btn1: Button
var _btn10: Button
var _pity: Label
var _msg: Label
var _flash: ColorRect
var _busy: bool = false
var _banner: Dictionary = SummonConfig.default_banner()
var _result: Label


func _ready() -> void:
    var margin := UIKit.margin(24)
    add_child(margin)
    UIKit.fill(margin)

    var vb := VBoxContainer.new()
    margin.add_child(vb)

    var header := HBoxContainer.new()
    header.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(110, 40)))
    header.add_child(UIKit.label("Summon", 32, UIKit.ACCENT))
    vb.add_child(header)

    vb.add_child(UIKit.label("%s   (odds are fixed and published)" % _banner["name"], 16, UIKit.TEXT))
    vb.add_child(UIKit.label("Rates:  " + SummonConfig.rates_text(_banner), 16, UIKit.MUTED))
    _pity = UIKit.label("", 16, UIKit.MUTED)
    vb.add_child(_pity)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    var multi: int = _banner["multi_count"]
    _btn1 = UIKit.button("Summon x1   (%d gems)" % SummonConfig.cost_for(_banner, 1), func(): _pull(1), Vector2(260, 52))
    _btn10 = UIKit.button("Summon x%d   (%d gems)" % [multi, SummonConfig.cost_for(_banner, multi)], func(): _pull(multi), Vector2(260, 52))
    buttons.add_child(_btn1)
    buttons.add_child(_btn10)
    vb.add_child(buttons)

    _msg = UIKit.label("", 18, UIKit.BAD)
    _msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(_msg)

    var center := CenterContainer.new()
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vb.add_child(center)
    _grid = GridContainer.new()
    _grid.columns = 5
    _grid.add_theme_constant_override("h_separation", 6)  # px
    _grid.add_theme_constant_override("v_separation", 6)  # px
    center.add_child(_grid)

    _result = UIKit.label("", 15, UIKit.TEXT)
    _result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _result.custom_minimum_size = Vector2(450, 0)  # px
    vb.add_child(_result)

    _flash = ColorRect.new()
    _flash.color = Color(1, 1, 1, 0)
    _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_flash)
    UIKit.fill(_flash)

    Game.changed.connect(_refresh)
    _refresh()


func _refresh() -> void:
    _pity.text = "4-star or better guaranteed in %d pulls   |   5-star guaranteed in %d pulls   |   Gems: %d   |   Beds free: %d" % [
        int(_banner["pity4"]) - Game.pity4, int(_banner["pity5"]) - Game.pity5, Game.gems, maxi(0, Game.max_hero_capacity() - Game.heroes.size())]
    _btn1.disabled = _busy or Game.gems < SummonConfig.cost_for(_banner, 1)
    _btn10.disabled = _busy or Game.gems < SummonConfig.cost_for(_banner, int(_banner["multi_count"]))


func _pull(n: int) -> void:
    if _busy:
        return
    var results: Array = Game.pull(n)
    if results.is_empty():
        var why := Game.housing_block(n)
        _msg.text = ("Cannot summon: " + why) if why != "" else "Not enough gems."
        return
    _msg.text = ""
    _busy = true
    _refresh()
    for c in _grid.get_children():
        c.queue_free()
    # D-063: the kit reveal (circle -> beam -> card -> hero), skippable, summary grid at the end
    var reveal := SummonReveal.new(results)
    add_child(reveal)
    await reveal.finished
    if not is_inside_tree():
        return
    for h in results:
        _grid.add_child(HeroCard.new(h))
    _busy = false
    _show_result(results)
    _refresh()


## Result panel for the highest-rarity hero of the pull (spec sec 2, step 8).
func _show_result(results: Array) -> void:
    var best: HeroData = results[0]
    for h in results:
        if h.stars > best.stars:
            best = h
    var trait_names: Array = []
    for t in best.traits:
        trait_names.append(String(HeroTables.TRAITS[t]["name"]))
    _result.text = "%s  -  %d-star %s  |  Traits: %s  |  Trust %d, Obedience %d\n%s" % [
        best.display_name(), best.stars, best.class_title(), ", ".join(trait_names),
        best.trust, best.obedience, best.background_text]
    _result.add_theme_color_override("font_color", best.star_color())


func _reveal(card: Control, h: HeroData) -> void:
    card.pivot_offset = card.custom_minimum_size * 0.5
    card.scale = Vector2(0.4, 0.4)
    var t := create_tween().set_parallel(true)
    t.tween_property(card, "modulate:a", 1.0, 0.16)
    t.tween_property(card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    if h.stars >= 4:
        _flash_screen(h.star_color(), 0.35 if h.stars == 4 else 0.55)
    await t.finished
    if h.stars >= 4:
        await get_tree().create_timer(0.25).timeout
    else:
        await get_tree().create_timer(0.05).timeout


func _flash_screen(c: Color, strength: float) -> void:
    _flash.color = Color(c, strength)
    var t := create_tween()
    t.tween_property(_flash, "color:a", 0.0, 0.5)
