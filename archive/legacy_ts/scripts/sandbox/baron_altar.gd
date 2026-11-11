class_name BaronAltar
extends Node2D
## Master prompt E: one altar of the Crimson Baron (numbers in AltarDefs). The screen owns the rules
## (phases, shield); the altar tracks who channels on it and draws itself, its menhir circle, the fallen
## adventurer and the faint thread of light to the Baron.

var boss: SandboxEnemy = null
var heroes: Array = []
var progress: float = 0.0            # seconds channeled (0..CHANNEL_TIME)
var done: bool = false               # channeled in this cycle
var _hp_seen: Dictionary = {}
var _props: Image = null
var _tex: Dictionary = {}


func _ready() -> void:
    z_index = -3
    if BosqueArt.available():
        var d: Dictionary = BosqueArt.defs()["props"]
        var img := BosqueArt._img(BosqueArt.PROPS)
        for k in ["altar", "menhir_runa", "menhir"]:
            if d.has(k) and img != null:
                var rc: Array = d[k]["rect"]
                _tex[k] = [ImageTexture.create_from_image(img.get_region(Rect2i(int(rc[0]), int(rc[1]), int(rc[2]), int(rc[3])))), d[k]["origin"]]


## Heroes standing on the altar right now (alive, not downed, not carrying).
func channelers() -> Array:
    return heroes.filter(func(h): return h.alive and not h.downed and h.position.distance_to(position) <= AltarDefs.RADIUS)


## Advances the channel; any hit on a channeler breaks it. Returns true the moment it completes.
func tick_channel(delta: float) -> bool:
    if done:
        return false
    var on := channelers()
    var hit := false
    for h in on:
        if int(_hp_seen.get(h, h.hp)) > h.hp:
            hit = true
    for h in heroes:
        _hp_seen[h] = h.hp
    if on.size() < AltarDefs.CHANNEL_HEROES or hit:
        if progress > 0.0 and hit:
            FloatingText.spawn(self, "Interrupted!", Color(1.0, 0.5, 0.4), false, 1.2)
        progress = 0.0
    else:
        progress += delta
        for h in on:
            h.credit("objective", delta / AltarDefs.CHANNEL_TIME * 2.0)
    queue_redraw()
    if progress >= AltarDefs.CHANNEL_TIME:
        done = true
        progress = 0.0
        return true
    return false


func pulse() -> float:
    return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * AltarDefs.PULSE_HZ)


func _process(_d: float) -> void:
    queue_redraw()


func _draw() -> void:
    # menhir circle (the focal point), then the altar on top
    for i in 6:
        var p := Vector2.RIGHT.rotated(TAU * float(i) / 6.0 + 0.3) * 92.0 * Vector2(1.0, 0.7)
        _blit("menhir_runa" if i % 2 == 0 else "menhir", p)
    var glow := 0.25 + 0.35 * pulse() if not done else 0.1
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
    draw_circle(Vector2.ZERO, AltarDefs.RADIUS, Color(1.0, 0.25, 0.2, glow * 0.35))
    if progress > 0.0:
        draw_arc(Vector2.ZERO, AltarDefs.RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress / AltarDefs.CHANNEL_TIME, 40, Color(1.0, 0.85, 0.4), 4.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    _blit("altar", Vector2.ZERO)
    # the fallen adventurer, a hand on the stone
    draw_rect(Rect2(Vector2(-34, 6), Vector2(20, 6)), Color(0.35, 0.3, 0.28))
    draw_circle(Vector2(-12, 8), 3.0, Color(0.85, 0.7, 0.6))
    # the thread of light to the Baron, faint, seen only up close
    if boss != null and is_instance_valid(boss) and boss.alive and boss.immune and not done:
        var near := heroes.any(func(h): return h.alive and (h.position.distance_to(position) < AltarDefs.THREAD_SEEN or h.position.distance_to(boss.position) < AltarDefs.THREAD_SEEN))
        if near:
            draw_line(Vector2(0, -14), boss.position - position + Vector2(0, -20), Color(1.0, 0.3, 0.25, 0.10 + 0.12 * pulse()), 2.0)


func _blit(key: String, at: Vector2) -> void:
    if not _tex.has(key):
        draw_rect(Rect2(at - Vector2(8, 16), Vector2(16, 16)), Color(0.5, 0.5, 0.55))
        return
    var o: Array = _tex[key][1]
    draw_texture(_tex[key][0], at - Vector2(float(o[0]), float(o[1])))
