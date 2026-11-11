class_name SummonReveal
extends Control
## The summon reveal (D-063, kit art per rarity): the rarity's circle spins, a beam falls, a card back
## flips and shows the hero with its rarity frame, stars, class and traits. Higher rarity = a little more
## shake, light and sound (never blinding). Click / Skip jumps ahead; a x10 pull ends on a summary grid.
## Rarity follows stars (5-star cap for now, D-062): 1 common .. 5 legendary.

signal finished

var heroes: Array = []
var _skip_all: bool = false
var _skip_one: bool = false
var _stage: Control
var _summary: GridContainer
var summary_shown: bool = false


func _init(list: Array = []) -> void:
    heroes = list
    mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
    UIKit.fill(self)
    var dim := ColorRect.new()
    dim.color = Color(ArtPalette.INK, 0.92)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    UIKit.fill(dim)
    _stage = Control.new()
    _stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_stage)
    UIKit.fill(_stage)
    var skip := UIKit.button("Skip", func(): _skip_all = true, Vector2(120, 32))
    add_child(skip)
    skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    skip.position = Vector2(-70, 6)
    _run()


func _gui_input(e: InputEvent) -> void:
    if e is InputEventMouseButton and e.pressed:
        _skip_one = true


func _anim(kind: String, rarity: String, frame_w: int, frames: int, fps: float, loop: bool) -> AnimatedSprite2D:
    var tex: Texture2D = load(AssetCatalog.summon(kind, rarity)) if ResourceLoader.exists(AssetCatalog.summon(kind, rarity)) else null
    var s := AnimatedSprite2D.new()
    if tex == null:
        return s
    var sf := SpriteFrames.new()
    sf.set_animation_loop("default", loop)
    sf.set_animation_speed("default", fps)
    for i in frames:
        var at := AtlasTexture.new()
        at.atlas = tex
        at.region = Rect2(i * frame_w, 0, frame_w, tex.get_height())
        sf.add_frame("default", at)
    s.sprite_frames = sf
    s.play()
    return s


func _wait(t: float) -> void:
    var left := t
    while left > 0.0 and not _skip_all and not _skip_one and is_inside_tree():
        await get_tree().process_frame
        left -= get_process_delta_time()


func _run() -> void:
    await get_tree().process_frame
    var centre := size * 0.5
    for h in heroes:
        if _skip_all or not is_inside_tree():
            break
        _skip_one = false
        var hd := h as HeroData
        var rarity := ArtPalette.rarity_of_stars(hd.stars)
        for c in _stage.get_children():
            c.queue_free()
        var circle := _anim("summon_circle", rarity, 64, 8, 10.0, true)
        circle.position = centre + Vector2(0, 40)
        circle.scale = Vector2(2, 2)
        _stage.add_child(circle)
        await _wait(0.5)
        var beam := _anim("summon_beam", rarity, 24, 6, 12.0, false)
        beam.position = centre + Vector2(0, -24)
        beam.scale = Vector2(2, 2)
        _stage.add_child(beam)
        UIKit.sound("pull_%s" % ("legendary" if hd.stars >= 4 else ("epic" if hd.stars == 3 else ("rare" if hd.stars == 2 else "common"))))
        if hd.stars >= 3:
            _shake(2.0 + float(hd.stars - 3) * 2.0)
        await _wait(0.45)
        var card := TextureRect.new()
        card.texture = load(AssetCatalog.summon("card_back", rarity)) if ResourceLoader.exists(AssetCatalog.summon("card_back", rarity)) else null
        card.position = centre + Vector2(-40, -56)
        card.scale = Vector2(2, 2)
        card.pivot_offset = Vector2(20, 28)
        _stage.add_child(card)
        var t := card.create_tween()
        t.tween_property(card, "scale:x", 0.0, 0.18)
        await _wait(0.4)
        card.visible = false
        _stage.add_child(_hero_card(hd, centre))
        await _wait(1.1 if hd.stars < 3 else 1.8)
    _show_summary()


func _shake(px: float) -> void:
    var t := create_tween()
    for i in 4:
        t.tween_property(_stage, "position", Vector2(px if i % 2 == 0 else -px, 0), 0.04)
    t.tween_property(_stage, "position", Vector2.ZERO, 0.04)


## The revealed hero: rarity frame, sprite, name, stars, class and its traits.
func _hero_card(hd: HeroData, centre: Vector2) -> Control:
    var pc := PanelContainer.new()
    var rarity := ArtPalette.rarity_of_stars(hd.stars)
    pc.add_theme_stylebox_override("panel", UIKit.nine(AssetCatalog.KIT + "ui/rarity_frame_%s.png" % rarity, 6, 0, 0, 8))
    var v := VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    pc.add_child(v)
    var portrait := HeroPortrait.new(hd, 2.0)
    portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    v.add_child(portrait)
    var nm := UIKit.label(hd.display_name(), 20, ArtPalette.rarity_color(rarity))
    nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(nm)
    var stars := StarRow.new(hd.stars, 16.0)
    stars.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_child(stars)
    v.add_child(UIKit.label("%s · %s" % [hd.class_title(), rarity.capitalize()], 14, UIKit.TEXT))
    for tr in hd.traits:
        v.add_child(UIKit.label(String(HeroTables.TRAITS[tr]["name"]), 12, UIKit.MUTED))
    pc.size = pc.get_combined_minimum_size()
    pc.position = (centre - pc.size * 0.5).floor()
    return pc


func _show_summary() -> void:
    for c in _stage.get_children():
        c.queue_free()
    var center := CenterContainer.new()
    _stage.add_child(center)
    UIKit.fill(center)
    var v := VBoxContainer.new()
    center.add_child(v)
    v.add_child(UIKit.label("Summoned", 28, UIKit.ACCENT))
    _summary = GridContainer.new()
    _summary.columns = 5
    v.add_child(_summary)
    for h in heroes:
        var hd := h as HeroData
        var rarity := ArtPalette.rarity_of_stars(hd.stars)
        var pc := PanelContainer.new()
        pc.add_theme_stylebox_override("panel", UIKit.nine(AssetCatalog.KIT + "ui/rarity_frame_%s.png" % rarity, 6, 0, 0, 4))
        pc.tooltip_text = "%s\n%d stars · %s" % [hd.display_name(), hd.stars, hd.class_title()]
        var cv := VBoxContainer.new()
        cv.add_theme_constant_override("separation", 0)
        pc.add_child(cv)
        cv.add_child(HeroPortrait.new(hd, 1.0))
        cv.add_child(StarRow.new(hd.stars, 9.0))
        cv.add_child(UIKit.label(hd.hero_name.split(" ")[0], 12, ArtPalette.rarity_color(rarity)))
        _summary.add_child(pc)
    v.add_child(UIKit.button("Done", close, Vector2(200, 36)))
    summary_shown = true


## Ends the reveal (the summary's Done button).
func close() -> void:
    finished.emit()
    queue_free()
