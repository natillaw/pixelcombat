class_name CombatFeel
extends RefCounted
## Presentation-only impact feedback (game feel report): screen shake by category, a very short LOCAL
## impact freeze, knock-back slides and the area flash that shows the real radius of an area skill.
## Never touches game time, damage, cooldowns or positions used by the rules: D-014 forbids pausing or
## slowing the simulation, so the "hit stop" here only holds the sprites of the units involved.

## Shake in SCREEN pixels and seconds. Small: a crit or a heavy creature's blow; medium: a big area skill,
## a boss blow, a hero going down; large: a hero's permanent death or a major skill.
## D-110 (pista C): never more than JuiceDefs.MAX_SHAKE (2 px) on screen.
const SHAKE := {"small": [1.0, 0.12], "medium": [1.5, 0.18], "large": [2.0, 0.25]}
## Impact freeze (sprites only) in seconds. Light basic hits get none.
const FREEZE := {"crit": 0.04, "heavy": 0.05, "boss": 0.05, "death": 0.05}   # D-110: 0.03-0.05 s
const SLIDE_TIME := 0.16                 # knock-back: the sprite slides from where it was hit
const AREA_FLASH_TIME := 0.45
## Player accessibility multiplier (0 = no shake). Kept here until there is an options screen.
static var shake_scale: float = 1.0


static func shake(from: Node, kind: String, dir: Vector2 = Vector2.ZERO) -> void:
    if SimMode.on:
        return
    if from == null or not from.is_inside_tree() or not SHAKE.has(kind) or shake_scale <= 0.0:
        return
    if kind == "small" and not shake_allowed(from):
        return
    var s: Array = SHAKE[kind]
    shake_px(from, float(s[0]), float(s[1]), dir)


## D-110 filter: a common creature's ordinary blow never shakes the camera (only bosses, crits,
## finishing blows and heavy skills do). Read only.
static func shake_allowed(from: Node) -> bool:
    if from == null or from.get("is_boss") == null:
        return true                                  # heroes call shake only for crits and skills
    if from.get("is_boss") == true:
        return true
    return String(from.get("casting_skill")) != "" or from.get("alive") == false


## Camera shake of `px` screen pixels (capped at JuiceDefs.MAX_SHAKE).
static func shake_px(from: Node, px: float, duration: float, dir: Vector2 = Vector2.ZERO) -> void:
    if SimMode.on or from == null or not from.is_inside_tree() or shake_scale <= 0.0:
        return
    var cam := from.get_viewport().get_camera_2d()
    if cam is FeelCamera:
        (cam as FeelCamera).add_shake(minf(px, JuiceDefs.MAX_SHAKE) * shake_scale, duration, dir)


## Holds a sprite's frame (and its pose tween) for a few hundredths of a second. The unit keeps
## moving and fighting: only the drawing stops.
static func freeze(sprite: AnimatedSprite2D, kind: String) -> void:
    if SimMode.on:
        return
    if sprite == null or not sprite.is_inside_tree() or not FREEZE.has(kind):
        return
    var tw: Tween = null
    if sprite.has_meta("anim_tween") and sprite.get_meta("anim_tween") is Tween:
        tw = sprite.get_meta("anim_tween")
        if tw.is_valid():
            tw.pause()
    sprite.pause()
    # B4: a tween owned by the sprite dies with it, so the callback never runs on a freed node
    sprite.create_tween().tween_callback(func():
        if not sprite.is_playing():
            sprite.play()
        if tw != null and tw.is_valid():
            tw.play()
    ).set_delay(float(FREEZE[kind]))


## D-110: render-only freeze for a given time (0.03-0.05 s from JuiceProfile).
static func freeze_for(sprite: CanvasItem, seconds: float) -> void:
    if SimMode.on or not (sprite is AnimatedSprite2D) or not sprite.is_inside_tree() or seconds <= 0.0:
        return
    var a := sprite as AnimatedSprite2D
    a.pause()
    a.create_tween().tween_callback(func():
        if not a.is_playing():
            a.play()
    ).set_delay(clampf(seconds, JuiceDefs.FREEZE_MIN, JuiceDefs.FREEZE_MAX))


## The unit already moved (rules); its sprite starts at the old spot and slides home.
static func slide(sprite: Node2D, from_offset: Vector2) -> void:
    if SimMode.on:
        return
    if sprite == null or not sprite.is_inside_tree() or from_offset.length() < 1.0:
        return
    if sprite.has_meta("anim_tween") and sprite.get_meta("anim_tween") is Tween:
        var old: Tween = sprite.get_meta("anim_tween")
        if old.is_valid():
            old.kill()
    sprite.position = from_offset
    var t := sprite.create_tween()
    sprite.set_meta("anim_tween", t)
    t.tween_property(sprite, "position", Vector2.ZERO, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Ground flash exactly as big as the area that was hit (the art around it is decoration).
static func area_flash(parent: Node, centre: Vector2, radius: float, color: Color) -> void:
    if SimMode.on:
        return
    if parent == null or radius <= 0.0:
        return
    var f := AreaFlash.new()
    f.position = centre
    f.radius = radius
    f.color = color
    f.z_index = -5
    parent.add_child(f)


## Drawn under the units: a filled ellipse that fades and a ring that snaps out to the real radius.
class AreaFlash extends Node2D:
    var radius: float = 60.0
    var color: Color = Color(1.0, 0.7, 0.25)
    var _t: float = 0.0

    func _ready() -> void:
        physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

    func _process(delta: float) -> void:
        _t += delta
        if _t >= CombatFeel.AREA_FLASH_TIME:
            queue_free()
        queue_redraw()

    func _draw() -> void:
        var k := clampf(_t / CombatFeel.AREA_FLASH_TIME, 0.0, 1.0)
        var grow := minf(1.0, _t / 0.08)                       # the ring reaches the edge in 80 ms
        draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
        draw_circle(Vector2.ZERO, radius, Color(color, 0.22 * (1.0 - k)))
        draw_arc(Vector2.ZERO, radius * (0.75 + 0.25 * grow), 0.0, TAU, 48, Color(color, 0.9 * (1.0 - k)), 3.0)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
