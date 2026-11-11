class_name HeroPortrait
extends Control
## A hero's sprite with a rarity aura behind it. 3-star and up get a glow,
## 4-star and up pulse, 5-star also throw sparkles. All built in code.

var hero: HeroData
var pixel_scale: float = 3.0
var _sprite: Sprite2D


func _init(h: HeroData = null, scale_px: float = 3.0) -> void:
    hero = h
    pixel_scale = scale_px
    custom_minimum_size = Vector2(SpriteComposer.FRAME, SpriteComposer.FRAME) * scale_px
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
    if hero == null:
        return
    var col := hero.star_color()
    var box := custom_minimum_size

    if hero.stars >= 3:
        var grad := Gradient.new()
        grad.colors = PackedColorArray([Color(col, 0.60), Color(col, 0.0)])
        grad.offsets = PackedFloat32Array([0.0, 1.0])
        var gt := GradientTexture2D.new()
        gt.gradient = grad
        gt.fill = GradientTexture2D.FILL_RADIAL
        gt.fill_from = Vector2(0.5, 0.5)
        gt.fill_to = Vector2(1.0, 0.5)
        gt.width = 96
        gt.height = 96
        var aura := TextureRect.new()
        aura.texture = gt
        aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        aura.stretch_mode = TextureRect.STRETCH_SCALE
        aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(aura)
        aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        if hero.stars >= 4:
            var pulse := create_tween().set_loops()
            pulse.tween_property(aura, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
            pulse.tween_property(aura, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)

    _sprite = Sprite2D.new()
    _sprite.texture = SpriteComposer.pose_texture(hero, "idle")
    _sprite.centered = true
    _sprite.scale = Vector2.ONE * pixel_scale
    var base := Vector2(box.x * 0.5, box.y * 0.5)
    _sprite.position = base
    add_child(_sprite)

    # gentle idle bob
    var bob := create_tween().set_loops()
    bob.tween_property(_sprite, "position:y", base.y - pixel_scale, 0.75).set_trans(Tween.TRANS_SINE)
    bob.tween_property(_sprite, "position:y", base.y, 0.75).set_trans(Tween.TRANS_SINE)

    if hero.stars >= 5:
        var p := CPUParticles2D.new()
        p.amount = 14
        p.lifetime = 1.7
        p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
        p.emission_rect_extents = Vector2(box.x * 0.30, 3.0)
        p.direction = Vector2(0, -1)
        p.spread = 25.0
        p.gravity = Vector2.ZERO
        p.initial_velocity_min = 10.0
        p.initial_velocity_max = 26.0
        p.scale_amount_min = 1.5
        p.scale_amount_max = 3.0
        p.color = Color(1.0, 0.9, 0.5, 0.9)
        p.position = Vector2(box.x * 0.5, box.y * 0.85)
        add_child(p)
