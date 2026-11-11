class_name WorldLife
extends Node2D
## D-113 (pista C): a living expedition map, presentation only. Cloud shadows drifting over the floor,
## floating dust, birds that sit in clearings and fly off when a hero comes close, and a puff of dust
## when a hero brakes or turns sharply. Reads hero positions, never moves anything real.
## Ambience.quality (Options: visual effects) 0 = off, 1 = low, 2 = high.

const CLOUDS := {1: 2, 2: 4}
const BIRDS := {1: 3, 2: 6}
const BIRD_FLEE_RADIUS := 70.0
const BIRD_COLOR := Color(0.22, 0.18, 0.16)
const CLOUD_SPEED := Vector2(9.0, 3.0)      # px/s
const CLOUD_ALPHA := 0.10
const BRAKE_SPEED := 40.0                   # px/s a hero must have been moving at
const TURN_DOT := -0.2                      # direction change sharper than ~100 degrees
const DUST_COOLDOWN := 0.35
const MAX_RUN_SPEED := 400.0                # faster than this is a teleport/blink, not running

var screen: Node = null                     # SandboxScreen (heroes, map)
var world_size: Vector2 = Vector2(1000, 1000)
var _clouds: Array = []                     # [pos, radius]
var _birds: Array = []                      # {"pos", "vel", "flying", "t", "home"}
var _last: Dictionary = {}                  # hero id -> [pos, vel, dust cooldown]
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0


static func create(p_screen: Node, p_world_size: Vector2, seed_value: int) -> WorldLife:
    var w := WorldLife.new()
    w.screen = p_screen
    w.world_size = p_world_size
    w._rng.seed = seed_value
    w.z_index = -3                          # over the floor, under units and telegraphs
    w.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    return w


func _ready() -> void:
    if Ambience.quality <= 0 or SimMode.on:
        set_process(false)
        return
    for i in int(CLOUDS.get(Ambience.quality, 2)):
        _clouds.append([Vector2(_rng.randf() * world_size.x, _rng.randf() * world_size.y), _rng.randf_range(90.0, 170.0)])
    var spots := _clearings(int(BIRDS.get(Ambience.quality, 3)))
    for p in spots:
        _birds.append({"pos": p, "vel": Vector2.ZERO, "flying": false, "t": _rng.randf() * 3.0, "home": p})


## Walkable spots away from the heroes' start, for the birds to sit on.
func _clearings(n: int) -> Array:
    var out: Array = []
    var map = screen.get("map") if screen != null else null
    for tries in n * 20:
        if out.size() >= n:
            break
        var p := Vector2(_rng.randf() * world_size.x, _rng.randf() * world_size.y).round()
        if map is NavMap and (map as NavMap).is_blocked(p):
            continue
        out.append(p)
    return out


func _heroes() -> Array:
    var hs = screen.get("heroes") if screen != null else null
    return hs if hs is Array else []


func _process(delta: float) -> void:
    _t += delta
    for c in _clouds:
        var cp: Vector2 = c[0] + CLOUD_SPEED * delta + Vector2(200, 200)
        c[0] = Vector2(fposmod(cp.x, world_size.x + 400.0), fposmod(cp.y, world_size.y + 400.0)) - Vector2(200, 200)
    var hs := _heroes()
    for b in _birds:
        b["t"] = float(b["t"]) + delta
        if not b["flying"]:
            for h in hs:
                if is_instance_valid(h) and h.visible and (h as Node2D).position.distance_to(b["pos"]) < BIRD_FLEE_RADIUS:
                    b["flying"] = true
                    var away: Vector2 = (b["pos"] - (h as Node2D).position).normalized()
                    b["vel"] = (away + Vector2(0, -0.8)).normalized() * 120.0
                    break
        else:
            b["pos"] = b["pos"] + b["vel"] * delta
            b["vel"] = b["vel"] * (1.0 + 0.6 * delta)
    _birds = _birds.filter(func(b): return not b["flying"] or Rect2(Vector2(-200, -200), world_size + Vector2(400, 400)).has_point(b["pos"]))
    _brake_dust(hs, delta)
    queue_redraw()


## A puff of dust under a hero that stops hard or turns sharply (looks only).
func _brake_dust(hs: Array, delta: float) -> void:
    for h in hs:
        if not is_instance_valid(h) or not (h as Node2D).visible or not h.get("alive"):
            continue
        var id: int = h.get_instance_id()
        var pos: Vector2 = (h as Node2D).position
        var prev: Array = _last.get(id, [pos, Vector2.ZERO, 0.0])
        var vel: Vector2 = (pos - prev[0]) / maxf(0.001, delta)
        var cd := maxf(0.0, float(prev[2]) - delta)
        var was: Vector2 = prev[1]
        if cd <= 0.0 and was.length() > BRAKE_SPEED and was.length() < MAX_RUN_SPEED and vel.length() < MAX_RUN_SPEED:
            var braked := vel.length() < was.length() * 0.25
            var turned := vel.length() > BRAKE_SPEED and was.normalized().dot(vel.normalized()) < TURN_DOT
            if braked or turned:
                CombatVFX.play(get_parent(), pos.round(), "dust", 0.5, vel.x < 0.0)
                cd = DUST_COOLDOWN
        _last[id] = [pos, vel, cd]


func _draw() -> void:
    for c in _clouds:
        var p: Vector2 = c[0]
        var r: float = c[1]
        draw_set_transform(p.round(), 0.0, Vector2(1.0, 0.6))
        draw_circle(Vector2.ZERO, r, Color(0, 0, 0.05, CLOUD_ALPHA * 0.5))
        draw_circle(Vector2(r * 0.35, -r * 0.1), r * 0.7, Color(0, 0, 0.05, CLOUD_ALPHA * 0.5))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    for b in _birds:
        var p: Vector2 = (b["pos"] as Vector2).round()
        var flap := int(float(b["t"]) * (12.0 if b["flying"] else 1.5)) % 2 == 0
        if b["flying"]:
            # little "v" flapping: 2 px wings
            var wy := -1.0 if flap else 1.0
            draw_rect(Rect2(p, Vector2(1, 1)), BIRD_COLOR)
            draw_rect(Rect2(p + Vector2(-2, wy), Vector2(2, 1)), BIRD_COLOR)
            draw_rect(Rect2(p + Vector2(1, wy), Vector2(2, 1)), BIRD_COLOR)
        else:
            draw_rect(Rect2(p + Vector2(-1, -2), Vector2(3, 2)), BIRD_COLOR)
            draw_rect(Rect2(p + Vector2(1 if flap else -2, -3), Vector2(1, 1)), BIRD_COLOR)   # head pecking
            draw_rect(Rect2(p + Vector2(-2, 0), Vector2(5, 1)), Color(0, 0, 0, 0.2))
