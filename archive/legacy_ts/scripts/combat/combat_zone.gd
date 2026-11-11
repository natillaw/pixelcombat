class_name CombatZone
extends Node2D
## A lasting area left by a skill (smoke, trap, holy ground). Every PULSE seconds it applies a status
## to the units inside it. `units` is the live array of possible targets (the screen's enemies or
## heroes), so units that arrive later are also affected.

const PULSE := 0.5

var radius: float = 60.0
var duration: float = 5.0
var status_id: String = ""
var status_dur: float = 1.0
var magnitude: float = 0.0
var units: Array = []
var source: Node2D = null
var color: Color = Color(1, 1, 1)
var once: bool = false             # traps: each unit is caught only once
var _caught: Dictionary = {}
var _t: float = 0.0
var _pulse: float = 0.0


static func spawn(parent: Node, at: Vector2, p_radius: float, p_duration: float, p_status: String, p_sdur: float,
        p_mag: float, p_units: Array, p_source: Node2D, p_once: bool = false) -> CombatZone:
    var z := CombatZone.new()
    z.position = at
    z.radius = p_radius
    z.duration = p_duration
    z.status_id = p_status
    z.status_dur = p_sdur
    z.magnitude = p_mag
    z.units = p_units
    z.source = p_source
    z.once = p_once
    z.color = CombatRules.STATUS.get(p_status, {}).get("color", Color(1, 1, 1))
    z.z_index = -1
    if parent != null:
        parent.add_child(z)
    var look: Array = CombatVFX.ZONE_FX.get(p_status, [])
    if not look.is_empty():
        CombatVFX.attach(z, String(look[0]), Vector2.ZERO, p_radius / float(look[1]), true)
        if p_status == "weaken":                          # a smoke screen is several puffs
            for k in 4:
                var off := Vector2(cos(k * TAU / 4.0), sin(k * TAU / 4.0) * 0.55) * p_radius * 0.55
                CombatVFX.attach(z, "smoke", off, p_radius / 50.0)
    return z


func _physics_process(delta: float) -> void:
    tick(delta)


func tick(delta: float) -> void:
    _t += delta
    _pulse -= delta
    if _pulse <= 0.0:
        _pulse = PULSE
        for u in units:
            if not is_instance_valid(u) or not u.alive or u.position.distance_to(position) > radius:
                continue
            if once and _caught.has(u.get_instance_id()):
                continue
            _caught[u.get_instance_id()] = true
            (u as Combatant).apply_status(status_id, status_dur, magnitude, source if is_instance_valid(source) else null)
    queue_redraw()
    if _t >= duration:
        queue_free()


func _draw() -> void:
    var a := 0.12 + 0.08 * sin(_t * 4.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
    draw_circle(Vector2.ZERO, radius, Color(color, a))
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.6), 2.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
