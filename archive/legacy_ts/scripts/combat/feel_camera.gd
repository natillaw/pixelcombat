class_name FeelCamera
extends Camera2D
## Mission camera (game feel report): frame-rate independent easing toward a target position and
## zoom, zoom eased slower than position (less dizzying), and one directional screen shake at a time
## through `offset`, so shaking never moves the camera's real position. Camera only: never touches
## game time, orders or targets (CONTROL_AND_MISSIONS §8).

const FOLLOW_RATE := 9.0          # 1/s: ~63% of the gap closed in 0.11 s, settled in ~0.4 s
const ZOOM_RATE := 4.0            # 1/s: zoom settles in ~0.9 s
var target_position: Vector2 = Vector2.ZERO
var target_zoom: float = 1.0
var bounds: Rect2 = Rect2()       # world area the view must stay inside (empty = no limit)
var _amp: float = 0.0             # screen pixels
var _left: float = 0.0
var _dur: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _t: float = 0.0
## D-114 (pista C): look-ahead. The view leans a little toward where its target is heading, drawn through
## `offset` (with the shake) so the camera's real position, bounds and framing tests are unchanged.
## No zoom of its own: D-082b says the camera never zooms by itself, so the "slight boss zoom" of the
## pista C prompt is left out until the owner decides.
const LEAD_TIME := 0.25           # s of the target's motion the view leans ahead
const LEAD_MAX := 14.0            # world px
const LEAD_RATE := 3.0            # 1/s: the lean eases in and out (slight lag)
var _lead: Vector2 = Vector2.ZERO
var _last_target: Vector2 = Vector2.INF


func snap() -> void:
    _lead = Vector2.ZERO
    _last_target = target_position
    zoom = Vector2.ONE * target_zoom
    position = _clamped(target_position)
    reset_physics_interpolation()


## Keeps the view over the map: no grey void past the edge. An axis where the map is smaller than
## the view (whole-map overview) is centred instead.
func _clamped(p: Vector2) -> Vector2:
    if bounds.size.x <= 0.0 or not is_inside_tree():
        return p
    var half := get_viewport_rect().size * 0.5 / maxf(0.05, zoom.x)
    var out := p
    for axis in 2:
        var lo := bounds.position[axis] + half[axis]
        var hi := bounds.end[axis] - half[axis]
        out[axis] = (bounds.position[axis] + bounds.end[axis]) * 0.5 if lo > hi else clampf(p[axis], lo, hi)
    return out


## A new shake only replaces the current one if it is stronger than what is left of it (no stacking).
func add_shake(amplitude: float, duration: float, dir: Vector2 = Vector2.ZERO) -> void:
    var left := _amp * _falloff()
    if amplitude < left:
        return
    _amp = amplitude
    _dur = maxf(0.01, duration)
    _left = _dur
    _dir = dir.normalized() if dir.length() > 0.01 else Vector2.ZERO


func shaking() -> bool:
    return _left > 0.0


func _falloff() -> float:
    if _left <= 0.0:
        return 0.0
    var k := _left / _dur
    return k * k


func step(delta: float) -> void:
    position = position.lerp(target_position, 1.0 - exp(-FOLLOW_RATE * delta))
    var z := lerpf(zoom.x, target_zoom, 1.0 - exp(-ZOOM_RATE * delta))
    zoom = Vector2.ONE * z
    position = _clamped(position)
    _t += delta
    var tv := Vector2.ZERO
    if _last_target != Vector2.INF and delta > 0.0:
        tv = (target_position - _last_target) / delta
    _last_target = target_position
    var want := (tv * LEAD_TIME).limit_length(LEAD_MAX) if tv.length() < 2000.0 else Vector2.ZERO   # a jump is not motion
    _lead = _lead.lerp(want, 1.0 - exp(-LEAD_RATE * delta))
    var lead := _lead.round()
    if _left > 0.0:
        _left = maxf(0.0, _left - delta)
        var a := _amp * _falloff() / maxf(0.1, z)          # constant size on screen at any zoom
        var wobble := Vector2(sin(_t * 61.0), cos(_t * 47.0 + 1.3))
        if _dir != Vector2.ZERO:
            wobble = _dir * sin(_t * 70.0) + wobble * 0.35   # mostly along the blow
        offset = lead + wobble * a
    else:
        offset = lead
