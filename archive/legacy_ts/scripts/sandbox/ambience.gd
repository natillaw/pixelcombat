class_name Ambience
extends RefCounted
## Overhaul phase 8 (light polish): flickering lights on fires and the altar, falling leaves and
## fireflies that follow the camera, and a soft vignette. quality (Options): 0 off, 1 low, 2 high.
## Never touches telegraphs or orders: everything sits under them (z) and is faint.

static var quality: int = 2
const LEAVES := {1: 6, 2: 14}          # particles on screen per quality
const FIREFLIES := {1: 8, 2: 18}


static func _glow_texture(radius: int, color: Color) -> GradientTexture2D:
    var g := Gradient.new()
    g.set_color(0, color)
    g.set_color(1, Color(color, 0.0))
    var t := GradientTexture2D.new()
    t.gradient = g
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to = Vector2(1.0, 0.5)
    t.width = radius * 2
    t.height = radius * 2
    return t


## A warm light that flickers (fires) or pulses (altar), as a soft additive glow under the units.
static func add_light(parent: Node2D, at: Vector2, color: Color, radius: int = 70, pulse: bool = false) -> void:
    if quality <= 0:
        return
    var s := Sprite2D.new()
    s.texture = _glow_texture(radius, Color(color, 0.45))
    s.position = at
    s.z_index = -4
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    s.material = mat
    parent.add_child(s)
    var tw := s.create_tween().set_loops()
    if pulse:
        tw.tween_property(s, "modulate:a", 0.55, 1.1).set_trans(Tween.TRANS_SINE)
        tw.tween_property(s, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
    else:
        for i in 4:
            tw.tween_property(s, "modulate:a", randf_range(0.7, 1.0), randf_range(0.08, 0.2))


## Leaves and fireflies drifting over the view; attach to the camera so they follow it.
static func add_particles(camera: Node2D, view_size: Vector2) -> void:
    if quality <= 0:
        return
    var leaves := CPUParticles2D.new()
    leaves.amount = int(LEAVES.get(quality, 6))
    leaves.lifetime = 7.0
    leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    leaves.emission_rect_extents = Vector2(view_size.x * 0.6, 10)
    leaves.position = Vector2(0, -view_size.y * 0.6)
    leaves.direction = Vector2(0.3, 1)
    leaves.spread = 20.0
    leaves.gravity = Vector2(6, 14)
    leaves.initial_velocity_min = 8.0
    leaves.initial_velocity_max = 18.0
    leaves.angular_velocity_min = -90.0
    leaves.angular_velocity_max = 90.0
    leaves.scale_amount_min = 1.5
    leaves.scale_amount_max = 2.5
    leaves.color = Color(0.55, 0.7, 0.3, 0.7)
    leaves.z_index = 30
    camera.add_child(leaves)
    var flies := CPUParticles2D.new()
    flies.amount = int(FIREFLIES.get(quality, 8))
    flies.lifetime = 5.0
    flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    flies.emission_rect_extents = view_size * 0.55
    flies.gravity = Vector2.ZERO
    flies.initial_velocity_min = 2.0
    flies.initial_velocity_max = 8.0
    flies.spread = 180.0
    flies.scale_amount_min = 1.0
    flies.scale_amount_max = 1.5
    flies.color = Color(1.0, 0.95, 0.55, 0.8)
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1, 1, 1, 0))
    ramp.add_point(0.5, Color(1, 1, 1, 1))
    ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
    flies.color_ramp = ramp
    flies.z_index = 30
    camera.add_child(flies)


## A soft dark vignette over the play area (UI stays above it).
static func add_vignette(parent: Control) -> void:
    if quality <= 0:
        return
    var g := Gradient.new()
    g.set_color(0, Color(0, 0, 0, 0))
    g.add_point(0.7, Color(0, 0, 0, 0))
    g.set_color(g.get_point_count() - 1, Color(0.02, 0.01, 0.0, 0.45))
    var t := GradientTexture2D.new()
    t.gradient = g
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to = Vector2(1.05, 0.5)
    var r := TextureRect.new()
    r.texture = t
    r.stretch_mode = TextureRect.STRETCH_SCALE
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(r)
    r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --- D-113 (pista C): wind and floating dust -------------------------------------------------------

const WIND_SHADER := "res://assets/shaders/wind_sway.gdshader"
const DUST := {1: 6, 2: 14}
static var _wind: Dictionary = {}


## Shared wind material. sprite_mode true for separate sprites (trees, grass, bushes: pista B can put it
## on the town's), false for a baked map texture (only the canopy moves). null when effects are off.
static func wind_material(sprite_mode: bool = true) -> ShaderMaterial:
    if quality <= 0 or not ResourceLoader.exists(WIND_SHADER):
        return null
    if not _wind.has(sprite_mode):
        var m := ShaderMaterial.new()
        m.shader = load(WIND_SHADER)
        m.set_shader_parameter("sprite_mode", sprite_mode)
        _wind[sprite_mode] = m
    return _wind[sprite_mode]


## Specks of dust floating in the light over the view; attach to the camera.
static func add_dust(camera: Node2D, view_size: Vector2) -> void:
    if quality <= 0:
        return
    var d := CPUParticles2D.new()
    d.amount = int(DUST.get(quality, 6))
    d.lifetime = 6.0
    d.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    d.emission_rect_extents = view_size * 0.55
    d.gravity = Vector2(1.5, -1.0)
    d.initial_velocity_min = 1.0
    d.initial_velocity_max = 4.0
    d.spread = 180.0
    d.scale_amount_min = 1.0
    d.scale_amount_max = 1.0
    d.color = Color(1.0, 0.95, 0.8, 0.35)
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1, 1, 1, 0))
    ramp.add_point(0.5, Color(1, 1, 1, 1))
    ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
    d.color_ramp = ramp
    d.z_index = 29
    camera.add_child(d)
