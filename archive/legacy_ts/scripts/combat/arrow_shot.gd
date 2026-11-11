class_name ArrowShot
extends Node2D
## D-082: a hero's basic shot as a real projectile. It is NOT homing: it flies in a straight line toward
## where the target stood at release (plus the shooter's aim error) and hits the first visible foe whose
## body it touches, so a target that keeps moving can step out of it. Trees and walls stop it. Stepped by
## the shooter on the simulation clock (step()), so it is deterministic; the node only draws it.
## An arrow rotates along its flight, leaves a faint trail and stays stuck where it lands for a moment.

var dir: Vector2 = Vector2.RIGHT
var speed: float = AiDefs.SHOT_SPEED
var max_dist: float = AiDefs.BOW_RANGE
var travelled: float = 0.0
var height: float = 16.0             # drawn this far above the ground point it flies over
var kind: String = "arrow"           # look: "arrow" (stays stuck) or any other CombatVFX key (bolts)
var done: bool = false               # landed (hit, wall or end of range)
var hit_unit: Node2D = null
var stuck_t: float = 0.0
var _stuck_offset: Vector2 = Vector2.ZERO
var _trail: Array[Vector2] = []
var _sprite: AnimatedSprite2D = null


static func make(from: Vector2, aim_dir: Vector2, reach: float, look: String) -> ArrowShot:
    var a := ArrowShot.new()
    a.position = from
    a.dir = aim_dir.normalized() if aim_dir.length() > 0.01 else Vector2.RIGHT
    a.max_dist = reach
    a.kind = look
    a.rotation = 0.0
    a.z_index = 15
    return a


func _ready() -> void:
    var frames := CombatVFX.frames_for(kind, true)
    if frames != null:
        _sprite = AnimatedSprite2D.new()
        _sprite.sprite_frames = frames
        _sprite.position = Vector2(0, -height)
        _sprite.rotation = dir.angle()
        _sprite.scale = Vector2.ONE * float(CombatVFX.FX[kind][2])
        add_child(_sprite)
        _sprite.play("fx")


## Advances the shot one tick. foes = creatures it can hit; map stops it. Returns the foe hit (or null).
func step(delta: float, foes: Array, map: NavMap) -> Node2D:
    if done:
        stuck_t -= delta
        if hit_unit != null and is_instance_valid(hit_unit):
            position = hit_unit.position + _stuck_offset          # stuck in the target, moves with it
        if stuck_t <= 0.0 and is_inside_tree():
            queue_free()
        queue_redraw()
        return null
    var move := minf(speed * delta, max_dist - travelled)
    var from := position
    var to := position + dir * move
    var best: Node2D = null
    var best_t := INF
    for f in foes:
        if not is_instance_valid(f) or not f.alive or not f.visible:
            continue
        var body: float = float(f.get("body_radius")) if f.get("body_radius") != null else CombatRules.HERO_BODY
        var q := Geometry2D.get_closest_point_to_segment(f.position, from, to)
        if q.distance_to(f.position) <= body + AiDefs.SHOT_WIDTH:
            var t := from.distance_to(q)
            if t < best_t:
                best_t = t
                best = f
    if best != null:
        position = from + dir * best_t
        _land(best)
        return best
    if map != null and map.is_blocked(to):
        _land(null)                                  # a tree or a wall: the arrow sticks in it
        return null
    position = to
    travelled += move
    _trail.append(position)
    if _trail.size() > maxi(2, roundi(AiDefs.ARROW_TRAIL / maxf(0.001, delta))):
        _trail.remove_at(0)
    if travelled >= max_dist - 0.01:
        _land(null)                                  # spent: it drops to the ground
    queue_redraw()
    return null


func _land(unit: Node2D) -> void:
    done = true
    hit_unit = unit
    stuck_t = AiDefs.ARROW_STICK if kind == "arrow" else 0.0
    _trail.clear()
    if unit != null:
        _stuck_offset = position - unit.position
    if _sprite != null:
        _sprite.stop()
        if kind != "arrow":
            _sprite.visible = false
    if not is_inside_tree():
        return
    if kind != "arrow" and get_parent() != null:
        CombatVFX.play(get_parent(), position + Vector2(0, -height), "spark_small", 0.8)
    if stuck_t <= 0.0:
        queue_free()


func _draw() -> void:
    if done:
        if kind == "arrow" and _sprite == null:      # headless / no art: a short stuck stick
            var a := clampf(stuck_t / AiDefs.ARROW_STICK, 0.0, 1.0)
            draw_line(Vector2(0, -height), Vector2(0, -height) - dir * 10.0, Color(0.85, 0.75, 0.55, a), 2.0)
        if _sprite != null:
            _sprite.modulate.a = clampf(stuck_t / AiDefs.ARROW_STICK, 0.0, 1.0)
        return
    for i in range(1, _trail.size()):
        var k := float(i) / float(_trail.size())
        draw_line(_trail[i - 1] - position + Vector2(0, -height), _trail[i] - position + Vector2(0, -height), Color(1.0, 0.95, 0.8, 0.35 * k), 1.5)
    if _sprite == null:
        draw_line(Vector2(0, -height), Vector2(0, -height) - dir * 12.0, Color(0.9, 0.8, 0.6), 2.0)
